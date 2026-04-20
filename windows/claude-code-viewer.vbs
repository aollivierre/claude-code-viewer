' Claude Code Viewer launcher (Task Scheduler target — supervisor loop)
'
' Invoked by the "ClaudeCodeViewer" scheduled task at user logon.
' Runs the viewer hidden and relaunches it forever if the node
' process exits for any reason (crash, OOM kill, manual taskkill).
'
' Log file: %LOCALAPPDATA%\claude-code-viewer\viewer.log

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

logDir  = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\claude-code-viewer")
If Not fso.FolderExists(logDir) Then fso.CreateFolder(logDir)
logFile = logDir & "\viewer.log"

' When launched via Task Scheduler with LogonType=S4U, the task runs in
' session 0 where %USERPROFILE% does NOT resolve to the user's home —
' it comes back as "C:\" and the viewer ends up trying to watch
' "C:\.claude\projects". Resolve paths via the well-known user SID
' profile list or hard-code for reliability. We expand LOCALAPPDATA
' (which DOES work in session 0) to derive the profile root.
localAppData = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%")  ' C:\Users\i\AppData\Local
userProfile  = fso.GetParentFolderName(fso.GetParentFolderName(localAppData))  ' C:\Users\i

nodeExe   = localAppData & "\nodejs\node.exe"
mainJs    = userProfile  & "\code\claude-code-viewer\dist\main.js"
claudeExe = userProfile  & "\.local\bin\claude.exe"
claudeDir = userProfile  & "\.claude"

q = Chr(34)
cmd = "cmd /c " & q & q & nodeExe & q & " " & q & mainJs & q & _
      " --port 3400" & _
      " --claude-dir "  & q & claudeDir  & q & _
      " --executable " & q & claudeExe & q & _
      " >> " & q & logFile & q & " 2>&1" & q

' Supervisor loop: launch the viewer hidden, wait for it to exit, then
' sleep and relaunch forever. This VBS becomes the crash-recovery
' supervisor — Task Scheduler's built-in "restart on failure" only
' handles launch failures (permissions, user-not-logged-on, etc.),
' NOT non-zero action exit codes from long-running processes, so a
' loop here is the reliable option.
'
' To stop the viewer permanently: stop the "ClaudeCodeViewer" scheduled
' task (End-ScheduledTask or Task Scheduler UI). Killing just the node
' process will cause this loop to relaunch it within ~5 seconds.
Do
  sh.Run cmd, 0, True   ' 0 = hidden window; True = wait for child exit
  WScript.Sleep 5000    ' brief backoff before respawn
Loop
