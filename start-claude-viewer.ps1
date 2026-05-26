# Claude Code Viewer Startup Script
# Launches claude-code-viewer as a supervised child process:
#   * captures stdout + stderr to a rotating log file
#   * restarts the child on crash with exponential backoff
#   * logs supervisor events (start, exit, restart, throttle) separately
# Triggered by the ClaudeCodeViewer scheduled task at logon.

$ErrorActionPreference = 'Stop'

#region Configuration
$Port           = 3400
$ClaudeDir      = "$env:USERPROFILE\.claude"
$NodeExe        = "$env:USERPROFILE\AppData\Local\nodejs\node.exe"
$MainJs         = "$env:USERPROFILE\code\claude-code-viewer\dist\main.js"
$ClaudeExe      = "$env:USERPROFILE\.local\bin\claude.exe"

$LogDir         = "$env:USERPROFILE\.claude\viewer-logs"
$AppLog         = Join-Path $LogDir 'viewer-app.log'      # child stdout+stderr
$SupervisorLog  = Join-Path $LogDir 'viewer-supervisor.log' # supervisor events

$MaxLogBytes    = 10MB         # rotate when AppLog exceeds this
$KeepRotations  = 5            # keep N rotated copies
$MinBackoffSec  = 2            # initial restart delay
$MaxBackoffSec  = 300          # cap restart delay (5 minutes)
$CrashWindowSec = 60           # consecutive crashes within this window grow backoff
#endregion

#region Helpers
function Write-SupLog {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message
    try { Add-Content -Path $SupervisorLog -Value $line -ErrorAction Stop } catch { }
}

function Invoke-LogRotation {
    param([string]$LogPath)
    if (-not (Test-Path $LogPath)) { return }
    $size = (Get-Item $LogPath -ErrorAction SilentlyContinue).Length
    if ($null -eq $size -or $size -lt $MaxLogBytes) { return }

    for ($i = $KeepRotations - 1; $i -ge 1; $i--) {
        $src = "$LogPath.$i"
        $dst = "$LogPath.$($i + 1)"
        if (Test-Path $src) {
            Move-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
        }
    }
    Move-Item -Path $LogPath -Destination "$LogPath.1" -Force -ErrorAction SilentlyContinue
    Write-SupLog "Rotated $LogPath (size was $size bytes)"
}

function Assert-Path {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-SupLog "MISSING $Label : $Path" 'ERROR'
        throw "$Label not found: $Path"
    }
}
#endregion

#region Init
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-SupLog "=== Supervisor starting (PID $PID) ==="
Write-SupLog "NodeExe=$NodeExe"
Write-SupLog "MainJs=$MainJs"
Write-SupLog "ClaudeDir=$ClaudeDir"
Write-SupLog "ClaudeExe=$ClaudeExe"
Write-SupLog "Port=$Port"
Write-SupLog "AppLog=$AppLog (rotate at $MaxLogBytes bytes, keep $KeepRotations)"

Assert-Path $NodeExe   'NodeExe'
Assert-Path $MainJs    'MainJs'
Assert-Path $ClaudeDir 'ClaudeDir'
Assert-Path $ClaudeExe 'ClaudeExe'
#endregion

#region Supervisor loop
$backoff = $MinBackoffSec
$lastCrashTime = $null
$startCount = 0

while ($true) {
    Invoke-LogRotation -LogPath $AppLog
    Invoke-LogRotation -LogPath $SupervisorLog

    $startCount++
    $startTime = Get-Date
    Write-SupLog "Spawn #$startCount : starting viewer"

    $procArgs = @(
        $MainJs,
        '--port',       $Port,
        '--claude-dir', $ClaudeDir,
        '--executable', $ClaudeExe
    )

    try {
        $proc = Start-Process `
            -FilePath $NodeExe `
            -ArgumentList $procArgs `
            -RedirectStandardOutput $AppLog `
            -RedirectStandardError  $AppLog `
            -WindowStyle Hidden `
            -PassThru `
            -ErrorAction Stop
    }
    catch {
        Write-SupLog "Start-Process failed: $_" 'ERROR'
        Start-Sleep -Seconds $backoff
        $backoff = [Math]::Min($backoff * 2, $MaxBackoffSec)
        continue
    }

    Write-SupLog "Viewer PID $($proc.Id) launched"
    $proc.WaitForExit()

    $exitCode = $proc.ExitCode
    $uptime   = (Get-Date) - $startTime
    Write-SupLog ("Viewer PID {0} exited (code={1}, uptime={2:hh\:mm\:ss})" -f $proc.Id, $exitCode, $uptime)

    # Backoff: if it crashed quickly after a previous crash, grow the delay.
    $now = Get-Date
    if ($null -ne $lastCrashTime -and ($now - $lastCrashTime).TotalSeconds -lt $CrashWindowSec) {
        $backoff = [Math]::Min($backoff * 2, $MaxBackoffSec)
        Write-SupLog "Rapid restart detected; backoff -> ${backoff}s" 'WARN'
    } elseif ($uptime.TotalSeconds -ge $CrashWindowSec) {
        $backoff = $MinBackoffSec  # ran long enough; reset backoff
    }
    $lastCrashTime = $now

    Write-SupLog "Sleeping ${backoff}s before restart"
    Start-Sleep -Seconds $backoff
}
#endregion
