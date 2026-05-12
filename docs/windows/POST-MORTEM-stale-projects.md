# Post-Mortem: Viewer Showed Stale Project List on Windows

**Date:** 2026-05-12
**Reporter:** user observed `http://localhost:3400/projects` listing only projects that existed when the viewer was started (~3 weeks earlier).
**Impact:** Every new project created after the viewer's last restart was invisible in the UI. On long-running deployments this looked like total cache rot.

---

## Summary

After investigating, two latent Windows-only bugs combined into a single user-visible symptom. The viewer relied entirely on a SQLite cache populated once at startup, with the file watcher expected to keep it in sync. On Windows the watcher chain was a no-op, so the cache never updated. A 22-day-old viewer process correctly served the snapshot it had taken at logon — the cache was doing its job; the invalidation path was the bug.

## Symptom

- Disk: `~/.claude/projects/` contained 15 project directories, 8 of them created in the previous 3 weeks.
- API: `GET /api/projects` returned only 7 projects, all dated before the viewer's start time (2026-04-20 12:04:48).
- Process inspection: the running node viewer had been up continuously since logon. It was not crashing, not erroring, and the supervisor (`%LOCALAPPDATA%\claude-code-viewer\claude-code-viewer.vbs`) was healthy.
- Restarting the viewer immediately fixed the count (7 → 15), confirming the data was correct on disk and the cache was stale.

## Root cause

### Bug 1 — `parseSessionFilePath` regex requires `/`, Windows `path.relative()` returns `\`

`src/server/core/events/services/fileWatcher.ts` computes the file path relative to the projects directory and hands it to `parseSessionFilePath`:

```ts
const relativePath = changedPath.startsWith(claudeProjectsDirPath)
  ? path.relative(claudeProjectsDirPath, changedPath)
  : changedPath;
const parsed = parseSessionFilePath(relativePath);
```

`parseSessionFilePath` uses these regexes:

```ts
const sessionFileRegExp = /(?<projectId>.*?)\/(?<sessionId>.*?)\.jsonl$/;
const agentFileRegExp   = /(?<projectId>.*?)\/agent-(?<agentSessionId>.*?)\.jsonl$/;
```

On Windows, `path.relative` returns separators with `\` — e.g. `C--code-foo\\abc123.jsonl`. The regex requires `/`, so **every event the watcher emitted was parsed as `null` and silently discarded.** The watcher effectively did nothing on Windows: no project syncs, no session syncs, no FTS updates.

### Bug 2 — No backstop when the watcher misses events

Even with the regex fixed, Node's `fs.watch(dir, { recursive: true })` on Windows is documented as unreliable for files created inside directories that didn't exist when the watcher started. New top-level project dirs in `~/.claude/projects/` were exactly that case. The architecture had no periodic re-scan — only the one-shot `SyncService.fullSync()` at process start (`src/server/hono/initialize.ts:60`).

### Why this manifested as "viewer is 22 days stale"

Combining the two: the watcher chain was effectively dead on Windows, and the only refresh path was a process restart. The user's viewer had been up since their last reboot — so the cache was frozen to that moment.

## Misdiagnosis along the way

Worth recording, because we burned time on it:

- **"Scheduled task is broken (error 0x80070420)"** — false. The error code surfaced when triggering the task because the existing instance was *already running fine* — that's exactly what 0x80070420 means. The VBS supervisor had been alive since logon and was respawning the viewer correctly on crashes. Running `Stop-ScheduledTask` to "clear the ghost" actually killed a healthy supervisor and required restoring it. Take-away: investigate Task Scheduler "ghosts" with `Get-CimInstance Win32_Process -Filter "Name='wscript.exe'"` first — if the supervisor process exists, the task is healthy.
- **"Cache invalidation is the only fix"** — partial. We also needed the path-separator fix, otherwise even sessions inside *existing* projects would silently fail to update.

## Fix

Two minimal source changes in the fork:

### 1. Normalize path separators in `parseSessionFilePath`

`src/server/core/events/functions/parseSessionFilePath.ts`:

```ts
export const parseSessionFilePath = (filePath: string): FileMatch => {
  // Normalize Windows path separators so the regexes (which match "/") work on Windows
  filePath = filePath.replace(/\\/g, "/");

  const agentMatch = filePath.match(agentFileRegExp);
  // ...
};
```

One-line fix. Restores the watcher's intended behavior on Windows.

### 2. Periodic `fullSync` daemon as backstop

`src/server/hono/initialize.ts`, after `fileWatcher.startWatching()`:

```ts
const periodicSyncDaemon = Effect.repeat(
  Effect.gen(function* () {
    yield* Effect.logInfo("[InitializeService] Periodic fullSync starting...");
    const start = Date.now();
    yield* syncService.fullSync().pipe(
      Effect.catchAll((e) => {
        Effect.runFork(
          Effect.logError(`[InitializeService] periodic fullSync failed: ${String(e)}`),
        );
        return Effect.void;
      }),
    );
    yield* Effect.logInfo(
      `[InitializeService] Periodic fullSync completed in ${Date.now() - start}ms`,
    );
  }),
  Schedule.fixed("2 minutes"),
);
yield* Effect.forkDaemon(periodicSyncDaemon);
```

A 2-minute cadence trades a small constant CPU cost (~1-2s every 2 min on this dataset) for guaranteed convergence regardless of watcher reliability. `fullSync()` is idempotent: when nothing changed on disk it just stats the project dirs and exits quickly.

## Verification

After rebuilding `dist/main.js` and restarting via the supervisor:

```
11:00:18  Server is running on http://localhost:3400
11:00:18  Periodic fullSync daemon started (interval: 2 minutes)
11:00:18  [InitializeService] Periodic fullSync starting...
11:00:18  [InitializeService] Periodic fullSync completed in 73ms
11:02:18  [InitializeService] Periodic fullSync starting...
11:02:20  [InitializeService] Periodic fullSync completed in 2175ms
11:04:18  [InitializeService] Periodic fullSync starting...
11:04:19  [InitializeService] Periodic fullSync completed in 1135ms

