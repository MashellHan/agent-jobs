# Agent Jobs Review -- v005
**Date:** 2026-04-11T01:23:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit -- all new work is uncommitted)
**Files scanned:** 17 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md
**Previous review:** v004 (2026-04-11T01:15:00Z, score 62/100)
**.implementation/ status:** Directory exists but is EMPTY -- no design docs from the implementation agent.

## Overall Score: 76/100

+14 from v004. Major improvements this round: the `detect.ts` module-level `main()` call is now behind an `import.meta.url` guard, making `detect()` properly importable by tests. All 48 tests pass (0 failures). The detect test suite has been rewritten with proper fs mocks and concrete value assertions. The `--version` command now reads dynamically from `package.json` via `createRequire`. tsup config uses `banner` for shebangs. The `scanner.ts` has been fully refactored to use async `execFile` instead of sync `execFileSync`. The fixture `liveProcessJob.agent` is corrected to `"manual"`.

---

## Category Scores

| Category | Score | v004 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 26 | 20 | +6 | GREEN |
| Architecture (20pts) | 14 | 11 | +3 | YELLOW |
| Production-readiness (20pts) | 16 | 12 | +4 | GREEN |
| Open-source quality (15pts) | 12 | 12 | -- | GREEN |
| Security (15pts) | 8 | 7 | +1 | YELLOW |
| **TOTAL** | **76** | **62** | **+14** | |

---

## Diff Since Last Review (v004)

### Fixed

| v004 ID | Description | Resolution |
|---------|-------------|------------|
| C3 | All 12 detect tests fail -- `detect is not a function` because `main()` runs on import | FIXED. `detect.ts:302-308` now guards `main()` behind `if (isDirectRun)` using `import.meta.url` comparison. Import no longer triggers `main()`. All 16 detect tests pass. |
| C4 | `--version` hardcoded as `v1.0.0` | FIXED. `cli/index.ts:67-72` now uses `createRequire(import.meta.url)` to dynamically read `package.json` version. |
| H1 | `scanLiveProcesses()` uses sync `execFileSync` blocking event loop | FIXED. `scanner.ts:90-133` now uses async `execFile` wrapped in a Promise. No more event loop blocking. |
| H6 | Build script shebang injection is fragile inline script | FIXED. `tsup.config.ts:17-19` now uses `banner: { js: "#!/usr/bin/env node" }`. |
| H8 | `detect.test.ts` mocking strategy fundamentally broken | FIXED. Test now uses `vi.mock("fs")` with proper mock implementations for `existsSync`, `readFileSync`, `writeFileSync`, `mkdirSync`, `renameSync`. Tests import `detect` cleanly and run with real assertions. |
| H9 | `job-table.test.tsx` uses assertion-weakening bug baselines | PARTIALLY FIXED. The tests still document rendering bugs in comments, but the core assertions now actually verify expected values. The column-wrapping bug comments remain (see M6 below). |
| M7 | Weak assertions: `expect(typeof result).toBe("boolean")` | FIXED. All detect tests now assert concrete `true`/`false` values (e.g., `expect(result).toBe(true)`). Added 4 new test cases (16 total, up from 12). |
| L11 | `liveProcessJob` fixture has `agent: "unknown"` but scanner returns `"manual"` | FIXED. `fixtures.ts:84` now reads `agent: "manual"`. |

### Not Fixed (carried from v004)

