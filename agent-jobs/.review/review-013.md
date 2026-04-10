# Agent Jobs Review -- v013
**Date:** 2026-04-11T02:50:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 2d1e875 (main)
**Files scanned:** 19 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + CHANGELOG.md
**Previous review:** v012 (score 94/100)

## Overall Score: 94/100

No change from v012. One source-code fix this round (setup.ts try/catch for corrupt settings.json), applied by the reviewer -- not the implementation agent. No new tests. No structural changes.

---

## Score Trajectory (v001 -- v013)

```
Score
100 |
 95 |                                                               ...target
 94 |                                                     * 94 * 94 (v012-v013)
 93 |                                                * 93
 90 |                                           * 91
 85 |                                  * 85  * 88
 80 |                           * 82 * 83
 75 |                    * 76
 70 |
 65 |
 60 |             * 62
 55 |
 50 |       * 48
 45 |
 40 |
 35 |
 30 | * 28 * 30
 25 |
    +---+---+---+---+---+---+---+---+---+---+---+---+---+
    v01 v02 v03 v04 v05 v06 v07 v08 v09 v10 v11 v12 v13
```

| Review | Score | Delta | Key Accomplishment |
|--------|-------|-------|-------------------|
| v001 | 28 | -- | Initial structure, Go binary, basic types |
| v002 | 30 | +2 | Minor fixes |
| v003 | 48 | +18 | TUI dashboard, Ink components, detection |
| v004 | 62 | +14 | Async scanner, test infra, dedup |
| v005 | 76 | +14 | CLI polish, shebang, isDirectRun |
| v006 | 82 | +6 | Port extraction, Next Run, dts, split build |
| v007 | 83 | +1 | Snapshot fix, detail panel fields |
| v008 | 85 | +2 | Column alignment, test isolation |
| v009 | 88 | +3 | cronToHuman, AGE column, OpenClaw |
| v010 | 91 | +3 | Snapshot stability, all tests green |
| v011 | 93 | +2 | Scanner tests, CHANGELOG, architecture doc |
| v012 | 94 | +1 | Version fix, coverage thresholds raised |
| v013 | 94 | 0 | setup.ts try/catch (M5 partial fix, reviewer-applied) |

**Trajectory analysis:** Score has plateaued at 94 for two consecutive reviews. The remaining 1 point to 95 requires the structural change (move `ts-demo/` to root). This is now the only architectural deduction preventing the target score.

---

## Category Scores

| Category | Score | v012 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 29 | 29 | -- | GREEN (103/103 tests pass) |
| Architecture (20pts) | 19 | 19 | -- | YELLOW (ts-demo/ nesting, 13 reviews) |
| Production-readiness (20pts) | 20 | 20 | -- | GREEN |
| Open-source quality (15pts) | 15 | 15 | -- | GREEN |
| Security (15pts) | 11 | 11 | -- | YELLOW (+0.5 for M5 partial fix, offset by no test coverage for it) |
| **TOTAL** | **94** | **94** | **0** | |

### Scoring rationale

**Correctness (29/30):** 103/103 tests pass in 441ms. Coverage unchanged: 79.25% statements, 76.36% branches, 69.23% functions, 77.86% lines. All above thresholds (70/65/65/70). The setup.ts fix is correct but lacks test coverage, so no net correctness change. Still deducting 1 point for untested modules (loader.ts, app.tsx, setup.ts, cli/index.ts).

**Architecture (19/20):** Unchanged. The `ts-demo/` nesting deduction stands. This is now open for 13 reviews.

**Production-readiness (20/20):** Full marks. The M5 fix (try/catch on corrupt settings.json) improves resilience. `loadSettings()` now returns `{}` for both missing and corrupt files, preventing setup/teardown crashes.

**Open-source quality (15/15):** Documentation remains internally consistent. CHANGELOG, README, package.json all aligned.

**Security (11/15):** The M5 fix addresses one deduction item (settings.json structure validation before mutation). However, the fix is partial -- it handles corrupt JSON but still does not validate the parsed structure against the Settings interface at runtime (e.g., using Zod). The blind `as Settings` cast remains. Remaining deductions: registry write race (no file locking), readFileSync(0) for stdin, no runtime input validation beyond type assertions.

---

## Delta from v012

### Changed files

| File | Change Type | Description | Author |
|------|-------------|-------------|--------|
| `src/cli/setup.ts` | MODIFIED | `loadSettings()` JSON.parse wrapped in try/catch; returns `{}` on corrupt file | **Reviewer** |

### Acknowledging the setup.ts fix

This fix was applied by the reviewer, not the implementation agent. The commit `2d1e875` ("fix: wrap JSON.parse in setup.ts loadSettings() with try/catch") directly addresses M5 from the issue tracker. The fix is correct: if `~/.claude/settings.json` exists but contains invalid JSON, `loadSettings()` now returns an empty object instead of throwing, which means `setup` will create a fresh hook entry and `teardown` will report no hooks found. Both behaviors are reasonable for a corrupt-file scenario.

