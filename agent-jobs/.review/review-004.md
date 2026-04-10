# Agent Jobs Review -- v004
**Date:** 2026-04-11T01:15:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit -- all new work is uncommitted)
**Files scanned:** 17 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md
**Previous review:** v003 (2026-04-11T01:10:00Z, score 48/100)

## Overall Score: 62/100

+14 from v003. Significant progress this round: three test files added (utils.test.ts, detect.test.ts, job-table.test.tsx) with fixtures, vitest config wired up, README with install/usage/architecture docs, MIT LICENSE file, CONTRIBUTING.md, `--version` command, `isAgentJobsHook` parentheses fixed, `saveSettings()` now uses atomic write, `watchJobsFile` now watches both `jobs.json` and `scheduled_tasks.json`, onboarding empty state added, `filterJobs` no longer conflates "live" with "cron".

---

## Category Scores

| Category | Score | v003 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 20 | 18 | +2 | YELLOW |
| Architecture (20pts) | 11 | 9 | +2 | YELLOW |
| Production-readiness (20pts) | 12 | 8 | +4 | YELLOW |
| Open-source quality (15pts) | 12 | 6 | +6 | GREEN |
| Security (15pts) | 7 | 7 | -- | YELLOW |
| **TOTAL** | **62** | **48** | **+14** | |

---

## Diff Since Last Review (v003)

### Fixed

| v003 ID | Description | Resolution |
|---------|-------------|------------|
| C3 | `setup.ts` writes settings.json without backup | FIXED. `setup.ts:52-54` now uses temp+rename atomic write pattern identical to `detect.ts`. |
| H1 | Zero tests | PARTIALLY FIXED. Three test files added: `utils.test.ts` (15 tests, pass), `job-table.test.tsx` (17 tests, pass), `detect.test.ts` (12 tests, ALL FAIL). 32/44 tests pass. |
| M1 | Comment says 15s, code uses 10s | STILL OPEN. `app.tsx:68` comment still says "every 15 seconds", code still uses `10_000`. |
| M2 | Tab "live" includes "cron" | FIXED. `filterJobs` in `app.tsx:19` now only filters `j.source === "live"` without cron. |
| M4 | No onboarding empty state | FIXED. `app.tsx:160-167` shows "Get started" instructions when `allJobs.length === 0`. |
| M5 | Only watches `jobs.json`, not `scheduled_tasks.json` | FIXED. `loader.ts:61-62` now creates watchers for both `JOBS_PATH` and `CLAUDE_TASKS_PATH`. |
| M8 | `isAgentJobsHook` operator precedence | FIXED. `setup.ts:58-59` now uses explicit parentheses. |
| L6 | No `--version` flag | FIXED. `cli/index.ts:74-77` handles `--version`, `-v`, and `version` commands. |

### Not Fixed (carried from v003)

| v003 ID | Status | Notes |
|---------|--------|-------|
| C1 | OPEN | Go binary (4.9MB) still in `agent-jobs/` directory |
| C2 | OPEN | Project still nested in `ts-demo/` -- not publishable from root |
| H2 | OPEN | No LaunchAgent scanner |
| H3 | OPEN | `scanLiveProcesses()` uses sync `execFileSync` blocking event loop |
| H4 | OPEN | Registry write race condition (no locking) |
| H5 | OPEN | `detect.ts` reads stdin with `readFileSync(0)` instead of streams |
| H6 | OPEN | tsup config missing `dts: true` |
| H7 | OPEN | Build script shebang injection is fragile inline script |
| H8 | OPEN | `loader.ts` calls sync functions inside async wrapper |
| M3 | OPEN | `JobsFile` type still duplicated between `detect.ts:112-115` and `types.ts:23-26` |
| M6 | OPEN | `utils.ts` functions accept `string` not typed unions -- ACTUALLY FIXED (see below) |
| M7 | OPEN | Dedup uses `name` not richer key |
| M9 | OPEN | `postinstall` runs before build in development |
| M10 | OPEN | `setup.ts` doesn't validate settings JSON structure |
| M11 | OPEN | Source-level shebangs in `detect.ts` and `index.ts` |
| L1 | OPEN | Monotone magenta |
| L2 | OPEN | Footer separator -- actually now has `marginTop={1}` which is acceptable |
| L3 | OPEN | Detail view lacks log paths |
| L4 | OPEN | `shared/jobs.json` hardcoded paths |
| L5 | OPEN | List command reimplements job loading |
| L7 | OPEN | `index.tsx` is a 2-line file |
| L8 | OPEN | `dev` script uses `npx tsx` unnecessarily |

