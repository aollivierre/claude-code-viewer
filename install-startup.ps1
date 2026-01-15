# Install Claude Code Viewer to Windows Startup folder
# No admin rights required

$StartupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$VbsSource = 'C:\code\claude\code-viewer\start-claude-viewer.vbs'
$ShortcutPath = "$StartupFolder\ClaudeCodeViewer.lnk"

# Create shortcut to the VBS file
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $VbsSource
$Shortcut.WorkingDirectory = 'C:\code\claude\code-viewer'
$Shortcut.Description = 'Claude Code Viewer Web UI'
$Shortcut.Save()

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host 'Startup shortcut created!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host ''
Write-Host "Location: $ShortcutPath"
Write-Host ''
Write-Host 'Claude Code Viewer will start automatically at login.'
