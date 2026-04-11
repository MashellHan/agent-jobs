# Agent Jobs Review -- v022
**Date:** 2026-04-11T14:40:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 4940b93 (main)
**Files scanned:** detect.ts, scanner.ts, loader.ts, types.ts, utils.ts, job-table.tsx, job-detail.tsx, fixtures.ts
**Previous review:** v021 (score 97/100)
**Trigger:** User feedback — 4 critical UX/architecture issues

## Overall Score: 72/100 (-25)

This is an **architecture-level review** triggered by user feedback revealing fundamental gaps in the data pipeline. The UI code (v021 = 97/100) is well-tested and clean, but the **backend data sources are broken**: launchd services don't appear, scheduled tasks are missing, names are still opaque, and timestamps use relative format instead of absolute. These are not UI bugs — they require data pipeline and scanner refactoring.

---

## User Feedback (4 Issues)

| # | 原文 | Severity | Root Cause |
|---|------|----------|------------|
| FB-1 | pew sync 每10分钟运行一次，但 dashboard 没有数据 | **CRITICAL** | `scanner.ts` has no launchd scanner — only reads `lsof` (live ports) and `scheduled_tasks.json` (missing file) |
| FB-2 | service name 还是不清晰，应该显示 pew sync 这样人能看懂的 name | **HIGH** | `detect.ts:240` hardcodes `"always-on"` for all registered jobs; name extraction relies on regex, not service metadata |
| FB-3 | schedule 全都是 always-on，定时任务和 agent 启动的定时任务没出现 | **CRITICAL** | `scanClaudeScheduledTasks()` reads `~/.claude/scheduled_tasks.json` which **does not exist**; no launchd schedule parsing |
| FB-4 | last run 应该展示日期和时间格式，不是相对的 | **MEDIUM** | `job-table.tsx` LAST RUN column uses `formatRelativeTime()` instead of `formatTime()` |

---

## Root Cause Analysis

### Architecture Gap: Missing Data Sources

The current loader (`loader.ts:11-16`) merges 3 sources:

```typescript
const [registered, live, cron] = await Promise.all([
  loadRegisteredJobs(),       // ← reads ~/.agent-jobs/jobs.json (4 test entries)
  scanLiveProcesses(),        // ← lsof -i (listening ports only)
  scanClaudeScheduledTasks(), // ← reads ~/.claude/scheduled_tasks.json (FILE MISSING)
]);
```

**What's missing:**

| Source | Status | What it catches | What it misses |
|--------|--------|----------------|----------------|
| `registered` | ✅ Partial | Services started via Claude Code Bash/Write hooks | Services started outside Claude sessions |
| `live` | ✅ Works | Processes listening on TCP ports (`lsof -i`) | Background tasks without open ports (pew sync, cron jobs) |
| `cron` | ❌ Broken | Would read `scheduled_tasks.json` | File doesn't exist on this system |
| **`launchd`** | ❌ Missing | Nothing | **All macOS LaunchAgent services** (pew sync, pew update, etc.) |

### Why pew sync is invisible

1. **pew sync** runs via `~/Library/LaunchAgents/com.pew.sync.plist` — a macOS launchd service
2. It runs every 600 seconds (10 min), executes `/opt/homebrew/bin/pew sync`, then exits
3. It does **NOT** listen on a TCP port → `scanLiveProcesses()` (lsof) can't see it
4. It was **NOT** started via Claude Code → `detect.ts` PostToolUse hook never fired
5. There is **no** `scanLaunchdServices()` function → this entire class of services is invisible

**Evidence — pew sync IS running:**
```
$ launchctl list | grep pew
-    0    com.pew.update
-    0    com.pew.sync

$ cat ~/Library/LaunchAgents/com.pew.sync.plist
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/bin/pew</string>
  <string>sync</string>
</array>
<key>StartInterval</key>
<integer>600</integer>
```

### Why all services show "always-on"

**`detect.ts:240`** — hardcoded:
```typescript
file.jobs.push({
  // ...
  schedule: "always-on",   // ← ALWAYS hardcoded, regardless of actual schedule
});
```

The PostToolUse hook detects _that_ a service was started, but has no mechanism to determine _how often_ it runs. For launchd plists, the schedule is in `StartInterval` or `StartCalendarInterval` keys. For cron, it's the cron expression. For always-on services (docker, pm2), "always-on" is correct. But the current code applies "always-on" to everything.

### Current jobs.json data quality