### Status correction from v003

| v003 ID | Correction |
|---------|-----------|
| M6 | `utils.ts:22` `statusIcon(status: JobStatus)` and `utils.ts:35` `resultColor(result: JobResult)` now accept typed unions. This was actually already fixed in v003 but I missed it. Marking FIXED. |
| M1 | Comment/code mismatch still present. Not fixed. |

---

## Critical Issues (must fix)

### C1. [CARRIED] Go binary in source tree (4.9MB)
**File:** `agent-jobs/agent-jobs` -- Mach-O 64-bit arm64 executable
**Severity:** CRITICAL
Unchanged from v003. This is the single largest blocker for git commit. Once committed, 4.9MB binary permanently bloats git history.

**Fix:** `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` before any commit.

### C2. [CARRIED] Project nested inside `ts-demo/`
**File:** entire project lives under `ts-demo/`
**Severity:** CRITICAL
Unchanged from v003. The npm package, README, LICENSE, CONTRIBUTING all live inside `ts-demo/` but the repo root contains `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/`. No contributor or user will understand this structure.

**Fix:** Move `ts-demo/*` to repo root and delete legacy directories.

### C3. [NEW] All 12 detect.test.ts tests fail -- `detect is not a function`
**File:** `ts-demo/src/detect.test.ts:23-35`
**Severity:** CRITICAL
The test file attempts to import `detect` from `./cli/detect.js` using a `beforeAll` hook that catches the `process.exit` throw from `main()`. However, the module-level `main()` call in `detect.ts:289` executes `process.exit(0)` (mocked to throw), and the double-import in the catch block still results in `detect` being undefined.

Root cause: `detect.ts` has `main()` called at module scope (line 289). When the module is imported, `main()` runs, hits `readFileSync(0)` (mocked to return `""`), finds empty input, calls `process.exit(0)` (mocked to throw). The thrown error is caught in `beforeAll`, but the re-import in the catch block reuses the cached (crashed) module, so `detect` is never properly assigned.

This means the project has 0 passing tests for the most critical code path (the detection engine). The test file exists but provides no actual verification.

**Fix:** Separate `detect.ts` into two files: a library module that exports `detect()`, `extractPort()`, `registerJob()` etc., and a CLI entry point (`detect-cli.ts`) that imports the library and calls `main()`. Tests import the library module only. Alternatively, move `main()` behind an `if` guard:
```typescript
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
```

### C4. [NEW] `--version` is hardcoded, will drift from package.json
**File:** `ts-demo/src/cli/index.ts:76`
```typescript
process.stdout.write("agent-jobs v1.0.0\n");
```
**Severity:** HIGH (downgraded from CRITICAL -- functional but will drift)
The version string is hardcoded as `"v1.0.0"`. After a version bump in `package.json`, the CLI will report the wrong version. This is a common source of user confusion.

**Fix:** Read from `package.json` at build time or runtime:
```typescript
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const { version } = require("../../package.json");
process.stdout.write(`agent-jobs v${version}\n`);
```
Or use tsup's `define` option to inject at build time.

---

## High Priority (should fix)

### H1. [CARRIED] `scanLiveProcesses()` uses sync `execFileSync`
**File:** `ts-demo/src/scanner.ts:68`
**Severity:** HIGH
Unchanged. Blocks event loop for up to 5 seconds every 10 seconds. TUI freezes during scan.

### H2. [CARRIED] Registry write race condition
**File:** `ts-demo/src/cli/detect.ts:128-135`
**Severity:** HIGH
Unchanged. `loadJobs()` + `saveJobs()` is not atomic as a pair.

