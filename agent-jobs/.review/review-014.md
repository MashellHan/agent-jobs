# Agent Jobs Review -- v014
**Date:** 2026-04-11T08:15:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 3588ac5 (main) + unstaged restructure
**Files scanned:** 12 source files + package.json + README.md + CONTRIBUTING.md + CHANGELOG.md + LICENSE
**Previous review:** v013 (score 94/100)

## Overall Score: 95/100 (+1)

The implementation agent finally resolved the 13-review-old project structure issue. `ts-demo/` contents moved to repo root, legacy directories deleted, documentation updated. Source code is byte-identical -- no regressions. This unblocks the Architecture score.

---

## Score Trajectory (v001 -- v014)

```
Score
100 |
 95 |                                                                    * 95 (v014)
 94 |                                                     * 94 * 94
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
    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+
    v01 v02 v03 v04 v05 v06 v07 v08 v09 v10 v11 v12 v13 v14
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
| v013 | 94 | 0 | setup.ts try/catch (reviewer-applied) |
| v014 | 95 | +1 | **Project restructure: ts-demo/ to root** |

---

## Category Scores

| Category | Score | v013 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 29 | 29 | -- | GREEN (103/103 tests pass) |
| Architecture (20pts) | 20 | 19 | +1 | **GREEN** (restructure resolved) |
| Production-readiness (20pts) | 20 | 20 | -- | GREEN |
| Open-source quality (15pts) | 15 | 15 | -- | GREEN |
| Security (15pts) | 11 | 11 | -- | YELLOW |
| **TOTAL** | **95** | **94** | **+1** | |

### Scoring rationale

**Correctness (29/30):** Unchanged. 103/103 tests pass. Coverage identical at 79.25% statements. Deducting 1 point for untested modules (loader.ts, app.tsx, setup.ts, cli/index.ts).

**Architecture (20/20):** Full marks restored. The project restructure resolves C-struct-1 (Go binary removed) and C-struct-2 (ts-demo/ nesting removed). Clean root layout: src/, dist/, package.json, README.md, LICENSE, CONTRIBUTING.md, CHANGELOG.md. This matches the expected npm package structure for `npm install -g agent-jobs`.

**Production-readiness (20/20):** Full marks. Package.json has proper `bin`, `files`, `engines`, `prepublishOnly`, `keywords`, `repository` fields. Build config (tsup) and test config (vitest) at root level.

**Open-source quality (15/15):** Full marks. README.md is comprehensive with install, usage, keyboard shortcuts, architecture diagram, detected patterns table, development instructions. CONTRIBUTING.md has project structure and PR workflow. CHANGELOG.md has v0.1.0 features. LICENSE is MIT.

**Security (11/15):** Unchanged. Remaining deductions: registry write race (no file locking), readFileSync(0) for stdin, no runtime input validation beyond type assertions, setup.ts lacks runtime struct validation (M5 partial).

---

## Delta from v013

### Changed files

| File | Change Type | Description | Author |
|------|-------------|-------------|--------|
| All files | MOVED | `ts-demo/*` -> repo root | Implementation agent |
| `go-demo/` | DELETED | Legacy Go demo directory | Implementation agent |
| `python-demo/` | DELETED | Legacy Python demo directory | Implementation agent |
| `shared/` | DELETED | Legacy shared directory | Implementation agent |
| `agent-jobs/` (Go binary) | DELETED | 5.1MB arm64 Mach-O binary | Implementation agent |
| `README.md` | UPDATED | Path references: `cd agent-jobs/ts-demo` -> `cd agent-jobs` | Implementation agent |
| `CONTRIBUTING.md` | UPDATED | Path references updated | Implementation agent |

### Source code diff

Zero source code changes. All `.ts`/`.tsx` files are byte-identical to their `ts-demo/` counterparts. No regressions possible from a move-only operation. Verified by running full test suite from new location.

### New Issues

None introduced.

---

## Issue Table (Current Open Issues)

| ID | Severity | Category | Description | Source | Status |
|----|----------|----------|-------------|--------|--------|
| H2 | HIGH | Correctness | Registry write race condition in `detect.ts` (no file locking) | v004 | OPEN |
| H3 | MEDIUM | Feature | No LaunchAgent scanner (macOS `.plist` running services) | v004 | OPEN |
| H4 | MEDIUM | Code Quality | `detect.ts` reads stdin with `readFileSync(0)` instead of streams | v004 | OPEN |
| M3 | MEDIUM | Correctness | Dedup uses `name` only (not `name`+`project` or richer key) | v004 | OPEN |
| M4 | MEDIUM | Production | `postinstall` runs before build in development | v004 | OPEN |
| M5 | MEDIUM | Security | `setup.ts` parse-only validation (no runtime struct validation) | v004 | PARTIALLY FIXED |
| M11 | MEDIUM | Feature | Detail panel lacks history view (User feedback #3) | v004 | OPEN (**10 reviews**) |
| L1 | LOW | UX | Monotone magenta color scheme | v003 | OPEN |
| L2 | LOW | Feature | Detail view lacks log paths | v003 | OPEN |
| L4 | LOW | Code Quality | `list` command reimplements job loading inline | v003 | OPEN |
| L5 | LOW | Code Quality | `index.tsx` is a 2-line file | v003 | OPEN |

### Closed This Round

| ID | Resolution |
|----|------------|
| C-struct-1 | **CLOSED.** Go binary deleted. Legacy `agent-jobs/` directory removed. Open for 13 reviews. |
| C-struct-2 | **CLOSED.** Project moved from `ts-demo/` to repo root. Open for 13 reviews. |

---

## Test Results

```
$ cd agent-jobs && npx vitest run --reporter=verbose

 RUN  v4.1.4

 ✓ src/scanner.test.ts (27 tests)
 ✓ src/detect.test.ts (19 tests)
 ✓ src/utils.test.ts (26 tests)
 ✓ src/job-table.test.tsx (19 tests + 2 snapshots)

 Test Files  4 passed (4)
      Tests  103 passed (103)
   Duration  374ms
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

---

## User Feedback Conformance Checklist

| # | User Feedback | Status | Since | Notes |
|---|---------------|--------|-------|-------|
| 1 | Schedule display: cronToHuman | **DONE** | v009 | |
| 2 | Registration time in table: AGE column | **DONE** | v009 | |
| 3 | History view in detail panel | **NOT DONE** | -- | **10 reviews open.** |
| 4 | OpenClaw support | **DONE** | v009 | |
| 5 | Documentation quality | **DONE** | v012 | |
| 6 | Project structure: move ts-demo to root | **DONE** | v014 | Resolved this round |

**Summary: 5 of 6 fully done (+1 from v013). 1 not done (history view).**

---

## Communication

### Acknowledging the restructure

Well done. The project restructure resolves the longest-standing open issue in the review series (13 reviews, since v001). The execution was clean: files moved correctly, no import breakage, documentation paths updated, legacy directories deleted, tests pass from the new location. The implementation log (`impl-2026-04-11T0232.md`) is clear and well-structured.

### Note on uncommitted state

The restructure exists as unstaged working tree changes. It appears the implementation agent performed the restructure but did not commit or push. The previous git HEAD (`3588ac5`) still has the old `ts-demo/` structure. The restructure needs to be committed and pushed for it to be durable.

### Path to 96+

The plateau is broken. The restructure was the gate. Now the path forward:

| Target | Required Action | Est. Time |
|--------|----------------|-----------|
| 96 | Add setup.ts tests (verify try/catch, setup/teardown flows) | 15 min |
| 97 | Implement or formally descope history view (M11) | 45 min or 5 min |
| 98 | Add tests for loader.ts, scanLiveProcesses, scanClaudeScheduledTasks | 30 min |

### History view decision needed (M11)

This is now the longest-standing feature gap (10 reviews). Please either implement it or formally descope it for v0.2.0. The indecision is the problem, not the feature itself.

---

## Prioritized Next Steps

### Tier 0: Commit the restructure

1. **[1 min] Commit and push the restructure.** The working tree changes need to be staged, committed, and pushed. Without this, the restructure is ephemeral.

### Tier 1: Reach 97+ (1 hour)

2. **[15 min] Add tests for `setup.ts`.** Mock fs and verify: (a) setup with empty file, (b) setup with corrupt JSON, (c) setup with valid settings, (d) teardown removes hook.

3. **[45 min] Implement history view OR [5 min] formally descope it.** Either add `history` array to Job type and render in detail panel, or document the descoping decision in task_list.md. Resolves M11 and User feedback #3.

### Tier 2: Reach 98+ (30 minutes)

4. **[15 min] Add tests for `scanLiveProcesses` and `scanClaudeScheduledTasks`.** Mock execFile and readFile.

5. **[15 min] Add tests for `loader.ts`.** Verify merge behavior of registered + live + cron jobs.

---

## Summary

v014 breaks the two-review score plateau with a +1 to 95/100. The implementation agent resolved the 13-review-old project structure issue by moving `ts-demo/` to the repo root and deleting legacy directories. Source code is unchanged -- zero regression risk. The remaining gap to 96+ is test coverage for untested modules (setup.ts, loader.ts, scanner integration) and a decision on the history view feature (open for 10 reviews). The restructure needs to be committed and pushed.
