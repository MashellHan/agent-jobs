# Agent Jobs Review -- v023
**Date:** 2026-04-11T14:50:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 09ae7ec + unstaged changes (main)
**Files scanned:** utils.ts, scanner.ts, job-table.tsx, job-detail.tsx, job-table.test.tsx, utils.test.ts, scanner.test.ts, snapshots
**Previous review:** v022 (score 72/100, architecture gaps)

## Overall Score: 80/100 (+8)

The implementation agent addressed **2 of the 4 user feedback items** from review-022: date format (FB-4) and cron task naming (partial FB-2/FB-3). Detail panel section headers also added per v021's optional P2. Tests are green (184, up from 174) with new test coverage for `formatCompactTime` and `friendlyCronName`. However, the **two CRITICAL items remain unimplemented**: no launchd scanner (FB-1 — pew sync still invisible) and no registered-job schedule detection (FB-3 — everything still hardcoded "always-on").

---

## What Was Done

### 1. `formatCompactTime()` added (`utils.ts`) — FB-4 ✅

```typescript
export function formatCompactTime(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  return `${mm}-${dd} ${hh}:${mi}`;
}
```

- LAST RUN column now shows `"04-10 18:00"` instead of `"7h ago"` ✅
- CREATED column kept as `formatRelativeTime()` — reasonable choice (relative is fine for "when was this created")
- `COL.lastRun` increased from 10 → 12 to fit the `"MM-DD HH:MM"` format ✅
- 4 new tests in `utils.test.ts` covering null, invalid, valid format, and padding

### 2. `friendlyCronName()` added (`utils.ts`) — partial FB-2 ✅

Extracts human-readable names from cron task prompts:
- `"pew sync --all"` → `"pew sync"` (shell command parsing)
- `"Run nightly database backup"` → `"nightly database ba…"` (verb stripping + 20-char cap)
- `""` → `"cron task"` (fallback)

Used in `scanner.ts:156` replacing the old `(t.prompt).slice(0, 50)` approach.

6 new tests in `utils.test.ts`:
- Shell command extraction, path binary, empty prompt, natural language, truncation, verb detection

### 3. `scanClaudeScheduledTasks` updated (`scanner.ts`) — test improvement ✅

- Now uses `friendlyCronName()` instead of raw `prompt.slice(0, 50)`
- Scanner tests updated: `"Run backup script"` → `"backup script"`, `"Check health endpoint"` → `"health endpoint"`
- Long prompt truncation test now verifies 20-char cap with ellipsis

### 4. Detail panel section headers (`job-detail.tsx`) — v021 P2 ✅

- Fields split into 3 groups: info, schedule, history
- Visual separators: `── Schedule ──` and `── History ──`
- `renderField` helper for DRY rendering
- `"Schedule"` label changed to `"Frequency"` (clearer)
- Snapshot updated to reflect new layout

### 5. Test results

```
Test Files  7 passed (7)
     Tests  184 passed (184)  (+10 from v021's 174)
```

New test breakdown: `formatCompactTime` (4) + `friendlyCronName` (6) = 10 new tests.

---

## What Is Still MISSING

### P0: Launchd scanner — FB-1 (CRITICAL, UNCHANGED)

**Pew sync is still invisible.** No `scanLaunchdServices()` function has been implemented. The user has a real service at `~/Library/LaunchAgents/com.pew.sync.plist` running every 10 minutes via launchd, and the dashboard cannot see it.

Review-022 provided a complete technical design for this (see "Phase 1: Launchd Scanner"). The key implementation steps:

1. **Read `~/Library/LaunchAgents/*.plist`** — skip `com.apple.*`
2. **Parse via `plutil -convert json -o -`** — no external dependency
3. **Extract schedule** from `StartInterval` (seconds) or `StartCalendarInterval`
4. **Extract command** from `ProgramArguments` array
5. **Check loaded status** via `launchctl list`
6. **Update `loader.ts`** to add the 4th data source

**This is the #1 priority.** Without it, the user's primary complaint (pew sync not showing) remains unresolved.

### P1: Registered job schedule detection — FB-3 (partially addressed)

`detect.ts:240` still hardcodes `schedule: "always-on"` for all registered jobs. The `friendlyCronName` and `cronToHuman` improvements are good for display, but the underlying data for registered jobs is always `"always-on"` regardless of actual schedule.

For jobs started with `--interval`, `--cron`, or similar flags, the detector should extract the schedule from the command string. Review-022 provided a `detectScheduleFromCommand()` design.

### P1: Service name cleanup — FB-2 (partially addressed)

`friendlyCronName` handles cron task naming well. But registered jobs still prefix runtime in the name:
- `"pm2 api.js"` → should be `"api.js"` (pm2 is the runtime)
- `"node server.js"` → should be `"server.js"` (node is the runtime)
- `"docker:my-app"` → should be `"my-app"` (docker is the runtime)

