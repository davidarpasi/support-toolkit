# Support Toolkit

I started this to keep useful diagnostics from my support work in one place. At the moment it contains one PowerShell script for Windows network checks.

It collects network configuration and IPv4 routes, checks a ping target, and looks up a DNS name. It does not change settings or perform cleanup.

## Run it

Use PowerShell on Windows. Administrator access is not normally needed for these read-only checks. The network commands depend on the Windows networking modules.

```powershell
./powershell-scripts/get-network-info.ps1
./powershell-scripts/get-network-info.ps1 -PingTarget 1.1.1.1 -DnsName example.com -AsJson
```

The targets are configurable because a blocked ping or a failed external DNS lookup does not automatically mean the local network is broken. The script sends two ICMP probes and makes a DNS query.

## Shareable output

JSON output hides addresses, interface names and target names by default. Use `-IncludeAddresses` when you need the actual values for a local investigation. Review that output before sharing it.

```powershell
./powershell-scripts/get-network-info.ps1 -AsJson > network-report.json
./powershell-scripts/get-network-info.ps1 -AsJson -IncludeAddresses
```

Exit code `0` means the collection and checks succeeded. Exit code `1` means at least one check or collection failed. Other available results are still included in the report. A failed probe can reflect a firewall policy rather than an outage.

For an unreachable target, `PingSucceeded` is false and `Errors` contains a short explanation. Raw exception messages are not copied into the report.

## Tests

```powershell
./tests/test-network-info.ps1
```

The tests use mocked network commands. They cover successful output, redaction, failed checks and partial results without sending probes. GitHub Actions runs them on Windows.

I’ll add more tools when there is a concrete troubleshooting task for them. A Linux version is a possible next step.

MIT license.
