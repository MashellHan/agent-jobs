# Agent Jobs Review -- v024
**Date:** 2026-04-11T14:52:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 6879a23 + unstaged changes (main)
**Files scanned:** scanner.ts, loader.ts, loader.test.ts, scanner.test.ts, utils.ts, utils.test.ts, job-table.tsx, job-detail.tsx, snapshots
**Previous review:** v023 (score 80/100, launchd scanner missing)

## Overall Score: 85/100 (+5)

**Major milestone: The launchd scanner is implemented.** `scanLaunchdServices()` is now in `scanner.ts` with `deriveSchedule()`, `deriveFriendlyName()`, `parsePlist()`, and `checkLaunchctlLoaded()` helpers. `loader.ts` integrates all 4 data sources. The pew sync service will now appear in the dashboard. However, **8 tests are failing** because `loader.test.ts` was not updated to mock the new `scanLaunchdServices` export, and a snapshot needs regeneration. Additionally, the launchd scanner has **zero test coverage** — no unit tests for any of the 5 new exported functions.

---

## What Was Done

### 1. `scanLaunchdServices()` implemented (`scanner.ts:331-384`) — FB-1 ✅

The core function that resolves the user's #1 complaint (pew sync invisible):

- Reads `~/Library/LaunchAgents/*.plist`
- Filters out `com.apple.*` plists
- Parses each plist via `plutil -convert json -o -` (native macOS, zero dependencies)
- Returns `Job[]` with source `"launchd"`

**Architecture is sound:** async iterator with `Promise.all()`, null filtering for failed parses, error-resilient (catches readdir/plutil failures).

### 2. `deriveSchedule()` (`scanner.ts:199-248`) — FB-3 ✅

Converts plist schedule data to human-readable strings:

| Plist Key | Example | Output |
|-----------|---------|--------|
| `StartInterval: 600` | pew sync | `"every 10 min"` |
| `StartInterval: 3600` | hourly task | `"hourly"` |
| `StartCalendarInterval: {Hour: 2}` | daily 2am | `"daily 2am"` |
| `StartCalendarInterval: {Hour: 9, Weekday: 1}` | Monday 9am | `"Mon 9am"` |
| `KeepAlive: true` | daemon | `"always-on"` |
| none | on-demand | `"on-demand"` |

**Well-designed:** Covers the three main launchd scheduling mechanisms (interval, calendar, keep-alive), with graceful fallback.

### 3. `deriveFriendlyName()` (`scanner.ts:254-270`) — FB-2 ✅

Converts launchd labels + ProgramArguments to human names:
- `["pew", "sync"]` → `"pew sync"` ✅
- `["/opt/homebrew/bin/pew", "sync"]` → `"pew sync"` (strips path) ✅
- `["/usr/local/bin/myservice"]` → `"myservice"` ✅
- label `"com.pew.sync"` fallback → `"sync"` ✅
- 20-char truncation with `"…"` ✅

### 4. Helper functions

- `parsePlist()` (`scanner.ts:276-290`) — Calls `plutil -convert json -o -` with 3s timeout, returns `PlistData | null`
- `checkLaunchctlLoaded()` (`scanner.ts:296-316`) — Parses `launchctl list` output for PID and loaded status
- `getFileMtime()` (`scanner.ts:321-325`) — Gets plist file mtime for `created_at` field
- `PlistData` interface (`scanner.ts:11-22`) — Well-typed with relevant fields

### 5. `loader.ts` updated — 4 data sources merged ✅

```typescript
const [registered, live, cron, launchd] = await Promise.all([
  loadRegisteredJobs(),
  scanLiveProcesses(),
  scanClaudeScheduledTasks(),
  scanLaunchdServices(),  // ← NEW
]);
return [...registered, ...cron, ...launchd, ...live];
```

---

## What Is BROKEN — 8 Failing Tests

### 7 failures in `loader.test.ts`

**Root cause:** The scanner mock at line 10-13 does not include `scanLaunchdServices`:

```typescript
// Current mock (BROKEN):
vi.mock("./scanner.js", () => ({
  scanLiveProcesses: vi.fn(),
  scanClaudeScheduledTasks: vi.fn(),
  // ← scanLaunchdServices MISSING
}));
```

`loadAllJobs()` now calls `scanLaunchdServices()` from the mock, which doesn't exist, causing:
```
Error: [vitest] No "scanLaunchdServices" export is defined on the "./scanner.js" mock.
```

**Fix:** Add `scanLaunchdServices` to the mock:

```typescript
vi.mock("./scanner.js", () => ({
  scanLiveProcesses: vi.fn(),
  scanClaudeScheduledTasks: vi.fn(),
  scanLaunchdServices: vi.fn(),  // ← ADD THIS
}));
```

And add to imports + mock setup:

```typescript
import { scanLiveProcesses, scanClaudeScheduledTasks, scanLaunchdServices } from "./scanner.js";
const mockScanLaunchd = vi.mocked(scanLaunchdServices);

beforeEach(() => {
  vi.resetAllMocks();
  mockScanLaunchd.mockResolvedValue([]); // default: no launchd services
});
```

