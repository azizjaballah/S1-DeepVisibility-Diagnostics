<#
.SYNOPSIS
  SentinelOne Visibility Cloud connectivity diagnostics.

.DESCRIPTION
  This script specifically tests connectivity from the local machine to the
  SentinelOne Visibility Cloud endpoint:

      https://ioc-gw-prod-eu-1b.sentinelone.net/

  It checks DNS resolution, TCP 443 connectivity, TLS 1.2 handshake,
  WinHTTP proxy configuration, environment proxy variables and basic route info.
  Results are written to a JSON file under C:\ProgramData\S1-NetCheck.
#>

[CmdletBinding()]
param(
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"

# --- Target S1 Visibility Cloud endpoint (hard-coded) ---
$S1VisibilityHost = 'ioc-gw-prod-eu-1b.sentinelone.net'
$S1VisibilityUri  = 'https://ioc-gw-prod-eu-1b.sentinelone.net/'

# --- Output path ---
$OutputRoot = "C:\ProgramData\S1-NetCheck"
if (!(Test-Path $OutputRoot)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}
$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$OutFile   = Join-Path $OutputRoot "S1-VisibilityDiag_$Timestamp.json"

if ($VerboseOutput) {
    Write-Host "=== SentinelOne Visibility Cloud Connectivity Check ==="
    Write-Host "Target host : $S1VisibilityHost"
    Write-Host "Target URI  : $S1VisibilityUri"
    Write-Host ""
}

function Test-S1Dns {
    param([string]$Host)
    $result = [ordered]@{
        Host    = $Host
        Success = $false
        Records = @()
        Error   = $null
    }

    try {
        $records = Resolve-DnsName -Name $Host -ErrorAction Stop
        $result.Success = $true
        $result.Records = $records | Select-Object Name, QueryType, IPAddress
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

function Test-S1Tcp {
    param([string]$Host, [int]$Port = 443)
    $result = [ordered]@{
        Host          = $Host
        Port          = $Port
        TcpReachable  = $false
        RemoteAddress = $null
        LatencyMs     = $null
        Error         = $null
    }

    try {
        $tnc = Test-NetConnection -ComputerName $Host -Port $Port -WarningAction SilentlyContinue
        $result.TcpReachable  = $tnc.TcpTestSucceeded
        $result.RemoteAddress = $tnc.RemoteAddress
        if ($tnc.PingSucceeded -and $tnc.PingReplyDetails) {
            $result.LatencyMs = $tnc.PingReplyDetails.RoundtripTime
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

function Test-S1Tls12 {
    param([string]$Uri)

    $result = [ordered]@{
        Uri        = $Uri
        Success    = $false
        StatusCode = $null
        Server     = $null
        Error      = $null
        Protocol   = "TLS1.2"
    }

    try {
        # Force TLS 1.2 for this process
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri $Uri -Method Head -UseBasicParsing -TimeoutSec 20
        $result.Success    = $true
        $result.StatusCode = [int]$resp.StatusCode
        $result.Server     = $resp.Headers['Server']
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

function Get-WinHttpProxyInfo {
    $result = [ordered]@{
        WinHttpProxyRaw = $null
        Env_HTTP_PROXY  = $env:HTTP_PROXY
        Env_HTTPS_PROXY = $env:HTTPS_PROXY
    }

    try {
        $txt = netsh winhttp show proxy 2>&1
        $result.WinHttpProxyRaw = $txt -join "`n"
    }
    catch {
        $result.WinHttpProxyRaw = "Error: $($_.Exception.Message)"
    }
    return $result
}

function Get-RouteInfo {
    param([string]$Host)

    $result = [ordered]@{
        Traceroute = @()
        Error      = $null
    }

    try {
        # Run a short tracert with 10 hops max
        $trace = tracert -d -h 10 $Host 2>&1
        $result.Traceroute = $trace
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}

# --- Run tests ---

$dnsResult   = Test-S1Dns  -Host $S1VisibilityHost
$tcpResult   = Test-S1Tcp  -Host $S1VisibilityHost -Port 443
$tlsResult   = Test-S1Tls12 -Uri $S1VisibilityUri
$proxyResult = Get-WinHttpProxyInfo
$routeResult = Get-RouteInfo -Host $S1VisibilityHost

# --- Combine output ---

$out = [ordered]@{
    Timestamp         = (Get-Date)
    ComputerName      = $env:COMPUTERNAME
    VisibilityHost    = $S1VisibilityHost
    VisibilityUri     = $S1VisibilityUri
    Dns               = $dnsResult
    Tcp443            = $tcpResult
    Tls12             = $tlsResult
    Proxy             = $proxyResult
    Route             = $routeResult
}

$out | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutFile -Encoding UTF8

if ($VerboseOutput) {
    Write-Host ""
    Write-Host "JSON report written to:"
    Write-Host "  $OutFile"
    Write-Host ""
    Write-Host "Quick summary:"
    Write-Host "  DNS OK : $($dnsResult.Success)"
    Write-Host "  TCP 443: $($tcpResult.TcpReachable)"
    Write-Host "  TLS 1.2: $($tlsResult.Success) (StatusCode=$($tlsResult.StatusCode))"
}

# Exit code convention:
# 0 = everything looks OK
# 1 = DNS failure
# 2 = TCP failure
# 3 = TLS failure
$exitCode = 0
if (-not $dnsResult.Success)   { $exitCode = 1 }
elseif (-not $tcpResult.TcpReachable) { $exitCode = 2 }
elseif (-not $tlsResult.Success)      { $exitCode = 3 }

exit $exitCode