The `detect.ts` `BASH_PATTERNS` label functions need updating per review-022's Phase 2 design.

---

## Code Quality Notes

### Good patterns observed

1. **`formatCompactTime` uses local timezone** — `d.getHours()`, `d.getMinutes()` use local time, which is correct for a dashboard showing "when did this last run" to the user sitting at the terminal.

2. **`friendlyCronName` design** — The verb-stripping + shell-command-parsing dual approach is smart. It handles both natural language (`"Run nightly backup"`) and CLI commands (`"pew sync --all"`).

3. **Detail panel sections** — The `infoFields` / `scheduleFields` / `historyFields` split is clean and makes the component more maintainable.

### Minor issues

1. **`friendlyCronName` edge case**: The `check` verb is in the strip list (`run|execute|do|perform|check`), but `"check system health status"` currently matches the shell-command branch first (because `wasStripped` check runs after verb stripping). The test at line 278 shows `"check system"` as output — this is from the command branch, not verb stripping. This means `"check" + space + word` always takes the command path. Acceptable behavior but documenting for clarity.

2. **Snapshot line length**: The table snapshot (line 4) now shows `LAST RUN` with 12-char width, but the total row width is 108 chars (was 106). This is fine for ≥120-char terminals but may wrap on very narrow terminals.

---

## Category Scores

| Category | Score | v022 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 25 | 18 | **+7** | 184/184 pass, date format fixed, cron names improved. Still no launchd data. |
| Architecture (20pts) | 15 | 14 | **+1** | Detail panel well-structured. Still missing launchd scanner architecture. |
| Production-readiness (20pts) | 16 | 16 | -- | Pew sync still invisible — user's primary complaint unresolved. |
| Open-source quality (15pts) | 12 | 12 | -- | Good JSDoc on new functions. No docs for launchd limitation. |
| Security (15pts) | 12 | 12 | -- | Unchanged. Corrupted jobs.json entries still present. |
| **TOTAL** | **80** | **72** | **+8** | |

---

## Action Items for Implementation Agent

### P0: Implement `scanLaunchdServices()` — BLOCKING

This is the **single most important remaining task**. Without it, the user's real `pew sync` service is invisible.

**Implementation outline** (full design in review-022):

```typescript
// scanner.ts — add this function

import { readdir } from "fs/promises";

export async function scanLaunchdServices(): Promise<Job[]> {
  const agentsDir = join(homedir(), "Library", "LaunchAgents");
  
  // 1. List plist files (skip com.apple.*)
  let files: string[];
  try {
    files = (await readdir(agentsDir)).filter(
      f => f.endsWith(".plist") && !f.startsWith("com.apple.")
    );
  } catch {
    return [];
  }
  
  // 2. Parse each plist using macOS native plutil
  const jobs: Job[] = [];
  for (const file of files) {
    try {
      const json = await parsePlist(join(agentsDir, file));
      const label = json.Label ?? file.replace(".plist", "");
      const args: string[] = json.ProgramArguments ?? [];
      const command = args.join(" ");
      
      // 3. Derive friendly name
      const name = deriveFriendlyName(args) || label.split(".").pop()!;
      
      // 4. Derive schedule
      const schedule = deriveSchedule(json);
      
      // 5. Check if loaded
      const isLoaded = await isLaunchdLoaded(label);
      
      jobs.push({
        id: `launchd-${label}`,
        name,
        description: command,
        agent: "system",
        schedule,
        status: isLoaded ? "active" : "stopped",
        source: "launchd",
        project: "",
        created_at: new Date().toISOString(), // or use plist file mtime
        last_run: null, // can try parsing log files later
        next_run: null,
        last_result: isLoaded ? "success" : "unknown",
        run_count: -1,
      });
    } catch {
      continue; // skip corrupt plists
    }
  }
  return jobs;
}

// Parse plist to JSON using macOS native tool
async function parsePlist(path: string): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    execFile("plutil", ["-convert", "json", "-o", "-", path],
      { encoding: "utf-8", timeout: 3000 },
      (err, stdout) => {
        if (err) return reject(err);
        try { resolve(JSON.parse(stdout)); }
        catch (e) { reject(e); }
      }
    );
  });
}

// Extract schedule from plist data
function deriveSchedule(plist: Record<string, unknown>): string {
  const interval = plist.StartInterval as number | undefined;
  if (interval) {
    if (interval < 60) return `every ${interval}s`;
    if (interval < 3600) return `every ${Math.round(interval / 60)} min`;
    return `every ${Math.round(interval / 3600)}h`;
  }
  if (plist.StartCalendarInterval) return "calendar"; // could parse further
  if (plist.KeepAlive || plist.RunAtLoad) return "always-on";
  return "on-demand";
}

// Derive name from ProgramArguments: ["pew", "sync"] → "pew sync"
function deriveFriendlyName(args: string[]): string {
  if (args.length === 0) return "";
  const binary = args[0]!.split("/").pop()!;
  const subArgs = args.slice(1).filter(a => !a.startsWith("-"));
  return subArgs.length > 0 ? `${binary} ${subArgs.join(" ")}` : binary;
}

// Check if a launchd service is loaded
async function isLaunchdLoaded(label: string): Promise<boolean> {
  return new Promise((resolve) => {
    execFile("launchctl", ["list", label],
      { encoding: "utf-8", timeout: 3000 },
      (err) => resolve(!err)
    );
  });
}
```

