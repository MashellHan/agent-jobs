# Agent Jobs Review -- v009
**Date:** 2026-04-11T01:55:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (main)
**Files scanned:** 19 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md
**Previous review:** v008 (2026-04-11T01:50:00Z, score 85/100)
**.implementation/ status (root):** Directory exists but is EMPTY -- **NINTH consecutive review with no design docs.**
**.implementation/ status (ts-demo):** Contains `impl-2026-04-11T0151.md` -- documents column alignment fix, test isolation fix, detect/scanner test additions. This is a change log, not a design doc.

## Overall Score: 88/100

+3 from v008. This round delivers three genuinely important user feedback items that had been outstanding for 5+ reviews: (1) `cronToHuman()` utility replaces the universally hardcoded `"always-on"` display, (2) `created_at` is now visible in the main table via a new `AGE` column using `formatRelativeTime()`, and (3) OpenClaw agent detection is implemented in `scanner.ts:inferAgent()`. The `vitest.config.ts` now has coverage thresholds. However, the test suite is RED (2 snapshot failures) because the snapshots contain error stacktraces from a **prior version of the code** and were never regenerated after the column changes. The detail panel still lacks history. The project remains nested in `ts-demo/`. The `.implementation/` root directory is still empty.

---

## Category Scores

| Category | Score | v008 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 27 | 27 | -- | YELLOW (2 snapshot tests failing, app code correct) |
| Architecture (20pts) | 19 | 18 | +1 | GREEN (AGE column, cronToHuman integrated, clean layout) |
| Production-readiness (20pts) | 18 | 18 | -- | YELLOW (test suite red; coverage thresholds added) |
| Open-source quality (15pts) | 13 | 12 | +1 | YELLOW (impl doc in ts-demo, still no CHANGELOG, no root impl docs) |
| Security (15pts) | 11 | 10 | +1 | GREEN (OpenClaw detection broadens agent model) |
| **TOTAL** | **88** | **85** | **+3** | |

---

## Diff Since Last Review (v008)

### Changed files

| File | Change Type | Description |
|------|-------------|-------------|
| `src/utils.ts` | MODIFIED | Added `formatRelativeTime()` (lines 17-40) and `cronToHuman()` (lines 42-87). Both are well-structured with clear branching logic. |
| `src/components/job-table.tsx` | MODIFIED | Replaced `lastRun` column with `age` column (width 10). Now imports and uses `formatRelativeTime` and `cronToHuman`. Column header changed from "LAST RUN" to "AGE". |
| `src/components/job-detail.tsx` | MODIFIED | Now imports `formatRelativeTime` and `cronToHuman`. Created field shows both absolute and relative time. Schedule field uses `cronToHuman()`. |
| `src/scanner.ts` | MODIFIED | `inferAgent()` now detects `openclaw`/`claw` keywords and returns `"openclaw"` (line 63). |
| `src/fixtures.ts` | MODIFIED | Added `cronJob` fixture (cron-scheduled job with `schedule: "0 2 * * *"`). Added `cronJob` to `allFixtureJobs` array. |
| `src/job-table.test.tsx` | MODIFIED | Rewrote terminal width patching to use ink-testing-library's prototype `columns` property instead of `process.stdout.columns`. Added `cronJob` import. Test count increased to 19. |
| `src/utils.test.ts` | NOT CHANGED | Still 15 tests. No tests for `formatRelativeTime` or `cronToHuman` were added. |
| `vitest.config.ts` | MODIFIED | Added coverage thresholds: statements=60, branches=50, functions=60, lines=60. |
| `ts-demo/.implementation/impl-2026-04-11T0151.md` | NEW | Implementation change log documenting column alignment and test fixes. |

### Fixed (from v008 / earlier)

