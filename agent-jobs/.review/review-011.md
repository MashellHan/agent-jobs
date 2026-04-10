# Agent Jobs Review -- v011
**Date:** 2026-04-11T02:20:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (main)
**Files scanned:** 19 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md + CHANGELOG.md
**Previous review:** v010 (2026-04-11T02:10:00Z, score 91/100)
**.implementation/ status (root):** `architecture.md` exists -- **first non-empty root .implementation/ in 11 reviews.**
**.implementation/ status (ts-demo):** Contains `task_list.md`, 4 implementation logs (`impl-2026-04-11T0151.md` through `impl-2026-04-11T0215.md`)

## Overall Score: 93/100

+2 from v010. This round addressed three of the four Tier 1 items from v010: scanner tests expanded (parseLsofOutput + inferAgent now exported and tested, 15 new tests), CHANGELOG.md created, root `.implementation/architecture.md` written, and postinstall noise silenced. Tests jumped from 88 to 103 (all passing). Statement coverage jumped from 68.9% to 79.3% (+10.4pp). Scanner coverage specifically went from 16.4% to 54.8% statements. The remaining deductions come from structural issues (nested `ts-demo/`, legacy directories), version still at 1.0.0, missing history view, and incomplete scanner coverage for side-effecting functions.

---

## Score Trajectory (v001 -- v011)

```
Score
100 |                                                               
 95 |                                                     ...target
 93 |                                                 * 93 (v011)
 90 |                                            * 91
 85 |                                   * 85  * 88
 80 |                            * 82 * 83
 75 |                     * 76
 70 |
 65 |
 60 |              * 62
 55 |
 50 |        * 48
 45 |
 40 |
 35 |
 30 |  * 28 * 30
 25 |
    +----+----+----+----+----+----+----+----+----+----+----+
     v001 v002 v003 v004 v005 v006 v007 v008 v009 v010 v011
```

| Review | Score | Delta | Key Accomplishment |
|--------|-------|-------|-------------------|
| v001 | 28 | -- | Initial structure, Go binary, basic types |
| v002 | 30 | +2 | Minor fixes, still foundational |
| v003 | 48 | +18 | TUI dashboard, Ink components, detection patterns |
| v004 | 62 | +14 | Async scanner, test infrastructure, dedup |
| v005 | 76 | +14 | CLI polish, shebang, isDirectRun, job IDs |
| v006 | 82 | +6 | Port extraction, Next Run, dts, split build |
| v007 | 83 | +1 | Snapshot fix, detail panel fields |
| v008 | 85 | +2 | Column alignment, test isolation, scanner tests |
| v009 | 88 | +3 | cronToHuman, AGE column, OpenClaw, coverage thresholds |
| v010 | 91 | +3 | Snapshot stability (fake timers), all tests green |
| v011 | 93 | +2 | Scanner test expansion, CHANGELOG, architecture doc, coverage 79% |

**Trajectory analysis:** Diminishing returns territory. The +2 gain represents solid housekeeping (tests, docs, coverage) rather than feature work. The project is 2 points from the 95 target. Those 2 points require the longest-deferred structural change: moving `ts-demo/` to repo root. Every other low-hanging fruit has been picked.

---

## Category Scores

| Category | Score | v010 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 29 | 29 | -- | GREEN (103/103 tests pass, no regressions) |
| Architecture (20pts) | 19 | 19 | -- | GREEN (Clean component tree, well-separated pipeline) |
| Production-readiness (20pts) | 20 | 19 | +1 | GREEN (Coverage 79.3%, postinstall silenced, CHANGELOG present) |
| Open-source quality (15pts) | 14 | 13 | +1 | GREEN (CHANGELOG.md, architecture.md, task_list.md all present) |
| Security (15pts) | 11 | 11 | -- | GREEN (Atomic writes, no secrets, input validation) |
| **TOTAL** | **93** | **91** | **+2** | |

### Scoring rationale

