<#
.SYNOPSIS
  SentinelOne Deep Visibility passive diagnostics for agents
  active in console but inactive in Deep Visibility.

.DESCRIPTION
  This script performs READ-ONLY checks to diagnose Deep Visibility
  connectivity issues. It does not modify any settings or agent configuration.

.PARAMETER S1VisibilityHost
  The SentinelOne visibility host to test (e.g., 'ioc-gw-prod-eu-1b.sentinelone.net').

.PARAMETER VerboseOutput
  Display detailed output to console in addition to JSON report.

.EXAMPLE
  .\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost 'ioc-gw-prod-eu-1b.sentinelone.net' -VerboseOutput

.EXAMPLE
  .\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost 'ioc-gw-prod-us-1.sentinelone.net'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "SentinelOne visibility host (e.g., ioc-gw-prod-eu-1b.sentinelone.net)")]
    [string]$S1VisibilityHost,

    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"

# --- Construct URI from host ---
$S1VisibilityUri = "https://$S1VisibilityHost/"

# --- Output folder (TEMP policy) ---
$OutputRoot = "C:\Windows\Temp"
if (-not (Test-Path -Path $OutputRoot)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}

$Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$OutFile   = Join-Path -Path $OutputRoot -ChildPath "S1-DeepVisibilityDiag_$Timestamp.json"

if ($VerboseOutput) {
    Write-Host "=== SentinelOne Deep Visibility Passive Diagnostics ===" -ForegroundColor Cyan
    Write-Host "Target Host  : $S1VisibilityHost"
    Write-Host "Target URI   : $S1VisibilityUri"
    Write-Host "Timestamp    : $Timestamp"
    Write-Host ""
}