| v004 ID | Status | Notes |
|---------|--------|-------|
| C1 | OPEN | Go binary (5.1MB) still in `agent-jobs/` directory |
| C2 | OPEN | Project still nested in `ts-demo/` -- not publishable from root |
| H2 | OPEN | Registry write race condition (no locking) |
| H3 | OPEN | No LaunchAgent scanner |
| H4 | OPEN | `detect.ts` reads stdin with `readFileSync(0)` instead of streams |
| H5 | OPEN | tsup config missing `dts: true` -- no type declarations emitted |
| H7 | OPEN | `loader.ts` calls sync-signature functions inside async wrapper (though scanner.ts is now async, the `loadRegisteredJobs` still wraps `readFile` callback in Promise) |
| M1 | OPEN | Comment says 15s, code uses 10s (see below -- actually now fixed by omission, comment removed) |
| M2 | OPEN | `JobsFile` type still semantically inconsistent between `detect.ts` import and usage |
| M3 | OPEN | Dedup uses `name` not richer key |
| M4 | OPEN | `postinstall` runs before build in development |
| M5 | OPEN | `setup.ts` doesn't validate settings JSON structure |
| M6 | OPEN | Source-level shebangs in `.ts` files (though tsup banner now handles build output) |
| M8 | OPEN | `CONTRIBUTING.md` says `cd agent-jobs` but project is in `ts-demo/` |
| M9 | OPEN | `README.md` dev instructions incomplete -- no `cd ts-demo` |
| M10 | OPEN | `CONTRIBUTING.md` does not mention `npm test` |
| M11 | OPEN | No `created_at` / registration time in the main table |
| M12 | OPEN | Detail panel lacks history view |
| L1 | OPEN | Monotone magenta color scheme |
| L3 | OPEN | Detail view lacks log paths |
| L4 | OPEN | `shared/jobs.json` hardcoded paths |
| L5 | OPEN | List command reimplements job loading |
| L6 | OPEN | `index.tsx` is a 2-line file |
| L7 | OPEN | `dev` script uses `npx tsx` -- minor, acceptable |
| L8 | OPEN | `CONTRIBUTING.md` PR section minimal |
| L9 | OPEN | `README.md` missing test section |
| L10 | OPEN | `vitest.config.ts` has no coverage thresholds |

### Status corrections from v004

| v004 ID | Correction |
|---------|-----------|
| M1 | The comment/code mismatch (`app.tsx:68`) appears resolved. Line 68-70 now reads `// Auto-refresh live processes every 10 seconds` followed by `setInterval(refresh, 10_000)`. The comment matches the code. Marking FIXED. |
| H7 | `loader.ts` `loadRegisteredJobs` uses callback-based `readFile` (async) but still wraps it in a manual Promise. This is acceptable -- no sync blocking. However the pattern is verbose. Downgrading from HIGH to MEDIUM. |
| H5 | tsup config still has no `dts: true`. However, `tsconfig.json:12` has `"declaration": true` -- but tsup ignores tsconfig's declaration setting. tsup needs its own `dts: true`. Keeping HIGH. |

---

## New Issues Found in v005

### C1. [CARRIED] Go binary in source tree (5.1MB)
**File:** `agent-jobs/agent-jobs` -- Mach-O 64-bit arm64 executable
**Severity:** CRITICAL
Unchanged since v001. Still the single largest blocker for git commit. 5.1MB binary permanently bloats git history once committed.

**Fix:** `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` before any commit.

### C2. [CARRIED] Project nested inside `ts-demo/`
**File:** entire project lives under `ts-demo/`
**Severity:** CRITICAL
Unchanged since v001. Running `npm install -g .` from the repo root will fail. The package.json, README, LICENSE, CONTRIBUTING all live inside `ts-demo/` while the repo root contains `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/`.

**Fix:** Move `ts-demo/*` to repo root and delete legacy directories.

### H1. [NEW] tsup `banner` adds shebang to ALL entry points including `index.tsx`
**File:** `ts-demo/tsup.config.ts:17-19`
```typescript
banner: {
  js: "#!/usr/bin/env node",
},
```
**Severity:** HIGH
The tsup banner configuration applies `#!/usr/bin/env node` to every output chunk. This includes `dist/index.js` (the TUI render entry), which does not need a shebang and is imported by `cli/index.ts` via `import("../index.js")`. While Node.js tolerates shebangs, a library consumer importing `index.js` would get a file starting with a shebang -- an unusual and rough edge.

Additionally, with `splitting: true`, tsup may create shared chunks. All chunks get the shebang prefix.

**Fix:** Use per-entry point shebang injection. Remove the global `banner` and use tsup's `esbuildOptions` with `banner` filtering, or create a postbuild script that only adds shebangs to `cli/index.js` and `cli/detect.js`. Alternatively, since tsup 8 supports `entry`-level config:
```typescript
export default defineConfig([
  {
    entry: { "cli/index": "src/cli/index.ts", "cli/detect": "src/cli/detect.ts" },
    format: "esm", target: "node18", platform: "node",
    banner: { js: "#!/usr/bin/env node" },
    // ... other options
  },
  {
    entry: { index: "src/index.tsx" },
    format: "esm", target: "node18", platform: "node",
    // no banner
    // ... other options
  },
]);
```