```json
// ~/.agent-jobs/jobs.json — 4 entries, 2 corrupted
"docker:my-app"          ✅ Clean
"docker:container"       ❌ Description has test command leakage
"pm2 api.js"             ✅ Clean
"pm2 api.js\"},\"tool_result\":\"started\"}'\"   ❌ Corrupted name (JSON residue)
```

---

## Technical Design: Required Changes

### Phase 1: Launchd Scanner (FB-1, FB-3) — CRITICAL

Add `scanLaunchdServices()` to `scanner.ts`:

```typescript
// scanner.ts — NEW FUNCTION

export async function scanLaunchdServices(): Promise<Job[]> {
  const agentsDir = join(homedir(), "Library", "LaunchAgents");
  
  // 1. List user LaunchAgent plists
  const plists = await readdir(agentsDir).catch(() => []);
  const userPlists = plists.filter(f => f.endsWith(".plist") && !f.startsWith("com.apple."));
  
  // 2. Parse each plist for schedule and command
  const jobs: Job[] = [];
  for (const filename of userPlists) {
    const plistPath = join(agentsDir, filename);
    const content = await readFileContents(plistPath);
    const parsed = parsePlist(content); // Use plist XML parser
    
    // 3. Extract label, command, schedule
    const label = parsed.Label ?? filename.replace(".plist", "");
    const args: string[] = parsed.ProgramArguments ?? [];
    const command = args.join(" ");
    const friendlyName = deriveFriendlyName(label, args);
    const schedule = deriveSchedule(parsed);
    
    // 4. Check if actually loaded via launchctl
    const isLoaded = await checkLaunchctlLoaded(label);
    
    jobs.push({
      id: `launchd-${label}`,
      name: friendlyName,         // e.g. "pew sync"
      description: command,        // e.g. "/opt/homebrew/bin/pew sync"
      agent: "system",
      schedule: schedule,          // e.g. "every 10 min" or cron expression
      status: isLoaded ? "active" : "stopped",
      source: "launchd",
      project: "",
      created_at: /* plist file mtime */,
      last_run: /* parse from log or launchctl */,
      next_run: /* calculate from schedule */,
      last_result: isLoaded ? "success" : "unknown",
      run_count: -1,
    });
  }
  return jobs;
}
```

**Key helper functions needed:**

```typescript
// Parse plist StartInterval / StartCalendarInterval → schedule string
function deriveSchedule(parsed: PlistData): string {
  if (parsed.StartInterval) {
    const seconds = parsed.StartInterval;
    if (seconds < 60) return `every ${seconds}s`;
    if (seconds < 3600) return `every ${Math.round(seconds / 60)} min`;
    if (seconds < 86400) return `every ${Math.round(seconds / 3600)}h`;
    return `every ${Math.round(seconds / 86400)}d`;
  }
  if (parsed.StartCalendarInterval) {
    // Convert to cron-like string for cronToHuman()
    return calendarIntervalToCron(parsed.StartCalendarInterval);
  }
  if (parsed.KeepAlive || parsed.RunAtLoad) {
    return "always-on";
  }
  return "on-demand";
}

// Derive human-friendly name from launchd label + args
// "com.pew.sync" + ["/opt/homebrew/bin/pew", "sync"] → "pew sync"
function deriveFriendlyName(label: string, args: string[]): string {
  // Use the actual command name, not the reverse-DNS label
  if (args.length >= 2) {
    const binary = args[0]!.split("/").pop()!;
    const subcommand = args.slice(1).filter(a => !a.startsWith("-")).join(" ");
    return subcommand ? `${binary} ${subcommand}` : binary;
  }
  if (args.length === 1) {
    return args[0]!.split("/").pop()!;
  }
  // Fallback: strip reverse-DNS prefix
  const parts = label.split(".");
  return parts.length > 2 ? parts.slice(2).join(" ") : label;
}
```

**Plist parsing approach:**
- macOS plists are XML — use `execFile("plutil", ["-convert", "json", "-o", "-", plistPath])` to convert to JSON natively
- This avoids adding a plist parsing dependency

**Update `loader.ts`:**
```typescript
export async function loadAllJobs(): Promise<Job[]> {
  const [registered, live, cron, launchd] = await Promise.all([
    loadRegisteredJobs(),
    scanLiveProcesses(),
    scanClaudeScheduledTasks(),
    scanLaunchdServices(),      // ← NEW
  ]);
  return [...registered, ...cron, ...launchd, ...live];
}
```

### Phase 2: Service Name Redesign (FB-2)

**Current problem:** Names like `docker:my-app`, `pm2 api.js`, corrupted JSON residue names.