### H3. [CARRIED] No LaunchAgent scanner
**Severity:** HIGH
Unchanged. Hook detects `launchctl load` but TUI cannot show live launchd service status.

### H4. [CARRIED] `detect.ts` reads stdin with `readFileSync(0)`
**File:** `ts-demo/src/cli/detect.ts:264`
**Severity:** HIGH
Unchanged. Non-standard and makes the module untestable (see C3).

### H5. [CARRIED] tsup config missing `dts: true`
**File:** `ts-demo/tsup.config.ts`
**Severity:** HIGH
No type declarations emitted. Anyone importing `agent-jobs` as a library gets no types.

### H6. [CARRIED] Build script shebang injection is fragile
**File:** `ts-demo/package.json:13`
**Severity:** HIGH
Unchanged. Inline Node script using `require()` in an ESM package. Should use tsup's `banner` option.

### H7. [CARRIED] `loader.ts` calls sync functions inside async wrapper
**File:** `ts-demo/src/loader.ts:11-14`
**Severity:** HIGH
`scanLiveProcesses()` (sync, up to 5s) called inside a `.then()` gives false sense of async safety.

### H8. [NEW] `detect.test.ts` mocking strategy is fundamentally broken
**File:** `ts-demo/src/detect.test.ts:5-35`
**Severity:** HIGH
Beyond the immediate "detect is not a function" failure (C3), the test architecture has deeper issues:
1. Mocking `fs.readFileSync` globally affects all modules that use it, including `registerJob()` which calls `loadJobs()` -> `readFileSync(JOBS_PATH)`. This means even if `detect()` were properly imported, the positive-match tests would fail or produce side effects because `registerJob` would get the real filesystem.
2. No mock for `writeFileSync` or `renameSync`, so positive detections would write to the real `~/.agent-jobs/jobs.json` during tests.
3. No `afterEach` cleanup of the jobs file.

**Fix:** Mock the entire job registry (loadJobs/saveJobs) or use a temp directory for `JOBS_DIR`.

### H9. [NEW] `job-table.test.tsx` documents bugs without tracking them
**File:** `ts-demo/src/job-table.test.tsx:45-48, 149-154`
**Severity:** MEDIUM (elevated to HIGH because the tests mask real failures)
The test file contains multiple comments like "BUG: rows wrap to multiple lines" and uses assertions that *allow* the bug to pass:
```typescript
// BUG: "registered" gets split across lines due to column overflow
expect(frame).toContain("registere");  // not "registered"
```
```typescript
// Currently wrapping to 2 lines -- after fix should be 1 line.
expect(lines.length).toBeLessThanOrEqual(2);
```
These tests pass, creating the impression the code is correct, when in fact they document known rendering bugs. Tests should either (a) `it.skip` the failing assertion with a TODO, or (b) use `it.fails` to mark them as known failures, or (c) actually fix the underlying column width issue.

The column alignment bug is real: total column width is `4+30+16+20+12+20+10 = 112` plus `6 gaps * 2 = 12` plus indicator = `125` chars. In ink-testing-library's default 80-column render width, this wraps.

---

## Medium Priority (nice to have)

### M1. [CARRIED] Comment says 15s, code uses 10s
**File:** `ts-demo/src/app.tsx:68-70`
**Severity:** MEDIUM

### M2. [CARRIED] `JobsFile` type duplicated
**File:** `ts-demo/src/cli/detect.ts:112-115` vs `ts-demo/src/types.ts:23-26`
**Severity:** MEDIUM
`detect.ts` uses `Array<Record<string, unknown>>`, `types.ts` uses `Array<Omit<Job, "source">>`. They represent the same file but with incompatible types.

### M3. [CARRIED] Dedup uses `name` not richer key
**File:** `ts-demo/src/cli/detect.ts:162`
**Severity:** MEDIUM

### M4. [CARRIED] `postinstall` runs before build in development
**File:** `ts-demo/package.json:19`
**Severity:** MEDIUM

### M5. [CARRIED] `setup.ts` doesn't validate settings JSON structure
**File:** `ts-demo/src/cli/setup.ts:48`
**Severity:** MEDIUM