### H2. [CARRIED] Registry write race condition
**File:** `ts-demo/src/cli/detect.ts:130-148`
**Severity:** HIGH
`loadJobs()` + modify + `saveJobs()` is not atomic as a pair. If two hooks fire simultaneously (e.g., Claude Code writes a plist then runs launchctl in quick succession), both read the same file, and the second write overwrites the first job registration.

**Fix:** Use file locking (`proper-lockfile`, `lockfile`, or `flock`-based approach), or use an append-only log that the TUI merges on read.

### H3. [CARRIED] No LaunchAgent scanner
**Severity:** HIGH
The hook detects `launchctl load` but the TUI cannot show live launchd service status. The data model includes `source: "launchd"` but nothing populates it.

### H4. [CARRIED] `detect.ts` reads stdin with `readFileSync(0)`
**File:** `ts-demo/src/cli/detect.ts:277`
**Severity:** HIGH
Non-standard stdin reading. If stdin is a TTY (no pipe), this blocks forever. The `try/catch` mitigates crashes, but it is not a clean approach for a hook that receives piped JSON.

**Fix:** Use `process.stdin` stream or `readline` with a timeout.

### H5. [CARRIED] tsup config missing `dts: true`
**File:** `ts-demo/tsup.config.ts`
**Severity:** HIGH
No type declarations emitted in the build output. Although `tsconfig.json` has `"declaration": true`, tsup does not use tsconfig's declaration setting -- it needs `dts: true` in its own config. Anyone importing `agent-jobs` as a library gets no TypeScript types.

### H6. [NEW] Source-level shebangs in `.ts` files AND tsup banner = double shebangs risk
**File:** `ts-demo/src/cli/detect.ts:1` and `ts-demo/src/cli/index.ts:1`
**Severity:** MEDIUM (elevated context)

Actually checking the file contents: detect.ts line 1 is a JSDoc comment `/**`, and index.ts line 1 is also a JSDoc comment `/**`. The source-level shebangs from v003 have been removed. tsup banner now handles it.

**Status:** FIXED from source, but see H1 about banner applying to all chunks.

### H7. [NEW] `detect.test.ts` mocks `existsSync` to return `false` globally -- registerJob always writes a fresh file
**File:** `ts-demo/src/detect.test.ts:9`
```typescript
existsSync: vi.fn(() => false),
```
**Severity:** MEDIUM
Every call to `detect()` that matches a pattern calls `registerJob() -> loadJobs() -> existsSync(JOBS_PATH) -> false -> returns { version: "1.0", jobs: [] }`. This means the dedup check (`file.jobs.some(j => j.name === label)`) in `registerJob` always sees an empty jobs array. The tests PASS but do not verify dedup behavior.

If a test called `detect()` twice with the same pattern, the second call would also return `true` (should return `false` due to dedup). This is a gap: the test does not use `beforeEach` to reset mock state across dedup scenarios.

**Fix:** Add at least one test: call `detect()` twice with the same input. On the first call, mock `existsSync` to return `false` (new file). On the second call, mock `readFileSync` to return the JSON from the first `writeFileSync` call. Assert second `detect()` returns `false`.

### H8. [NEW] `pm2 start api.js` test -- registerJob writes to disk via mocked fs, but port extraction returns undefined
**File:** `ts-demo/src/detect.test.ts:26-33`
**Severity:** LOW (correctness-wise sound, coverage gap)
The test verifies `detect()` returns `true` for `pm2 start api.js`. What it does NOT verify:
- The registered job name is `"pm2 api.js"`
- The registered job port is `undefined` (no --port flag, no server output)
- The registered job source is `"hook-bash"`

To verify what was actually written, the test could examine the `writeFileSync` mock's `calls` to validate the JSON payload.

**Fix:** Add assertions on `writeFileSync` mock to verify the job record content, at least for one positive-match test case.

