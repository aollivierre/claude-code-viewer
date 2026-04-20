# Claude Code Viewer — Windows Setup

Unofficial Windows setup guide for [`@kimuson/claude-code-viewer`](https://github.com/d-kimuson/claude-code-viewer).

> The upstream project's README states "Windows is not supported" — this guide is a community workaround that wires up a local auto-start on `http://localhost:3400` via a one-file VBS launcher in the user Startup folder. No admin, no WSL, no Docker.

## Status of the upstream Windows blocker

The latest published release (≥ 0.7.0) crashes on first launch on Windows with:

```
ENOENT: no such file or directory, scandir 'C:\C:\Users\<you>\...\dist\migrations'
```

Doubled `C:\C:\` caused by `new URL(..., import.meta.url).pathname` returning `/C:/...` on Windows.

Fix submitted as **[PR #201](https://github.com/d-kimuson/claude-code-viewer/pull/201)** to upstream. Until that merges and a release ships on npm, this guide builds from a patched fork.

Other known Windows gaps (out of scope for PR #201, mostly tracked in upstream [PR #85](https://github.com/d-kimuson/claude-code-viewer/pull/85)):
- `claude --version` subprocess fails with ENOENT because Node `spawn` without a shell doesn't apply PATHEXT. Worked around in this guide by passing `--executable <path>` explicitly.
- `@replit/ruspty` has no Windows binary → in-app terminal panel disabled (warn-only; rest of viewer works).

## Prerequisites

- **Windows 10 / 11** with PowerShell and Git Bash (install Git for Windows).
- **Node.js ≥ 24.0.0** — required by `drizzle-orm/node-sqlite` for `StatementSync.setReturnArrays`.
- **Claude Code CLI** already installed somewhere (the viewer shells out to it). Run `where claude` in `cmd` to find the `.exe`.
- For the interim path only: `pnpm` (`npm install -g pnpm`) and **gitleaks** (pre-commit hook requirement — optional if you're only consuming, not contributing).

### Install Node 24 without admin

Install into user space so you don't overwrite any existing system Node:

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

New shells will pick up Node 24 first.

## Happy path — once PR #201 is merged AND released on npm

Check here before deciding: <https://github.com/d-kimuson/claude-code-viewer/pull/201>. If it's merged and a newer version than 0.7.3 is on npm that includes the fix:

1. Copy `windows/claude-code-viewer.vbs` from this repo to `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\`.
2. Open it in a text editor and **switch to Mode (A)**: uncomment the `cmd = "cmd /c npx ..."` block and comment out Mode (B).
3. Confirm `claudeExe` points at your actual Claude Code CLI (`where claude` in cmd).
4. Smoke-test: `cscript //nologo "$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup/claude-code-viewer.vbs"` then `curl http://localhost:3400/api/projects` — expect HTTP 200.
5. Open <http://localhost:3400/>.

## Interim path — until PR #201 ships

1. **Clone the patched fork** with long-path support and skip the e2e snapshots (some paths exceed Windows' 260-char limit):

   ```bash
   git config --global core.longpaths true
   mkdir -p "$USERPROFILE/code" && cd "$USERPROFILE/code"
   git -c core.longpaths=true clone --depth 1 --filter=blob:none --no-checkout \
     https://github.com/aollivierre/claude-code-viewer.git
   cd claude-code-viewer
   git config core.longpaths true
   git sparse-checkout init --no-cone
   git sparse-checkout set '/*' '!e2e/snapshots'
   git checkout fix/windows-migrations-path
   ```

2. **Install deps and build** (Node 24 must be on PATH; `engine-strict=false` bypasses sub-pnpm engine checks that sometimes don't inherit the parent PATH):

   ```bash
   export PATH="$LOCALAPPDATA/nodejs:$PATH"
   export npm_config_engine_strict=false
   pnpm install --frozen-lockfile --config.engine-strict=false
   bash ./scripts/build.sh
   ```

3. **Install the VBS launcher:**

   ```bash
   cp windows/claude-code-viewer.vbs \
     "$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup/"
   ```

   Open the copied VBS in a text editor and confirm:
   - It's in **Mode (B)** (the one with `nodeExe` / `mainJs` uncommented) — that's the default in this template.
   - `mainJs` points at your actual `dist/main.js` location (default assumes `%USERPROFILE%\code\claude-code-viewer\dist\main.js`).
   - `claudeExe` points at your actual Claude Code CLI.

4. **Smoke-test without rebooting:**

   ```bash
   cscript //nologo "$APPDATA/Microsoft/Windows/Start Menu/Programs/Startup/claude-code-viewer.vbs"
   sleep 15
   curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:3400/api/projects
   # expect HTTP 200
   ```

5. Open <http://localhost:3400/>.

## Operating notes

- **Log file**: `%LOCALAPPDATA%\claude-code-viewer\viewer.log` — grows without rotation; delete periodically.
- **Port**: the VBS hardcodes `3400`. Change `--port 3400` if taken.
- **Process lifetime**: tied to your user session. Logoff kills it; login re-launches via the Startup folder entry. No auto-restart on crash — if you need that, convert the launcher to a Task Scheduler entry with "Restart if the task fails" enabled.
- **Stop**: find the PID with `netstat -ano | findstr :3400`, then `taskkill /F /PID <pid>`. Don't `taskkill /IM node.exe` unless you're sure no other Node apps are running.
- **Disable auto-start**: delete the VBS from the Startup folder.
- **Known CLI caveat**: the viewer passes the `--executable` path verbatim to `spawn`. Keep it pointed at the `.exe` (or `.cmd`) — a bare `claude` with no extension won't resolve without a shell.

## What to do on a fresh machine

Copy-paste the following into a new Claude Code session on the new box:

> Read <https://github.com/aollivierre/claude-code-viewer/blob/main/windows/SETUP.md> and set up the Claude Code Viewer to auto-start on `http://localhost:3400`. Check PR #201 status first to decide happy vs. interim path. Report when the viewer is live and `curl http://localhost:3400/api/projects` returns 200.

## Upstream contribution status

| Bug                                 | Fixed by                 | Status             |
| ----------------------------------- | ------------------------ | ------------------ |
| `C:\C:\...\dist\migrations` ENOENT  | PR #201 (this fork)      | Open, awaiting review |
| `claude` spawn without PATHEXT      | PR #85 (not this fork)   | WIP since Dec 2025 |
| `@replit/ruspty` no Windows binary  | —                        | Upstream gap, terminal panel disabled as a consequence |

If/when PR #201 and PR #85 both merge and release, this fork can be retired — remote users switch their VBS to Mode (A) and the guide boils down to "install Node 24, drop the VBS, done."