11:06:06  (TEST) created C--code-stale-fix-verification-test/ with one .jsonl
11:06:18  [InitializeService] Periodic fullSync starting...
11:06:20  Periodic fullSync completed in 1243ms — new project visible in API
```

Detection delay: **12 seconds** from disk creation to API visibility (worst case 2 minutes, the cadence interval). Pre-fix this would have been "until next process restart."

## Build + deploy commands (Windows)

```powershell
# Node 24+ required for the fork
$env:Path = "$env:USERPROFILE\AppData\Local\nodejs;" + $env:Path
Set-Location "$env:USERPROFILE\code\claude-code-viewer"
pnpm run build:backend

# Supervisor (VBS) respawns the viewer automatically when the old node exits
Stop-Process -Id (Get-NetTCPConnection -LocalPort 3400 -State Listen).OwningProcess -Force
# ~5 seconds later the VBS spawns a new node process loading dist/main.js
```

## Lessons

- **Path separators are a silent killer.** A regex that requires `/` won't throw on Windows — it just never matches. Every cross-platform regex over filesystem paths should normalize separators at the boundary, or use `path.sep` explicitly. Worth grepping the codebase for `\/` regex literals to find other instances.
- **Caches need an audit trail.** The viewer logged "Starting fullSync..." and "fullSync completed" once at startup, then went silent for 3 weeks. Nothing in the logs indicated whether the watcher was working or dead. The new periodic-sync log line provides a 2-minute heartbeat that proves the cache invalidator is alive.
- **Long-running processes hide cache bugs.** A bug that only manifests after the watcher silently misses an event for the first time is invisible until you let the process run for days. CI tests that spin up the viewer and check `getProjects()` minutes later won't catch this — you'd need a test that creates a project dir mid-run and waits for it to appear.
- **Trust process inspection over scheduler state.** Task Scheduler's "Running" state and exit codes (0x80070420 in particular) are unreliable indicators of whether a long-lived task action is actually doing its job. Check the actual processes via `Get-CimInstance Win32_Process` before stopping the task.

## Follow-ups (not done yet)

- **Log rotation.** `viewer.log` is currently ~55 KB after 22 days. With my new periodic-sync lines it'll grow ~30 MB/year. Easy to add in the VBS supervisor or via a nightly scheduled task; not urgent.
- **DB cleanup of legacy duplicate rows.** Pre-existing rows in the SQLite cache reference cwds that case-collide (`C:\code\bitlocker` vs `C--code-BitLocker`) and some reference paths inside `.claude/projects/` itself. Cosmetic; doesn't affect functionality. Would need a one-shot migration to dedupe.
- **Upstream PR.** Both fixes are arguably upstream-worthy if anyone wants to maintain Windows support in `d-kimuson/claude-code-viewer`. The path-separator fix is uncontroversial; the periodic fullSync may want a config flag for users who don't need it.