---

## Medium Priority (nice to have)

### M1. [FIXED] Comment says 15s, code uses 10s
**File:** `ts-demo/src/app.tsx:68-70`
**Status:** FIXED. Comment now reads "Auto-refresh live processes every 10 seconds" and code uses `10_000`.

### M2. [CARRIED] `JobsFile` type usage inconsistency
**File:** `ts-demo/src/cli/detect.ts:16` imports `JobsFile` from `../types.js`
**Severity:** MEDIUM
`detect.ts` now correctly imports `JobsFile` from `types.ts`. However, `types.ts:24` defines `JobsFile.jobs` as `Array<Omit<Job, "source">>`, while `registerJob` in `detect.ts:180-194` pushes a record with no `source` field -- which is correct per the Omit type. But `registerJob` pushes fields like `port`, `pid`, `created_at` etc. that are required by `Job` but might be `undefined` in the Omit type. If TypeScript strict mode catches this, good; if not, the runtime behavior could produce inconsistent `jobs.json`.

Actually analyzing more carefully: `Omit<Job, "source">` includes all fields of `Job` except `source`. The push at line 180-194 does not include `source`, so this is correct. The `port` field is optional in `Job` (`port?: number`), so this works. This issue is lower severity than initially assessed.

**Revised severity:** LOW. The import is correct.

### M3. [CARRIED] Dedup uses `name` not richer key
**File:** `ts-demo/src/cli/detect.ts:175`
**Severity:** MEDIUM
Two different services with the same name (e.g., two different `flask-server` instances on different ports) will be deduped incorrectly. The dedup should use a composite key like `name + port` or `name + project`.

### M4. [CARRIED] `postinstall` runs before build in development
**File:** `ts-demo/package.json:19`
**Severity:** MEDIUM
`"postinstall": "node dist/cli/index.js setup || true"` -- when cloning and running `npm install`, `dist/` doesn't exist yet. The `|| true` suppresses the error but leaves the hook uninstalled. This is a poor developer experience: the contributing guide says `npm install` but the hook is silently not installed.

### M5. [CARRIED] `setup.ts` doesn't validate settings JSON structure
**File:** `ts-demo/src/cli/setup.ts:48`
**Severity:** MEDIUM
`loadSettings()` does `JSON.parse` and trusts the result is a `Settings` object. If `~/.claude/settings.json` is malformed or has unexpected structure, the `hasHook` function might crash on `hooks.some()`.

### M6. [CARRIED] job-table.test.tsx documents column-wrapping bug
**File:** `ts-demo/src/job-table.test.tsx:45-48, 149-154`
**Severity:** MEDIUM
Tests still contain comments like `// BUG: "registered" gets split across lines` and use `expect(frame).toContain("registere")` (partial match). The underlying column width issue (total 125 chars vs 80-col ink test width) is not fixed. The tests document the bug rather than asserting correct behavior.

### M7. [CARRIED] `CONTRIBUTING.md` says `cd agent-jobs` but project is in `ts-demo/`
**File:** `ts-demo/CONTRIBUTING.md:7`
**Severity:** MEDIUM
After clone, `npm install` at repo root fails because `package.json` is in `ts-demo/`.

### M8. [CARRIED] `README.md` dev instructions incomplete -- no `cd ts-demo`
**File:** `ts-demo/README.md:88-89`
**Severity:** MEDIUM
Same as M7.

### M9. [CARRIED] `CONTRIBUTING.md` does not mention running tests
**File:** `ts-demo/CONTRIBUTING.md:36-40`
**Severity:** MEDIUM
PR checklist says "Run `npm run build` to verify" but does not mention `npm test`.

### M10. [CARRIED] No `created_at` / registration time in the main table
**Severity:** MEDIUM
Per review criteria: "Job registration time should be visible in the main table." Currently shown only in detail panel.

### M11. [CARRIED] Detail panel lacks history view
**Severity:** MEDIUM
Per review criteria: "Detail panel should include friendly history view." Only static fields shown. No run history or timestamps of past events.

