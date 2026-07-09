# SentinelOne Deep Visibility Diagnostics

This project collects the SentinelOne Deep Visibility diagnostic scripts and related documentation that were found locally.

## Recommended Script

Use:

```powershell
scripts/recommended/zip-source/DiagnoseNET.ps1
```

This is the packaged `DiagnoseNET.ps1` variant from `DiagnoseNET.ps1.zip`. It is the most stable candidate for customer or RemoteOps use because it:

- identifies itself as `DiagnosticVersion = "1.2-remoteops-safe"`
- writes to `$env:TEMP\S1-DeepVisibilityDiag.json`
- performs an early write test
- handles HTTP `407 Proxy Authentication Required` as a critical proxy finding
- keeps all checks read-only

The loose copy is also included here:

```powershell
scripts/recommended/DiagnoseNET-remoteops-safe.ps1
```

## Script Inventory

| Path | Purpose |
| --- | --- |
| `scripts/recommended/zip-source/DiagnoseNET.ps1` | Recommended packaged RemoteOps-safe script |
| `scripts/recommended/DiagnoseNET-remoteops-safe.ps1` | Loose `DiagnoseNET.ps1` copy |
| `scripts/variants/S1-DeepVisibility-PassiveDiag-desktop-20260109.ps1` | Newer formatted `1.1-relaxed` variant from Desktop |
| `scripts/variants/S1-DeepVisibility-PassiveDiag-downloads-20251124.ps1` | Older `1.1-relaxed` variant from Downloads |
| `scripts/legacy/DiagnoseDV-hardcoded-eu-v1.ps1` | Legacy hard-coded EU Deep Visibility diagnostic |
| `scripts/connectivity/S1-VisibilityCloud-Diagnostics-hardcoded-eu.ps1` | Connectivity-only Visibility Cloud diagnostic |

## Documentation

Word documents are kept under `docs/docx/`. Text conversions are kept under `docs/text/` for easier review in GitHub.

## Usage

Run PowerShell as Administrator on the Windows endpoint:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\DiagnoseNET.ps1 -S1VisibilityHost "ioc-gw-prod-eu-1b.sentinelone.net" -VerboseOutput
```

The recommended packaged script writes its report to:

```text
%TEMP%\S1-DeepVisibilityDiag.json
```

## Notes

- These scripts are read-only diagnostics.
- Prior endpoint run artifacts were not included because JSON/stdout outputs may contain customer or host-specific data.
- PowerShell syntax validation was not run locally because `pwsh` was not installed on the packaging Mac.
