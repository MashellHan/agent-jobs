# Agent Jobs Review -- v007
**Date:** 2026-04-11T01:40:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit -- all new work is uncommitted)
**Files scanned:** 18 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md
**Previous review:** v006 (2026-04-11T01:33:00Z, score 82/100)
**.implementation/ status:** Directory exists but is EMPTY -- no design docs from the implementation agent. This is now the SEVENTH review with no implementation docs.

## Overall Score: 83/100

+1 from v006. A minimal delta round. The only changed file is `src/components/job-detail.tsx`, which fixes the "Next Run" field that was incorrectly showing port numbers (v006 design question #2). Port and PID are now displayed as separate conditional fields at the bottom of the detail panel. This is the correct fix. However, the snapshot test was not updated, producing a new test failure (1/51). The previously failing port extraction test (v006-C1) is now fixed via `vi.resetAllMocks()` in `beforeEach`. Net result: one fix traded for one new failure -- the test suite remains red.

---

## Category Scores

| Category | Score | v006 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 27 | 27 | -- | YELLOW (1 test still failing, different test) |
| Architecture (20pts) | 17 | 16 | +1 | GREEN (detail panel fields now semantically correct) |
| Production-readiness (20pts) | 17 | 17 | -- | YELLOW (tests still red) |
| Open-source quality (15pts) | 12 | 12 | -- | GREEN |
| Security (15pts) | 10 | 10 | -- | GREEN |
| **TOTAL** | **83** | **82** | **+1** | |

---

## Diff Since Last Review (v006)

### Fixed

| v006 ID | Description | Resolution |
|---------|-------------|------------|
| C1 | Port extraction test fails due to mock state leaking from dedup test | **FIXED.** `detect.test.ts:177-185` now uses `vi.resetAllMocks()` plus re-establishes default mock implementations for `existsSync` and `readFileSync`. All 19 detect tests pass. |
| (design Q #2) | "Next Run" field in job-detail.tsx showed port number instead of next run time | **FIXED.** `job-detail.tsx:20` now shows `formatTime(job.next_run)` unconditionally. Port and PID are appended as separate conditional fields (lines 25-31). Semantically correct. |
| M1 | `splitting: true` in CLI config may generate shared chunks with shebangs | **FIXED.** `tsup.config.ts:21` now has `splitting: false`. |
| H5 | tsup config missing `dts: true` -- no type declarations emitted | **FIXED.** `tsup.config.ts:9` includes `dts: true` in the shared config. Both configs now emit `.d.ts` files. |

### New Issues (introduced this round)

| ID | Severity | File | Description |
|----|----------|------|-------------|
| C1 | CRITICAL | `job-table.test.tsx:209` / `__snapshots__/job-table.test.tsx.snap:21-39` | **Snapshot test fails.** The "renders a table with expanded detail" snapshot still expects `Next Run: :3000` (old buggy behavior) but `job-detail.tsx` now correctly shows `Next Run: -` and a separate `Port: 3000` field. The snapshot needs to be updated with `npx vitest run --update`. |

### Not Fixed (carried from previous reviews)

| ID | Source | Status | Notes |
|----|--------|--------|-------|
| C-struct-1 | v001 | OPEN | Go binary (4.9MB) still in `agent-jobs/` directory |
| C-struct-2 | v001 | OPEN | Project still nested in `ts-demo/` -- not publishable from root |
| H2 | v004 | OPEN | Registry write race condition (no locking) |
| H3 | v004 | OPEN | No LaunchAgent scanner |
| H4 | v004 | OPEN | `detect.ts` reads stdin with `readFileSync(0)` instead of streams |
| M3 | v004 | OPEN | Dedup uses `name` not richer key |
| M4 | v004 | OPEN | `postinstall` runs before build in development |
| M5 | v004 | OPEN | `setup.ts` doesn't validate settings JSON structure |
| M6 | v004 | OPEN | `job-table.test.tsx` documents column-wrapping bug |
| M7 | v004 | OPEN | `CONTRIBUTING.md` says `cd agent-jobs` but project is in `ts-demo/` |
| M8 | v004 | OPEN | `README.md` dev instructions incomplete -- no `cd ts-demo` |
| M9 | v004 | OPEN | `CONTRIBUTING.md` does not mention `npm test` |
| M10 | v004 | OPEN | No `created_at` / registration time in the main table |
| M11 | v004 | OPEN | Detail panel lacks history view |
| L1 | v003 | OPEN | Monotone magenta color scheme |
| L2 | v003 | OPEN | Detail view lacks log paths |
| L3 | v003 | OPEN | `shared/jobs.json` hardcoded paths in legacy directories |
| L4 | v003 | OPEN | List command reimplements job loading |
| L5 | v003 | OPEN | `index.tsx` is a 2-line file |
| L7 | v004 | OPEN | `CONTRIBUTING.md` PR section minimal |
| L8 | v004 | OPEN | `README.md` missing test section |
| L9 | v004 | OPEN | `vitest.config.ts` has no coverage thresholds |
| L11 | v005 | OPEN | `detect.ts` truncates to 200 chars but `scanner.ts` truncates to 120 chars |

---

## Detailed Issue Analysis

### C1. [NEW, REGRESSION] Snapshot test fails -- stale snapshot after job-detail.tsx fix

**File:** `ts-demo/src/job-table.test.tsx:209` and `ts-demo/src/__snapshots__/job-table.test.tsx.snap:21-39`
**Severity:** CRITICAL (test suite red)
**Test:** `Full table snapshot > renders a table with expanded detail`
**Error:** Snapshot mismatch

**Root cause:**

The `job-detail.tsx` component was correctly updated to:
1. Show `formatTime(job.next_run)` instead of the port number under "Next Run"
2. Add a separate conditional "Port" field
3. Add a separate conditional "PID" field

The old snapshot (line 33) expected:
```
│  Next Run:      :3000
```

The actual output now produces:
```
│  Next Run:      -
│  Run Count:     5
│  Last Result:   success
│  Port:          3000
```

This is **correct behavior** -- the snapshot is stale, not the code.

**Fix:** Run `npx vitest run --update` to regenerate the snapshot file. Then verify the new snapshot visually to confirm it matches expectations. This is a 30-second fix.

---

## Test Results

```
$ cd agent-jobs/ts-demo && npx vitest run

 RUN  v4.1.4

 ❯ src/job-table.test.tsx (17 tests | 1 failed)
     × renders a table with expanded detail (snapshot mismatch)
 ✓ src/utils.test.ts (15 tests)
 ✓ src/detect.test.ts (19 tests)

 Test Files  1 failed | 2 passed (3)
      Tests  1 failed | 50 passed (51)
   Duration  481ms
```

### Test Summary

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `utils.test.ts` | 15 | 15 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor` |
| `job-table.test.tsx` | 17 | 16 | 1 | `TableHeader`, `JobRow`, alignment, snapshots |
| `detect.test.ts` | 19 | 19 | 0 | `detect()` patterns, dedup, registration payload, port extraction |
| **Total** | **51** | **50** | **1** | |

### Pass rate: 98% (50/51)

### Key change from v006:
- **Port extraction test:** Now PASSES (was failing in v006). The `vi.resetAllMocks()` fix works correctly.
- **Snapshot test:** Now FAILS (was passing in v006). Stale snapshot from `job-detail.tsx` changes.

### What is tested (well)
- **utils.ts:** Fully covered. All 4 exported functions, edge cases, JSON residue truncation.
- **job-table.tsx:** Visual regression tests, snapshot tests, selection indicators, truncation.
- **detect.ts `detect()` function:** 14 bash patterns, 3 file patterns, tool filtering, dedup, registration payload, port extraction.

### What is NOT tested (unchanged)
- **setup.ts:** 0%
- **scanner.ts:** 0%
- **loader.ts:** 0%
- **app.tsx:** 0%
- **cli/index.ts:** 0%
- **header.tsx, tab-bar.tsx, footer.tsx, job-detail.tsx:** 0% (job-detail is only tested via snapshot)

### Estimated effective code coverage: ~35%

---

## User Feedback Conformance Checklist

The user provided specific feedback on four areas. Here is the conformance status:

| # | User Feedback | Status | Analysis |
|---|---------------|--------|----------|
| 1 | **Schedule display**: `schedule: "always-on"` is hardcoded for registered services. For cron/scheduled services, should show actual frequency (e.g., "every 5 min", "weekdays 9am"). Need a `cronToHuman()` utility. Distinguish daemon vs scheduled vs one-shot. | **NOT IMPLEMENTED** | `detect.ts:188` still hardcodes `schedule: "always-on"` for all registered jobs. `scanner.ts:118` hardcodes `schedule: "always-on"` for live processes. `scanner.ts:156` correctly stores the raw cron expression for Claude scheduled tasks, but no `cronToHuman()` formatter exists. The job table and detail panel show the raw cron string (e.g., `*/5 * * * *`) which is unreadable to most users. The type system defines `schedule: string` but has no semantic distinction between daemon, scheduled, and one-shot job types. |
| 2 | **Registration time visibility**: `created_at` should be visible in the main job table as relative time (e.g., "2h ago"). | **NOT IMPLEMENTED** | `created_at` is stored in the data model and displayed in the detail panel via `formatTime()` (absolute time), but it is not shown in the main table columns. No `formatRelativeTime()` or `timeAgo()` utility exists. The `job-table.tsx` COL definition has no column for registration time. |
| 3 | **History in detail panel**: Detail panel should include friendly history view with smart truncation for long histories. Recent N entries shown, "show more" for longer. | **NOT IMPLEMENTED** | The Job type has no `history` or `run_history` field. The detail panel shows `run_count` and `last_result` but no list of past runs. There is no data model for historical runs. This requires both a schema change and a UI component. |
| 4 | **OpenClaw support**: Should support detecting services from OpenClaw agent, not just Claude Code. | **NOT IMPLEMENTED** | `scanner.ts:59` `inferAgent()` only checks for `claude`, `cursor`, and `copilot` in the command string. `detect.ts:188` hardcodes `agent: "claude-code"` for all hook-detected services. No OpenClaw detection pattern exists. The README mentions only Claude Code, Cursor, and Copilot. |

**Summary:** 0 of 4 user feedback items have been addressed. These represent significant feature gaps between what the user wants and what exists.

---

## Architecture Assessment

### Positive changes
- The `job-detail.tsx` fix is clean and correct. Separating "Next Run" from port/PID into independent conditional fields follows the principle of semantic correctness. Each field label now accurately describes its value.
- The `detect.test.ts` mock isolation fix (`vi.resetAllMocks()` + re-establishing defaults) is the textbook solution. This demonstrates understanding of the vitest mock lifecycle.
- `dts: true` in tsup shared config and `splitting: false` in CLI config are both correct choices.

### Remaining concerns

1. **`job-detail.tsx` lacks the "Schedule" field.** The detail panel shows Source, Status, Created, Next Run, Run Count, Last Result, Port, PID -- but does not show the job's `schedule` value. Given that the main table does show the schedule column, omitting it from the detail view is inconsistent. When/if `cronToHuman()` is implemented, the detail view should show both the raw cron expression and the human-readable interpretation.

2. **`job-detail.tsx` lacks the "Agent" field.** The detail panel omits `job.agent`, which is shown in the main table. For consistency, the detail view should show at least as much information as the table row, plus additional detail.

3. **`setup.ts` mutates the settings object in place (carried).** Lines 76-94 modify `settings.hooks` directly.

4. **`scanner.ts:93` -- error handling in `execFile` callback (carried).** The stdout extraction cast is undocumented.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | YES | `agent-jobs detect` works correctly |
| Hook auto-installation (`setup`) | YES | Atomic write, idempotent |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | **IMPROVED** | Port/PID now in separate fields; "Next Run" correct |
| Live process scanning (lsof) | YES | Async via execFile |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| File watching (both files) | YES | Watches `jobs.json` and `scheduled_tasks.json` |
| Onboarding empty state | YES | Shows "Get started" guide |
| `--version` | YES | Reads from package.json dynamically |
| Type declarations (.d.ts) | **YES** | FIXED. `dts: true` now in tsup shared config |
| `cronToHuman()` schedule display | NO | User feedback #1 -- not implemented |
| Registration time in main table | NO | User feedback #2 -- not implemented |
| History view in detail panel | NO | User feedback #3 -- not implemented |
| OpenClaw agent support | NO | User feedback #4 -- not implemented |
| LaunchAgent scanner | NO | Primary feature gap |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | **YES** | Split config, correct shebang, dts, no splitting |
| npm publish ready | PARTIAL | Nested in `ts-demo/` |
| `postinstall`/`preuninstall` | YES | |
| Tests (passing) | **NO** | 50/51 pass -- 1 snapshot failure |
| Tests (coverage) | PARTIAL | ~35% estimated, no thresholds |
| README | PARTIAL | Missing test instructions, wrong dev path |
| LICENSE file | YES | MIT |
| CONTRIBUTING.md | PARTIAL | Missing test mention, wrong dev path |
| CI/CD | NO | |

---

## Progress Tracking

| Issue | v001 | v002 | v003 | v004 | v005 | v006 | v007 | Notes |
|-------|------|------|------|------|------|------|------|-------|
| Go binary | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | 4.9MB arm64 Mach-O |
| Nested `ts-demo/` | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | Blocks npm publish |
| `detect` CLI broken | -- | -- | -- | NEW | REGR | **FIXED** | FIXED | |
| `isDirectRun` fragility | -- | -- | -- | -- | NEW | **FIXED** | FIXED | |
| Shebang on all chunks | -- | -- | -- | -- | NEW | **FIXED** | FIXED | |
| Job ID collisions | -- | -- | -- | -- | NEW | **FIXED** | FIXED | |
| Dedup test missing | -- | -- | -- | -- | NEW | **FIXED** | FIXED | |
| Payload assertion test | -- | -- | -- | -- | NEW | **FIXED** | FIXED | |
| Port extraction test fail | -- | -- | -- | -- | -- | FAIL | **FIXED** | `vi.resetAllMocks()` |
| "Next Run" shows port | -- | -- | -- | -- | -- | BUG | **FIXED** | Separate Port field |
| dts missing | -- | -- | -- | OPEN | OPEN | OPEN | **FIXED** | `dts: true` added |
| splitting + shebang | -- | -- | -- | -- | -- | NEW | **FIXED** | `splitting: false` |
| Stale snapshot | -- | -- | -- | -- | -- | -- | **NEW** | Trivial fix needed |
| Race condition | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | No locking |
| No LaunchAgent scanner | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |
| stdin readFileSync(0) | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |

**Issues resolved this round:** 4 (v006-C1 port test, v006 "Next Run" bug, v006-M1 splitting, v006-H5 dts)
**New issues found:** 1 (C1 stale snapshot)
**Regressions:** 1 (C1 -- snapshot became stale when job-detail.tsx was fixed without updating snapshot)

---

## Actionable Next Steps (prioritized)

### Tier 0: Immediate (30 seconds)

1. **[30 sec] Update the stale snapshot (C1)** -- Run `npx vitest run --update` and verify the regenerated snapshot visually. This is the ONLY blocker for a green test suite.

### Tier 1: Must do before commit (blockers)

2. **[5 min] Delete legacy directories** -- `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` to remove the 4.9MB Go binary and dead code (C-struct-1).

3. **[10 min] Move `ts-demo/` to repo root** -- `mv ts-demo/* ts-demo/.* . && rmdir ts-demo/` (C-struct-2). Update README/CONTRIBUTING dev instructions.

### Tier 2: User feedback items (should do before publish)

4. **[30 min] Implement `cronToHuman()` utility (User feedback #1)**
   - Create a `cronToHuman(cron: string): string` function in `utils.ts`
   - Convert common patterns: `*/5 * * * *` -> `"every 5 min"`, `0 9 * * 1-5` -> `"weekdays 9am"`, `"always-on"` -> `"daemon (always-on)"`
   - Add a `jobType` derived property: `"daemon"` (always-on), `"scheduled"` (has cron), `"one-shot"` (has cron, not recurring)
   - Use `cronToHuman()` in `job-table.tsx` SCHEDULE column and `job-detail.tsx`
   - Add tests for all common cron patterns

5. **[20 min] Add `created_at` relative time to main table (User feedback #2)**
   - Create a `formatRelativeTime(iso: string): string` utility in `utils.ts`
   - Convert ISO timestamps to "2h ago", "3d ago", "just now", etc.
   - Add a `REGISTERED` or `AGE` column to `job-table.tsx` showing relative time
   - Adjust column widths to fit (may need to drop or narrow another column)
   - Add tests for the relative time formatter

6. **[1 hr] Add history view to detail panel (User feedback #3)**
   - Extend `Job` type with `history?: Array<{ timestamp: string; result: JobResult; duration_ms?: number }>`
   - Modify `detect.ts` to append to history array on re-detection (update existing job instead of dedup-skip)
   - Show last N (5) entries in `job-detail.tsx` with "show more" hint
   - Smart truncation for long command outputs in history entries

7. **[20 min] Add OpenClaw agent detection (User feedback #4)**
   - Add `"openclaw"` to `inferAgent()` in `scanner.ts` -- check for `openclaw` or `claw` in command string
   - In `detect.ts`, detect the agent from hook input metadata (if available) instead of hardcoding `"claude-code"`
   - Update README to list OpenClaw alongside Claude Code, Cursor, Copilot

### Tier 3: Quality improvements

8. **[5 min] Fix README/CONTRIBUTING dev instructions (M7, M8)** -- Add `cd ts-demo` or fix after root move.
9. **[5 min] Add `npm test` to CONTRIBUTING PR checklist (M9)** and test section to README (L8).
10. **[5 min] Add `Schedule` and `Agent` fields to the detail panel** -- for consistency with the main table.
11. **[1 hr] Write tests for `scanner.ts`** -- Mock `execFile`, test `parseLsofOutput`, `inferAgent`, `friendlyLiveName`.
12. **[30 min] Write tests for `setup.ts`** -- Mock settings file, test install/teardown/idempotency.
13. **[30 min] Add vitest coverage thresholds (L9)** in `vitest.config.ts` (set 60% as first milestone).
14. **[2 hr] Implement LaunchAgent scanner (H3)**.

---

## Communication

### To the implementation agent:

**The snapshot test is failing.** The `job-detail.tsx` fix is correct -- you properly separated "Next Run" from port/PID display, which is exactly what v006 recommended. But the snapshot in `__snapshots__/job-table.test.tsx.snap` (line 33) still expects the old buggy output `Next Run: :3000`. Run `npx vitest run --update` to regenerate. This is a 30-second fix that should have been done as part of the `job-detail.tsx` change. When modifying a component that has snapshot tests, always run `--update` and verify the diff.

**Good decisions this round:**
- Fixing the "Next Run" / port conflation was the right call. Each field now has semantic integrity.
- The mock isolation fix (`vi.resetAllMocks()` + re-establishing defaults) is the correct vitest pattern. Option A from the v006 review was followed precisely.
- Adding `dts: true` and setting `splitting: false` clean up two long-standing build issues.

**Pace concern:**
This is the seventh review. The only code change this round was a single component file (`job-detail.tsx`) plus test infrastructure fixes. The project has been scoring in the low-to-mid 80s for three reviews now. To break into the 90s, the implementation rate needs to increase. The remaining items are well-defined and estimated:
- Tier 0 + Tier 1 = 15 minutes of work = score to 88+
- Tier 2 (user feedback) = ~2 hours = score to 92+
- Tier 3 (quality) = ~4 hours = score to 95+

**Critical question: Why is `.implementation/` still empty after seven reviews?**
This is the seventh time this has been flagged. The `.implementation/` directory exists but contains zero files. No PRD, no architecture doc, no task list, no system design document. The implementation agent appears to be working without any documented plan. This creates several problems:
1. The reviewer cannot verify whether the implementation matches the intended design.
2. There is no record of design decisions for future contributors.
3. User feedback items (schedule display, registration time, history, OpenClaw) have no tracking -- they are raised in reviews but there is no evidence they are being tracked or prioritized by the implementation agent.
4. It is unclear whether the implementation agent has seen or acknowledged the user's feedback at all.

At minimum, a `task_list.md` in `.implementation/` should exist mapping user feedback to planned work items with status.

**User feedback relay:**
The user has provided four specific feature requests that have not been addressed across multiple review cycles. I am relaying them here with emphasis:

1. **Schedule display is broken for end users.** `"always-on"` for daemons is fine, but cron-scheduled jobs show raw cron expressions like `*/5 * * * *` which are unreadable. A `cronToHuman()` utility is needed. The type system should also distinguish daemon, scheduled, and one-shot job types rather than treating `schedule` as an opaque string.

2. **Registration time** (`created_at`) is available in the data model but invisible in the main table. Users want to see when a service was first detected, displayed as relative time ("2h ago"). This is a straightforward column addition.

3. **History view** is a more significant feature requiring data model changes. The current `run_count` and `last_result` fields are summaries, but users want to see individual run entries. This needs a `history` array on the Job type and a scrollable view in the detail panel.

4. **OpenClaw support** is a small change (add string matching in `inferAgent()` and optionally in the hook metadata) but signals that the project should be agent-agnostic, not Claude Code-specific. The README and branding already partially support this ("AI coding agents") but the code does not.

None of these have been acknowledged in any form. Are they on the roadmap? Are there technical blockers? Is there a prioritization disagreement?

---

## Summary

v007 is a cleanup round that resolves four issues from v006 (port extraction test, "Next Run" field semantics, dts declarations, splitting config) but introduces one new regression (stale snapshot). The snapshot failure is trivial to fix -- it is a side effect of the correct `job-detail.tsx` change.

The project is functionally solid for its core use case (detect services, display in TUI). The build pipeline is now correct (split configs, dts, no erroneous shebangs). The detection engine has good test coverage. The remaining structural issues (legacy directories, nested `ts-demo/`) are the main blockers for npm publish.

However, four pieces of user feedback remain entirely unaddressed after being raised explicitly. The implementation velocity has slowed -- this round's delta was a single component file. The `.implementation/` directory remains empty, suggesting no planning or tracking infrastructure exists.

**Score trajectory:** 35 (v001) -> 39 (v002) -> 48 (v003) -> 62 (v004) -> 76 (v005) -> 82 (v006) -> 83 (v007)
**Next target:** 88+ after updating snapshot and cleaning repo structure. 92+ requires addressing user feedback items.
