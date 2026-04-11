# Agent Jobs Review -- v025
**Date:** 2026-04-11T14:55:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** eedeca7 + unstaged changes (main)
**Files scanned:** scanner.ts, scanner.test.ts, job-table.test.tsx, loader.test.ts, loader.ts, utils.ts, utils.test.ts, fixtures.ts, job-table.tsx, job-detail.tsx, detect.ts
**Previous review:** v024 (score 85/100, 8 tests failing)

## Overall Score: 90/100 (+5)

**Significant progress: 37 new launchd scanner tests added, loader mock fixed, 3 launchd fixtures created.** The implementation agent addressed most v024 action items — `scanLaunchdServices` mock added to `loader.test.ts`, launchd scanner tests written for `deriveSchedule`, `deriveFriendlyName`, and `scanLaunchdServices`. However, **2 tests still fail** due to a mock format mismatch in `scanner.test.ts`, and `loadLaunchctlList()` is dead code. The `detect.ts` improvement (`detectScheduleFromCommand`) was added but not covered by the v024 review — nice initiative.

---

## What Was Done (since v024)

### 1. Loader test mock fixed — 7/7 previously failing tests now pass ✅

`loader.test.ts` line 13: `scanLaunchdServices: vi.fn()` added to scanner mock.
Line 29: `mockScanLaunchd` imported and `mockResolvedValue([])` set in beforeEach.
Line 110-139: New test `"merges launchd jobs into the result (4 sources)"` verifying pew sync appears with correct source, name, and schedule.

### 2. Launchd scanner tests added — 30 new tests ✅

| Function | Tests | Coverage |
|----------|-------|----------|
| `deriveSchedule` | 15 tests | All branches: StartInterval (30s, 60s, 600s, 3600s, 7200s, 86400s, 172800s), StartCalendarInterval (daily, pm, midnight, array, weekday), KeepAlive, RunAtLoad, priority, empty |
| `deriveFriendlyName` | 8 tests | binary+subcommand, pew update, flags stripping, single arg, node gateway, label fallback, short labels, truncation |
| `scanLaunchdServices` | 7 tests | ENOENT, no plists, skip com.apple.*, valid plist parse, stopped services, KeepAlive+PID, plutil failure, multiple plists |

### 3. New launchd fixtures added (`fixtures.ts:183-250`) ✅

- `launchdPewSyncJob`: source "launchd", schedule "every 10 min" — the critical pew sync fixture
- `launchdPewUpdateJob`: schedule "daily 9am" — tests StartCalendarInterval display
- `launchdKeepAliveJob`: schedule "always-on", pid 1786, agent "openclaw" — tests KeepAlive

All 3 added to `allFixtureJobs` array (now 13 total).

### 4. Job table tests for launchd services (`job-table.test.tsx:277-325`) ✅

4 new tests in `"launchd services"` describe block:
- Verifies `"every 10 min"`, `"daily 9am"`, `"always-on"` schedule display
- Verifies launchd services appear in full table render
- Verifies schedule diversity (6 different schedule types visible)

### 5. `detectScheduleFromCommand()` added (`detect.ts:220-242`) ✅

**Not in v024 action items — implementation agent's initiative.** Detects `--interval` and `--cron` flags from hook-registered commands instead of hardcoding `"always-on"`. Good improvement, partially addresses the "all schedules show always-on" issue for registered jobs.

### 6. Snapshot regenerated ✅

The job-table snapshot was updated to reflect the new column widths and launchd fixture additions.

---

## What Is BROKEN — 2 Failing Tests

### Root cause: `checkLaunchctlLoaded` mock format mismatch

The implementation uses `checkLaunchctlLoaded(label)` which calls `launchctl list <label>` (per-label query). This returns key-value format:

```
"PID" = 1786;
"Status" = 0;
```

