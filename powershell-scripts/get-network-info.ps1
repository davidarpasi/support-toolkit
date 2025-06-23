# get-network-info.ps1
# Collects detailed network information for diagnostics

Write-Host "Collecting network configuration..." -ForegroundColor Cyan
Get-NetIPConfiguration | Format-List

Write-Host "Active network adapters:" -ForegroundColor Cyan
Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Format-Table Name, Status, LinkSpeed, MacAddress

Write-Host "Routing table (IPv4):" -ForegroundColor Cyan
Get-NetRoute -AddressFamily IPv4 | Format-Table DestinationPrefix, NextHop, InterfaceAlias, RouteMetric

Write-Host "Testing internet connectivity..." -ForegroundColor Cyan
Test-Connection -ComputerName 8.8.8.8 -Count 4

Write-Host "Testing DNS resolution..." -ForegroundColor Cyan
Resolve-DnsName google.com