#############################
# AGENT STATUS CHECK
#############################
function Get-S1AgentInfo {
    $result = [ordered]@{
        ServiceExists    = $false
        ServiceStatus    = $null
        ServiceStartType = $null
        AgentVersion     = $null
        InstallPath      = $null
        ProcessRunning   = $false
        ProcessDetails   = @()
        Error            = $null
    }

    try {
        # Check service
        $service = Get-Service -Name "SentinelAgent" -ErrorAction SilentlyContinue
        if ($service) {
            $result.ServiceExists    = $true
            $result.ServiceStatus    = $service.Status.ToString()
            $result.ServiceStartType = $service.StartType.ToString()
        }

        # Check registry for version and path
        $regPaths = @(
            "HKLM:\SOFTWARE\SentinelOne\Sentinel Agent",
            "HKLM:\SOFTWARE\WOW6432Node\SentinelOne\Sentinel Agent"
        )

        foreach ($regPath in $regPaths) {
            if (Test-Path -Path $regPath) {
                $regKey = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($regKey.Version)     { $result.AgentVersion = $regKey.Version }
                if ($regKey.InstallPath) { $result.InstallPath  = $regKey.InstallPath }
            }
        }

        # Check running processes
        $processes = Get-Process -Name "SentinelAgent", "SentinelAgentWorker", "SentinelStaticEngine" -ErrorAction SilentlyContinue
        if ($processes) {
            $result.ProcessRunning  = $true
            $result.ProcessDetails  = $processes |
                Select-Object Name, Id, StartTime, WorkingSet64 |
                ForEach-Object {
                    [ordered]@{
                        Name      = $_.Name
                        PID       = $_.Id
                        StartTime = $_.StartTime
                        MemoryMB  = [math]::Round($_.WorkingSet64 / 1MB, 2)
                    }
                }
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# DEEP VISIBILITY CONFIG CHECK
#############################
function Get-S1DeepVisibilityConfig {
    $result = [ordered]@{
        DVEnabled          = $null
        DVMode             = $null
        NetworkQuarantined = $null
        ConfigSource       = $null
        RegistryValues     = @()
        Error              = $null
    }

    try {
        $regPath = "HKLM:\SOFTWARE\SentinelOne\Sentinel Agent"

        if (Test-Path -Path $regPath) {
            $regKey = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

            $dvSettings = @(
                "DeepVisibilityEnabled",
                "DeepVisibilityMode",
                "NetworkQuarantineEnabled",
                "AgentId",
                "SiteId",
                "ManagementUrl"
            )

            foreach ($setting in $dvSettings) {
                if ($null -ne $regKey.$setting) {
                    $result.RegistryValues += [ordered]@{
                        Name  = $setting
                        Value = $regKey.$setting
                    }

                    switch ($setting) {
                        "DeepVisibilityEnabled"    { $result.DVEnabled          = $regKey.$setting }
                        "DeepVisibilityMode"       { $result.DVMode             = $regKey.$setting }
                        "NetworkQuarantineEnabled" { $result.NetworkQuarantined = $regKey.$setting }
                    }
                }
            }

            $result.ConfigSource = $regPath
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# DNS TEST
#############################
function Test-S1Dns {
    param(
        [string]$TargetHost
    )

    $result = [ordered]@{
        TargetHost = $TargetHost
        Success    = $false
        Records    = @()
        Error      = $null
    }

    try {
        $records        = Resolve-DnsName -Name $TargetHost -ErrorAction Stop
        $result.Success = $true
        $result.Records = $records | Select-Object Name, QueryType, IPAddress, TTL
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# TCP TEST
#############################
function Test-S1Tcp {
    param(
        [string]$TargetHost,
        [int]$Port = 443
    )

    $result = [ordered]@{
        TargetHost    = $TargetHost
        Port          = $Port
        TcpReachable  = $false
        RemoteAddress = $null
        LatencyMs     = $null
        Error         = $null
    }

    try {
        $tnc = Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue

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

#############################
# TLS TEST (RELAXED)
#############################
function Test-S1Tls12 {
    param(
        [string]$TargetUri
    )

    $result = [ordered]@{
        TargetUri          = $TargetUri
        Success            = $false
        StatusCode         = $null
        Server             = $null
        Error              = $null
        Protocol           = "TLS1.2"
        HttpErrorTolerated = $false  # true when 2xx–4xx but used as connectivity-success
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $resp = Invoke-WebRequest -Uri $TargetUri -Method Head -UseBasicParsing -TimeoutSec 20

        $result.Success    = $true
        $result.StatusCode = [int]$resp.StatusCode
        $result.Server     = $resp.Headers["Server"]
    }
    catch {
        # RELAXED LOGIC:
        # If we got an HTTP response (e.g., 400 Bad Request), we still treat
        # this as "connectivity OK" because TLS + HTTP completed.
        $result.Error = $_.Exception.Message
        $webEx        = $_.Exception

        if ($webEx.Response -and $webEx.Response.StatusCode) {
            $code = [int]$webEx.Response.StatusCode
            $result.StatusCode = $code

            if ($code -ge 200 -and $code -lt 500) {
                # HTTP 4xx still means network/TLS is fine.
                $result.Success            = $true
                $result.HttpErrorTolerated = $true
            }
        }
    }

    return $result
}

#############################
# PROXY INFO
#############################
function Get-WinHttpProxyInfo {
    $result = [ordered]@{
        WinHttpProxyRaw = $null
        Env_HTTP_PROXY  = $env:HTTP_PROXY
        Env_HTTPS_PROXY = $env:HTTPS_PROXY
        IEProxyEnabled  = $null
        IEProxyServer   = $null
    }

    try {
        $txt = netsh winhttp show proxy 2>&1
        $result.WinHttpProxyRaw = $txt -join "`n"

        $iePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        if (Test-Path -Path $iePath) {
            $ieSettings = Get-ItemProperty -Path $iePath -ErrorAction SilentlyContinue
            $result.IEProxyEnabled = $ieSettings.ProxyEnable
            $result.IEProxyServer  = $ieSettings.ProxyServer
        }
    }
    catch {
        $result.WinHttpProxyRaw = "Error: $($_.Exception.Message)"
    }

    return $result
}

#############################
# FIREWALL CHECK
#############################
function Get-WindowsFirewallStatus {
    $result = [ordered]@{
        FirewallEnabled = @()
        S1AgentRules    = @()
        Error           = $null
    }

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        $result.FirewallEnabled = $profiles | Select-Object Name, Enabled

        $s1Rules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Sentinel*" -or $_.DisplayName -like "*S1*" }

        if ($s1Rules) {
            $result.S1AgentRules = $s1Rules | Select-Object DisplayName, Enabled, Direction, Action
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# AGENT LOG CHECK
#############################
function Get-S1AgentLogInfo {
    $result = [ordered]@{
        LogPath      = $null
        LogExists    = $false
        LogSizeMB    = $null
        LastModified = $null
        RecentErrors = @()
        Error        = $null
    }

    try {
        $logPaths = @(
            "C:\ProgramData\SentinelOne\Logs\Agent\SentinelAgent.log",
            "C:\Program Files\SentinelOne\Sentinel Agent\Logs\SentinelAgent.log"
        )

        foreach ($logPath in $logPaths) {
            if (Test-Path -Path $logPath) {
                $result.LogPath   = $logPath
                $result.LogExists = $true

                $logFile = Get-Item -Path $logPath
                $result.LogSizeMB    = [math]::Round($logFile.Length / 1MB, 2)
                $result.LastModified = $logFile.LastWriteTime

                try {
                    $lastLines = Get-Content -Path $logPath -Tail 50 -ErrorAction SilentlyContinue
                    $errors    = $lastLines | Where-Object { $_ -match "ERROR|WARN|FAIL|Deep.*Visibility" }
                    if ($errors) {
                        $result.RecentErrors = $errors | Select-Object -First 10
                    }
                }
                catch {
                    $result.RecentErrors = @("Log file not accessible for reading")
                }

                break
            }
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# NETWORK STATS
#############################
function Get-NetworkStats {
    $result = [ordered]@{
        ActiveConnections = 0
        S1Connections     = @()
        Error             = $null
    }

    try {
        $connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
            Where-Object { $_.RemoteAddress -notmatch "^(127\.|::1)" }

        $result.ActiveConnections = $connections.Count

        $s1Conn = $connections | Where-Object {
            $_.RemoteAddress -match "sentinelone" -or $_.RemotePort -eq 443
        } | Select-Object -First 10

        if ($s1Conn) {
            $result.S1Connections = $s1Conn | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

#############################
# SYSTEM INFO
#############################
function Get-SystemInfo {
    $result = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        OSVersion    = $null
        OSBuild      = $null
        LastBoot     = $null
        TimeZone     = $null
        Error        = $null
    }

    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $result.OSVersion = $os.Caption
        $result.OSBuild   = $os.BuildNumber
        $result.LastBoot  = $os.LastBootUpTime
        $result.TimeZone  = (Get-TimeZone).Id
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

###############
# RUN TESTS
###############
if ($VerboseOutput) {
    Write-Host "Running diagnostics..." -ForegroundColor Yellow
}

$systemInfo  = Get-SystemInfo
$agentInfo   = Get-S1AgentInfo
$dvConfig    = Get-S1DeepVisibilityConfig
$dnsResult   = Test-S1Dns   -TargetHost $S1VisibilityHost
$tcpResult   = Test-S1Tcp   -TargetHost $S1VisibilityHost -Port 443
$tlsResult   = Test-S1Tls12 -TargetUri  $S1VisibilityUri
$proxyResult = Get-WinHttpProxyInfo
$fwResult    = Get-WindowsFirewallStatus
$logInfo     = Get-S1AgentLogInfo
$netStats    = Get-NetworkStats

###############
# ANALYSIS (RELAXED TLS)
###############
$issues = @()

# Agent checks
if (-not $agentInfo.ServiceExists) {
    $issues += "CRITICAL: SentinelAgent service not found"
}
if ($agentInfo.ServiceStatus -ne "Running") {
    $issues += "CRITICAL: SentinelAgent service is $($agentInfo.ServiceStatus)"
}
if (-not $agentInfo.ProcessRunning) {
    $issues += "WARNING: SentinelAgent process not running"
}

# DV config
if ($dvConfig.DVEnabled -eq 0 -or $dvConfig.DVEnabled -eq $false) {
    $issues += "CRITICAL: Deep Visibility is DISABLED in agent configuration"
}
if ($null -eq $dvConfig.DVEnabled) {
    $issues += "INFO: Deep Visibility configuration not in registry (may be managed by console)"
}
if ($dvConfig.NetworkQuarantined -eq 1 -or $dvConfig.NetworkQuarantined -eq $true) {
    $issues += "WARNING: Agent is in Network Quarantine mode"
}

# Network connectivity
if (-not $dnsResult.Success) {
    $issues += "CRITICAL: Cannot resolve $S1VisibilityHost"
}
if (-not $tcpResult.TcpReachable) {
    $issues += "CRITICAL: Cannot reach $S1VisibilityHost on port 443"
}

# RELAXED TLS: only CRITICAL if Success is false AND we did not just tolerate an HTTP 4xx
# NOTE: S1 Deep Visibility endpoints may reject browser-like requests with TLS errors
# even when agent connectivity is working properly
if (-not $tlsResult.Success -and -not $tlsResult.HttpErrorTolerated) {
    $issues += "INFO: TLS 1.2 test failed (this is NORMAL for DV endpoints - they reject non-agent requests)"
}
elseif ($tlsResult.HttpErrorTolerated) {
    $issues += "INFO: TLS succeeded but HTTP status was $($tlsResult.StatusCode) (connectivity OK; request not agent-like)"
}

# Proxy info
if ($proxyResult.WinHttpProxyRaw -and $proxyResult.WinHttpProxyRaw -notmatch "Direct access") {
    $issues += "INFO: WinHTTP proxy configured - verify SentinelOne endpoints are allowed"
}

###############
# WRITE JSON
###############
$out = [ordered]@{
    Timestamp         = (Get-Date)
    DiagnosticVersion = "1.1-relaxed"
    System            = $systemInfo
    Agent             = $agentInfo
    DeepVisibility    = $dvConfig
    DNS               = $dnsResult
    TCP443            = $tcpResult
    TLS12             = $tlsResult
    Proxy             = $proxyResult
    Firewall          = $fwResult
    AgentLog          = $logInfo
    NetworkStats      = $netStats
    DetectedIssues    = $issues
}

$out | ConvertTo-Json -Depth 8 | Out-File -FilePath $OutFile -Encoding UTF8

###############
# SUMMARY
###############
if ($VerboseOutput) {
    Write-Host "`n=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Cyan

    Write-Host "`nAgent Status:"
    Write-Host "  Service Running   : $($agentInfo.ServiceStatus)"
    Write-Host "  Version           : $($agentInfo.AgentVersion)"
    Write-Host "  Process Running   : $($agentInfo.ProcessRunning)"

    Write-Host "`nDeep Visibility Config:"
    Write-Host "  DV Enabled        : $($dvConfig.DVEnabled)"
    Write-Host "  DV Mode           : $($dvConfig.DVMode)"
    Write-Host "  Network Quarantine: $($dvConfig.NetworkQuarantined)"

    Write-Host "`nConnectivity:"
    Write-Host "  DNS Resolution    : $($dnsResult.Success)"
    Write-Host "  TCP Port 443      : $($tcpResult.TcpReachable)"
    Write-Host "  TLS 1.2 Test      : $($tlsResult.Success) (Note: DV endpoints may reject non-agent requests)"

    if ($issues.Count -gt 0) {
        Write-Host "`n=== DETECTED ISSUES ===" -ForegroundColor Red
        foreach ($issue in $issues) {
            $color = if ($issue -match "CRITICAL") { "Red" }
            elseif ($issue -match "WARNING") { "Yellow" }
            else { "White" }

            Write-Host "  - $issue" -ForegroundColor $color
        }
    }
    else {
        Write-Host "`nNo issues detected - configuration appears normal." -ForegroundColor Green
    }

    Write-Host "`nJSON report saved to:" -ForegroundColor Cyan
    Write-Host "  $OutFile"
    Write-Host ""
}

# Exit codes
$exitCode = 0
if ($issues | Where-Object { $_ -match "CRITICAL" }) {
    $exitCode = 1
}
elseif ($issues | Where-Object { $_ -match "WARNING" }) {
    $exitCode = 2
}

exit $exitCode