| v008 ID | Description | Resolution |
|---------|-------------|------------|
| M10 (v004) | No `created_at` / registration time in main table | **FIXED.** New `AGE` column with `formatRelativeTime()` shows "7h ago", "just now", "1d ago" etc. User feedback #2 addressed. |
| User #1 | Schedule displays `"always-on"` for everything | **FIXED.** `cronToHuman()` converts cron expressions to human-readable strings ("daemon", "daily 2am", "every 5 min", "hourly", "weekdays 9am"). `"always-on"` now renders as `"daemon"`. |
| User #4 | No OpenClaw support | **FIXED.** `inferAgent()` now checks for `openclaw`/`claw` in command strings. |
| L9 (v004) | `vitest.config.ts` has no coverage thresholds | **FIXED.** Thresholds set at 60/50/60/60 (statements/branches/functions/lines). |
| H1 (v008) | Import-after-statement anti-pattern | **FIXED.** The `beforeAll`/`afterAll` block is now restructured to use ink-testing-library prototype patching rather than module-level `process.stdout.columns` assignment. Imports are back above setup code. |

### New Issues (introduced this round)

| ID | Severity | File | Description |
|----|----------|------|-------------|
| C1 | CRITICAL | `__snapshots__/job-table.test.tsx.snap` | **Snapshot contains error stacktraces from a prior code version.** Both snapshots record a `formatTime is not defined` error referencing `COL.lastRun` at `job-table.tsx:63` -- code that no longer exists. The current `job-table.tsx` has no `lastRun` column and no `formatTime` reference. The snapshots were generated during a broken intermediate state and never regenerated. The tests render correctly now (the "Received" output in the test failure is actually correct), but they fail because the "Expected" snapshot literally contains an error stack trace. This is a 10-second fix: `npx vitest run src/job-table.test.tsx --update`. |
| M1 | MEDIUM | `src/utils.test.ts` | **No tests for `formatRelativeTime()` or `cronToHuman()`.** Two significant new utility functions added but zero test coverage. `cronToHuman` has 7 code paths (every N min, hourly, every N hours, daily, weekdays, daemon, fallback). `formatRelativeTime` has 6 time buckets. These are pure functions that are trivial to test. |
| M2 | MEDIUM | `src/fixtures.ts:49-51` | **All non-cron fixtures still use `schedule: "always-on"`.** The `cronToHuman()` utility now correctly renders `"always-on"` as `"daemon"`, which is an improvement, but the underlying data model still hardcodes `"always-on"` in `detect.ts:188`. For daemons this is semantically correct, but the detect hook should distinguish between actual daemons (e.g. docker -d, pm2, systemctl) and potentially one-shot scripts (nohup node script.js &). |
| L1 | LOW | `src/components/job-detail.tsx` | **Detail panel "Created" field shows absolute+relative time but inconsistent with main table.** Main table shows only relative ("7h ago"), detail shows "2026-04-10 18:00 (7h ago)". This is actually a good design choice -- noting as observation, not issue. |

### Not Fixed (carried from previous reviews)

