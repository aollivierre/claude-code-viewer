' Claude Code Viewer auto-start (Windows)
'
' Drop this file at:
'   %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\claude-code-viewer.vbs
'
' It launches the viewer hidden at login and appends logs to
'   %LOCALAPPDATA%\claude-code-viewer\viewer.log
'
' Two run modes — uncomment ONE:
'
'   (A) HAPPY PATH — latest published npm version. Use this once PR #201
'       (https://github.com/d-kimuson/claude-code-viewer/pull/201) is merged
'       AND a release containing it has shipped to npm.
'
'   (B) INTERIM PATH — run a locally built copy of the fork. Use this until
'       upstream releases a version with PR #201.
'
' Both modes need Node >= 24.0.0 on PATH (or at the path below) and rely on
' the viewer's --executable flag to find claude.exe without PATHEXT shell
' resolution.

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

logDir    = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\claude-code-viewer")
If Not fso.FolderExists(logDir) Then fso.CreateFolder(logDir)
logFile   = logDir & "\viewer.log"

' Path to the Claude Code CLI executable. If you installed claude via the
' official Windows installer this is where it lives; adjust if yours differs.
' Use "where claude" in cmd or "which claude" in Git Bash to confirm.
claudeExe = sh.ExpandEnvironmentStrings("%USERPROFILE%\.local\bin\claude.exe")

' ---- Mode (A) HAPPY PATH: npx @latest -----------------------------------
' nodeExe and mainJs are not needed in this mode (npx handles it).
'
' q = Chr(34)
' cmd = "cmd /c npx --yes @kimuson/claude-code-viewer@latest" & _
'       " --port 3400 --executable " & q & claudeExe & q & _
'       " >> " & q & logFile & q & " 2>&1"

' ---- Mode (B) INTERIM PATH: locally built fork --------------------------
' Adjust these two paths to match your machine.
nodeExe = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\nodejs\node.exe")
mainJs  = sh.ExpandEnvironmentStrings("%USERPROFILE%\code\claude-code-viewer\dist\main.js")

q = Chr(34)
cmd = "cmd /c " & q & q & nodeExe & q & " " & q & mainJs & q & _
      " --port 3400 --executable " & q & claudeExe & q & _
      " >> " & q & logFile & q & " 2>&1" & q

sh.Run cmd, 0, False
