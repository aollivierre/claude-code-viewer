# Claude Code Viewer — Windows Setup

Unofficial Windows setup guide for [`@kimuson/claude-code-viewer`](https://github.com/d-kimuson/claude-code-viewer).

> Upstream's README says "Windows is not supported." This guide gets the viewer running on `http://localhost:3400` with crash-auto-restart via **Task Scheduler + a supervisor VBS**. No admin, no WSL, no Docker.

## Known Windows blockers

| Bug | Fixed by | Where |
|---|---|---|
| `C:\C:\...\dist\migrations` ENOENT on startup (doubled drive letter from `URL.pathname`) | **This fork's `main` branch** (upstream PR still open) | PR [#201](https://github.com/d-kimuson/claude-code-viewer/pull/201) |
| `claude --version` spawn fails because Node `spawn` (no shell) doesn't apply PATHEXT | Workaround: pass `--executable <path-to-claude.exe>` | VBS arg |
| `USERPROFILE` expands to `C:\` when the task runs with `LogonType=S4U` (session 0) → file watcher tries `C:\.claude\projects` | Workaround: pass `--claude-dir <path>` explicitly, derived from `%LOCALAPPDATA%` | VBS arg |
| `@replit/ruspty` ships no Windows binary → in-app terminal panel disabled (warn-only) | Open upstream | None — rest of viewer works |

## Migrating from the npm-global install

If you previously ran `npm i -g @kimuson/claude-code-viewer` and used a Startup-folder shortcut to auto-start it, **disable that first** — otherwise the old instance holds port 3400, its HTTP 200 masks a broken fork build, and the supervised setup can't take over.

```powershell
# 1. Disable the Startup-folder shortcut (reversible — we rename, not delete)
$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeCodeViewer.lnk"
if (Test-Path $lnk) { Move-Item -LiteralPath $lnk -Destination "$lnk.bak" -Force }

# 2. Kill any listener on 3400
netstat -ano | Select-String ':3400 .*LISTENING' | ForEach-Object {
  $procId = ($_ -split '\s+')[-1]
  Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
}

# 3. (optional) Remove the global package entirely
# npm uninstall -g @kimuson/claude-code-viewer
```

## Prerequisites

- **Windows 10 / 11** with PowerShell and Git Bash (install Git for Windows).
- **Node.js ≥ 24.0.0** — required by `drizzle-orm/node-sqlite` for `StatementSync.setReturnArrays`.
- **Claude Code CLI** installed somewhere. `where claude` in `cmd` to find the `.exe`.
- **pnpm** (`npm install -g pnpm`) — only needed until upstream releases include PR #201.

### Shell choice

Commands below split by shell deliberately. Run `npm`, `pnpm`, `node`, and every PowerShell cmdlet from **PowerShell** — Git Bash's MSYS path conversion mangles `.cmd` shim arguments and breaks npm with `Cannot find module 'C:\Program Files\Git\Users\...'`. Keep Git Bash for `git`, `curl`, `cp`, `unzip`, `mkdir`, and for invoking `bash ./scripts/build.sh`.

### Install Node 24 user-locally (no admin)

```bash
# Git Bash
mkdir -p "$LOCALAPPDATA/nodejs"
curl -L -o /tmp/node24.zip https://nodejs.org/dist/v24.10.0/node-v24.10.0-win-x64.zip
unzip -q /tmp/node24.zip -d /tmp/
mv /tmp/node-v24.10.0-win-x64/* "$LOCALAPPDATA/nodejs/"
rm -rf /tmp/node24.zip /tmp/node-v24.10.0-win-x64
"$LOCALAPPDATA/nodejs/node.exe" --version   # expect v24.10.0
```

Persist on user PATH (PowerShell — no admin):

```powershell
$n = "$env:LOCALAPPDATA\nodejs"
$u = [Environment]::GetEnvironmentVariable('PATH','User')
if (($u -split ';') -notcontains $n) {
  [Environment]::SetEnvironmentVariable('PATH',
    (@($n) + ($u -split ';' | ? { $_ })) -join ';', 'User')
}
```

## Build the patched viewer

Clone in **Git Bash** (sparse-checkout trims the ~1800 e2e snapshot files that blow up `pnpm install` wall time):

```bash
git config --global core.longpaths true    # some e2e snapshot paths exceed 260 chars
mkdir -p "$USERPROFILE/code" && cd "$USERPROFILE/code"
git -c core.longpaths=true clone --depth 1 --filter=blob:none --no-checkout \
  https://github.com/aollivierre/claude-code-viewer.git
cd claude-code-viewer
git config core.longpaths true
git sparse-checkout init --no-cone
git sparse-checkout set '/*' '!e2e/snapshots'
git checkout main
```

Install and build in **PowerShell** (Git Bash mangles npm.cmd args — see "Shell choice" above):

```powershell
$env:PATH = "$env:LOCALAPPDATA\nodejs;$env:PATH"
$env:npm_config_engine_strict = 'false'
Set-Location "$env:USERPROFILE\code\claude-code-viewer"
npm install -g pnpm
pnpm install --frozen-lockfile --config.engine-strict=false
bash ./scripts/build.sh
```

Result: `$USERPROFILE/code/claude-code-viewer/dist/main.js` is your runnable build.

## Install the supervisor launcher

```bash
mkdir -p "$LOCALAPPDATA/claude-code-viewer"
cp "$USERPROFILE/code/claude-code-viewer/windows/claude-code-viewer.vbs" \
   "$LOCALAPPDATA/claude-code-viewer/claude-code-viewer.vbs"
```

**Read the VBS** — it hardcodes these paths inside the launcher (all derived from `%LOCALAPPDATA%` so they work in session 0):

| Variable | Default | Edit if |
|---|---|---|
| `nodeExe` | `%LOCALAPPDATA%\nodejs\node.exe` | you installed Node elsewhere |
| `mainJs` | `%USERPROFILE%\code\claude-code-viewer\dist\main.js` | you cloned elsewhere |
| `claudeExe` | `%USERPROFILE%\.local\bin\claude.exe` | `where claude` says different |
| `claudeDir` | `%USERPROFILE%\.claude` | non-default Claude Code dir |
| port | `3400` | port in use |

## Register the scheduled task

Run this in **PowerShell** (no admin needed for this configuration):

```powershell
$taskName = 'ClaudeCodeViewer'
$vbs = "$env:LOCALAPPDATA\claude-code-viewer\claude-code-viewer.vbs"
# Use the actual interactive identity — $env:USERNAME can be wrong under
# some launcher contexts (e.g. when this PowerShell was itself spawned
# from a service). GetCurrent().Name is authoritative.
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action    = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings  = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 999 `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
# S4U (Service For User) — avoids the "user not logged on" false negative
# Task Scheduler can throw under RDP / Windows Hello / Azure AD sessions
# when using LogonType Interactive. The tradeoff is that the task runs in
# session 0, which is why the VBS derives paths from %LOCALAPPDATA%
# rather than %USERPROFILE% (see top of windows/claude-code-viewer.vbs).
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Limited

Register-ScheduledTask -TaskName $taskName `
    -Description 'Auto-start Claude Code Viewer on localhost:3400 (supervised)' `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

## Smoke-test without rebooting

```powershell
Start-ScheduledTask -TaskName 'ClaudeCodeViewer'
```

```bash
sleep 15
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3400/api/projects  # expect 200
```

Open <http://localhost:3400/>. First launch takes ~15–25 s while node / node_modules warm up.

## Verifying crash recovery

```bash
# find and kill node
PID=$(netstat -ano | grep ":3400.*LISTENING" | awk '{print $NF}' | head -1)
taskkill //PID $PID //F

# should be back in ~5–10 s (VBS supervisor backoff + node startup)
for i in $(seq 1 30); do
  netstat -ano | grep -qE ":3400\b.*LISTENING" && echo "respawned at +${i}s" && break
  sleep 1
done
```

## Operating notes

- **Log**: `%LOCALAPPDATA%\claude-code-viewer\viewer.log` — grows without rotation; prune periodically.
- **Stop permanently**: stop the scheduled task. `Stop-ScheduledTask -TaskName ClaudeCodeViewer` — this kills wscript, which kills its cmd+node chain. If you just `taskkill node.exe`, the VBS supervisor will relaunch it in ~5 s.
- **Disable auto-start**: `Disable-ScheduledTask -TaskName ClaudeCodeViewer` (keeps the definition) or `Unregister-ScheduledTask` (removes it).
- **Port conflict**: edit `--port 3400` in `claude-code-viewer.vbs`, then `Stop-ScheduledTask` + `Start-ScheduledTask`.
- **Update to newer fork commit**: `cd ~/code/claude-code-viewer && git pull && bash scripts/build.sh` — the running supervisor will pick up the new `dist/main.js` after the next restart (`taskkill node` is enough).
- **Switch to upstream once PR #201 ships**: replace the VBS's `cmd` line with `"cmd /c npx --yes @kimuson/claude-code-viewer@latest --port 3400 --claude-dir " & q & claudeDir & q & " --executable " & q & claudeExe & q & " >> " & q & logFile & q & " 2>&1"`, restart the task, delete the clone at `~/code/claude-code-viewer`.

## Why this design

- **Task Scheduler over Startup folder**: Startup folder fires only at login. If the viewer dies mid-session, it stays dead until next login. Task Scheduler keeps the supervisor alive independently of user sessions.
- **Supervisor loop in VBS over Task Scheduler's built-in restart**: Task Scheduler's "restart on failure" only fires when the task *fails to launch* (permission, missing file) — not when the action returns non-zero. A long-running process crash returns non-zero, which Task Scheduler treats as "completed, OK" and does not restart. The VBS loop handles that case. Task Scheduler is still useful for starting the supervisor and restarting it if it itself dies.
- **S4U over Interactive**: Interactive logon type checks for an active interactive desktop session, which fails under RDP / Windows Hello / Azure AD even when the user is obviously logged on. S4U avoids the check. The cost is running in session 0 — we work around that by computing paths from `%LOCALAPPDATA%` (which works) rather than `%USERPROFILE%` (which breaks).

## Fresh-machine prompt

Paste this into a Claude Code session on a new Windows 11 box:

> Set up `@kimuson/claude-code-viewer` to auto-start on `http://localhost:3400` with crash-auto-restart. Follow <https://github.com/aollivierre/claude-code-viewer/blob/main/windows/SETUP.md> end to end — including the "Migrating from the npm-global install" section if this box previously auto-started the viewer from the Startup folder. Before starting, check <https://github.com/d-kimuson/claude-code-viewer/pull/201> — if merged and released to npm with a version newer than 0.7.4, you can skip the fork build and edit the VBS to use `npx --yes @kimuson/claude-code-viewer@latest` instead of the local `node ... dist/main.js`. Report back with: the Node version you installed, the path to your `claude.exe`, the task's `LastTaskResult` after `Start-ScheduledTask`, and the HTTP status from `curl http://localhost:3400/api/projects`.