| ID | Source | Status | Notes |
|----|--------|--------|-------|
| C-struct-1 | v001 | OPEN | Go binary (5.1MB) still in `agent-jobs/` directory |
| C-struct-2 | v001 | OPEN | Project still nested in `ts-demo/` -- not publishable from root |
| H2 | v004 | OPEN | Registry write race condition (no locking) |
| H3 | v004 | OPEN | No LaunchAgent scanner |
| H4 | v004 | OPEN | `detect.ts` reads stdin with `readFileSync(0)` instead of streams |
| M3 | v004 | OPEN | Dedup uses `name` not richer key |
| M4 | v004 | OPEN | `postinstall` runs before build in development |
| M5 | v004 | OPEN | `setup.ts` doesn't validate settings JSON structure |
| M7 | v004 | OPEN | `CONTRIBUTING.md` says `cd agent-jobs` but project is in `ts-demo/` |
| M8 | v004 | OPEN | `README.md` dev instructions say `cd agent-jobs/ts-demo` |
| M9 | v004 | OPEN | `CONTRIBUTING.md` does not mention `npm test` -- **FIXED** in this round. `CONTRIBUTING.md` line 40 now includes `npm test`. Resolving. |
| M11 | v004 | OPEN | Detail panel lacks history view (User feedback #3) |
| L1 | v003 | OPEN | Monotone magenta color scheme |
| L2 | v003 | OPEN | Detail view lacks log paths |
| L3 | v003 | OPEN | `shared/jobs.json` hardcoded paths in legacy directories |
| L4 | v003 | OPEN | List command reimplements job loading |
| L5 | v003 | OPEN | `index.tsx` is a 2-line file |
| L7 | v004 | OPEN | `CONTRIBUTING.md` PR section minimal |
| L8 | v004 | OPEN | `README.md` missing test section |

---

## Test Results

```
$ cd agent-jobs/ts-demo && npx vitest run

 RUN  v4.1.4

 x src/job-table.test.tsx (19 tests | 2 failed) 127ms
     x renders a complete table with header and all fixture jobs
     x renders a table with expanded detail
 + src/scanner.test.ts (12 tests)
 + src/detect.test.ts (19 tests)
 + src/utils.test.ts (15 tests)

 Test Files  1 failed | 3 passed (4)
      Tests  2 failed | 68 passed (70)
   Duration  591ms
```

### Test Summary

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `scanner.test.ts` | 12 | 12 | 0 | `friendlyLiveName`: scripts, frameworks, fallback |
| `detect.test.ts` | 19 | 19 | 0 | `detect()` patterns, dedup, registration, port extraction |
| `utils.test.ts` | 15 | 15 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor` |
| `job-table.test.tsx` | 19 | 17 | 2 | `TableHeader`, `JobRow`, alignment, snapshots |
| **Total** | **65** | **63** | **2** | |

### Pass rate: 96.9% (63/65) -- was 98.4% in v008

Note: The test count is 70 per vitest output but some tests are nested. The non-snapshot tests (68) all pass.

### Root Cause of Failures

Both failures are **stale snapshots** that contain error output from a previous code version. The snapshot file at `src/__snapshots__/job-table.test.tsx.snap` records a `ReferenceError: formatTime is not defined` stack trace from when `job-table.tsx` referenced `formatTime` and `COL.lastRun` -- both of which were removed in this round's refactoring (replaced by `formatRelativeTime` and `COL.age`). The actual rendered output (visible in the "Received" side of the diff) is correct and shows the new AGE column, daemon/cron schedule display, and proper formatting.

**Fix:** `npx vitest run src/job-table.test.tsx --update` -- literally a one-command fix.

### What is tested (well)
- **utils.ts:** `truncate`, `formatTime`, `statusIcon`, `resultColor` -- fully covered
- **detect.ts `detect()` function:** 19 tests covering all bash patterns and file patterns
- **scanner.ts `friendlyLiveName`:** 12 tests covering all code paths
- **job-table.tsx:** Column headers, status icons, name display, truncation, selection indicators, alignment

### What is NOT tested
- **utils.ts `formatRelativeTime()`:** 0 tests (NEW function, 6 code paths)
- **utils.ts `cronToHuman()`:** 0 tests (NEW function, 7 code paths)
- **scanner.ts:** `scanLiveProcesses`, `scanClaudeScheduledTasks`, `parseLsofOutput`, `inferAgent` -- 0%
- **setup.ts, loader.ts, app.tsx, cli/index.ts:** 0%
- **header.tsx, tab-bar.tsx, footer.tsx, job-detail.tsx:** 0%

### Estimated effective code coverage: ~42% (up from ~40% in v008)

The two new utility functions (`formatRelativeTime`, `cronToHuman`) represent significant logic with zero test coverage. This is a notable gap given that they are pure functions -- the easiest possible things to test.

---

## User Feedback Conformance Checklist

| # | User Feedback | Status | Analysis |
|---|---------------|--------|----------|
| 1 | **Schedule display**: No more `"always-on"` for everything. cronToHuman utility needed. Distinguish daemon/scheduled/one-shot. | **PASS** | `cronToHuman()` implemented in `utils.ts:42-87`. Handles: daemon, every N min, hourly, every N hours, daily at HH:MM (AM/PM), weekdays at HH. Falls back to raw cron string for unrecognized patterns. `"always-on"` now displays as `"daemon"`. Cron schedule `"0 2 * * *"` displays as `"daily 2am"`. The utility is used in both `job-table.tsx` and `job-detail.tsx`. One-shot vs daemon is not fully distinguished at the data model level (no `type` field), but the display correctly differentiates cron-scheduled from always-on. |
| 2 | **Registration time visibility**: `created_at` must be visible in the main job table as relative time (e.g., "2h ago"). | **PASS** | New `AGE` column (width 10) added to `job-table.tsx`. `formatRelativeTime()` in `utils.ts:17-40` formats ISO dates into human-readable relative times: "just now", "Nm ago", "Nh ago", "Nd ago", "Nmo ago". The column replaces the old `LAST RUN` column, which is a good trade-off since last run is still visible in the detail panel. |
| 3 | **History in detail panel**: Friendly history view with smart truncation. | **FAIL -- NOT IMPLEMENTED** | The `Job` type still has no `history` field. The detail panel shows `run_count` and `last_result` but no per-run history entries. No data model changes. This is the only remaining unaddressed user feedback item from the original 4 feature requests. |
| 4 | **OpenClaw support**: Detect services from OpenClaw agent. | **PASS** | `scanner.ts:63` now checks for `"openclaw"` or `"claw"` in command strings and returns `"openclaw"` as the agent identifier. This is implemented in `inferAgent()` which is called for live process scanning. Note: `detect.ts:187` still hardcodes `agent: "claude-code"` for hook-detected services. For PostToolUse hooks this is correct (only Claude Code fires these hooks), but if OpenClaw adopts similar hooks in the future, the detect agent should be configurable. |
| 5 | **Documentation quality**: README, CHANGELOG.md, JSDoc, .implementation/ docs. | **PARTIAL** | README is solid with install, usage, keyboard shortcuts, architecture diagram, and detected patterns table. `CONTRIBUTING.md` now includes `npm test`. `.implementation/impl-2026-04-11T0151.md` exists in `ts-demo/` with a change log. **But:** No CHANGELOG.md. Root `.implementation/` is still empty. Minimal JSDoc (only `detect.ts` module docblock). No architectural design doc. |
| 6 | **Project structure**: ts-demo to root, delete legacy dirs. | **FAIL -- NOT IMPLEMENTED** | `ts-demo/` is still nested. `agent-jobs/` (Go binary 5.1MB), `go-demo/`, `python-demo/`, `shared/` all still exist. |

**Summary: 3 of 6 user feedback items fully addressed (up from 0 in v008). 1 partial. 2 remaining.**

This is significant progress. Items #1, #2, and #4 were outstanding for 5+ reviews and are now properly implemented.

---

## .implementation/ Spec Conformance Check

### Root `.implementation/` directory
Empty. Ninth consecutive review with no content.

### `ts-demo/.implementation/impl-2026-04-11T0151.md`
This file was created between v008 and v009. It documents:
1. Column alignment fix (COL.indicator, width adjustments)
2. Test isolation fix (vi.resetAllMocks)
3. New detect pattern tests (+6)
4. Scanner friendlyLiveName tests (+12)

**Assessment:** This is a change log, not a design document. It records what was done but not why, nor does it describe the system architecture, data flow, or design decisions. It does not reference user feedback items or track their implementation status.

**What was expected:**
- `architecture.md` -- hook-detect-register-display pipeline description
- `prd.md` -- product requirements derived from user feedback
- `task_list.md` -- tracking the 6 user feedback items and their status

**Conformance verdict:** The presence of `impl-2026-04-11T0151.md` is a step forward from zero documentation, but it does not satisfy the design documentation requirement. The document reads as a commit message, not as a living design artifact.

---

## Detailed Issue Analysis

### C1. [NEW] Stale snapshots contain error stacktraces from removed code

**File:** `src/__snapshots__/job-table.test.tsx.snap`
**Severity:** CRITICAL (test suite red, 2 failures)

The snapshot file records error output from a code state where `job-table.tsx` had:
```
<Box width={COL.lastRun}><Text>{formatTime(job.last_run)}</Text></Box>
```
This code no longer exists. The current `job-table.tsx` has:
```
<Box width={COL.age}><Text dimColor>{formatRelativeTime(job.created_at)}</Text></Box>
```

The snapshots were generated during an intermediate broken state (where `formatTime` was imported from a location where it was not available) and were committed as-is. The actual test output is now correct -- it shows the AGE column with relative times, shows `"daemon"` for always-on schedules, and shows `"daily 2am"` for the cron job. The fix is literally one command.

This same category of bug (stale snapshots) has now appeared in v006, v007, v008, and v009. The pattern is: code is changed, snapshots are not regenerated. A CI pipeline or a pre-commit hook that runs `vitest run` would catch this instantly.

### M1. [NEW] No tests for `formatRelativeTime()` and `cronToHuman()`

**File:** `src/utils.test.ts`
**Severity:** MEDIUM

Two new utility functions with significant branching logic have zero test coverage:

`cronToHuman()` paths:
1. `"always-on"` -> `"daemon"`
2. `*/N * * * *` -> `"every N min"`
3. `M * * * *` -> `"hourly"`
4. `M */N * * *` -> `"every Nh"`
5. `M H * * *` -> `"daily Ham/pm"` or `"daily H:MMam/pm"`
6. `M H * * 1-5` -> `"weekdays Ham/pm"`
7. Non-5-field or unrecognized -> passthrough

`formatRelativeTime()` paths:
1. null -> "-"
2. Invalid date -> passthrough
3. Future date -> "just now"
4. <60s -> "just now"
5. <60min -> "Nm ago"
6. <24h -> "Nh ago"
7. <30d -> "Nd ago"
8. >=30d -> "Nmo ago"

These are pure functions with no side effects. Adding 15-20 tests would take 10 minutes and would catch regressions immediately.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | YES | `agent-jobs detect` works |
| Hook auto-installation (`setup`) | YES | Atomic write, idempotent |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | YES | Port/PID/Created(relative+absolute) |
| Live process scanning (lsof) | YES | Async via execFile |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| File watching (both files) | YES | Watches `jobs.json` and `scheduled_tasks.json` |
| Onboarding empty state | YES | Shows "Get started" guide |
| Column alignment | YES | Fixed since v008 |
| `--version` | YES | Reads from package.json dynamically |
| Type declarations (.d.ts) | YES | `dts: true` in tsup |
| `cronToHuman()` schedule display | **YES (NEW)** | User feedback #1 |
| Registration time (AGE) in main table | **YES (NEW)** | User feedback #2 |
| OpenClaw agent detection | **YES (NEW)** | User feedback #4 |
| Coverage thresholds | **YES (NEW)** | 60/50/60/60 in vitest.config |
| History view in detail panel | NO | User feedback #3 |
| CHANGELOG.md | NO | User feedback #5 |
| .implementation/ design docs (root) | NO | User feedback #5 |
| Project structure cleanup | NO | User feedback #6 |
| LaunchAgent scanner | NO | Feature gap |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | YES | Split config, dts, no splitting |
| npm publish ready | NO | Nested in `ts-demo/` |
| Tests (passing) | **NO** | 63/65 pass -- 2 stale snapshot failures |
| Tests (coverage) | PARTIAL | ~42% estimated, thresholds at 60% |
| README | PARTIAL | Has basics, still shows `cd agent-jobs/ts-demo` |
| LICENSE file | YES | MIT |
| CONTRIBUTING.md | PARTIAL | Now mentions `npm test`, still says `cd agent-jobs/ts-demo` |
| CI/CD | NO | |

---

## Progress Tracking

| Issue | v001 | v002 | v003 | v004 | v005 | v006 | v007 | v008 | v009 | Notes |
|-------|------|------|------|------|------|------|------|------|------|-------|
| Go binary | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | 5.1MB arm64 Mach-O |
| Nested `ts-demo/` | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | Blocks npm publish |
| Column wrapping | -- | -- | BUG | BUG | BUG | BUG | BUG | **FIXED** | FIXED | |
| Snapshot stale | -- | -- | -- | -- | -- | FAIL | FIXED | FIXED | **STALE AGAIN** | Different cause: old error in snap |
| Scanner untested | -- | -- | -- | OPEN | OPEN | OPEN | OPEN | PARTIAL | PARTIAL | friendlyLiveName tested |
| Test env issue | -- | -- | -- | -- | -- | -- | -- | NEW | **FIXED** | Prototype patching approach |
| Race condition | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | No locking |
| No LaunchAgent | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |
| stdin readFileSync(0) | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |
| User feedback #1 (schedule) | -- | -- | -- | -- | -- | OPEN | OPEN | OPEN | **FIXED** | cronToHuman() |
| User feedback #2 (age) | -- | -- | -- | -- | OPEN | OPEN | OPEN | OPEN | **FIXED** | AGE column |
| User feedback #3 (history) | -- | -- | -- | -- | OPEN | OPEN | OPEN | OPEN | OPEN | |
| User feedback #4 (OpenClaw) | -- | -- | -- | -- | -- | OPEN | OPEN | OPEN | **FIXED** | inferAgent() |
| .implementation/ empty | -- | -- | -- | -- | OPEN | OPEN | OPEN | OPEN | PARTIAL | impl doc in ts-demo only |

**Issues resolved this round:** 5 (User feedback #1, #2, #4; coverage thresholds; test env fix from v008)
**New issues found:** 2 (C1 stale snapshots, M1 missing utility tests)
**Net improvement:** Strong -- first round to address user feedback items

---

## Communication

### To the implementation agent:

**This is the best round of the project.** Three user feedback items that had been outstanding for 5+ reviews are now properly implemented. Let me be specific about what is good:

1. **`cronToHuman()` is well-implemented.** The function handles 7 distinct patterns with clean, readable branching. The AM/PM formatting for daily schedules is correct (handles midnight as 12am, noon as 12pm). The fallback to raw cron string for unrecognized patterns is the right choice. The `"always-on"` -> `"daemon"` mapping gives users a clear semantic signal.

2. **The AGE column is a significant UX improvement.** Replacing the `LAST RUN` formatted timestamp with a relative `AGE` column ("7h ago", "1d ago", "just now") makes the table dramatically more scannable. The absolute time + relative time in the detail panel is the correct design: summary view gets relative, detail view gets both. This is exactly what the user asked for.

3. **OpenClaw detection is correctly scoped.** Adding `openclaw`/`claw` to `inferAgent()` covers the right surface area (live process scanning). The hook detection correctly remains `"claude-code"` since only Claude Code fires PostToolUse hooks. If OpenClaw adopts a similar hook mechanism, the detect module can be extended then.

4. **The test environment fix is clean.** Patching the ink-testing-library prototype's `columns` property is the correct approach -- it targets the actual mock stdout class rather than the real `process.stdout`. The `beforeAll`/`afterAll` with proper cleanup is well-structured.

5. **Coverage thresholds in vitest.config.ts** are a genuine quality gate (60/50/60/60). These are set conservatively, which is fine for now.

**Now the problems:**

### The snapshots are broken AGAIN. This is the fourth time.

The snapshot file contains error stacktraces from code that no longer exists. The "Expected" output in the snapshot literally records a `ReferenceError: formatTime is not defined` at `job-table.tsx:63` referencing `COL.lastRun` -- code that was replaced by the AGE column in this very round. The snapshots were generated during a broken intermediate edit and never updated.

**This is a 10-second fix:**
```bash
npx vitest run src/job-table.test.tsx --update && npx vitest run
```

This is the fourth consecutive review where snapshots have been stale (v006, v007, v008, v009 -- though v008 fixed v007's staleness and introduced new staleness). Snapshot management needs to become part of the workflow: after any change to component output, regenerate snapshots. Consider adding to the workflow: always run `vitest run --update` after modifying component rendering code, then verify the diff looks correct.

### Two significant utility functions with ZERO tests

`formatRelativeTime()` and `cronToHuman()` are pure functions with clear input/output contracts and multiple code paths. They are the easiest possible things to test. Not testing them is an unnecessary risk, especially since `cronToHuman` handles edge cases like midnight (h=0), noon (h=12), and single-digit minutes. These functions are directly visible to users in the TUI -- a bug here is immediately visible.

### The .implementation/ root directory is still empty after 9 reviews

The `ts-demo/.implementation/impl-2026-04-11T0151.md` file exists, which is progress. But it is a change log, not a design document. The root `.implementation/` directory remains empty. At this point I am downgrading the severity of this item -- the project has working code, good test coverage growth, and the README serves as basic documentation. But a design doc (even 30 lines describing the hook -> detect -> register -> display pipeline) would significantly improve contributor onboarding.

### Score trajectory and remaining path

**Score trajectory:** 35 (v001) -> 39 (v002) -> 48 (v003) -> 62 (v004) -> 76 (v005) -> 82 (v006) -> 83 (v007) -> 85 (v008) -> 88 (v009)

The deceleration pattern noted in v008 has reversed. This round gained +3 with meaningful feature additions rather than just bug fixes.

**Path to 95+:**
1. Fix stale snapshots (2 min) -> removes 2 test failures
2. Add tests for `formatRelativeTime` + `cronToHuman` (15 min) -> adds ~15 tests, improves coverage
3. Move ts-demo to root + delete legacy dirs (15 min) -> resolves the oldest open items
4. Create a minimal `.implementation/architecture.md` (10 min)
5. Create CHANGELOG.md (5 min)

Total estimated: ~45 minutes to reach 95. The remaining gaps are execution, not design.

### Acknowledgment

This round represents a clear shift in priorities. After 8 reviews of infrastructure improvements (tests, column alignment, test isolation), user feedback items were finally addressed. Three of the four feature requests are now implemented. The implementation quality is good -- `cronToHuman()` in particular shows careful attention to formatting edge cases. The test infrastructure work from prior rounds (fixtures, column layout system, mock isolation) provided a solid foundation for these feature additions.

---

## Actionable Next Steps (prioritized)

### Tier 0: Immediate (5 minutes)

1. **[10 sec] Regenerate snapshots.**
   ```bash
   cd ts-demo && npx vitest run src/job-table.test.tsx --update
   ```
   Then verify all tests pass:
   ```bash
   npx vitest run
   ```

### Tier 1: Tests (15 minutes)

2. **[10 min] Add tests for `cronToHuman()`.** At minimum:
   - `"always-on"` -> `"daemon"`
   - `"*/5 * * * *"` -> `"every 5 min"`
   - `"*/1 * * * *"` -> `"every min"`
   - `"0 * * * *"` -> `"hourly"`
   - `"0 */2 * * *"` -> `"every 2h"`
   - `"30 14 * * *"` -> `"daily 2:30pm"`
   - `"0 0 * * *"` -> `"daily 12am"` (midnight edge case)
   - `"0 12 * * *"` -> `"daily 12pm"` (noon edge case)
   - `"0 9 * * 1-5"` -> `"weekdays 9am"`
   - `"not valid"` -> `"not valid"` (passthrough)
   - `"0 2 * * *"` -> `"daily 2am"`

3. **[5 min] Add tests for `formatRelativeTime()`.** At minimum:
   - `null` -> `"-"`
   - Invalid date -> passthrough
   - Just now (<60s)
   - Minutes ago
   - Hours ago
   - Days ago
   - Months ago

### Tier 2: Project structure (15 minutes)

4. **[5 min] Delete legacy directories.** `rm -rf agent-jobs/ go-demo/ python-demo/ shared/`
5. **[10 min] Move `ts-demo/` contents to repo root.** Update README, CONTRIBUTING, package.json repository URL.

### Tier 3: Documentation (15 minutes)

6. **[5 min] Create CHANGELOG.md** with entries for v1.0.0 summarizing all features.
7. **[10 min] Create `.implementation/architecture.md`** describing the hook -> detect -> register -> display pipeline.

### Tier 4: Remaining user feedback

8. **[1 hr] Implement history view in detail panel (User feedback #3).** This requires:
   - Adding `history: Array<{ timestamp: string; result: string; }>` to `Job` type
   - Updating `detect.ts` to append to history on re-detection (instead of dedup skip)
   - Showing last N entries in `job-detail.tsx` with optional truncation
   - Adding a keyboard shortcut to scroll through history if it exceeds the visible area

---

## Summary

v009 is the first round to address user feedback items, delivering 3 of 6 requested features: `cronToHuman()` schedule display (replacing the universal "always-on"), `created_at` via an AGE column with relative time formatting, and OpenClaw agent detection. Coverage thresholds were added to vitest.config.ts. The previous round's test environment issue was fixed with a clean prototype-patching approach. However, the snapshots are stale again (containing error output from removed code), the two new utility functions lack test coverage, the project is still nested in `ts-demo/`, and the root `.implementation/` directory remains empty after 9 reviews. The test suite shows 63/65 passing (the 2 failures are stale snapshots that would pass if regenerated). Estimated code coverage is ~42%.
