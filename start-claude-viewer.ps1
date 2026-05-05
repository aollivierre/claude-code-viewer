# Claude Code Viewer Startup Script
# Runs claude-code-viewer on port 3400 without password authentication

$ErrorActionPreference = 'Stop'

# Configuration
$Port = 3400
$Hostname = '0.0.0.0'
$LogFile = "$env:USERPROFILE\.claude\viewer-service.log"

# Ensure log directory exists
$logDir = Split-Path $LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Log startup
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path $LogFile -Value "[$timestamp] Starting Claude Code Viewer on port $Port"

try {
    # Run claude-code-viewer with CLI arguments (this will block)
    & "$env:APPDATA\npm\claude-code-viewer.cmd" -p $Port -h $Hostname
}
catch {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] ERROR: $_"
    throw
}