Then update the merge test to verify 4 sources:

```typescript
it("merges registered, cron, launchd, and live jobs", async () => {
  // ... existing setup ...
  const launchdJob = { id: "launchd-com.pew.sync", source: "launchd", ... };
  mockScanLaunchd.mockResolvedValue([launchdJob]);
  
  const jobs = await loadAllJobs();
  expect(jobs).toHaveLength(4);
  expect(jobs.map(j => j.source)).toEqual(["registered", "cron", "launchd", "live"]);
});
```

### 1 snapshot failure

The snapshot needs regeneration after column width changes (LAST RUN 10→12). Run `npx vitest run -u` after fixing the loader tests.

---

## Missing Tests — Launchd Scanner (0% coverage)

The launchd scanner has **5 exported functions** and **zero tests**. This is the biggest gap:

### Required tests for `deriveSchedule()`:

```
1. "StartInterval 600 → 'every 10 min'"
2. "StartInterval 30 → 'every 30s'"
3. "StartInterval 3600 → 'hourly'"
4. "StartInterval 7200 → 'every 2h'"
5. "StartInterval 86400 → 'daily'"
6. "StartCalendarInterval {Hour:2} → 'daily 2am'"
7. "StartCalendarInterval {Hour:14, Minute:30} → 'daily 2:30pm'"
8. "StartCalendarInterval {Hour:9, Weekday:1} → 'Mon 9am'"
9. "StartCalendarInterval array picks first entry"
10. "KeepAlive → 'always-on'"
11. "RunAtLoad without interval → 'always-on'"
12. "empty plist → 'on-demand'"
```

### Required tests for `deriveFriendlyName()`:

```
1. "'com.pew.sync' + ['/opt/homebrew/bin/pew', 'sync'] → 'pew sync'"
2. "single arg ['/usr/local/bin/myservice'] → 'myservice'"
3. "no args → fallback from label"
4. "strips -flag arguments"
5. "truncates to 20 chars"
6. "label 'com.example.thing' → 'thing'"
```

### Required tests for `scanLaunchdServices()`:

```
1. "returns empty when LaunchAgents dir doesn't exist"
2. "skips com.apple.* plists"
3. "parses valid plist and returns Job with correct fields"
4. "sets status=active for loaded services"
5. "sets status=stopped for unloaded services"
6. "handles plutil parse failure (returns null)"
7. "uses plist file mtime for created_at"
```

---

## Code Review Notes

### Positive

1. **PlistData interface** (lines 11-22) — Well-typed with index signature for extensibility. Handles both single and array `StartCalendarInterval`.

2. **Error resilience** — `parsePlist` returns null on failure; `scanLaunchdServices` filters nulls. `readdir` error resolves to `[]`. No unhandled promise rejections.

3. **`plutil` approach** — Using macOS native `plutil` instead of an npm plist parser is the right call for a macOS-specific feature. Zero new dependencies.

4. **`getFileMtime`** — Using plist file mtime for `created_at` is a smart heuristic for "when was this service installed."

### Issues

1. **`checkLaunchctlLoaded` uses `launchctl list` (all services)** — This runs `launchctl list` once per plist, parsing the entire list each time. For N plists, that's N subprocess spawns of the same command. Better approach: run `launchctl list` once, parse all labels, then look up each. Or use `launchctl list <label>` which returns immediately with exit code 0/1.

   **Suggested fix:**
   ```typescript
   // Run once, cache result
   async function loadLaunchctlList(): Promise<Map<string, number | null>> {
     return new Promise((resolve) => {
       execFile("launchctl", ["list"], { encoding: "utf-8", timeout: 3000 }, (err, stdout) => {
         const map = new Map<string, number | null>();
         if (err || !stdout) { resolve(map); return; }
         for (const line of stdout.split("\n").slice(1)) {
           const parts = line.trim().split(/\t/);
           if (parts.length >= 3) {
             const pid = parts[0] !== "-" ? parseInt(parts[0]!, 10) : null;
             map.set(parts[2]!, isNaN(pid as number) ? null : pid);
           }
         }
         resolve(map);
       });
     });
   }
   ```

2. **`checkLaunchctlLoaded` line matching is loose** — `line.includes(label)` could match substrings (e.g., `com.pew` matches `com.pew.sync` AND `com.pew.update`). Should use exact label match:
   ```typescript
   const parts = line.trim().split(/\t/);
   if (parts.length >= 3 && parts[2] === label) { ... }
   ```

3. **`last_run` for launchd** (`scanner.ts:373`) — Sets `last_run: loaded ? new Date().toISOString() : null`. This is a rough approximation — it means "loaded now" not "last actual run." Acceptable as a v1 heuristic, but should be documented.

4. **`inferAgent` on launchd command** (`scanner.ts:366`) — Runs `inferAgent(command)` on launchd commands. For `"/opt/homebrew/bin/pew sync"`, this returns `"manual"`. The review-022 design suggested `"system"` as the agent for launchd services. Consider adding a launchd-specific agent or defaulting to `"system"`.

