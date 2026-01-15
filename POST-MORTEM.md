# Claude Code Viewer Setup - Post-Mortem

## Date: 2026-01-15

## Summary
Setup of `@kimuson/claude-code-viewer` on Windows 11 without Docker, configured for automatic startup on reboot.

---

## Issues Encountered

### Issue 1: Environment Variables Not Working
**Symptom:** Server started but bound to wrong IP address (198.18.1.154 instead of 0.0.0.0)

**Root Cause:** Environment variables (`CCV_PASSWORD`, `CCV_HOSTNAME`, `PORT`) set in PowerShell script were not being picked up by the node process.

**Solution:** Use CLI arguments instead of environment variables:
```powershell
# WRONG - env vars not reliable
$env:PORT = 3400
$env:CCV_PASSWORD = $Password
& claude-code-viewer.cmd

# CORRECT - CLI args work reliably
& claude-code-viewer.cmd -p 3400 -h 0.0.0.0 -P $Password
```

---

### Issue 2: 401 Unauthorized Despite Correct Password
**Symptom:** User entered correct password but received `HttpError: 401 Unauthorized`

**Root Cause:** Password contained special characters (`*`, `&`, `^`) that caused shell escaping issues when passed through PowerShell → cmd → node chain.

**Original Password:** `kHBw*P&zaNQDCfkzVW^FFMKz`

**Solution:** Use alphanumeric-only passwords to avoid shell escaping problems:
```powershell
# WRONG - special chars cause escaping issues
$Password = 'kHBw*P&zaNQDCfkzVW^FFMKz'

# CORRECT - alphanumeric only
$Password = '7FZQHKrfQTQFANx9JDHbkrNCVV6JPF58'
```

**Password Generation (safe characters only):**
```javascript
// Node.js - no special characters
const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
let password = '';
for (let i = 0; i < 32; i++) {
  password += chars[Math.floor(Math.random() * chars.length)];
}
console.log(password);
```

---

### Issue 3: Scheduled Task Requires Admin Rights
**Symptom:** `Register-ScheduledTask` failed with "Access is denied"

**Root Cause:** Creating scheduled tasks requires administrator privileges.

**Solution:** Use Windows Startup folder instead (no admin rights needed):
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

A VBScript launcher is used to run PowerShell hidden (no window flash):
```vbscript
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -WindowStyle Hidden ...", 0, False
```

---

## Final Working Configuration

### Files Created
| File | Purpose |
|------|---------|
| `start-claude-viewer.ps1` | Main startup script with configuration |
| `start-claude-viewer.vbs` | Silent launcher (no window) |
| `install-startup.ps1` | Creates shortcut in Startup folder |
| `setup-scheduled-task.ps1` | Alternative setup (requires admin) |
| `kill-viewer.ps1` | Utility to stop the viewer |

### Access Details
- **URL:** http://localhost:3400
- **Password:** `7FZQHKrfQTQFANx9JDHbkrNCVV6JPF58`
- **Listening:** `0.0.0.0:3400` (accessible from network)

### Auto-Start Location
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeCodeViewer.lnk
```

---

## Lessons Learned

1. **Prefer CLI arguments over environment variables** when launching Node.js apps from PowerShell scripts - more reliable across shell boundaries.

2. **Avoid special characters in passwords** when they'll be passed through multiple shell layers (PowerShell → cmd → node).

3. **Windows Startup folder is simpler than Scheduled Tasks** for user-level auto-start - no admin rights needed.

4. **Always test the actual user flow** (entering password in browser) not just HTTP status codes.

---

## To Recreate This Setup

```powershell
# 1. Install
npm install -g @kimuson/claude-code-viewer

# 2. Run install script
powershell -ExecutionPolicy Bypass -File "C:\code\claude\code-viewer\install-startup.ps1"

# 3. Start now (or reboot)
wscript "C:\code\claude\code-viewer\start-claude-viewer.vbs"
```

## To Uninstall

```powershell
# Stop the service
powershell -ExecutionPolicy Bypass -File "C:\code\claude\code-viewer\kill-viewer.ps1"

# Remove from startup
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\ClaudeCodeViewer.lnk"

# Uninstall package (optional)
npm uninstall -g @kimuson/claude-code-viewer
```