**Then update `loader.ts`:**

```typescript
import { scanLaunchdServices } from "./scanner.js";

export async function loadAllJobs(): Promise<Job[]> {
  const [registered, live, cron, launchd] = await Promise.all([
    loadRegisteredJobs(),
    scanLiveProcesses(),
    scanClaudeScheduledTasks(),
    scanLaunchdServices(),  // ← NEW
  ]);
  return [...registered, ...cron, ...launchd, ...live];
}
```

**Test plan for launchd scanner** (see review-022 for full list):

```
scanner.test.ts — new describe("scanLaunchdServices")

1. "returns empty when ~/Library/LaunchAgents doesn't exist"
2. "parses com.pew.sync.plist → name:'pew sync', schedule:'every 10 min'"
3. "skips com.apple.* plists"
4. "handles StartCalendarInterval"
5. "handles KeepAlive as always-on"
6. "sets status=stopped for unloaded services"
7. "derives friendly name from ProgramArguments"
```

### P1: Update `detect.ts` name patterns

Strip runtime prefixes from registered job names in `BASH_PATTERNS`:
- `pm2 start api.js` → `"api"` (not `"pm2 api.js"`)
- `node server.js` → `"server.js"` (not `"node server.js"`)
- `docker run --name my-app` → `"my-app"` (not `"docker:my-app"`)

### P1: Schedule detection in `detect.ts`

Replace `schedule: "always-on"` hardcode (line 240) with command-based detection:
```typescript
function detectSchedule(cmd: string): string {
  const interval = cmd.match(/--interval\s+(\d+)/);
  if (interval) return `every ${Math.round(parseInt(interval[1]!, 10) / 60)} min`;
  return "always-on"; // default for daemons
}
```

---

## Score Trajectory

```
v001: 28  ████
v002: 30  █████
...
v017: 98  ████████████████
v018: 99  ████████████████
v019: 92  ███████████████   ← user UX feedback
v020: 88  ██████████████    ← test regression
v021: 97  ████████████████  ← recovery
v022: 72  ████████████      ← architecture gaps exposed
v023: 80  █████████████     ← partial fixes (FB-4 done, FB-1 pending)
```

Expected score after launchd scanner: **92-95/100**.

---

## Communication

### To the implementation agent

#### Good progress on date format and cron names — now focus on the launchd scanner

You've addressed 2 of 4 user feedback items well:
- ✅ **FB-4 (date format)** — `formatCompactTime()` is exactly what was needed. The `"04-10 18:00"` format is clear and fits the column width.
- ✅ **FB-2 partial (cron naming)** — `friendlyCronName()` is a smart design with dual-mode parsing (shell command vs natural language). Well-tested.
- ✅ **Detail section headers** — Clean implementation splitting fields into logical groups.

**The big missing piece is the launchd scanner (FB-1).** The user's `pew sync` service runs via `~/Library/LaunchAgents/com.pew.sync.plist` and is completely invisible to the dashboard. This is their #1 complaint. I've provided the full implementation outline above — it's approximately 80 lines of code in `scanner.ts` plus a few lines in `loader.ts`.

Key implementation tips:
- Use `plutil -convert json -o -` to parse plists — it's a macOS built-in, zero dependencies
- Filter out `com.apple.*` plists (there are hundreds of Apple system plists)
- Use `launchctl list <label>` (single label, not `launchctl list | grep`) to check if loaded — it exits 0 if loaded, non-zero if not
- `StartInterval: 600` means "every 600 seconds" → `"every 10 min"`
- `ProgramArguments: ["/opt/homebrew/bin/pew", "sync"]` → name `"pew sync"`, description `"/opt/homebrew/bin/pew sync"`

After implementing the scanner, the user will finally see their pew sync service in the dashboard. That will resolve the primary complaint.

---

## Summary

v023 scores **80/100** (+8). Implementation agent addressed FB-4 (date format → `formatCompactTime`) and partial FB-2 (cron naming → `friendlyCronName`). Detail panel section headers added. 184 tests pass. However, the two CRITICAL items from review-022 remain: (1) no launchd scanner — pew sync still invisible, (2) registered job schedule still hardcoded "always-on". The launchd scanner is the #1 priority — full implementation outline provided.
