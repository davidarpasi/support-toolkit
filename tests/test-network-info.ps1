$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '../powershell-scripts/get-network-info.ps1'
$worker = Join-Path ([System.IO.Path]::GetTempPath()) ('network-test-' + [guid]::NewGuid() + '.ps1')
@'
param([string]$ScriptPath, [string]$Scenario)
function Get-NetIPConfiguration {
    param($ErrorAction)
    if ($Scenario -eq 'partial') { throw 'private-machine-name' }
    [pscustomobject]@{ InterfaceAlias='private-adapter'; IPv4Address=[pscustomobject]@{IPAddress='192.0.2.10'}; IPv4DefaultGateway=[pscustomobject]@{NextHop='192.0.2.1'} }
}
function Get-NetRoute {
    param($AddressFamily, $ErrorAction)
    [pscustomobject]@{DestinationPrefix='0.0.0.0/0';NextHop='192.0.2.1';RouteMetric=25}
}
function Test-Connection {
    param($ComputerName, $Count, [switch]$Quiet, $ErrorAction)
    return ($Scenario -ne 'failed')
}
function Resolve-DnsName {
    param($Name, $ErrorAction)
    if ($Scenario -eq 'failed') { throw 'private-dns-error' }
    [pscustomobject]@{Type='A';IPAddress='203.0.113.1'}
}
& $ScriptPath -AsJson -PingTarget private-target -DnsName private-name -IncludeAddresses:($Scenario -eq 'addresses')
exit $LASTEXITCODE
'@ | Set-Content -Path $worker -Encoding utf8

try {
    foreach ($scenario in @('success', 'failed', 'partial', 'addresses')) {
        $raw = & (Get-Process -Id $PID).Path -NoProfile -File $worker -ScriptPath $scriptPath -Scenario $scenario
        $code = $LASTEXITCODE
        $report = ($raw -join "`n") | ConvertFrom-Json
        $expected = if ($scenario -in @('failed', 'partial')) { 1 } else { 0 }
        if ($code -ne $expected) { throw "$scenario returned $code, expected $expected" }
        if ($scenario -ne 'addresses' -and ($raw -join '') -match 'private-|192\.0\.2\.|203\.0\.113\.') { throw "$scenario leaked identifying details" }
        if ($scenario -eq 'success' -and (-not $report.PingSucceeded -or $report.Errors.Count -ne 0)) { throw 'Success report is incorrect' }
        if ($scenario -eq 'failed' -and ($report.PingSucceeded -or $report.Errors.Count -ne 2)) { throw 'Failure report is incorrect' }
        if ($scenario -eq 'partial' -and (-not $report.PingSucceeded -or $report.Routes.Count -ne 1 -or $report.Errors.Count -ne 1)) { throw 'Partial results were lost' }
        if ($scenario -eq 'addresses' -and ($report.Adapters[0].IPv4[0] -ne '192.0.2.10' -or -not $report.AddressesIncluded)) { throw 'Address opt-in is incorrect' }
        Write-Output "Passed: $scenario"
    }
} finally {
    Remove-Item -LiteralPath $worker -ErrorAction SilentlyContinue
}