**Correctness (unchanged at 29/30):** All 103 tests pass in 502ms. The 15 new scanner tests (`parseLsofOutput` 8 tests, `inferAgent` 7 tests) cover edge cases well: empty input, header-only, irrelevant commands, PID deduplication, IPv6 addresses, case insensitivity. These are genuine correctness improvements -- they validate the pure function logic that feeds into the scanner pipeline. Still deducting 1 point because `loader.ts`, `app.tsx`, `setup.ts`, and `cli/index.ts` remain untested, and `scanLiveProcesses`/`scanClaudeScheduledTasks` (the side-effecting scanner functions) have zero coverage.

**Architecture (unchanged at 19/20):** No architectural changes. The decision to export `parseLsofOutput` and `inferAgent` is correct -- these were always pure functions that happened to be private. Exporting them for testing does not weaken encapsulation since they have no access to internal mutable state. The 1-point deduction remains for the `ts-demo/` nesting which creates a misleading package/repo boundary.

**Production-readiness (+1 to 20/20):** Coverage rose significantly: 79.3% statements (was 68.9%), 76.4% branches (was 66.4%), 69.2% functions (was 65.4%), 77.9% lines (was 69.3%). All four metrics are well above thresholds (60/50/60/60). The `postinstall` script now includes `2>/dev/null`, eliminating spurious error output on fresh clones. CHANGELOG.md is present for npm publish. Full marks for production-readiness.

**Open-source quality (+1 to 14/15):** Three meaningful documentation additions this round: (1) `CHANGELOG.md` with a well-structured 0.1.0 entry covering features, (2) root `.implementation/architecture.md` with pipeline diagram, component tree, data format spec (addresses L-impl-1 after 10 reviews), (3) `impl-2026-04-11T0215.md` implementation log documenting this round's changes. The 1-point deduction is because the CHANGELOG says `0.1.0` but package.json still says `1.0.0` -- this version mismatch is confusing. README and CONTRIBUTING still reference `cd agent-jobs/ts-demo`.

**Security (unchanged at 11/15):** No security-relevant changes this round. Prior deductions remain: (1) registry write race condition in `detect.ts` (no file locking -- two concurrent hook invocations could lose writes), (2) `setup.ts` does not validate settings JSON structure before mutation (could corrupt a malformed settings file), (3) `readFileSync(0)` for stdin is functional but not ideal, (4) no input validation on hook JSON beyond type assertion. These are acceptable for a single-user CLI tool but not for a production service.

---

## Delta from v010

### Changed files

| File | Change Type | Description |
|------|-------------|-------------|
| `src/scanner.ts` | MODIFIED | Exported `parseLsofOutput`, `inferAgent`, and `LsofEntry` interface. No behavior changes. |
| `src/scanner.test.ts` | MODIFIED | Added 15 new tests: 8 for `parseLsofOutput`, 7 for `inferAgent`. Total scanner tests: 27 (was 12). |
| `package.json` | MODIFIED | `postinstall` script now includes `2>/dev/null` to silence errors on fresh clones. |
| `CHANGELOG.md` | ADDED | New file with 0.1.0 entry documenting all features for initial release. |
| `../.implementation/architecture.md` | ADDED | Root-level architecture document (pipeline, component tree, data format). |
| `.implementation/impl-2026-04-11T0215.md` | ADDED | Implementation log documenting this round's changes with coverage delta table. |

### Fixed (from v010)

| v010 ID | Description | Resolution |
|---------|-------------|------------|
| L-impl-1 | Root `.implementation/` directory empty (10 reviews) | **FIXED.** `architecture.md` created with pipeline diagram, data flow, component tree, key files table, and data format spec. 59 lines. Concise and useful. |
| Tier 1 #5 (v010) | Export and test `parseLsofOutput` and `inferAgent` | **FIXED.** Both exported, 15 tests added. Scanner coverage: 16.4% to 54.8% statements. |
| Tier 1 #6 (v010) | Create architectural overview in `.implementation/` | **FIXED.** Root `architecture.md` created. |
| Tier 1 #7 (v010) | Silence `postinstall` errors | **FIXED.** Added `2>/dev/null` to postinstall script. |
| Blocker #3 (v010) | No CHANGELOG.md | **FIXED.** CHANGELOG.md created with 0.1.0 entry. |

