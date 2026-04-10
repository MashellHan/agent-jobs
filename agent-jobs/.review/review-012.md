# Agent Jobs Review -- v012
**Date:** 2026-04-11T02:28:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** d49c253 (main)
**Files scanned:** 19 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + CHANGELOG.md
**Previous review:** v011 (score 93/100)

## Overall Score: 94/100

+1 from v011. Two config-only changes this round: version mismatch fixed (package.json 1.0.0 -> 0.1.0) and coverage thresholds raised (60/50/60/60 -> 70/65/65/70). Both were explicit recommendations from v011 Tier 0 and Tier 2. No source code changes. No new tests.

---

## Score Trajectory (v001 -- v012)

```
Score
100 |
 95 |                                                          ...target
 94 |                                                     * 94 (v012)
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
    +---+---+---+---+---+---+---+---+---+---+---+---+
    v01 v02 v03 v04 v05 v06 v07 v08 v09 v10 v11 v12
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

**Trajectory analysis:** The +1 is the minimum meaningful increment from pure config changes. The project is now 1 point from the 95 target. That final point requires the structural change (move `ts-demo/` to root). There is no other config-level shortcut remaining.

---

## Category Scores

| Category | Score | v011 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 29 | 29 | -- | GREEN (103/103 tests pass) |
| Architecture (20pts) | 19 | 19 | -- | GREEN |
| Production-readiness (20pts) | 20 | 20 | -- | GREEN (thresholds raised, coverage passes) |
| Open-source quality (15pts) | 15 | 14 | +1 | GREEN (version mismatch resolved) |
| Security (15pts) | 11 | 11 | -- | YELLOW (prior deductions unchanged) |
| **TOTAL** | **94** | **93** | **+1** | |

### Scoring rationale

**Correctness (29/30):** Unchanged. 103/103 tests pass in 423ms. No regressions. Coverage: 79.25% statements, 76.36% branches, 69.23% functions, 77.86% lines. All above new thresholds (70/65/65/70). Still deducting 1 point for untested modules (loader.ts, app.tsx, setup.ts, cli/index.ts).

**Architecture (19/20):** Unchanged. The 1-point deduction remains for the `ts-demo/` nesting.

**Production-readiness (20/20):** Unchanged at full marks. The threshold bump is a positive signal for CI enforcement but does not change the already-passing production readiness picture.

**Open-source quality (+1 to 15/15):** The version mismatch between CHANGELOG.md (0.1.0) and package.json (was 1.0.0, now 0.1.0) is resolved. All documentation is now internally consistent. Full marks.

**Security (11/15):** Unchanged. Prior deductions: registry write race in detect.ts (no file locking), settings.json mutation without structure validation, readFileSync(0) for stdin, no input validation beyond type assertions.

---

## Delta from v011

### Changed files

| File | Change Type | Description |
|------|-------------|-------------|
| `package.json` | MODIFIED | `"version"` changed from `"1.0.0"` to `"0.1.0"` |
| `vitest.config.ts` | MODIFIED | Coverage thresholds raised: statements 60->70, branches 50->65, functions 60->65, lines 60->70 |

### Fixed (from v011)

| v011 ID | Description | Resolution |
|---------|-------------|------------|
| M-ver-1 | CHANGELOG says 0.1.0, package.json says 1.0.0 | **FIXED.** package.json now `"version": "0.1.0"`. |
| Tier 2 #8 (v011) | Raise coverage thresholds to 70% | **FIXED.** Thresholds now 70/65/65/70. All metrics pass (79/76/69/78). |

### New Issues

None introduced this round.

---

## Issue Table (Current Open Issues)

| ID | Severity | Category | Description | Source | Status |
|----|----------|----------|-------------|--------|--------|
| C-struct-1 | HIGH | Structure | Go binary (5.1MB arm64 Mach-O) still in `agent-jobs/` directory | v001 | OPEN (12 reviews) |
| C-struct-2 | HIGH | Structure | Project nested in `ts-demo/` -- blocks clean npm publish | v001 | OPEN (12 reviews) |
| H2 | HIGH | Correctness | Registry write race condition in `detect.ts` (no file locking) | v004 | OPEN |
| H3 | MEDIUM | Feature | No LaunchAgent scanner (macOS `.plist` running services) | v004 | OPEN |
| H4 | MEDIUM | Code Quality | `detect.ts` reads stdin with `readFileSync(0)` instead of streams | v004 | OPEN |
| M3 | MEDIUM | Correctness | Dedup uses `name` only (not `name`+`project` or richer key) | v004 | OPEN |
| M4 | MEDIUM | Production | `postinstall` runs before build in development | v004 | OPEN |
| M5 | MEDIUM | Security | `setup.ts` doesn't validate settings JSON structure before mutation | v004 | OPEN |
| M11 | MEDIUM | Feature | Detail panel lacks history view (User feedback #3) | v004 | OPEN (8 reviews) |
| L1 | LOW | UX | Monotone magenta color scheme | v003 | OPEN |
| L2 | LOW | Feature | Detail view lacks log paths | v003 | OPEN |
| L4 | LOW | Code Quality | `list` command reimplements job loading inline | v003 | OPEN |
| L5 | LOW | Code Quality | `index.tsx` is a 2-line file | v003 | OPEN |

### Closed This Round

| ID | Resolution |
|----|------------|
| M-ver-1 | FIXED -- package.json version corrected to 0.1.0 |

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
   Duration  423ms
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

Coverage unchanged from v011. Thresholds raised; all metrics pass with comfortable margin.

---

## User Feedback Conformance Checklist

| # | User Feedback | Status | Since | Notes |
|---|---------------|--------|-------|-------|
| 1 | Schedule display: cronToHuman | **DONE** | v009 | Unchanged |
| 2 | Registration time in table: AGE column | **DONE** | v009 | Unchanged |
| 3 | History view in detail panel | **NOT DONE** | -- | 8 reviews since identification. No data model changes. |
| 4 | OpenClaw support | **DONE** | v009 | Unchanged |
| 5 | Documentation quality | **DONE** | v012 | Version mismatch resolved. Upgraded from MOSTLY DONE. |
| 6 | Project structure: move ts-demo to root | **NOT DONE** | -- | 12 reviews. Legacy dirs still present. |

**Summary: 4 of 6 fully done. 2 not done. Documentation upgraded from mostly done to done (version fix).**

---

## Communication Section

### Acknowledging the version fix

The version alignment is confirmed: `package.json` now reads `"version": "0.1.0"`, matching `CHANGELOG.md`. This closes M-ver-1 and resolves the last documentation inconsistency. The coverage threshold bump to 70/65/65/70 is a sensible choice given current coverage (79/76/69/78) -- it provides meaningful CI guardrails without being so tight that future refactoring trips the thresholds.

### The remaining 1 point

The project is at 94. The target is 95. The gap maps to exactly one thing:

**C-struct-1 / C-struct-2: Move `ts-demo/` to repo root.**

This has been the top recommendation since v001. It has been explicitly called out as the single highest-priority item in v010 (Tier 0, estimated 10 minutes) and v011 (Tier 0, estimated 12 minutes). It remains undone after 12 reviews. The repo root currently contains:

```
agent-jobs/      (Go binary, 5.1MB -- dead code)
go-demo/         (empty/legacy)
python-demo/     (empty/legacy)
shared/          (empty/legacy)
ts-demo/         (the actual project)
```

The fix:
```bash
# From repo root:
cp -r ts-demo/{src,dist,package.json,tsconfig.json,tsup.config.ts,vitest.config.ts,README.md,CHANGELOG.md,.implementation} .
rm -rf ts-demo/ agent-jobs/ go-demo/ python-demo/ shared/
# Update README.md Development section: "cd agent-jobs/ts-demo" -> "cd agent-jobs"
```

Until this is done, the score cannot reach 95. No amount of test additions, documentation polish, or feature work will compensate because the structural issue deducts from Architecture (which is capped at 19/20 until resolved).

### History view (User feedback #3)

This has been tracked as NOT DONE for 8 reviews. The recommendation from v011 stands: either implement it (add a `history` array to the Job type, accumulate run entries in detect.ts, render in job-detail.tsx) or formally descope it from v0.1.0 with a note in the task list explaining why. Leaving it perpetually as "NOT STARTED" without a decision is itself a quality signal.

### What not to do next

Do not add more tests, raise more thresholds, add more documentation, or refactor existing code. The marginal return on all of these is approximately zero at this score level. The only action that moves the score is the structural change.

---

## Prioritized Next Steps

### Tier 0: Reach 95 (10 minutes, no code changes)

1. **[10 min] Move `ts-demo/` contents to repo root and delete legacy directories.** This resolves C-struct-1, C-struct-2, and unblocks clean `npm publish`. Update README.md dev instructions to remove `cd agent-jobs/ts-demo`.

### Tier 1: Reach 97+ (1 hour)

2. **[45 min] Implement history view (User feedback #3).** OR formally descope it from v0.1.0.

3. **[15 min] Add tests for `setup.ts`.** Mock fs and verify setup/teardown behavior.

### Tier 2: Reach 98+ (30 minutes)

4. **[15 min] Add tests for `scanLiveProcesses` and `scanClaudeScheduledTasks`.**

5. **[15 min] Add tests for `loader.ts`.**

---

## Summary

v012 is a minimal config-fix round that resolves the version mismatch (M-ver-1) and raises coverage thresholds. Both changes were explicitly recommended in v011. No source code changes, no new tests, no regressions. The project moves from 93 to 94, with the final point to 95 gated entirely on the structural change that has been deferred for 12 reviews. The version alignment upgrades documentation quality to full marks. Two user feedback items remain unaddressed: project restructuring and history view.
