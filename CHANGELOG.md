# Changelog

## V2-Candidate - Not Stable

Status: not stable until further notice.

Based on `V1-Stable`, with these additions:

- Adds explicit HTTP `407 Proxy Authentication Required` detection.
- Reports HTTP 407 as a `CRITICAL` issue because proxy authentication can prevent Deep Visibility connectivity.
- Adds `ProxyAuthRequired` to the TLS result object.
- Adds a proxy collection `Error` field.
- Surfaces collection errors in `DetectedIssues` instead of only storing them inside each JSON section.
- Bumps `DiagnosticVersion` to `1.2-proxy-errors`.

Validation:

- PowerShell parser validation passed in Docker with the repository mounted read-only and networking disabled.
- The script was not live-executed on the packaging machine.

## V1-Stable

Status: stable.

This is the previous production-safe read-only diagnostic version from commit `7a6b17a`.

Version details:

- `DiagnosticVersion`: `1.1-relaxed`
- Source selected from latest locally modified script at packaging time:
  `/Users/a.jaballah/Desktop/DVDiag/S1-DeepVisibility-PassiveDiag.ps1`
- Read-only diagnostic behavior only.
- Relaxed TLS handling for Deep Visibility endpoints that reject non-agent requests.