### New Issues (introduced this round)

| ID | Severity | Description |
|----|----------|-------------|
| M-ver-1 | MEDIUM | CHANGELOG.md documents version `0.1.0` but `package.json` has `"version": "1.0.0"`. Version mismatch. Either update package.json to 0.1.0 or update CHANGELOG to 1.0.0 (the former is recommended per v010 guidance). |

---

## Issue Table (Current Open Issues)

Issues resolved since v010 are marked CLOSED.

| ID | Severity | Category | Description | Source | Status |
|----|----------|----------|-------------|--------|--------|
| C-struct-1 | HIGH | Structure | Go binary (5.1MB arm64 Mach-O) still in `agent-jobs/` directory | v001 | OPEN |
| C-struct-2 | HIGH | Structure | Project nested in `ts-demo/` -- blocks clean npm publish | v001 | OPEN |
| H2 | HIGH | Correctness | Registry write race condition in `detect.ts` (no file locking) | v004 | OPEN |
| M-ver-1 | MEDIUM | Docs | CHANGELOG says 0.1.0, package.json says 1.0.0 | v011 | **NEW** |
| H3 | MEDIUM | Feature | No LaunchAgent scanner (macOS `.plist` running services) | v004 | OPEN |
| H4 | MEDIUM | Code Quality | `detect.ts` reads stdin with `readFileSync(0)` instead of streams | v004 | OPEN |
| M3 | MEDIUM | Correctness | Dedup uses `name` only (not `name`+`project` or richer key) | v004 | OPEN |
| M4 | MEDIUM | Production | `postinstall` runs before build in development | v004 | OPEN |
| M5 | MEDIUM | Security | `setup.ts` doesn't validate settings JSON structure before mutation | v004 | OPEN |
| M7 | MEDIUM | Docs | `CONTRIBUTING.md` says `cd agent-jobs/ts-demo` -- will be wrong after restructure | v004 | OPEN |
| M8 | MEDIUM | Docs | `README.md` dev instructions say `cd agent-jobs/ts-demo` | v004 | OPEN |
| M11 | MEDIUM | Feature | Detail panel lacks history view (User feedback #3) | v004 | OPEN |
| L1 | LOW | UX | Monotone magenta color scheme | v003 | OPEN |
| L2 | LOW | Feature | Detail view lacks log paths | v003 | OPEN |
| L4 | LOW | Code Quality | `list` command reimplements job loading inline in `cli/index.ts` | v003 | OPEN |
| L5 | LOW | Code Quality | `index.tsx` is a 2-line file (could be inlined into `cli/index.ts`) | v003 | OPEN |
| L7 | LOW | Docs | `CONTRIBUTING.md` PR section minimal | v004 | OPEN |
| L8 | LOW | Docs | `README.md` missing test section (how to run tests, coverage) | v004 | OPEN |

### Closed This Round

| ID | Resolution |
|----|------------|
| L-impl-1 | FIXED -- Root `.implementation/architecture.md` created |
| Tier 1 #5 (v010) | FIXED -- `parseLsofOutput` and `inferAgent` exported and tested (15 tests) |
| Tier 1 #6 (v010) | FIXED -- Architecture overview created |
| Tier 1 #7 (v010) | FIXED -- postinstall silenced with `2>/dev/null` |
| Blocker #3 (v010) | FIXED -- CHANGELOG.md created |

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
   Duration  502ms
```

### Test Summary

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `scanner.test.ts` | 27 | 27 | 0 | `friendlyLiveName` (12), `parseLsofOutput` (8), `inferAgent` (7) |
| `detect.test.ts` | 19 | 19 | 0 | `detect()`: all bash/file patterns, dedup, registration, port |
| `utils.test.ts` | 26 | 26 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor`, `cronToHuman`, `formatRelativeTime` |
| `job-table.test.tsx` | 19 | 19 | 0 | `TableHeader`, `JobRow`, alignment, snapshots (2) |
| **Total** | **103** | **103** | **0** | |

### Pass rate: 100% (103/103)

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
Statements   : 79.25%   (threshold: 60%)  PASS
Branches     : 76.36%   (threshold: 50%)  PASS
Functions    : 69.23%   (threshold: 60%)  PASS
Lines        : 77.86%   (threshold: 60%)  PASS
```

### Coverage delta from v010

| Metric | v010 | v011 | Delta |
|--------|------|------|-------|
| Statements | 68.88% | 79.25% | **+10.37pp** |
| Branches | 66.36% | 76.36% | **+10.00pp** |
| Functions | 65.38% | 69.23% | **+3.85pp** |
| Lines | 69.26% | 77.86% | **+8.60pp** |

### Coverage analysis

**Improved modules:**
- `scanner.ts` -- 54.8% statements (was 16.4%). The `parseLsofOutput` and `inferAgent` functions are now well-tested. Remaining uncovered: `getFullCommand` (line 51-53, requires `execFile` mock), `scanLiveProcesses` (lines 93-135, complex async with `lsof`/`ps` mocking), `scanClaudeScheduledTasks` (lines 137-174, requires filesystem mock). These are the side-effecting functions that need integration-style mocking.

**Well-covered modules (unchanged):**
- `utils.ts` -- 98.5% statements. Only uncovered: default case in `statusIcon`.
- `job-table.tsx` -- 100% statements.
- `detect.ts` -- 80% statements. Uncovered: `loadJobs` error path, `main()` CLI entry, `import.meta.url` guard.
- `job-detail.tsx` -- 88.9% statements.

**Not covered at all (not in report):**
- `loader.ts`, `app.tsx`, `index.tsx`, `cli/index.ts`, `setup.ts`, `header.tsx`, `tab-bar.tsx`, `footer.tsx`, `fixtures.ts`, `types.ts` -- not instrumented because no test imports them directly.

### Estimated effective code coverage: ~56%

Up from ~50% in v010. The improvement comes entirely from the scanner test expansion. The gap between reported coverage (79%) and effective coverage (56%) exists because many files are not imported by any test and therefore excluded from the coverage report.

---

## User Feedback Conformance Checklist

| # | User Feedback | Status | Since | Analysis |
|---|---------------|--------|-------|----------|
| 1 | **Schedule display**: cronToHuman utility | **DONE** | v009 | `cronToHuman()` in `utils.ts:42-87`. 7 patterns. 10 tests. Used in table + detail. |
| 2 | **Registration time in table**: AGE column | **DONE** | v009 | `formatRelativeTime()` in `utils.ts:17-40`. AGE column width 10. 8 tests with fake timers. |
| 3 | **History view in detail panel** | **NOT DONE** | -- | No `history` field on `Job` type. No data model changes. No per-run tracking. Unchanged from v010. This has been unfulfilled for 7 reviews since v004. |
| 4 | **OpenClaw support** | **DONE** | v009 | `inferAgent()` in `scanner.ts:58-65`. Tests confirm case-insensitive matching. |
| 5 | **Documentation quality** | **PARTIAL -> MOSTLY DONE** | v011 | CHANGELOG.md added (well-structured 0.1.0 entry). Root `architecture.md` added. Still missing: version consistency (CHANGELOG says 0.1.0, package.json says 1.0.0), README/CONTRIBUTING still reference nested path. |
| 6 | **Project structure**: Move ts-demo to root | **NOT DONE** | -- | `ts-demo/` still nested. Go binary, `go-demo/`, `python-demo/`, `shared/` all still present. 11 reviews. |

**Summary: 3 of 6 fully done. 1 mostly done (upgraded from partial). 2 not started. Net change: documentation improved from partial to mostly done.**

---

## .implementation/ Spec Conformance Check

### Root `.implementation/` directory

**First non-empty state in 11 reviews.** Contains `architecture.md` (59 lines).

The architecture document is genuinely useful. It covers:
1. Pipeline diagram (Hook -> detect -> jobs.json -> TUI, with scanner feed)
2. Data flow in 6 numbered steps (hook trigger, detection, registration, live scanner, cron scanner, display)
3. Component tree (App -> Header, TabBar, TableHeader, JobRow[], JobDetail, Footer)
4. Key files table (6 entries with purpose)
5. Data format example for jobs.json

**Quality assessment:** Good. It answers the "what does this system do and how does it fit together" question that was missing for 10 reviews. The data format example could include all fields (missing `run_count`, `next_run`, `last_run`), but the document is concise and accurate for its scope.

**Conformance verdict:** SATISFACTORY. A meaningful improvement from empty.

### `ts-demo/.implementation/` directory

Contains 5 files (was 4):
1. `task_list.md` -- User feedback tracking, review item history, architecture decisions, structural issues. **Good.**
2. `impl-2026-04-11T0151.md` -- Column alignment, test isolation, detect/scanner tests
3. `impl-2026-04-11T0156.md` -- cronToHuman, AGE column, OpenClaw, coverage thresholds
4. `impl-2026-04-11T0159.md` -- Test env hack removal, name column widening
5. `impl-2026-04-11T0215.md` -- **NEW.** Scanner test expansion, CHANGELOG, architecture doc, postinstall fix. Includes a useful coverage delta table.

The new implementation log (`impl-2026-04-11T0215.md`) follows the established pattern and includes quantitative data (coverage before/after table). This is the best of the four implementation logs for traceability.

---

## Communication Section

### Acknowledging progress

The scanner test expansion is the most impactful change this round. Exporting `parseLsofOutput` and `inferAgent` was exactly the right move -- these were always pure functions hiding behind unnecessary encapsulation. The 15 new tests are well-designed:

- `parseLsofOutput` tests cover the critical edge cases: empty input, header-only, irrelevant commands (spotify), PID deduplication across IPv4/IPv6 binds, multiple valid entries, malformed short lines, IPv6 address port extraction. This is thorough.
- `inferAgent` tests verify all 4 agent types plus the "manual" fallback and case insensitivity. The `claw` keyword alias test is a nice touch.

The CHANGELOG.md is well-structured. It follows Keep a Changelog conventions with a clear features section organized by capability. The version `0.1.0` header aligns with v010's guidance to use semantic pre-stable versioning -- but package.json still says `1.0.0`. This needs a 1-second fix.

The root `architecture.md` resolves L-impl-1 after 10 reviews of being flagged. The document is concise (59 lines), accurately describes the pipeline, and would help a new contributor understand the system within 2 minutes. The component tree diagram is particularly useful.

### What is not changing

**Two items have been open since v001 (11 reviews) and remain untouched:**

1. **C-struct-1/C-struct-2: Project nested in `ts-demo/`, Go binary in repo.** This was the #1 priority in v010's "Prioritized Next Steps" with an estimated 10-minute effort. It remains undone. The CHANGELOG was created *referencing* version 0.1.0, the architecture doc was written, the scanner tests were expanded -- but the single highest-impact structural change was skipped again.

2. **M11: History view (User feedback #3).** Seven reviews since identification. Not started. The `task_list.md` explicitly lists it as "NOT STARTED" and describes the requirement ("Requires data model change"). At this point, either implement it or formally descope it from v0.1.0 with a note.

### Scoring transparency

The +2 gain breaks down as:
- **+1 Production-readiness:** Coverage improvement from 69% to 79% (all metrics), postinstall silenced, CHANGELOG present
- **+1 Open-source quality:** CHANGELOG.md, architecture.md, implementation log

Why not +3 or +4? Because:
- No code changes to the product itself (no new features, no bug fixes)
- The two HIGH structural issues (C-struct-1, C-struct-2) remain
- The version mismatch (M-ver-1) is a new issue introduced this round
- History view still absent

### The path forward

The project is at 93. The target is 95. The gap is exactly 2 points, and it maps almost entirely to the structural issues:

- **Move `ts-demo/` to root, delete legacy dirs** (+1.5 points): resolves C-struct-1, C-struct-2, makes M7/M8 irrelevant, unblocks clean npm publish
- **Fix version to 0.1.0 in package.json** (+0.5 points): resolves M-ver-1, aligns with CHANGELOG

That is 95. No code changes required. Estimated time: 12 minutes.

For 97+, implement history view (M11). For 98+, add tests for `setup.ts` and `loader.ts`.

---

## Prioritized Next Steps

### Tier 0: Reach 95 (12 minutes, no code changes)

1. **[10 min] Move `ts-demo/` contents to repo root and delete legacy directories.**
   ```bash
   # From repo root (agent-jobs/):
   cp -r ts-demo/{src,dist,package.json,tsconfig.json,tsup.config.ts,vitest.config.ts,README.md,LICENSE,CONTRIBUTING.md,CHANGELOG.md,.implementation} .
   cp -r ts-demo/node_modules . 2>/dev/null || true
   rm -rf ts-demo/ agent-jobs/ go-demo/ python-demo/ shared/
   # Update README.md: change "cd agent-jobs/ts-demo" to "cd agent-jobs"
   # Update CONTRIBUTING.md: same path fix
   ```

2. **[1 min] Change version from `1.0.0` to `0.1.0` in `package.json`.**
   This aligns package.json with CHANGELOG.md and signals pre-stable release.

3. **[1 min] Add `"prepublishOnly": "npm test && npm run build"` to `package.json` scripts.**
   Prevents accidental publishing without tests/build.

### Tier 1: Reach 97+ (1 hour)

4. **[45 min] Implement history view in detail panel (User feedback #3).**
   - Add `history?: Array<{ timestamp: string; result: JobResult }>` to `Job` type in `types.ts`
   - In `detect.ts` `registerJob`, when dedup finds existing job, update `last_run`, increment `run_count`, and append to `history` array (capped at 20 entries)
   - In `job-detail.tsx`, render last 5 history entries below existing fields
   - Add tests for history accumulation in `detect.test.ts`

5. **[15 min] Add tests for `setup.ts`.** Mock `fs` and verify:
   - `setup()` creates hook entry when none exists
   - `setup()` skips when hook already present
   - `teardown()` removes only the agent-jobs hook
   - `teardown()` is a no-op when no hooks exist

### Tier 2: Reach 98+ (30 minutes)

6. **[15 min] Add tests for `scanLiveProcesses` and `scanClaudeScheduledTasks`.**
   Mock `execFile` and `readFile` to test the integration logic without OS calls. This would push scanner.ts coverage above 80%.

7. **[10 min] Add test section to README.md.**
   ```markdown
   ## Testing
   npm test              # Run tests
   npm run test:watch    # Watch mode
   npm run test:coverage # Coverage report (threshold: 60%)
   ```

8. **[5 min] Raise coverage thresholds to 70%.** Current coverage (79/76/69/78) supports a bump from 60/50/60/60 to 70/65/65/70.

---

## Summary

v011 is a housekeeping round that addresses documentation and test gaps flagged in v010. The scanner test expansion (15 new tests for `parseLsofOutput` and `inferAgent`) is well-executed and pushed coverage from 69% to 79%. The CHANGELOG.md is properly structured for npm publish. The root `architecture.md` finally fills the documentation gap that has been flagged since v005. The postinstall noise fix is a small but appreciated quality-of-life improvement.

The project is now at 93/100, 2 points from the 95 target. Those 2 points require no code changes -- only moving `ts-demo/` to the repo root and aligning the version number. This is a 12-minute task that has now been deferred for 11 reviews.

Three of six user feedback items are fully done. Documentation has improved from partial to mostly done. History view (feedback #3) and project restructuring (feedback #6) remain the only unaddressed items. Of these, the restructuring is the easiest win and has the highest impact on score and publishability.