**Design principle:** Name = what a human would call this service. It should answer "what is running?"

| Service | Current Name | Desired Name |
|---------|-------------|--------------|
| pew sync | _(not shown)_ | `pew sync` |
| Docker container | `docker:my-app` | `my-app` (from --name) |
| PM2 process | `pm2 api.js` | `api.js` (pm2 is the runtime, not the name) |
| Node server | `node server.js` | `server.js` |
| Flask app | `flask-server` | `flask` |
| launchd update | _(not shown)_ | `pew update` |

**Implementation changes in `detect.ts`:**

1. Strip runtime prefixes from registered names — `docker:`, `pm2 `, `node `, `python ` should not be part of the service name. These go in a new `runtime` or `via` metadata field.

2. Update `BASH_PATTERNS` label functions:

```typescript
// Before:
{ re: /pm2\s+start\s+(\S+)/i, label: (m) => `pm2 ${m[1]!.split("/").pop()!}` }
// After:
{ re: /pm2\s+start\s+(\S+)/i, label: (m) => m[1]!.split("/").pop()!.replace(/\.[jt]sx?$/, "") }

// Before:
{ re: /\bnode\s+(\S+\.(?:js|mjs|ts))\b/i, label: (m) => `node ${m[1]!.split("/").pop()!}` }
// After:
{ re: /\bnode\s+(\S+\.(?:js|mjs|ts))\b/i, label: (m) => m[1]!.split("/").pop()! }
```

3. Add a `runtime` field to the `Job` type (optional, display in detail panel):

```typescript
export interface Job {
  // ... existing fields
  runtime?: string;  // "docker", "pm2", "node", "python", "launchd", etc.
}
```

4. **Table display format:** `SERVICE` column shows the friendly name; `COMMAND` column shows the full command. Runtime info goes in the detail panel.

### Phase 3: Schedule Fix (FB-3)

Three sub-problems:

**3a. Registered jobs hardcode "always-on"**

In `detect.ts:240`, replace hardcoded `"always-on"` with actual schedule detection:

```typescript
function detectScheduleFromCommand(cmd: string): string {
  // Check if the command itself contains scheduling hints
  // e.g., cron expressions in the command, --interval flags, --cron flags
  const intervalFlag = cmd.match(/--interval\s+(\d+)/);
  if (intervalFlag) {
    const seconds = parseInt(intervalFlag[1]!, 10);
    return `every ${Math.round(seconds / 60)} min`;
  }
  
  // For background daemons (docker -d, pm2, nohup), "always-on" is correct
  return "always-on";
}
```

**3b. Claude scheduled tasks file missing**

`scanClaudeScheduledTasks()` reads `~/.claude/scheduled_tasks.json`. This file doesn't exist because:
- Claude Code's CronCreate tool only creates in-memory or session-scoped cron jobs by default
- Only `durable: true` cron jobs write to `.claude/scheduled_tasks.json`
- The user's cron jobs were session-only → no file on disk

**Fix:** Also scan the Claude Code projects directory for per-project scheduled tasks:
```typescript
// Additional paths to check:
// ~/.claude/projects/*/scheduled_tasks.json
// ~/.claude/scheduled_tasks.json  (global)
```

**3c. Launchd schedule extraction** — covered in Phase 1 `deriveSchedule()`.

### Phase 4: LAST RUN Date Format (FB-4)

**Current:** `job-table.tsx` line 63 uses `formatRelativeTime(job.last_run)` → shows "7h ago"

**User wants:** Absolute date+time format like `04-11 14:30`

**Change in `job-table.tsx`:**

```typescript
// Before (line 63):
<Text>{formatRelativeTime(job.last_run)}</Text>

// After:
<Text>{formatShortDateTime(job.last_run)}</Text>
```

**Add new helper in `utils.ts`:**

```typescript
/**
 * Short date+time for table columns: "04-11 14:30" or "-" for null.
 * Omits year when same year as now.
 */
export function formatShortDateTime(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  
  const now = new Date();
  const sameYear = d.getFullYear() === now.getFullYear();
  
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const hour = String(d.getHours()).padStart(2, "0");
  const minute = String(d.getMinutes()).padStart(2, "0");
  
  if (sameYear) {
    return `${month}-${day} ${hour}:${minute}`;
  }
  return `${d.getFullYear()}-${month}-${day} ${hour}:${minute}`;
}
```

**Column width adjustment:** `LAST RUN` column needs to be at least 12 chars for `"04-11 14:30"` format. Current `COL.lastRun = 10` → increase to 12.