### M12. [NEW] `detect.ts:303-305` -- `isDirectRun` guard has fragility
**File:** `ts-demo/src/cli/detect.ts:303-305`
```typescript
const isDirectRun =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith("detect.js");
```
**Severity:** MEDIUM
Two issues:
1. `process.argv[1]` may contain URL-encoded characters (spaces, unicode). The raw string comparison `file://${process.argv[1]}` fails if the path has spaces. Should use `import("url").pathToFileURL(process.argv[1]).href`.
2. The fallback `process.argv[1]?.endsWith("detect.js")` is overly broad -- any script named `detect.js` would trigger `main()`, not just this one. This could cause issues if the module is imported by another tool that happens to be named `detect.js`.

**Fix:**
```typescript
import { pathToFileURL } from "url";
const isDirectRun =
  process.argv[1] != null &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
```

### M13. [NEW] `cli/index.ts` uses dynamic import for `detect` command -- module-level guard may not trigger
**File:** `ts-demo/src/cli/index.ts:27`
```typescript
case "detect":
  import("./detect.js");
  break;
```
**Severity:** MEDIUM
When `agent-jobs detect` is called, `cli/index.ts` is the entry point (`process.argv[1]`). The dynamic `import("./detect.js")` loads `detect.ts`, where the `isDirectRun` guard checks if `process.argv[1]?.endsWith("detect.js")`. But `process.argv[1]` would be something like `/path/to/dist/cli/index.js`, not `detect.js`. So the guard check `process.argv[1]?.endsWith("detect.js")` returns `false`, and `import.meta.url === file://${process.argv[1]}` also fails because `import.meta.url` points to `detect.js` while `process.argv[1]` points to `index.js`.

This means `main()` never executes when using `agent-jobs detect`.