But the test mocks return tab-separated format (`PID\tStatus\tLabel`), which is the output of `launchctl list` (all-services query). The parser in `checkLaunchctlLoaded()` uses `stdout.match(/"PID"\s*=\s*(\d+)/)` which doesn't match the tab format.

#### Test 1: `"marks unloaded services as stopped"` (line 517-542)

The mock returns `"PID\tStatus\tLabel\n"` (header only, no matching line). But `checkLaunchctlLoaded` receives no error from `execFile`, so it returns `{ loaded: true, pid: null }` — making status `"active"` instead of `"stopped"`.

**Fix:** Mock should return an error for unloaded services:
```typescript
mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
  if (cmd === "launchctl") {
    // launchctl list <label> returns error for unloaded services
    (cb as (err: Error) => void)(new Error("Could not find service"));
  }
  // ...
});
```

#### Test 2: `"handles KeepAlive service with PID"` (line 544-571)

The mock returns `"1786\t0\tai.openclaw.gateway\n"` (tab format). But `checkLaunchctlLoaded` parses `"PID" = 1786` format, so PID is null.

**Fix:** Mock should return per-label format:
```typescript
mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
  if (cmd === "launchctl") {
    (cb as (err: null, stdout: string) => void)(null,
      '{\n\t"PID" = 1786;\n\t"Status" = 0;\n\t"Label" = "ai.openclaw.gateway";\n}\n');
  }
  // ...
});
```

### `loadLaunchctlList()` is dead code (line 321-341)

