# SentinelOne Deep Visibility Passive Diagnostics

This repository contains versioned SentinelOne Deep Visibility diagnostic scripts plus the matching troubleshooting documentation.

## Version Status

| Version | Status | Path | Notes |
| --- | --- | --- | --- |
| V1-Stable | Stable | `versions/V1-Stable/S1-DeepVisibility-PassiveDiag.ps1` | Production-safe default. Root script mirrors this version. |
| V2-Candidate | Not stable | `versions/V2-Candidate/S1-DeepVisibility-PassiveDiag.ps1` | Adds HTTP 407 and collection-error visibility. Do not ship as stable until promoted. |

The root-level script is intentionally the stable version:

```text
S1-DeepVisibility-PassiveDiag.ps1
```

## Selected Script

Use:

```powershell
.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost "ioc-gw-prod-eu-1b.sentinelone.net" -VerboseOutput
```

The stable script is based on the latest locally found version before candidate changes:

```text
S1-DeepVisibility-PassiveDiag.ps1
Source: /Users/a.jaballah/Desktop/DVDiag/S1-DeepVisibility-PassiveDiag.ps1
Modified: 2026-01-09 14:44:36 CET
DiagnosticVersion: 1.1-relaxed
```

See `CHANGELOG.md` for what `V2-Candidate` adds.

## Behavior

The script is read-only. It does not change SentinelOne agent configuration, firewall rules, proxy settings, registry values, or services.

It checks:

- SentinelOne service and process status
- Deep Visibility registry configuration
- DNS resolution for the supplied Visibility host
- TCP 443 connectivity
- TLS 1.2 behavior with relaxed handling for DV endpoints
- WinHTTP, IE/system, and environment proxy context
- Windows Firewall profile and SentinelOne-related rules
- SentinelOne agent log metadata and recent relevant log lines
- Basic system and network connection information

## Output

The script writes a timestamped JSON report to:

```text
C:\Windows\Temp\S1-DeepVisibilityDiag_<timestamp>.json
```

Exit codes:

- `0`: no critical or warning findings
- `1`: at least one critical finding
- `2`: warnings only

## Documentation

Documentation is kept in:

```text
docs/docx/Deep-Visibility-Inactivity-Troubleshooting-Guide.docx
docs/text/Deep-Visibility-Inactivity-Troubleshooting-Guide.txt
```

## Validation Notes

V1-Stable was reviewed locally for structure and obvious syntax issues. V2-Candidate additionally passed PowerShell parser validation in a Docker sandbox with the repository mounted read-only and networking disabled. Neither script was live-executed on the packaging machine because the diagnostic uses Windows-specific cmdlets.

No active/remediation version is included. The locally found scripts were diagnostic/read-only variants, and adding remediation behavior without a defined operational requirement would change the risk profile of the tool.
