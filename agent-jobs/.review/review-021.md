# Agent Jobs Review -- v021
**Date:** 2026-04-11T14:25:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 49e1d9e + unstaged changes (main)
**Files scanned:** job-table.tsx, job-table.test.tsx, job-detail.tsx, utils.ts, utils.test.ts, fixtures.ts, snapshots
**Previous review:** v020 (score 88/100, 8 tests failing)

## Overall Score: 97/100 (+9)

The implementation agent has **fully recovered from the v020 regression**. All 8 failing tests are fixed, 7 new tests added, snapshots regenerated, and coverage improved to 92.22% lines. The UX redesign (table + detail panel) is complete and well-tested. All 5 user feedback items are now fully addressed with passing tests.

---

## What Was Done

### 1. All 8 failing tests fixed (`job-table.test.tsx`) — P0 RESOLVED ✅

The implementation agent rewrote the test file from 211 lines to 333 lines, not just fixing assertions but significantly improving test coverage:

| # | Old Failing Test | How Fixed |
|---|-----------------|-----------|
| 1 | `renders all column headers` | → `renders all new column headers` — asserts SERVICE, COMMAND, SCHEDULE, LAST RUN, RESULT, CREATED |
| 2 | `renders a normal job with correct columns` | → `renders a normal job with new columns` — checks service name, command, schedule, result |
| 3 | `truncates long names with ellipsis` | → `truncates long names with ellipsis in service column` — verifies ellipsis present and full name absent |
| 4 | `renders live source label` | → Replaced by `shows command for live process job` in new `command column display` describe |
| 5 | `displays 'pew sync' service name` | → Fixed: removed agent column assertion, kept service name + result check |
| 6-7 | `shows description under job name row` (x2) | → Replaced by `command column display` describe block (3 tests) |
| 8 | `header and rows have matching column starts` | → `header and rows have matching SERVICE column start` — uses indexOf for alignment |

### 2. New tests added (+7 net new)

Total tests: 167 → 174

New test additions:
- `does NOT render old column headers` — negative assertion for JOB NAME, AGENT, AGE
- `shows COMMAND column content on the row` — verifies command text in rendered output
- `shows LAST RUN time (not creation time as AGE)` — verifies relative time for last_run
- `shows dash for LAST RUN when job has never run` — tests neverRunJob fixture
- `command column display` describe block:
  - `shows command for cron job`
  - `shows command for live process job`
  - `sanitizes command column for JSON residue job`
- `schedule column clarity` describe block:
  - `shows always-on for daemon-like services`
  - `shows human-readable cron schedule` (daily 2am)
  - `shows every 30 min for openclaw job`
  - `shows weekdays schedule`
- `real-world service names` describe block:
  - `displays openclaw-monitor service name`
  - `pew sync is visible in the full table`

### 3. Snapshots regenerated ✅

Both snapshots updated to reflect new column layout:
- Full table snapshot with all 10 fixtures renders cleanly
- Expanded detail snapshot shows all fields including Run History section

### 4. Test infrastructure improvements

- `joinFrame()` helper added to normalize Ink word-wrap in narrow test terminals
- `vi.useFakeTimers()` set at top level for stable relative time output in snapshots
- Tests organized in logical describe blocks: `name display issues`, `command column display`, `schedule column clarity`, `real-world service names`

---

## Test Results

```
Test Files  7 passed (7)
     Tests  174 passed (174)
  Duration  614ms
```

### Coverage

```
Statements : 91.49% (452/494)
Branches   : 83.63% (276/330)
Functions  : 90.9%  (100/110)
Lines      : 92.22% (415/450)
```

| File | Stmts | Branch | Funcs | Lines |
|------|-------|--------|-------|-------|
| job-table.tsx | 100% | 83.33% | 100% | 100% |
| job-detail.tsx | 92.3% | 65% | 100% | 92.3% |
| utils.ts | 98.7% | 92.47% | 100% | 98.46% |
| app.tsx | 87.95% | 80% | 82.6% | 92% |
| scanner.ts | 98.63% | 83.05% | 100% | 98.46% |
| detect.ts | 81.48% | 77.61% | 82.75% | 81.1% |

---

## Category Scores