The function was implemented (likely following v024's P2 optimization suggestion) but never integrated. `scanLaunchdServices()` still calls `checkLaunchctlLoaded(label)` per-plist (line 384). Either:
- **Option A:** Remove `loadLaunchctlList()` (dead code cleanup)
- **Option B:** Integrate it into `scanLaunchdServices()` and remove `checkLaunchctlLoaded()`

**Recommended: Option B** — it's the right optimization (run `launchctl list` once instead of N times).

---

## Code Quality Analysis

### Positive

1. **Comprehensive test coverage for pure functions** — 15 `deriveSchedule` tests and 8 `deriveFriendlyName` tests cover every branch. These are textbook unit tests: pure input/output, no mocking needed.

2. **Scanner integration tests are thorough** — 7 `scanLaunchdServices` tests cover ENOENT, empty dir, apple filter, valid parse, stopped status, KeepAlive, and plutil failure. The multi-plist test (line 589-625) is especially good — verifies 2 plists with different schedule types in one scan.

3. **`detectScheduleFromCommand()` is well-designed** — Extracts `--interval` and `--cron` flags from commands. Uses the same second→human conversion pattern as `deriveSchedule()`. Consistent API.

4. **Loader test structure is clean** — `mockScanLaunchd` properly integrated into beforeEach blocks. The 4-source merge test (line 110-139) explicitly verifies pew sync data flows through.

5. **`sourceToHuman()` tests added** — 5 tests covering all 4 sources + unknown fallback. Clean and complete.

### Issues

1. **Mock format mismatch causes 2 failures** (P0) — See "What Is BROKEN" above. Tests assume `launchctl list` all-services format, but implementation uses `launchctl list <label>` per-label format.

2. **Dead code: `loadLaunchctlList()`** (P1) — Function exists at line 321-341 but is never called. Either integrate it or remove it.

3. **`detectScheduleFromCommand()` has no tests** (P1) — The function in `detect.ts:220-242` is exported but has no unit tests. Add tests for:
   - `--interval 60` → `"every min"`
   - `--interval 300` → `"every 5 min"`
   - `--cron "0 2 * * *"` → `"0 2 * * *"` (passes through raw cron)
   - No flags → `"always-on"`

4. **`checkLaunchctlLoaded` still called N times** (P2) — Same issue from v024. Not blocking, but unnecessary subprocess spawns.

5. **Scanner test line 533:** Stopped service mock returns `"PID\tStatus\tLabel\n"` — this is header-only, but `checkLaunchctlLoaded` doesn't parse headers. The mock needs to either return an error (for unloaded) or return the per-label format.

---

## Test Statistics

| Metric | v024 | v025 | Delta |
|--------|------|------|-------|
| Total tests | 184 | 221 | **+37** |
| Passing | 176 | 219 | **+43** |
| Failing | 8 | 2 | **-6** |
| Test files | 7 | 7 | 0 |
| Scanner test count | ~60 | ~97 | **+37** |

### Test breakdown by file:

| File | Tests | Status |
|------|-------|--------|
| scanner.test.ts | ~97 | **1 file, 2 failures** |
| utils.test.ts | ~55 | ✅ all pass |
| loader.test.ts | ~15 | ✅ all pass |
| job-table.test.tsx | ~33 | ✅ all pass |
| app.test.tsx | ~12 | ✅ all pass |
| detect.test.ts | ~7 | ✅ all pass |
| cli.test.ts | ~2 | ✅ all pass |

---

## Category Scores

| Category | Score | v024 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 26 | 22 | **+4** | 219/221 tests pass (up from 176/184). 2 failures are mock issues, not logic bugs. |
| Architecture (20pts) | 19 | 19 | **0** | Sound architecture. Dead code (`loadLaunchctlList`) is minor. |
| Production-readiness (20pts) | 19 | 18 | **+1** | `detectScheduleFromCommand` improves hook detection. 2 mock failures don't affect production. |
| Open-source quality (15pts) | 13 | 13 | **0** | Good test structure. JSDoc maintained. |
| Security (15pts) | 13 | 13 | **0** | No new security concerns. |
| **TOTAL** | **90** | **85** | **+5** | |

---

## Action Items for Implementation Agent

### P0: Fix 2 failing scanner tests (mock format)

The test mocks for `scanLaunchdServices` return tab-separated `launchctl list` (all-services) format, but `checkLaunchctlLoaded()` calls `launchctl list <label>` (per-label) which returns a different format.

**Fix option 1 (recommended):** Update mocks to match the per-label format:

```typescript
// Test: "marks unloaded services as stopped" (line 528)
mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
  if (cmd === "plutil") {
    (cb as (err: null, stdout: string) => void)(null, JSON.stringify(plist));
  } else if (cmd === "launchctl") {
    // Per-label query returns error for unloaded services
    (cb as (err: Error, stdout: string) => void)(new Error("Could not find service"), "");
  }
  return {} as ReturnType<typeof execFile>;
});

// Test: "handles KeepAlive service with PID" (line 556)
mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
  if (cmd === "plutil") {
    (cb as (err: null, stdout: string) => void)(null, JSON.stringify(plist));
  } else if (cmd === "launchctl") {
    // Per-label query returns key-value pairs
    (cb as (err: null, stdout: string) => void)(null,
      '{\n\t"LimitLoadToSessionType" = "Aqua";\n\t"Label" = "ai.openclaw.gateway";\n\t"TimeOut" = 30;\n\t"OnDemand" = false;\n\t"LastExitStatus" = 0;\n\t"PID" = 1786;\n\t"Program" = "/opt/homebrew/opt/node/bin/node";\n}\n');
  }
  return {} as ReturnType<typeof execFile>;
});
```

**Fix option 2 (better architecture):** Switch to the batch approach — replace `checkLaunchctlLoaded(label)` call on line 384 with `loadLaunchctlList()` called once before the `Promise.all`. Then update mocks to return tab format (which they already do). This also fixes the P2 performance issue.

```typescript
// In scanLaunchdServices(), before Promise.all:
const launchctlMap = await loadLaunchctlList();

// In each plist map (replace line 384):
const loaded = launchctlMap.has(label);
const pid = launchctlMap.get(label) ?? null;
```

Then remove `checkLaunchctlLoaded()` entirely (dead code). The existing test mocks would work as-is since they already return tab format.

### P0: Remove dead code — `loadLaunchctlList()` or `checkLaunchctlLoaded()`

One of these functions is dead code. If you chose Fix option 2 above, remove `checkLaunchctlLoaded()`. If you chose Fix option 1, remove `loadLaunchctlList()`.

### P1: Add tests for `detectScheduleFromCommand()`

The function at `detect.ts:220-242` is exported but untested. Add to `detect.test.ts`:

```typescript
describe("detectScheduleFromCommand", () => {
  it("detects --interval 60 as 'every min'", () => {
    expect(detectScheduleFromCommand("node task.js --interval 60")).toBe("every min");
  });

  it("detects --interval 300 as 'every 5 min'", () => {
    expect(detectScheduleFromCommand("node sync.js --interval 300")).toBe("every 5 min");
  });

  it("detects --interval 3600 as 'hourly'", () => {
    expect(detectScheduleFromCommand("pew sync --interval 3600")).toBe("hourly");
  });

  it("detects --cron flag", () => {
    expect(detectScheduleFromCommand('node backup.js --cron "0 2 * * *"')).toBe("0 2 * * *");
  });

  it("defaults to 'always-on' when no schedule flags", () => {
    expect(detectScheduleFromCommand("node server.js --port 3000")).toBe("always-on");
  });
});
```

### P2: Fix the pew sync multi-plist test mock (line 589-625)

This test currently passes but only because all `launchctl list <label>` calls succeed (returning loaded=true with no PID) due to the mock not matching the per-label format. The test accidentally passes because `loaded: true` is the right state for both plists. If you switch to the batch approach (Fix option 2), the existing mock already works correctly.

---

## Communication

### To the implementation agent

#### Strong recovery — 37 new tests, loader fixed, 2 failures remaining

You addressed the core v024 issues:
- ✅ Loader mock fixed (7 tests recovered)
- ✅ 37 new launchd scanner tests (15 deriveSchedule + 8 deriveFriendlyName + 7 scanLaunchdServices + 4 table display + 3 fixtures)
- ✅ `detectScheduleFromCommand()` added — nice initiative
- ✅ `sourceToHuman` tests added
- ✅ Snapshot regenerated

**But 2 tests fail because the mocks don't match the implementation's API.**

`checkLaunchctlLoaded(label)` calls `launchctl list <label>` which returns `"PID" = 1786` format, but your mocks return `1786\t0\tlabel` tab format (which is the all-services `launchctl list` output).

**Best fix: Switch to the batch approach.** You already have `loadLaunchctlList()` written at line 321-341 — it's dead code. Integrate it:

1. In `scanLaunchdServices()`, call `const launchctlMap = await loadLaunchctlList()` once before `Promise.all`
2. Replace `checkLaunchctlLoaded(label)` call (line 384) with `launchctlMap.has(label)` and `launchctlMap.get(label)`
3. Delete `checkLaunchctlLoaded()` function
4. Your existing test mocks already return the right format — tests will pass

This fixes both the 2 failing tests AND the P2 performance issue in one change.

Also add tests for `detectScheduleFromCommand()` — it's an exported function with 0 test coverage.

#### Expected score after fixes: 96+/100

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
v024: 85  ██████████████    ← launchd scanner added, 8 tests failing
v025: 90  ███████████████   ← 37 new tests, 2 mock failures remaining
```

---

## Summary

v025 scores **90/100** (+5). Massive test recovery: 37 new tests added (221 total, 219 passing — up from 184 total, 176 passing). Loader mock fixed, comprehensive launchd scanner tests written, 3 launchd fixtures added, `detectScheduleFromCommand()` implemented. Two tests still fail due to mock format mismatch — `checkLaunchctlLoaded` uses per-label query format but mocks return all-services tab format. Dead code `loadLaunchctlList()` exists but is not integrated. Recommended fix: integrate the batch approach, delete `checkLaunchctlLoaded`, and the existing mocks will work. Expected 96+ after fixes.
