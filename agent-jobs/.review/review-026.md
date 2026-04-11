# Agent Jobs Review -- v026
**Date:** 2026-04-11T14:58:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 1354791 + unstaged changes (main)
**Files scanned:** scanner.ts, scanner.test.ts (primary changes); all other src/ files unchanged since v025
**Previous review:** v025 (score 90/100, 2 tests failing)

## Overall Score: 95/100 (+5)

**All 221 tests pass. Zero failures.** The implementation agent followed v025's recommended "Option B" — integrating `loadLaunchctlList()` into `scanLaunchdServices()` as a batch lookup, replacing the per-label `checkLaunchctlLoaded()` approach. The test mocks now correctly match the implementation. Scanner coverage at 95.88% lines. One remaining issue: `checkLaunchctlLoaded()` is now dead code but was not removed.

---

## What Was Done (since v025)

### 1. Batch `launchctl list` integrated — v025 P0 fixed ✅

`scanner.ts` line 373-374: `scanLaunchdServices()` now calls `loadLaunchctlList()` once before `Promise.all`, storing the result in `launchctlMap`:

```typescript
loadLaunchctlList().then((launchctlMap) => {
  Promise.all(
    plists.map(async (filename): Promise<Job | null> => {
      // ...
      const loaded = launchctlMap.has(label);      // line 386
      const pid = launchctlMap.get(label) ?? null;  // line 387
```

This is exactly the fix recommended in v025 § "Action Items → P0 → Fix option 2 (better architecture)". Benefits:
- **1 subprocess** instead of N for `launchctl list` — O(1) instead of O(N)
- Test mocks already used tab-separated format — tests pass without mock changes
- Cleaner async flow: batch lookup → parallel plist parsing

### 2. Test mocks updated to match batch approach ✅

All `scanLaunchdServices` test mocks now consistently return the `launchctl list` (all-services) tab format:

| Test | Mock `launchctl` response | Status |
|------|--------------------------|--------|
| `"parses a valid plist"` (line 502) | `"PID\tStatus\tLabel\n-\t0\tcom.pew.sync\n"` | ✅ Loaded, no PID |
| `"marks unloaded services"` (line 533) | `"PID\tStatus\tLabel\n"` (header only) | ✅ Not in map → stopped |
| `"KeepAlive with PID"` (line 561) | `"PID\tStatus\tLabel\n1786\t0\tai.openclaw.gateway\n"` | ✅ PID=1786 extracted |
| `"plutil failure"` (line 583) | `"PID\tStatus\tLabel\n"` | ✅ Graceful null handling |
| `"multiple plists"` (line 619) | `"...\n-\t0\tcom.pew.sync\n-\t0\tcom.pew.update\n"` | ✅ Both loaded |

### 3. Error handling added for `loadLaunchctlList` failure ✅

`scanner.ts` line 410: `.catch(() => resolve([]))` added to the outer `loadLaunchctlList().then()` chain. If `launchctl list` fails entirely, the scanner returns `[]` instead of crashing.

---

## Test Results

```
 Test Files  7 passed (7)
      Tests  221 passed (221)
   Duration  464ms
```

| Metric | v025 | v026 | Delta |
|--------|------|------|-------|
| Total tests | 221 | 221 | 0 |
| Passing | 219 | **221** | **+2** |
| Failing | 2 | **0** | **-2** |
| Line coverage | 90.32% | **91.56%** | **+1.24%** |

### Coverage by file:

| File | Stmts | Branch | Funcs | Lines | Notes |
|------|-------|--------|-------|-------|-------|
| scanner.ts | 95.88% | 85.11% | 91.89% | 95.56% | ↑ Dead code lines (301-307) reduce coverage slightly |
| utils.ts | 99.02% | 92.66% | 100% | 98.86% | Near-perfect |
| loader.ts | 87.09% | 70% | 90.9% | 92.85% | Acceptable |
| job-table.tsx | 100% | 83.33% | 100% | 100% | ✅ |
| job-detail.tsx | 91.66% | 66.66% | 100% | 91.66% | Acceptable |
| detect.ts | 77.18% | 68.35% | 83.33% | 77.14% | ⚠ `detectScheduleFromCommand` still untested |

---

## Remaining Issues

### P1: Dead code — `checkLaunchctlLoaded()` (scanner.ts:301-315)

`checkLaunchctlLoaded()` is no longer called anywhere. `scanLaunchdServices()` now uses `loadLaunchctlList()` (line 374). The dead function:
- Wastes 15 lines
- Reduces scanner.ts coverage (lines 301-307 appear as uncovered)
- Creates confusion about which approach is canonical

**Fix:** Delete lines 297-315 (the JSDoc + function). No other code references it.

### P2: `detectScheduleFromCommand()` still untested (detect.ts:220-242)

Carried from v025. The function is exported and called in `registerJob()` (line 268), but has zero test coverage. Lines 222-237 are uncovered. Tests proposed in v025 still apply:

```typescript
describe("detectScheduleFromCommand", () => {
  it("detects --interval 60 → 'every min'");
  it("detects --interval 300 → 'every 5 min'");
  it("detects --interval 3600 → 'hourly'");
  it("detects --cron flag → raw cron string");
  it("defaults to 'always-on' when no schedule flags");
});
```