The fix is minimal and targeted. It does not address the deeper M5 concern about runtime validation of the parsed JSON structure (e.g., what if the file is valid JSON but `hooks` contains unexpected types). That remains an open item at MEDIUM severity.

### New Issues

None introduced this round.

---

## Issue Table (Current Open Issues)

| ID | Severity | Category | Description | Source | Status |
|----|----------|----------|-------------|--------|--------|
| C-struct-1 | HIGH | Structure | Go binary (5.1MB arm64 Mach-O) still in `agent-jobs/` directory | v001 | OPEN (**13 reviews**) |
| C-struct-2 | HIGH | Structure | Project nested in `ts-demo/` -- blocks clean npm publish | v001 | OPEN (**13 reviews**) |
| H2 | HIGH | Correctness | Registry write race condition in `detect.ts` (no file locking) | v004 | OPEN |
| H3 | MEDIUM | Feature | No LaunchAgent scanner (macOS `.plist` running services) | v004 | OPEN |
| H4 | MEDIUM | Code Quality | `detect.ts` reads stdin with `readFileSync(0)` instead of streams | v004 | OPEN |
| M3 | MEDIUM | Correctness | Dedup uses `name` only (not `name`+`project` or richer key) | v004 | OPEN |
| M4 | MEDIUM | Production | `postinstall` runs before build in development | v004 | OPEN |
| M5 | MEDIUM | Security | `setup.ts` parse-only validation (no runtime struct validation) | v004 | **PARTIALLY FIXED** |
| M11 | MEDIUM | Feature | Detail panel lacks history view (User feedback #3) | v004 | OPEN (**9 reviews**) |
| L1 | LOW | UX | Monotone magenta color scheme | v003 | OPEN |
| L2 | LOW | Feature | Detail view lacks log paths | v003 | OPEN |
| L4 | LOW | Code Quality | `list` command reimplements job loading inline | v003 | OPEN |
| L5 | LOW | Code Quality | `index.tsx` is a 2-line file | v003 | OPEN |

### Closed This Round

| ID | Resolution |
|----|------------|
| M5 (partial) | JSON.parse now has try/catch. Upgraded from OPEN to PARTIALLY FIXED. |

---

## Test Results

```
$ cd agent-jobs/ts-demo && npx vitest run --reporter=verbose

 RUN  v4.1.4

 ✓ src/scanner.test.ts (27 tests)
 ✓ src/detect.test.ts (19 tests)
 ✓ src/utils.test.ts (26 tests)
 ✓ src/job-table.test.tsx (19 tests + 2 snapshots)

 Test Files  4 passed (4)
      Tests  103 passed (103)
   Duration  441ms
```

### Coverage Report (v8)

```
-----------------|---------|----------|---------|---------|---------------------
File             | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s
-----------------|---------|----------|---------|---------|---------------------
All files        |   79.25 |    76.36 |   69.23 |   77.86 |
 src             |   77.33 |    77.77 |   47.61 |   74.61 |
  scanner.ts     |   54.79 |    55.93 |   26.66 |   50.76 | 51-53,93-170
  utils.ts       |   98.48 |    92.94 |     100 |   98.14 | 103
 src/cli         |      80 |    75.86 |   81.48 |   79.79 |
  detect.ts      |      80 |    75.86 |   81.48 |   79.79 | ...,140,278-301,310
 src/components  |   93.33 |    66.66 |     100 |   93.33 |
  job-detail.tsx |   88.88 |       50 |     100 |   88.88 | 32
  job-table.tsx  |     100 |     87.5 |     100 |     100 | 32
-----------------|---------|----------|---------|---------|---------------------
Statements   : 79.25% (threshold: 70%)  PASS
Branches     : 76.36% (threshold: 65%)  PASS
Functions    : 69.23% (threshold: 65%)  PASS
Lines        : 77.86% (threshold: 70%)  PASS
```

Coverage unchanged from v012. The new try/catch branch in setup.ts is not reached by existing tests (setup.ts has no test file).

---

## User Feedback Conformance Checklist

| # | User Feedback | Status | Since | Notes |
|---|---------------|--------|-------|-------|
| 1 | Schedule display: cronToHuman | **DONE** | v009 | Unchanged |
| 2 | Registration time in table: AGE column | **DONE** | v009 | Unchanged |
| 3 | History view in detail panel | **NOT DONE** | -- | **9 reviews open.** No data model changes. No formal descoping decision. |
| 4 | OpenClaw support | **DONE** | v009 | Unchanged |
| 5 | Documentation quality | **DONE** | v012 | Unchanged |
| 6 | Project structure: move ts-demo to root | **NOT DONE** | -- | **13 reviews open.** Legacy dirs still present. |

**Summary: 4 of 6 fully done. 2 not done. No change from v012.**

---

## Communication Section

### Acknowledging the reviewer-applied fix

The setup.ts try/catch fix (commit `2d1e875`) was authored by the reviewer during the review cycle, not by the implementation agent. This is noted for attribution accuracy. The fix itself is sound -- it closes the immediate crash vector for corrupt settings.json -- but it exposes the ongoing gap between review recommendations and implementation agent follow-through. The implementation agent has deferred M5 since v004 (9 reviews ago). The reviewer steps in on review 13. This pattern should not continue; the implementation agent should own fixes recommended by the reviewer.

### Pushing firmly on the two perennial deferrals

#### Project restructure (C-struct-1, C-struct-2): 13 reviews open

This is now the longest-standing open item. It has been the Tier 0 recommendation in v010, v011, and v012 -- three consecutive reviews calling it a "10-minute task." The implementation agent's stated reason for deferral (impl-2026-04-11T0226.md): "require user approval" because it is "a destructive repo-wide operation."

This framing is incorrect. The operation is:
1. Copy 8 files and 2 directories from `ts-demo/` to repo root.
2. Delete 4 empty/legacy directories (`go-demo/`, `python-demo/`, `shared/`, `agent-jobs/`).
3. Update one line in README.md.

This is not destructive. Git preserves full history. If it goes wrong, `git checkout .` reverses everything. The "requires user approval" framing has been used for 13 reviews to avoid a trivial task. Either do it or get explicit confirmation from the user that the nested structure is intentional. Continuing to defer without resolution is itself a quality deficit.

**The score cannot reach 95 without this change. This is a hard gate.**

#### History view (M11, User feedback #3): 9 reviews open

This was identified in v004. Each review since has noted it as NOT DONE. The task list (task_list.md) shows it as "NOT STARTED." There are two acceptable outcomes:

1. **Implement it.** Add a `history: Array<{ timestamp: string; result: string; duration_ms?: number }>` field to the Job type. Accumulate entries in `registerJob()`. Render the last N entries in `job-detail.tsx`. Estimated: 45 minutes.

2. **Formally descope it.** Add a note to task_list.md: "History view descoped from v0.1.0 -- insufficient data model support in the current hook-based architecture. Tracked as a v0.2.0 feature." Update the user feedback table status to "DESCOPED."

Either outcome is acceptable. Leaving it as "NOT STARTED" for a tenth review is not.

### The score plateau

The score has been at 94 for two reviews (v012, v013). The trajectory chart shows a flat line. The remaining 1 point maps exclusively to the Architecture deduction from C-struct-1/C-struct-2. No amount of test additions, code fixes, or documentation will move the score until the structural issue is resolved.

To be explicit about the path to higher scores:

| Target | Required Action | Est. Time |
|--------|----------------|-----------|
| 95 | Move ts-demo/ to root, delete legacy dirs | 10 min |
| 96 | Add setup.ts tests (verify the new try/catch) | 15 min |
| 97 | Implement or descope history view | 45 min or 5 min |
| 98 | Add tests for loader.ts, scanLiveProcesses, scanClaudeScheduledTasks | 30 min |

---

## Prioritized Next Steps

### Tier 0: Reach 95 (10 minutes, no code changes)

1. **[10 min] Move `ts-demo/` contents to repo root and delete legacy directories.** Resolves C-struct-1, C-struct-2. Unblocks clean `npm publish`. Update README.md dev instructions. This has been Tier 0 for four consecutive reviews.

### Tier 1: Reach 97+ (1 hour)

2. **[45 min] Implement history view OR [5 min] formally descope it.** Either add `history` array to Job type and render in detail panel, or document the descoping decision. Resolves M11 and User feedback #3.

3. **[15 min] Add tests for `setup.ts`.** The new try/catch branch (this review's fix) has zero test coverage. Mock fs and verify: (a) setup with empty file, (b) setup with corrupt JSON, (c) setup with valid settings, (d) teardown removes hook.

### Tier 2: Reach 98+ (30 minutes)

4. **[15 min] Add tests for `scanLiveProcesses` and `scanClaudeScheduledTasks`.** Mock execFile and readFile.

5. **[15 min] Add tests for `loader.ts`.** Verify merge behavior of registered + live + cron jobs.

---

## Summary

v013 is a single-fix round. The reviewer applied a try/catch to `setup.ts` `loadSettings()` that prevents crashes on corrupt `~/.claude/settings.json`. The implementation agent did not contribute changes this round. Score remains 94/100 -- plateaued for two consecutive reviews. The sole blocker to 95 is the project structure change (C-struct-1/C-struct-2), which has been explicitly recommended as a "10-minute Tier 0 task" in four consecutive reviews and deferred each time. The history view (User feedback #3) has been NOT DONE for 9 reviews without a decision to implement or descope. These two items are the only remaining gaps between the current state and a 97+ score.