| Category | Score | v020 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 30 | 22 | **+8** | 174/174 pass, all green |
| Architecture (20pts) | 20 | 20 | -- | Clean column redesign, well-structured tests |
| Production-readiness (20pts) | 19 | 18 | **+1** | All UX issues fully implemented and tested |
| Open-source quality (15pts) | 14 | 14 | -- | Good test organization, describe blocks, coverage |
| Security (15pts) | 14 | 14 | -- | Unchanged |
| **TOTAL** | **97** | **88** | **+9** | |

---

## Remaining Items (Non-blocking)

### P2: Detail panel section headers (cosmetic)

Review-019 suggested section headers (`── Schedule ──`, `── History ──`) for visual grouping in the detail panel. Current implementation uses "Run History:" as a section header but no grouping for other fields. This is **optional** — the current layout is functional and clean.

### P2: Detail panel branch coverage (65%)

`job-detail.tsx` has 65% branch coverage. The untested branch is line 33 (`job.run_count < 0` → "(live process)"). Adding a test for this edge case would be straightforward:

```typescript
it("shows (live process) for negative run count", () => {
  const { lastFrame } = render(<JobDetail job={liveProcessJob} />);
  expect(lastFrame()!).toContain("(live process)");
});
```

### P3: detect.ts coverage (81%)

`detect.ts` is at 81% line coverage — the uncovered lines are lockfile edge cases (stale PID detection, timeout) which are harder to test in unit tests. Not blocking.

---

## UX Feedback Conformance — COMPLETE ✅

| # | User Feedback | Status | Verified By |
|---|---------------|--------|-------------|
| UX-1 | name 不清晰 | **DONE + TESTED** | `renders a normal job with new columns` — SERVICE column |
| UX-2 | 没有执行的命令 | **DONE + TESTED** | `command column display` — 3 tests covering cron, live, JSON residue |
| UX-3 | schedule/source/age 不清晰 | **DONE + TESTED** | `schedule column clarity` — 4 tests; LAST RUN replaces AGE; sourceToHuman in detail |
| UX-4 | 创建时间不清楚 | **DONE + TESTED** | `shows LAST RUN time (not creation time as AGE)` — CREATED column visible |
| UX-5 | detail 没有 history | **DONE + TESTED** | Snapshot test shows Run History with "... and 4 earlier runs" |

All 5 user UX issues are **implemented, tested, and verified in snapshots**.

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
v019: 92  ███████████████   ← user UX feedback reset
v020: 88  ██████████████    ← test regression
v021: 97  ████████████████  ← recovery
```

---

## Communication

### To the implementation agent

#### Excellent recovery — all tests green, UX complete

Outstanding work fixing all 8 failing tests and adding 7 new ones. The test file went from needing fixes to being one of the best-structured test files in the project. Specific praise:

1. **Test organization** — `command column display`, `schedule column clarity`, `real-world service names` describe blocks make the test intent crystal clear
2. **Negative assertions** — `does NOT render old column headers` catches regressions if someone accidentally reintroduces old columns
3. **joinFrame() helper** — Smart solution for handling Ink word-wrap in narrow test terminals
4. **Fake timers at top level** — Makes snapshot output deterministic

#### Optional improvements (not blocking)

1. **job-detail.tsx branch coverage**: Add one test for `liveProcessJob` in detail panel to cover the `run_count < 0` → "(live process)" branch (currently 65% branch coverage)
2. **Section headers**: Consider adding `── Schedule ──` and `── History ──` visual separators in the detail panel for a more polished look

#### Current status: SHIP-READY

The project is at 97/100 with 174 passing tests, 92% line coverage, and all 5 user UX issues fully addressed. This is ready for release.

---

## Summary

v021 scores **97/100** (+9). Full recovery from v020's test regression. All 8 failing tests fixed, 7 new tests added (174 total), snapshots regenerated, coverage at 92.22% lines. All 5 user UX feedback items are implemented, tested, and verified. The table redesign (SERVICE, COMMAND, SCHEDULE, LAST RUN, RESULT, CREATED) and detail panel improvements (sourceToHuman, Run History) are production-ready. Only optional cosmetic items remain (detail section headers, branch coverage for live process edge case).