---

## Category Scores

| Category | Score | v023 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 22 | 25 | **-3** | 8/184 tests failing (loader mock + snapshot). Scanner logic correct but untested. |
| Architecture (20pts) | 19 | 15 | **+4** | Launchd scanner architecture is sound. 4-source merger in loader.ts. PlistData type. |
| Production-readiness (20pts) | 18 | 16 | **+2** | Pew sync will be visible. `deriveSchedule` handles real-world plist patterns. |
| Open-source quality (15pts) | 13 | 12 | **+1** | Good JSDoc on new functions. PlistData interface well-documented. |
| Security (15pts) | 13 | 12 | **+1** | plutil is trusted system binary. execFile with timeout prevents hangs. |
| **TOTAL** | **85** | **80** | **+5** | |

---

## Action Items for Implementation Agent

### P0: Fix 8 failing tests (BLOCKING)

**`loader.test.ts`** — add `scanLaunchdServices` to the scanner mock:

```typescript
// Line 10-13: Add scanLaunchdServices to mock
vi.mock("./scanner.js", () => ({
  scanLiveProcesses: vi.fn(),
  scanClaudeScheduledTasks: vi.fn(),
  scanLaunchdServices: vi.fn(),
}));

// Line 22-23: Import and mock
import { scanLiveProcesses, scanClaudeScheduledTasks, scanLaunchdServices } from "./scanner.js";
const mockScanLaunchd = vi.mocked(scanLaunchdServices);

// Line 29-31: Default mock in beforeEach
beforeEach(() => {
  vi.resetAllMocks();
  mockScanLaunchd.mockResolvedValue([]);
});

// Also: all test beforeEach blocks that set up mockScanLive/mockScanCron
// need to also set mockScanLaunchd.mockResolvedValue([])
```

**Snapshot** — run `npx vitest run -u` after fixing loader tests.

### P0: Add launchd scanner tests

Add tests for `deriveSchedule`, `deriveFriendlyName`, and `scanLaunchdServices` to `scanner.test.ts`. See the "Missing Tests" section above for the full list. These are pure functions — easy to test without mocks.

### P1: Fix `checkLaunchctlLoaded` substring matching

`line.includes(label)` on line 305 can match partial labels. Use tab-split + exact match:

```typescript
const parts = line.trim().split(/\t/);
if (parts.length >= 3 && parts[2] === label) {
```

### P2: Optimize `checkLaunchctlLoaded` — run `launchctl list` once

Currently runs `launchctl list` N times (once per plist). Cache the result:

```typescript
// In scanLaunchdServices(), before the Promise.all:
const launchctlMap = await loadLaunchctlList(); // run once

// Then in each plist map:
const loaded = launchctlMap.has(label);
const pid = launchctlMap.get(label) ?? null;
```

---

## Communication

### To the implementation agent

#### Great work implementing the launchd scanner — now fix the tests

The launchd scanner is **architecturally solid**. `deriveSchedule`, `deriveFriendlyName`, and `parsePlist` are all well-designed. The user's pew sync service (`com.pew.sync.plist`, `StartInterval: 600`) will now appear as:
- Name: `pew sync` ✅
- Schedule: `every 10 min` ✅
- Source: `launchd` ✅

**But you shipped with 8 broken tests.** Same pattern as v020 — source code changed but tests not updated. The fix is straightforward:

1. Add `scanLaunchdServices: vi.fn()` to the scanner mock in `loader.test.ts`
2. Add `mockScanLaunchd.mockResolvedValue([])` to all `beforeEach` blocks
3. Run `npx vitest run -u` for snapshot update
4. **Add unit tests for the 5 new exported functions** — `deriveSchedule`, `deriveFriendlyName`, `scanLaunchdServices`, `parsePlist` (via scanLaunchdServices), `checkLaunchctlLoaded` (via scanLaunchdServices)

Also fix the `checkLaunchctlLoaded` substring matching bug — `line.includes(label)` matches partial labels. Use `parts[2] === label` with tab-split.

#### Expected score after fixes: 95+/100

---

## Score Trajectory

```
v017: 98  ████████████████
v018: 99  ████████████████
v019: 92  ███████████████   ← user UX feedback
v020: 88  ██████████████    ← test regression
v021: 97  ████████████████  ← recovery
v022: 72  ████████████      ← architecture gaps exposed
v023: 80  █████████████     ← partial fixes
v024: 85  ██████████████    ← launchd scanner added, tests broken
```

---

## Summary

v024 scores **85/100** (+5). The critical launchd scanner is implemented — `scanLaunchdServices()`, `deriveSchedule()`, `deriveFriendlyName()`, `parsePlist()`, `checkLaunchctlLoaded()` — and `loader.ts` now merges all 4 data sources. Pew sync will appear as `"pew sync"` with `"every 10 min"` schedule. However, 8 tests fail because `loader.test.ts` mock doesn't include `scanLaunchdServices`, and the scanner has zero test coverage. Also: `checkLaunchctlLoaded` has a substring matching bug. Expected score 95+ once tests are fixed and scanner tests added.