**Wait** -- let me re-examine. In the tsup build with `splitting: true`, the built `detect.js` has its own `import.meta.url` that will be the detect chunk. And `process.argv[1]` will be `dist/cli/index.js`. So neither condition matches:
- `import.meta.url === file://dist/cli/index.js` -> NO (import.meta.url is for detect.js)
- `process.argv[1]?.endsWith("detect.js")` -> NO (it's index.js)

**This means the `agent-jobs detect` command does nothing.** The import resolves the module, the guard prevents `main()` from running, and the `break` exits the switch. stdin is never read. This is a **regression** introduced by the guard fix for C3.

**Revised severity:** CRITICAL -> re-labeled as C3 below.

### C3. [NEW, REGRESSION] `agent-jobs detect` command does nothing due to `isDirectRun` guard
**File:** `ts-demo/src/cli/index.ts:26-28` + `ts-demo/src/cli/detect.ts:302-308`
**Severity:** CRITICAL
The `import.meta.url` guard that fixed the test import issue (v004 C3) now prevents `main()` from running when `detect.ts` is dynamically imported by `cli/index.ts`. Since `process.argv[1]` points to `cli/index.js` (not `detect.js`), neither guard condition is true.

The entire detection pipeline -- the core feature of the project -- is broken for the `agent-jobs detect` CLI command.

**Fix:** Two approaches:
1. **Recommended:** Export `main()` from `detect.ts` and call it explicitly in `cli/index.ts`:
   ```typescript
   case "detect": {
     const { main } = await import("./detect.js");
     main();
     break;
   }
   ```
   This keeps the guard for direct execution while allowing `cli/index.ts` to call it explicitly.
2. Update the guard to also check `process.argv[2] === "detect"` (less clean).

### C4. [NEW] tsup `banner` shebang on all chunks causes parse issues in shared modules
**File:** `ts-demo/tsup.config.ts:14,17-19`
```typescript
splitting: true,
// ...
banner: {
  js: "#!/usr/bin/env node",
},
```
**Severity:** HIGH (downgrade from CRITICAL -- Node.js tolerates shebangs but browsers/bundlers may not)
With `splitting: true`, tsup creates shared code chunks in `dist/`. These shared chunks also get the `#!/usr/bin/env node` shebang. If any downstream tool or bundler processes these chunks, the shebang will cause parse errors.

---

## Low Priority (polish)

### L1. [CARRIED] Monotone magenta color scheme
### L2. [CARRIED] Detail view lacks log paths (stdout/stderr)
### L3. [CARRIED] `shared/jobs.json` hardcoded paths in legacy directories
### L4. [CARRIED] List command reimplements job loading
### L5. [CARRIED] `index.tsx` is a 2-line file
### L6. [CARRIED] `dev` script uses `tsx`
### L7. [CARRIED] `CONTRIBUTING.md` PR section minimal
### L8. [CARRIED] `README.md` missing test section
### L9. [CARRIED] `vitest.config.ts` has no coverage thresholds
### L10. [NEW] `detect.ts:182` uses `Date.now()` for job ID -- not collision-safe
**File:** `ts-demo/src/cli/detect.ts:182`
```typescript
id: `hook-${Date.now()}`,
```
If two services are detected within the same millisecond, they get the same ID. Use `crypto.randomUUID()` or `hook-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`.

### L11. [NEW] `detect.ts:183` truncates description to 200 chars but `scanner.ts:111` truncates to 120 chars
**File:** `detect.ts:183` vs `scanner.ts:111`
Inconsistent truncation limits for the same field. Should use a shared constant.

---

## Test Coverage Assessment

### Current State

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `utils.test.ts` | 15 | 15 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor` |
| `job-table.test.tsx` | 17 | 17 | 0 | `TableHeader`, `JobRow`, column alignment, snapshot |
| `detect.test.ts` | 16 | 16 | 0 | `detect()` -- bash patterns, file patterns, tool filtering |
| **Total** | **48** | **48** | **0** | |

### Pass rate: 100% (48/48) -- up from 73% (32/44) in v004

### What is tested (well)
- **utils.ts:** Fully covered. All 4 exported functions, edge cases, JSON residue truncation.
- **job-table.tsx:** Visual regression tests, snapshot tests, status icons, selection indicators, name truncation, live source rendering.
- **detect.ts `detect()` function:** All 14 BASH_PATTERNS covered (pm2, nohup, docker, systemctl, launchctl, docker-compose, flask, node +server-output). File patterns covered (.plist, docker-compose.yml, .service). Tool filtering (Read ignored, no tool_name ignored). Negative cases covered.
- **fixtures.ts:** Well-designed, covers all job states.

### What is tested (with caveats)
- **detect.ts registerJob/dedup:** The mock always returns an empty jobs file, so dedup is never actually tested. A duplicate-detection test is missing.
- **detect.ts extractPort:** Port extraction is exercised indirectly through `detect()`, but no direct unit tests for `extractPort()` exist.
- **job-table.tsx:** Some tests document known column-wrapping bugs rather than asserting correct behavior.

### What is NOT tested
- **setup.ts:** 0%. No tests for `setup()` or `teardown()`. These write to `~/.claude/settings.json`.
- **scanner.ts:** 0%. No tests for `scanLiveProcesses()`, `scanClaudeScheduledTasks()`, `parseLsofOutput()`, `inferAgent()`, `friendlyLiveName()`.
- **loader.ts:** 0%. No tests for `loadAllJobs()` or `watchJobsFile()`.
- **app.tsx:** 0%. No integration/render tests for the main App component.
- **cli/index.ts:** 0%. No tests for command routing.
- **header.tsx, tab-bar.tsx, footer.tsx, job-detail.tsx:** 0%.

### Estimated effective code coverage: ~30-35%
Up from ~15-20% in v004. The detect engine -- the most critical code path -- is now properly tested. However, scanner, loader, setup, and all component (except job-table) are uncovered.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | BROKEN | detect() works in unit tests, but `agent-jobs detect` CLI command fails due to isDirectRun guard regression (C3) |
| Hook auto-installation (`setup`) | YES | Atomic write, idempotent |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | YES | Inline expansion, round border |
| Live process scanning (lsof) | YES | Now async via execFile |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| File watching (both files) | YES | Watches `jobs.json` and `scheduled_tasks.json` |
| Onboarding empty state | YES | Shows "Get started" guide |
| `--version` | YES | Reads from package.json dynamically |
| LaunchAgent scanner | NO | Primary gap |
| Registration time in table | NO | `created_at` only in detail panel |
| History view in detail panel | NO | No run history data model |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | PARTIAL | Works but shebang on all chunks |
| npm publish ready | PARTIAL | Nested in `ts-demo/` |
| `postinstall`/`preuninstall` | YES | |
| `.gitignore` | YES | |
| Tests (passing) | YES | 48/48 pass |
| Tests (coverage) | PARTIAL | ~30-35% estimated, no thresholds |
| README | YES | Missing test instructions, wrong dev path |
| LICENSE file | YES | MIT |
| CONTRIBUTING.md | YES | Missing test mention, wrong dev path |
| CI/CD | NO | |
| `agent-jobs doctor` | NO | |

---

## Progress Tracking

| v001 Issue | v002 | v003 | v004 | v005 | Notes |
|------------|------|------|------|------|-------|
| C1. bin->ts | OPEN | FIXED | FIXED | FIXED | |
| C2. Go binary | OPEN | OPEN | OPEN | OPEN | 5.1MB arm64 Mach-O |
| C3. No .gitignore | OPEN | FIXED | FIXED | FIXED | |
| C4. No stdin echo | FIXED | FIXED | FIXED | FIXED | |
| C5. No postinstall | OPEN | FIXED | FIXED | FIXED | |
| C6. Package name | OPEN | FIXED | FIXED | FIXED | |
| H1. Demo dirs | OPEN | OPEN | OPEN | OPEN | |
| H2. No launchd scanner | OPEN | OPEN | OPEN | OPEN | |
| H3. npx tsx hook | OPEN | FIXED | FIXED | FIXED | |
| H4. No tests | OPEN | OPEN | PARTIAL | FIXED(pass) | 48/48 pass |
| H5. Sync lsof | OPEN | OPEN | OPEN | FIXED | Now async execFile |
| H6. Race condition | OPEN | OPEN | OPEN | OPEN | |
| H7. Broad patterns | OPEN | OPEN | OPEN | OPEN | |
| v004-C3. detect import crash | NEW | -- | -- | FIXED | Guard added, but see regression C3 |
| v004-C4. Hardcoded version | NEW | -- | -- | FIXED | createRequire from package.json |
| v004-H6. Shebang injection | NEW | -- | -- | FIXED | tsup banner (but creates new H1) |
| v004-H8. Test mock broken | NEW | -- | -- | FIXED | Proper vi.mock("fs") |
| v004-M7. Weak assertions | NEW | -- | -- | FIXED | Concrete true/false assertions |
| v004-L11. Fixture agent | NEW | -- | -- | FIXED | Changed to "manual" |

**Issues resolved this round:** 8 (v004-C3, v004-C4, v004-H1, v004-H6, v004-H8, v004-H9 partial, v004-M7, v004-L11)
**New issues found:** C3 (critical regression), C4/H1 (shebang), H6-H8, M12-M13, L10-L11 = 9 new issues
**Regressions:** 1 (C3 -- `agent-jobs detect` broken by the guard that fixed the import issue)

---

## Actionable Next Steps (prioritized)

### Tier 1: Must do before first commit (blockers)

1. **[15 min] Fix `agent-jobs detect` regression (C3)** -- Export `main()` from `detect.ts` and call it explicitly from `cli/index.ts`. This is the most critical issue: the entire detection pipeline is broken.
   ```typescript
   // detect.ts: export main()
   export function main(): void { ... }
   
   // cli/index.ts:
   case "detect": {
     const { main } = await import("./detect.js");
     main();
     break;
   }
   ```

2. **[5 min] Delete legacy directories** -- `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` to remove the 5.1MB binary (C1)

3. **[10 min] Move `ts-demo/` to repo root** -- `mv ts-demo/* ts-demo/.* . && rmdir ts-demo/` (C2). Update README/CONTRIBUTING dev instructions.

4. **[5 min] Fix tsup shebang to apply only to CLI entries (H1)** -- Use array config to separate CLI entries from TUI entry, or switch to a postbuild script.

5. **[5 min] Fix isDirectRun guard path handling (M12)** -- Use `pathToFileURL` instead of string template. Remove the broad `endsWith("detect.js")` fallback.

### Tier 2: Should do before publish

6. **[5 min] Add `dts: true` to tsup.config.ts (H5)** -- Emit type declarations for library consumers.
7. **[10 min] Fix README/CONTRIBUTING dev instructions (M7, M8)** -- Add `cd ts-demo` (or fix after root move).
8. **[5 min] Add `npm test` to CONTRIBUTING PR checklist (M9)** and test section to README (L8).
9. **[15 min] Add dedup test for detect.ts (H7)** -- Call detect twice with same input, verify second returns false.
10. **[10 min] Add `created_at` column to main table (M10)**.
11. **[15 min] Add one assertion-strength test that inspects writeFileSync payload (H8)** -- Verify registered job fields.
12. **[5 min] Use `crypto.randomUUID()` for job IDs (L10)**.

### Tier 3: Polish for quality open-source release

13. **[1 hr] Write tests for `scanner.ts`** -- Mock `execFile`, test `parseLsofOutput`, `inferAgent`, `friendlyLiveName`.
14. **[30 min] Write tests for `setup.ts`** -- Mock settings file, test install/teardown/idempotency.
15. **[30 min] Add vitest coverage thresholds** in vitest.config.ts.
16. **[30 min] Fix job-table column widths** to avoid wrapping in 80-col terminals.
17. **[2 hr] Implement LaunchAgent scanner (H3)**.
18. **[30 min] Add history view to detail panel (M11)**.

---

## Communication

### To the implementation agent:

**CRITICAL REGRESSION -- please prioritize.** The `isDirectRun` guard fix (v004's highest-priority item C3) has successfully fixed the test import issue, but it has created a regression: the `agent-jobs detect` CLI command no longer works. When `cli/index.ts` dynamically imports `detect.js`, neither `isDirectRun` condition evaluates to `true`, so `main()` never runs. This means the entire PostToolUse hook pipeline is dead in production. The fix is straightforward: export `main()` and call it explicitly from the switch case in `cli/index.ts`.

**Good decisions this round:**
- Using `vi.mock("fs")` with the actual module spread is a solid mocking strategy
- Concrete `true`/`false` assertions in detect tests (replacing the hollow `typeof` checks) are a major quality improvement
- The `createRequire` approach for version reading is the correct ESM solution
- Refactoring `scanner.ts` to use async `execFile` removes the worst performance issue (5s TUI freeze)
- The `import.meta.url` guard concept is correct -- the execution just needs to be adjusted for the indirect-import case

**Design questions:**
1. **Where are the implementation docs?** The `.implementation/` directory is empty. Without design docs, the reviewer cannot verify spec conformance. If there is a PRD, architecture doc, or task list, please add them so the review can check alignment.
2. **Why use `readFileSync(0)` for stdin?** Is there a reason not to use async stdin reading via `process.stdin`? The sync approach is unusual for Node.js and makes error handling harder.
3. **Is dedup by name intentional?** Two different services could legitimately have the same display name (e.g., two Flask servers on different ports). A composite key (`name + port` or `name + project`) would prevent legitimate services from being silently dropped.

**The project has improved significantly.** Going from 73% test pass rate to 100%, fixing the sync scanner, and closing the version/shebang issues shows strong momentum. The v005 score of 76/100 reflects a project that works in most cases and has real test coverage. The path to 85+ is: fix the detect regression, clean up the repo structure, and add 2-3 more test files for untested modules.

---

## Summary

v005 marks a substantial jump in code quality. The implementation agent closed 8 issues from v004, including the hardest one (detect.ts testability). All 48 tests now pass. The scanner is async. The version reads from package.json. The tsup config uses banner for shebangs.

However, a critical regression was introduced: the `isDirectRun` guard that fixed test imports also prevents `main()` from running when `detect.ts` is loaded via `cli/index.ts`'s dynamic import. **The core feature of the project -- PostToolUse hook detection -- is broken in production.** This is a 15-minute fix and should be the #1 priority.

The remaining structural blockers (Go binary, nested ts-demo/) are unchanged since v001 and must be resolved before any git commit or npm publish.

**Score trajectory:** 35 (v001) -> 39 (v002) -> 48 (v003) -> 62 (v004) -> 76 (v005)
**Next target:** 85+ after fixing the detect regression, cleaning repo structure, and adding scanner/setup tests.