### M6. [CARRIED] Source-level shebangs in `.ts` files
**File:** `ts-demo/src/cli/detect.ts:1`, `ts-demo/src/cli/index.ts:1`
**Severity:** MEDIUM
Shebangs in TypeScript source files are harmless but conceptually wrong. Build output also injects shebangs, risking double shebangs.

### M7. [NEW] Test assertions are too weak -- `expect(typeof result).toBe("boolean")`
**File:** `ts-demo/src/detect.test.ts:51, 59, 67, 75, etc.`
**Severity:** MEDIUM
Multiple tests assert only `typeof result === "boolean"` instead of checking the actual value. For detection tests, this is meaningless -- both `true` (detected) and `false` (not detected) pass. Even if the tests ran, they would not verify correct behavior.

For example, "generates pm2:\<script\> name for pm2 start" should assert `result === true` and verify the registered job's name is `"pm2:api.js"`.

### M8. [NEW] `CONTRIBUTING.md` says `cd agent-jobs` but project is in `ts-demo/`
**File:** `ts-demo/CONTRIBUTING.md:7-8`
```
git clone https://github.com/MashellHan/agent-jobs.git
cd agent-jobs
npm install
```
**Severity:** MEDIUM
After clone, `npm install` at the repo root fails because `package.json` is in `ts-demo/`. The contributing guide is wrong. Same issue in `README.md:88-91`.

### M9. [NEW] `README.md` dev instructions incomplete -- no `cd ts-demo`
**File:** `ts-demo/README.md:87-93`
**Severity:** MEDIUM
Same as M8. Development section says `cd agent-jobs` then `npm install` but actual commands need `cd agent-jobs/ts-demo`.

### M10. [NEW] `CONTRIBUTING.md` does not mention running tests
**File:** `ts-demo/CONTRIBUTING.md:36-40`
**Severity:** MEDIUM
PR checklist says "Run `npm run build` to verify" but does not mention `npm test`. Vitest is configured but not referenced in the contributing guide.

### M11. [NEW] No `created_at` / registration time in the main table
**Severity:** MEDIUM
Per review criteria, "Job registration time should be visible in the main table." Currently the table shows LAST RUN but not when the job was first registered. The `created_at` field exists in the data model but is only shown in the detail panel.

### M12. [NEW] Detail panel lacks history view
**Severity:** MEDIUM
Per review criteria, "Detail panel should include friendly history view with smart truncation for long histories." The detail panel shows static fields only -- no run history, no log entries, no timestamps of past runs. The data model has `run_count` but no history array.

---

## Low Priority (polish)

### L1. [CARRIED] Monotone magenta color scheme
### L2. [NEW] Footer `marginTop={1}` is acceptable -- closing this issue from v003
### L3. [CARRIED] Detail view lacks log paths (stdout/stderr)
### L4. [CARRIED] `shared/jobs.json` hardcoded paths
### L5. [CARRIED] List command reimplements job loading
### L6. [CARRIED] `index.tsx` is a 2-line file
### L7. [CARRIED] `dev` script uses `npx tsx` unnecessarily
### L8. [NEW] `CONTRIBUTING.md` "Pull Requests" section is minimal
Only 5 lines, no mention of tests, linting, commit message conventions, or code style.
### L9. [NEW] `README.md` missing "Test" section
No mention of `npm test` or test coverage in the README.
### L10. [NEW] `vitest.config.ts` has no coverage configuration
**File:** `ts-demo/vitest.config.ts`
`package.json` has `"test:coverage": "vitest run --coverage"` and `@vitest/coverage-v8` is in devDependencies, but vitest config has no coverage thresholds or reporting configuration. Coverage will run but not enforce any minimum.
### L11. [NEW] `liveProcessJob` fixture has `agent: "unknown"` but scanner.ts:62 would produce `"manual"`
**File:** `ts-demo/src/fixtures.ts:86`
The fixture data claims `agent: "unknown"` but the `inferAgent()` function in `scanner.ts:62` returns `"manual"` as the fallback. This means the fixture does not accurately represent what the scanner produces.

---

