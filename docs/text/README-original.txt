SentinelOne Deep Visibility Passive Diagnostics

Purpose

This PowerShell script performs read-only network connectivity checks for SentinelOne agents that appear active in the management console but are not sending data to Deep Visibility. It helps identify network connectivity issues, firewall blocks, proxy misconfigurations, or agent service problems.

What It Checks

✅ SentinelOne agent service and process status
✅ Deep Visibility configuration in registry
✅ DNS resolution to SentinelOne Deep Visibility endpoints
✅ TCP connectivity on port 443
✅ TLS 1.2 handshake capability
✅ Windows Firewall configuration
✅ Proxy settings (WinHTTP, environment variables, IE)
✅ Active network connections
✅ Agent log file access

Requirements

Windows OS: Windows 10/11 or Windows Server 2016+
PowerShell: Version 5.1 or higher
Permissions: Administrator/elevated PowerShell session required
SentinelOne Agent: Must be installed on the target machine

Usage

Basic Syntax

.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost '<your-dv-endpoint>' [-VerboseOutput]

Examples

Standard execution with console output (EU region):

.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost 'ioc-gw-prod-eu-1a.sentinelone.net' -VerboseOutput

Silent mode - JSON report only (US region):

.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost 'ioc-gw-prod-us-1.sentinelone.net'

APAC region:

.\S1-DeepVisibility-PassiveDiag.ps1 -S1VisibilityHost 'ioc-gw-prod-apac-1.sentinelone.net' -VerboseOutput

Finding Your Deep Visibility Endpoint

Your Deep Visibility endpoint depends on your SentinelOne console region:

Region

Deep Visibility Host

EU

ioc-gw-prod-eu-1a.sentinelone.net or ioc-gw-prod-eu-1b.sentinelone.net

US

ioc-gw-prod-us-1.sentinelone.net

APAC

ioc-gw-prod-apac-1.sentinelone.net

To verify your endpoint:

Check your SentinelOne console URL
Contact your SentinelOne administrator
Review your agent configuration in the S1 console under Settings > Endpoints

Output

JSON Report Location

C:\ProgramData\S1-NetCheck\S1-DeepVisibilityDiag_<timestamp>.json

The JSON file contains complete diagnostic data including:

System information (OS version, hostname, timezone)
Agent status and configuration
All connectivity test results
Detected issues with severity levels

Exit Codes

0 - No issues detected
1 - Critical issues found (agent not running, connectivity failed)
2 - Warnings only (configuration issues, but connectivity OK)

Understanding Results

Expected Behavior for Working Agents

Based on real-world testing, a properly functioning agent sending Deep Visibility data typically shows:

✅ Agent Service: Running
✅ DNS Resolution: Success
✅ TCP Port 443: Reachable
⚠️ TLS 1.2 Test: May fail (this is NORMAL)
ℹ️ DV Registry Config: May be empty (console-managed)
✅ SentinelCtl: Located (for manual configuration if needed)

Why TLS Test May Fail (This is Normal!)

Deep Visibility endpoints are designed for agent-to-server communication using proprietary protocols. They may reject standard HTTPS requests from non-agent clients (like this diagnostic script), even when agent connectivity is working perfectly.

A failed TLS test does NOT mean the agent cannot communicate - focus on DNS and TCP results instead.

Why Deep Visibility Config May Be Empty

The SentinelOne agent can receive its Deep Visibility configuration from:

Console-managed policies (recommended, most common)
Local registry settings (legacy or standalone deployments)
SentinelCtl command-line configuration (manual/testing)

If the diagnostic shows empty DV configuration in registry, this typically means the agent is properly receiving its configuration from the management console. You can verify this by:

Checking the agent's policy in the SentinelOne console
Running sentinelctl config -p deepVisibility.registry to see active settings
Confirming the agent is connected and reporting to the console

Issue Severity Levels

CRITICAL - Blocks agent functionality:

Agent service not running
DNS resolution failed
TCP port 443 blocked

WARNING - May impact performance:

Agent process not running (but service is)
Network quarantine enabled

INFO - Informational only:

TLS test failed (expected for DV endpoints)
DV config not in registry (may be console-managed)
Proxy configured (verify allowlist)

Troubleshooting Common Issues

Empty Deep Visibility Configuration

If the diagnostic shows Deep Visibility configuration is empty in the registry, this is often normal for console-managed agents. However, you can verify and configure Deep Visibility settings using the SentinelCtl command-line tool.

How to Check Deep Visibility Configuration

Open Command Prompt as Administrator
Navigate to the SentinelOne Agent directory:

 

Replace <version> with your installed version (e.g., 22.2.3.402)
Check current Deep Visibility settings:

Configuring Deep Visibility Registry Events

To enable specific registry event monitoring (requires passphrase):

sentinelctl config deepVisibility.registry.keyRename true -k "YOUR_PASSPHRASE"

Available registry event options:

deepVisibility.registry.keyDelete - Monitor registry key deletions
deepVisibility.registry.keyExport - Monitor registry key exports
deepVisibility.registry.keyImport - Monitor registry key imports
deepVisibility.registry.keyRename - Monitor registry key renames
deepVisibility.registry.keyCreated - Monitor registry key creation
deepVisibility.registry.valueDelete - Monitor registry value deletions
deepVisibility.registry.valueCreated - Monitor registry value creation
deepVisibility.registry.valueModified - Monitor registry value modifications
deepVisibility.registry.keySecurityChanged - Monitor registry security changes

From PowerShell (run as Administrator):

.\SentinelCtl.exe config deepVisibility.registry.keyRename true -k "YOUR_PASSPHRASE"

Note: The passphrase is typically provided by your SentinelOne administrator or found in your deployment documentation.

Example: Enable All Registry Events

sentinelctl config deepVisibility.registry.keyDelete true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.keyExport true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.keyImport true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.keyRename true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.keyCreated true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.valueDelete true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.valueCreated true -k "YOUR_PASSPHRASE"
sentinelctl config deepVisibility.registry.valueModified true -k "YOUR_PASSPHRASE"

Important: Deep Visibility configuration is typically managed centrally through the SentinelOne console. Local configuration changes may be overridden by console policies.

DNS Failure

Check DNS server configuration
Verify firewall allows DNS queries (UDP/53)
Test manual resolution: nslookup ioc-gw-prod-eu-1a.sentinelone.net

TCP Port 443 Blocked

Check Windows Firewall rules
Verify corporate firewall/proxy allows outbound HTTPS
Confirm security appliances aren't blocking the connection

Agent Service Not Running

Check Windows Event Logs
Verify agent installation integrity
Restart service: Restart-Service SentinelAgent

Proxy Configuration

If proxy is detected, ensure these SentinelOne endpoints are on the allowlist:

*.sentinelone.net
Your management console URL
Deep Visibility gateway endpoints

Security & Privacy

This script is completely passive and read-only:

❌ Does NOT modify agent configuration
❌ Does NOT restart services
❌ Does NOT change Windows settings
✅ Only reads system information and tests connectivity
✅ Safe to run in production environments

Support

If you encounter issues with this diagnostic script:

Ensure you're running as Administrator
Verify the SentinelOne agent is installed
Confirm you're using the correct Deep Visibility endpoint for your region
Review the JSON output file for detailed error messages

For SentinelOne agent issues, contact your security team or SentinelOne support with the generated JSON report.



Script Version: 1.1-relaxed
Last Updated: November 2025
Compatibility: Windows 10/11, Windows Server 2012+