### P3: `detect.ts` overall coverage is low (77.14% lines)

Below the 80% project standard. The `main()` function (lines 361-384) and `detectScheduleFromCommand()` (lines 222-237) are the primary uncovered areas. `main()` is harder to test (reads stdin), but `detectScheduleFromCommand()` is a pure function — easy to cover.

---

## Code Quality Analysis

### Positive

1. **Clean architectural fix** — The batch `loadLaunchctlList()` integration is textbook: one subprocess call instead of N, with the same Map-based lookup pattern that was already implemented and tested. No new code needed — just wiring.

2. **Error resilience chain** — The async flow in `scanLaunchdServices()` now has three catch paths:
   - `readdir` error → `resolve([])`
   - `loadLaunchctlList` failure → `resolve([])`
   - `Promise.all` error → `resolve([])`
   No unhandled rejection is possible.

3. **Mock consistency** — All 7 `scanLaunchdServices` tests now use the same mock format (tab-separated), matching the actual `launchctl list` output. No format mismatch risk.

4. **Test for stopped services works correctly now** — The `"marks unloaded services as stopped"` test (line 518-543) correctly verifies that a service whose label is NOT in the `launchctlMap` gets `status: "stopped"` and `last_result: "unknown"`. This was the core bug fixed.

5. **PID extraction works** — The `"handles KeepAlive service with PID"` test (line 545-573) verifies PID=1786 is correctly extracted from `1786\t0\tai.openclaw.gateway` tab format via `loadLaunchctlList()`.

### Minor Issues

1. **Unused variable** — `scanner.test.ts` line 612: `let plutilCallIndex = 0;` is declared but never used. Lint would catch this but it's harmless.

2. **`loadLaunchctlList()` is private** — The batch function is not exported, which is correct (internal optimization). But it means it can't be unit-tested in isolation. The current approach (testing through `scanLaunchdServices`) provides adequate coverage.

---

## Category Scores

| Category | Score | v025 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 29 | 26 | **+3** | 221/221 tests pass. Zero failures. 91.56% coverage. |
| Architecture (20pts) | 19 | 19 | **0** | Batch approach is optimal. Dead code (`checkLaunchctlLoaded`) is a minor blemish. |
| Production-readiness (20pts) | 20 | 19 | **+1** | All user-facing features work. Pew sync visible. Error handling complete. |
| Open-source quality (15pts) | 14 | 13 | **+1** | All tests green. Clean test structure. `detectScheduleFromCommand` untested is the gap. |
| Security (15pts) | 13 | 13 | **0** | No new security concerns. `execFile` with timeouts. |
| **TOTAL** | **95** | **90** | **+5** | |

---

## Action Items for Implementation Agent

### P1: Delete dead code `checkLaunchctlLoaded()` (30 seconds)

```
scanner.ts lines 297-315 — delete the JSDoc comment and entire function.
```

This is the old per-label approach that was replaced by `loadLaunchctlList()`. Removing it will:
- Eliminate 15 lines of dead code
- Improve scanner.ts coverage from 95.56% to ~97%+
- Remove the misleading JSDoc that references an approach no longer used

### P1: Add `detectScheduleFromCommand()` tests (5 minutes)

In `detect.test.ts`, add:

```typescript
import { detectScheduleFromCommand } from "./detect.js";

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

### P2: Remove unused variable in scanner.test.ts

Line 612: `let plutilCallIndex = 0;` — declared but never read. Delete it.

---

## Communication

### To the implementation agent

#### Excellent work — 221/221 tests passing, clean architecture

You followed the v025 recommendation perfectly:

- ✅ Integrated `loadLaunchctlList()` as a batch lookup (1 subprocess instead of N)
- ✅ Used `launchctlMap.has(label)` / `.get(label)` instead of per-label calls
- ✅ All 221 tests pass — including the two that were failing since v024
- ✅ Error handling added for `loadLaunchctlList` failure path
- ✅ 91.56% overall line coverage

**Two small cleanup items remain:**

1. **Delete `checkLaunchctlLoaded()`** (scanner.ts:297-315) — it's dead code now. You replaced it with `loadLaunchctlList()` but forgot to remove the old function.

2. **Add 5 tests for `detectScheduleFromCommand()`** — it's an exported function you wrote in the previous iteration that still has zero test coverage. The test code was provided in v025's action items.

Also delete the unused `plutilCallIndex` variable on scanner.test.ts line 612.

After these cleanups, the score will be **97-98/100** — matching the pre-v022 peak.

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
v026: 95  ████████████████  ← ALL TESTS PASS, batch launchctl integrated
```

---

## Summary

v026 scores **95/100** (+5). **All 221 tests pass** — the 2 failures from v025 are resolved. The implementation agent integrated `loadLaunchctlList()` as a batch lookup in `scanLaunchdServices()`, replacing per-label `checkLaunchctlLoaded()` calls. This fixes both the test mock format mismatch AND the O(N) subprocess performance issue. Coverage at 91.56% lines. Two cleanup items remain: delete the now-dead `checkLaunchctlLoaded()` function (15 lines), and add 5 tests for the untested `detectScheduleFromCommand()` export. Expected score 97-98 after cleanup.