## Test Coverage Assessment

### Current State

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `utils.test.ts` | 15 | 15 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor` |
| `job-table.test.tsx` | 17 | 17 | 0 | `TableHeader`, `JobRow`, column alignment, snapshot |
| `detect.test.ts` | 12 | 0 | 12 | `detect()` function -- ALL FAIL |
| **Total** | **44** | **32** | **12** | |

### Pass rate: 73% (32/44)

### What is tested
- **utils.ts:** Fully covered. All 4 exported functions have comprehensive tests including edge cases (null, invalid date, empty string, JSON residue truncation).
- **job-table.tsx:** Good visual regression tests. Snapshot tests, column alignment documentation, status icon rendering, selection indicators. Bug-baseline tests document known rendering issues.
- **fixtures.ts:** Well-designed fixtures covering normal jobs, unfriendly names, JSON residue, long names, live processes, error states.

### What is NOT tested
- **detect.ts:** 0% effective coverage. All 12 tests fail. The export `detect()` is not importable due to module-level `main()`.
- **setup.ts:** 0%. No tests for `setup()` or `teardown()`. These write to `~/.claude/settings.json`.
- **scanner.ts:** 0%. No tests for `scanLiveProcesses()` or `scanClaudeScheduledTasks()`.
- **loader.ts:** 0%. No tests for `loadAllJobs()` or `watchJobsFile()`.
- **app.tsx:** 0%. No integration/render tests for the main App component.
- **cli/index.ts:** 0%. No tests for command routing.

### Estimated effective code coverage: ~15-20%
Only `utils.ts` and `components/job-table.tsx` are meaningfully tested. The critical code paths (detection engine, hook setup, live scanning, job loading) have zero working tests.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | YES | Comprehensive BASH_PATTERNS |
| Hook auto-installation (`setup`) | YES | Atomic write now |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | YES | Inline expansion, round border |
| Live process scanning (lsof) | YES | Works but blocks event loop |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| File watching (both files) | YES | New in v004 -- watches both `jobs.json` and `scheduled_tasks.json` |
| Onboarding empty state | YES | New in v004 -- shows "Get started" guide |
| `--version` | YES | New in v004 -- but hardcoded |
| LaunchAgent scanner | NO | Primary gap |
| Registration time in table | NO | `created_at` only in detail panel |
| History view in detail panel | NO | No run history data model |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | YES | |
| npm publish ready | PARTIAL | Nested in `ts-demo/` |
| `postinstall`/`preuninstall` | YES | |
| `.gitignore` | YES | |
| Tests (passing) | PARTIAL | 32/44 pass; 12 fail; ~15% effective coverage |
| README | YES | New in v004 |
| LICENSE file | YES | New in v004 |
| CONTRIBUTING.md | YES | New in v004 |
| CI/CD | NO | |
| `agent-jobs doctor` | NO | |

---

## Progress Tracking

| v001 Issue | v002 | v003 | v004 | Notes |
|------------|------|------|------|-------|
| C1. bin->ts | OPEN | FIXED | FIXED | |
| C2. Go binary | OPEN | OPEN | OPEN | 4.9MB arm64 Mach-O |
| C3. No .gitignore | OPEN | FIXED | FIXED | |
| C4. No stdin echo | FIXED | FIXED | FIXED | |
| C5. No postinstall | OPEN | FIXED | FIXED | |
| C6. Package name | OPEN | FIXED | FIXED | |
| H1. Demo dirs | OPEN | OPEN | OPEN | |
| H2. No launchd scanner | OPEN | OPEN | OPEN | |
| H3. npx tsx hook | OPEN | FIXED | FIXED | |
| H4. No tests | OPEN | OPEN | PARTIAL | 32/44 pass, 12 fail |
| H5. Sync lsof | OPEN | OPEN | OPEN | |
| H6. Race condition | OPEN | OPEN | OPEN | |
| H7. Broad patterns | OPEN | OPEN | OPEN | |
| v003-C3. Atomic settings | NEW | -- | FIXED | |
| v003-M2. Tab conflation | NEW | -- | FIXED | |
| v003-M4. Empty state | NEW | -- | FIXED | |
| v003-M5. Watch both | NEW | -- | FIXED | |
| v003-M8. Operator prec. | NEW | -- | FIXED | |
| v003-L6. No --version | NEW | -- | FIXED | |

**Issues resolved this round:** 7 (v003-C3, v003-H1 partial, v003-M2, v003-M4, v003-M5, v003-M8, v003-L6)
**New issues found:** C3-C4 (critical), H8-H9 (high), M7-M12 (medium), L8-L11 (low) = 14 new issues
**Regressions:** 0

---

## Actionable Next Steps (prioritized)

### Tier 1: Must do before first commit (blockers)
1. **[5 min] Delete legacy directories** -- `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` to remove the 4.9MB binary
2. **[10 min] Move `ts-demo/` to repo root** -- `mv ts-demo/* ts-demo/.* . && rmdir ts-demo/`. Update README/CONTRIBUTING dev instructions accordingly
3. **[30 min] Fix `detect.ts` module structure** -- separate `detect()` library code from `main()` CLI entry point so the detection engine is testable. Move `main()` behind `import.meta.url` guard or into a separate `detect-cli.ts`. This unblocks all 12 failing tests
4. **[15 min] Fix detect.test.ts assertions** -- after fixing the import, change `expect(typeof result).toBe("boolean")` to actual value assertions. Mock the jobs registry (fs writes) to prevent tests from writing to disk
5. **[5 min] Fix comment/code mismatch** -- `app.tsx:68` change "15 seconds" to "10 seconds"
6. **[5 min] Fix version to read from package.json** -- `cli/index.ts:76`

### Tier 2: Should do before publish
7. **[5 min] Use tsup `banner` for shebang** -- replace fragile inline script. Remove source-level shebangs from `.ts` files
8. **[10 min] Fix README/CONTRIBUTING dev instructions** -- currently wrong (missing `cd ts-demo`)
9. **[10 min] Add `npm test` to CONTRIBUTING PR checklist** and add test section to README
10. **[15 min] Consolidate `JobsFile` type** -- single definition in `types.ts`, import in `detect.ts`
11. **[30 min] Make lsof scan async** -- `execFile` callback or `spawn`
12. **[15 min] Add `created_at` column to main table** -- per review criteria

### Tier 3: Polish for quality open-source release
13. **[1 hr] Write tests for `setup.ts`** -- mock settings file, test install/teardown/idempotency
14. **[1 hr] Write tests for `scanner.ts`** -- mock `execFileSync`/`execSync`, test `parseLsofOutput` directly
15. **[30 min] Fix job-table column widths** -- total exceeds 80 cols, causing wrapping in test render
16. **[2 hr] Implement LaunchAgent scanner**
17. **[30 min] Add vitest coverage thresholds** in vitest.config.ts
18. **[5 min] Fix fixture `agent: "unknown"` to `agent: "manual"`**

---

## Summary

v004 is a meaningful step toward publishability. The addition of README, LICENSE, CONTRIBUTING, test infrastructure, and several bug fixes shows clear momentum. The project now has documentation, a clear install story, and a test framework.

However, the most critical finding this round is that **100% of the detection engine tests fail**. The `detect.test.ts` file exists and looks thorough at a glance, but every single test throws `TypeError: detect is not a function` because `detect.ts` calls `main()` at module scope, making it impossible to import the `detect()` export cleanly. This is a structural problem that requires splitting the module.

Additionally, the tests that do exist for `detect.test.ts` have weak assertions (`typeof result === "boolean"`) that would not catch regressions even if they ran.

The remaining blockers are:
1. **Repo structure** -- legacy directories and `ts-demo/` nesting (unchanged from v001)
2. **Broken tests** -- 12/44 tests fail, effective coverage ~15-20%
3. **Sync blocking** -- `execFileSync` still freezes TUI every 10 seconds
4. **README/CONTRIBUTING accuracy** -- dev instructions reference wrong directory

The project has gone from "installs and works" (v003) to "has docs and tests that partially work" (v004). The next milestone is "tests actually pass, repo is clean, ready for first public commit."
