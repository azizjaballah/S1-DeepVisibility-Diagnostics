# V2-Candidate

Status: not stable until further notice.

This candidate keeps the read-only behavior from V1 and adds visibility for proxy-authentication and collection errors.

Additional behavior compared with V1:

- Detects HTTP `407 Proxy Authentication Required`.
- Reports HTTP 407 as `CRITICAL`.
- Adds `ProxyAuthRequired` to the TLS result object.
- Adds `Error` to proxy collection output.
- Adds collection errors to `DetectedIssues` so they are visible in the summary JSON.
- Sets `DiagnosticVersion` to `1.2-proxy-errors`.

Validation:

- PowerShell parser validation passed in Docker with a read-only mount and networking disabled.
- Not live-executed on the packaging machine.