**CREATED column:** Also change to `formatShortDateTime()` for consistency. Remove `dimColor` so both columns look the same.

---

## Category Scores

| Category | Score | v021 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 18 | 30 | **-12** | launchd services invisible, cron scanner broken (file missing), 2 corrupted entries in jobs.json |
| Architecture (20pts) | 14 | 20 | **-6** | Missing entire data source (launchd), hardcoded schedule, no service metadata model |
| Production-readiness (20pts) | 16 | 19 | **-3** | Real user service not visible, relative timestamps not useful for monitoring |
| Open-source quality (15pts) | 12 | 14 | **-2** | README doesn't mention launchd limitation, no docs on supported service types |
| Security (15pts) | 12 | 14 | **-2** | Corrupted jobs.json entries, no data validation on load |
| **TOTAL** | **72** | **97** | **-25** | |

---

## Test Plan

### Phase 1 Tests (Launchd Scanner)

```
scanner.test.ts — new describe("scanLaunchdServices")

1. "returns empty array when ~/Library/LaunchAgents is empty"
2. "parses com.pew.sync.plist correctly"
   - name = "pew sync"
   - schedule = "every 10 min" (from StartInterval: 600)
   - source = "launchd"
   - description = "/opt/homebrew/bin/pew sync"
3. "skips com.apple.* plists"
4. "handles StartCalendarInterval (cron-like schedule)"
5. "handles KeepAlive services as always-on"
6. "sets status=stopped for unloaded services"
7. "parses ProgramArguments into full command description"
8. "derives friendly name from reverse-DNS label as fallback"

utils.test.ts — new describe("deriveSchedule")

1. "converts StartInterval 600 → 'every 10 min'"
2. "converts StartInterval 3600 → 'every 1h'"
3. "converts StartInterval 30 → 'every 30s'"
4. "returns 'always-on' for KeepAlive services"
5. "converts StartCalendarInterval to cron expression"

fixtures.ts — add launchd fixtures

1. pewSyncPlist — parsed plist data for com.pew.sync
2. keepAlivePlist — always-on service
3. calendarIntervalPlist — cron-like schedule
```

### Phase 2 Tests (Name Redesign)

```
detect.test.ts — update existing tests

1. "pm2 start api.js → name is 'api' not 'pm2 api.js'"
2. "node server.js → name is 'server.js' not 'node server.js'"
3. "docker run --name my-app → name is 'my-app' not 'docker:my-app'"

scanner.test.ts — update friendlyLiveName tests

1. "friendlyLiveName drops runtime prefix"

utils.test.ts — new describe("deriveFriendlyName")

1. "'com.pew.sync' + ['/opt/homebrew/bin/pew', 'sync'] → 'pew sync'"
2. "'com.pew.update' + ['/opt/homebrew/bin/pew', 'update'] → 'pew update'"
3. "single arg: ['/usr/local/bin/myservice'] → 'myservice'"
4. "label-only fallback: 'com.example.thing' → 'thing'"
```

### Phase 3 Tests (Schedule)

```
detect.test.ts — update registerJob tests

1. "registered job with --interval 60 gets 'every 1 min' not 'always-on'"
2. "docker run -d still gets 'always-on' (correct)"
3. "nohup ... & still gets 'always-on' (correct)"

loader.test.ts — integration

1. "loadAllJobs merges registered + live + cron + launchd (4 sources)"
2. "launchd jobs appear in merged results"
```

### Phase 4 Tests (Date Format)

```
utils.test.ts — new describe("formatShortDateTime")

1. "formats same-year date as 'MM-DD HH:mm'"
2. "formats different-year date as 'YYYY-MM-DD HH:mm'"
3. "returns '-' for null"
4. "returns original string for invalid date"

job-table.test.tsx — update column assertions

1. "LAST RUN shows date format not relative time"
2. "CREATED shows date format not relative time"

Snapshot regeneration required after column changes.
```

### Data Cleanup Tests

```
loader.test.ts — validation

1. "strips corrupted entries from loaded jobs"
2. "validates job name is non-empty string"
3. "validates schedule is non-empty string"
```

---

## Implementation Priority

