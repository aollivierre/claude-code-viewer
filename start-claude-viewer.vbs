' Claude Code Viewer Silent Startup
' This VBScript runs the PowerShell script hidden (no window flash)

Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\code\claude\code-viewer\start-claude-viewer.ps1""", 0, False
