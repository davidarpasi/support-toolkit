[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string]$PingTarget = '1.1.1.1',
    [ValidateNotNullOrEmpty()][string]$DnsName = 'example.com',
    [switch]$AsJson,
    [switch]$IncludeAddresses
)

$failures = [System.Collections.Generic.List[string]]::new()
$adapters = @()
$routes = @()
$dns = @()
$pingOk = $false

try {
    $index = 0
    $adapters = @(Get-NetIPConfiguration -ErrorAction Stop | ForEach-Object {
        $index++
        [pscustomobject]@{
            Name = if ($IncludeAddresses) { $_.InterfaceAlias } else { "adapter-$index" }
            IPv4 = @(if ($IncludeAddresses) { $_.IPv4Address.IPAddress } else { '[redacted]' })
            Gateway = @(if ($IncludeAddresses) { $_.IPv4DefaultGateway.NextHop } else { '[redacted]' })
        }
    })
    if ($adapters.Count -eq 0) { $failures.Add('No network configuration found.') }
} catch { $failures.Add('Could not read network configuration.') }

try {
    $routes = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            Destination = if ($IncludeAddresses) { $_.DestinationPrefix } else { '[redacted]' }
            NextHop = if ($IncludeAddresses) { $_.NextHop } else { '[redacted]' }
            Metric = $_.RouteMetric
        }
    })
} catch { $failures.Add('Could not read the IPv4 routing table.') }

try {
    $pingOk = [bool](Test-Connection -ComputerName $PingTarget -Count 2 -Quiet -ErrorAction Stop)
    if (-not $pingOk) { $failures.Add('The ping target did not respond.') }
} catch { $failures.Add('The ping check failed.') }

try {
    $dns = @(Resolve-DnsName -Name $DnsName -ErrorAction Stop | Where-Object { $_.IPAddress } | ForEach-Object {
        [pscustomobject]@{
            Type = [string]$_.Type
            Address = if ($IncludeAddresses) { $_.IPAddress } else { '[redacted]' }
        }
    })
    if ($dns.Count -eq 0) { $failures.Add('DNS returned no address records.') }
} catch { $failures.Add('The DNS lookup failed.') }

$report = [pscustomobject]@{
    AddressesIncluded = [bool]$IncludeAddresses
    PingTarget = if ($IncludeAddresses) { $PingTarget } else { '[redacted]' }
    DnsName = if ($IncludeAddresses) { $DnsName } else { '[redacted]' }
    PingSucceeded = $pingOk
    Adapters = @($adapters)
    Routes = @($routes)
    DnsResults = @($dns)
    Errors = @($failures.ToArray())
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    "Network configuration entries: $($adapters.Count)"
    "IPv4 routes: $($routes.Count)"
    "Ping succeeded: $pingOk"
    "DNS address records: $($dns.Count)"
    if (-not $IncludeAddresses) { 'Addresses and target names are redacted. Use -AsJson for a structured report.' }
    foreach ($failure in $failures) { "Check failed: $failure" }
}

if ($failures.Count -gt 0) { exit 1 }
exit 0
