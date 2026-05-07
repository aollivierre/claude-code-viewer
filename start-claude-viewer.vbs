' Claude Code Viewer Silent Startup
' This VBScript runs the PowerShell script hidden (no window flash)

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
ScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ScriptDir & "\start-claude-viewer.ps1""", 0, False