```
P0 — Phase 1: Launchd scanner     (FB-1, FB-3) — BLOCKING
     Without this, real services like pew sync are invisible.
     
P0 — Phase 4: Date format fix     (FB-4) — QUICK WIN
     Simple change: formatRelativeTime → formatShortDateTime in 2 columns.
     Can be done in parallel with Phase 1.

P1 — Phase 3: Schedule fix        (FB-3) — depends on Phase 1
     Launchd schedule extraction is part of Phase 1.
     Registered jobs schedule detection is a separate change.

P1 — Phase 2: Name redesign       (FB-2) — can be done independently
     Update BASH_PATTERNS labels, add runtime field.

P2 — Data cleanup
     Clean corrupted entries from jobs.json.
     Add validation in loader.ts.
```

**Estimated effort:** ~2-3 hours total. Phase 1 is the largest (~1h). Phase 4 is the smallest (~10min).

---

## Communication

### To the implementation agent

#### We have 4 critical issues from the user — please prioritize

The UI layer (v021) is solid, but the **data pipeline has fundamental gaps**. The user has a real `pew sync` service running via macOS launchd every 10 minutes, and it's completely invisible to the dashboard. Here's why:

**1. CRITICAL — No launchd scanner (`scanner.ts`)**

The dashboard only scans 3 sources: registered hooks, TCP-listening processes (lsof), and Claude scheduled tasks. It **has no launchd scanner**. The pew sync service runs via `~/Library/LaunchAgents/com.pew.sync.plist` with `StartInterval: 600` — it runs, exits, and never listens on a port. You need to add `scanLaunchdServices()` that:
- Reads `~/Library/LaunchAgents/*.plist` (skip `com.apple.*`)
- Uses `plutil -convert json -o - <file>` to parse each plist natively
- Extracts: ProgramArguments → command, StartInterval/StartCalendarInterval → schedule, Label → id
- Checks `launchctl list` for loaded status

**2. HIGH — Service names still opaque**

Current names like `pm2 api.js`, `docker:my-app`, `node server.js` prefix the runtime. The user wants just the service name: `api.js`, `my-app`, `server.js`. The runtime (`pm2`, `docker`, `node`) is metadata for the detail panel, not the name. For launchd: `com.pew.sync` should become `pew sync` by joining the actual ProgramArguments.

**3. CRITICAL — Schedule always "always-on"**

`detect.ts:240` hardcodes `schedule: "always-on"` for every registered job. For launchd services, extract the schedule from the plist. For registered jobs, try to detect `--interval` flags in the command.

**4. MEDIUM — LAST RUN needs absolute date**

Change `job-table.tsx` line 63 from `formatRelativeTime(job.last_run)` to a new `formatShortDateTime()` helper that shows `"04-11 14:30"` format. Same for the CREATED column. Column width needs to increase from 10 to 12.

#### Execution order

1. **Start with Phase 4** (date format) — it's a 10-minute quick win that immediately improves UX
2. **Then Phase 1** (launchd scanner) — this is the core fix that makes pew sync visible
3. **Then Phase 2** (names) — clean up the naming convention
4. **Then Phase 3** (schedule) — improve registered job schedule detection

#### Watch out for

- Use `plutil -convert json -o -` for plist parsing — no external dependency needed
- Filter out `com.apple.*` plists (there are hundreds)
- The `launchctl list` output format is `PID\tStatus\tLabel` — PID is `-` when not running
- Don't break existing tests — 174 currently pass
- Update snapshots after column width changes

---

## Score Trajectory

```
v001: 28  ████
v002: 30  █████
v003: 48  ████████
v004: 62  ██████████
v005: 76  ████████████
v006: 82  █████████████
v007: 83  █████████████
v008: 85  ██████████████
v009: 88  ██████████████
v010: 91  ███████████████
v011: 93  ███████████████
v012: 94  ███████████████
v013: 94  ███████████████
v014: 95  ████████████████
v015: 95  ████████████████
v016: 96  ████████████████
v017: 98  ████████████████
v018: 99  ████████████████
v019: 92  ███████████████   ← user UX feedback
v020: 88  ██████████████    ← test regression
v021: 97  ████████████████  ← recovery
v022: 72  ████████████      ← architecture gaps exposed
```

---

## Summary

v022 scores **72/100** (-25). User feedback reveals 4 issues that expose **fundamental data pipeline gaps**: (1) no launchd scanner — pew sync service is invisible, (2) service names still prefixed with runtime, (3) schedule hardcoded to "always-on" for all registered jobs, (4) LAST RUN column uses relative time instead of absolute date. The UI code is clean but the data sources feeding it are incomplete. Requires adding `scanLaunchdServices()`, redesigning service name extraction, fixing schedule detection, and switching to `formatShortDateTime()`. Test plan provided for all 4 phases. Estimated effort: 2-3 hours.
