# Setup Scheduled Task for Claude Code Viewer
# Run this script once as Administrator to create the startup task

$ErrorActionPreference = 'Stop'

$TaskName = 'ClaudeCodeViewer'
$ScriptPath = 'C:\code\claude\code-viewer\start-claude-viewer.ps1'

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    Write-Host "Removing existing task '$TaskName'..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create the action - run PowerShell hidden with the startup script
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# Trigger at logon of current user
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Settings - allow running on battery, don't stop if on batteries
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Principal - run as current user
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Register the task
Write-Host "Creating scheduled task '$TaskName'..."
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Claude Code Viewer Web UI - starts automatically at logon'

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host 'Scheduled task created successfully!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host ''
Write-Host "Task Name: $TaskName"
Write-Host "Script: $ScriptPath"
Write-Host 'Trigger: At logon'
Write-Host ''
Write-Host 'The viewer will start automatically when you log in.'
Write-Host 'To start it now, run: Start-ScheduledTask -TaskName ClaudeCodeViewer'
