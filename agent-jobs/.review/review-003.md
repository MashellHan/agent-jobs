# Agent Jobs Review -- v003
**Date:** 2026-04-11T01:10:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit -- all new work is uncommitted)
**Files scanned:** 14 source files + package.json + tsconfig.json + tsup.config.ts + .gitignore
**Previous review:** v002 (2026-04-11T00:40:00Z, score 30/100)

## Overall Score: 48/100

+18 from v002. Major progress this round: build pipeline is fully wired up (tsup config, build script, shebang injection, dist output), `.gitignore` added, `package.json` overhauled with correct `bin`, `files`, `engines`, `scripts`, `repository`, and `license` fields. The hook command in `setup.ts` now correctly resolves to the compiled `detect.js` next to itself. Package name fixed to `agent-jobs`. Several critical and high-priority blockers from v001/v002 are now resolved.

---

## Category Scores

| Category | Score | v002 | Delta | Status |
|----------|-------|------|-------|--------|
| A. Architecture & Design | 4/10 | 4/10 | -- | RED |
| B. Functionality Completeness | 3/10 | 3/10 | -- | RED |
| C. Code Quality | 6/10 | 5/10 | +1 | YELLOW |
| D. UI/UX | 5/10 | 5/10 | -- | YELLOW |
| E. Performance | 6/10 | 6/10 | -- | YELLOW |
| F. Stability & Error Handling | 6/10 | 5/10 | +1 | YELLOW |
| G. Installation & Distribution | 7/10 | 2/10 | +5 | GREEN |
| H. Git & Open Source Readiness | 3/10 | 1/10 | +2 | RED |
| I. Feature Brainstorm | -- | -- | -- | -- |

---

## Scoring Breakdown (Rubric)

| Rubric Category | Points | Score | Notes |
|-----------------|--------|-------|-------|
| **Correctness (30pts)** | 30 | 18 | Build works, hook detects, TUI renders. But lsof sync blocks event loop, no tests to verify edge cases, race condition on registry writes. |
| **Architecture (20pts)** | 20 | 9 | Clean component split, good separation of detect/setup/app. But project still nested in `ts-demo/`, demo dirs still present, `JobsFile` type duplicated, `list` command reimplements loader logic. |
| **Production-readiness (20pts)** | 20 | 8 | Build pipeline works, postinstall/preuninstall present. Zero tests, no CI, no linting. |
| **Open-source quality (15pts)** | 15 | 6 | package.json metadata is solid (keywords, engines, repository, license). No README, no LICENSE file, no CONTRIBUTING, no CHANGELOG. |
| **Security (15pts)** | 15 | 7 | No secrets in code. Atomic write pattern on jobs.json (good). `setup.ts` writes to user's settings.json without backup. `execSync` for `ps` command does not sanitize PID (integer-only so low risk). |
| **TOTAL** | **100** | **48** | |

---

## Diff Since Last Review (v002)

### Fixed

| v002 ID | Description | Resolution |
|---------|-------------|------------|
| C1 | `bin` points to `.ts` -- npm install broken | FIXED. `package.json:7` now `"./dist/cli/index.js"`. `build` script runs tsup + injects shebang. `dist/cli/index.js` verified to start with `#!/usr/bin/env node`. |
| C3 | No `.gitignore` | FIXED. `.gitignore` added at `ts-demo/.gitignore` covering `node_modules/`, `dist/`, `.DS_Store`, `.env*`, `.review/`, `coverage/`, IDE files. |
| C5 | No `postinstall`/`preuninstall` hooks | FIXED. `package.json:19-20` has `"postinstall": "node dist/cli/index.js setup \|\| true"`, `"preuninstall": "node dist/cli/index.js teardown \|\| true"`. The `\|\| true` prevents install failures if hook setup fails. |
| C6 | Package name mismatch | FIXED. Now `"name": "agent-jobs"` matching the CLI binary name. |
| H3 | Hook command uses `npx tsx` | FIXED. `setup.ts:18-19` now resolves `detect.js` relative to `__dirname` (compiled output), producing `node "/path/to/dist/cli/detect.js"`. No tsx dependency at runtime. |
| H8 | No tsup configuration or build script | FIXED. `tsup.config.ts` added with 3 entry points, ESM format, node18 target, splitting enabled, sourcemaps. `package.json` has `"build": "tsup && <shebang-injector>"`. |
| M1 | Hardcoded separator 120 chars | FIXED. `job-table.tsx:30` now uses `process.stdout.columns` with fallback to 120, capped at 140. |
| L4/M11 | No `--version` | Partially addressed: `help` command exists but no `--version` flag. Still missing. |

### Not Fixed (carried from v002)

| v002 ID | Status | Notes |
|---------|--------|-------|
| C2 | OPEN | Go binary (5.1MB) still in `agent-jobs/` directory |
| C4 | OPEN | `readFileSync(0)` instead of stream -- works but fragile |
| H1 | OPEN | `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/` still present |
| H2 | OPEN | No LaunchAgent scanner |
| H4 | OPEN | Zero tests |
| H5 | OPEN | `scanLiveProcesses()` uses `execFileSync` blocking event loop |
| H6 | OPEN | No file locking on registry read-modify-write |
| H7 | OPEN | Broad node/python patterns |
| H9 | OPEN | `readFileSync(0)` vs stream pattern |
| M2 | OPEN | Comment says 15s, code uses 10s |
| M3 | OPEN | Tab "live" includes "cron" |
| M4 | OPEN | `utils.ts` accepts `string` not typed unions |
| M5 | OPEN | No onboarding empty state |
| M6 | OPEN | `JobsFile` type duplicated between `detect.ts` and `types.ts` |
| M7 | OPEN | Only watches `jobs.json`, not `scheduled_tasks.json` |
| M8 | OPEN | Redundant `index.tsx` entry point |
| M9 | OPEN | Dedup uses `name` not richer key |
| M10 | OPEN | Hardcoded `agent: "claude-code"` |
| L1 | OPEN | Monotone magenta color scheme |
| L2 | OPEN | Footer separator missing |
| L3 | OPEN | Detail view lacks log paths |
| L5 | OPEN | `shared/jobs.json` has hardcoded user paths |
| L6 | OPEN | Top-level await in list command |
| L7 | OPEN | List command reimplements job loading |

---

## Critical Issues (must fix)

### C1. [CARRIED] Go binary in source tree (5.1MB)
**File:** `agent-jobs/agent-jobs` -- Mach-O 64-bit arm64 executable
**Severity:** CRITICAL
This is the largest single blocker for a clean first commit. Once committed, the 5.1MB binary permanently bloats git history. The entire `agent-jobs/` directory (Go code) serves no purpose alongside the TypeScript implementation.

**Fix:** Delete `agent-jobs/`, `go-demo/`, `python-demo/`, `shared/` before any git commit.

### C2. [CARRIED] Project nested inside `ts-demo/` -- not publishable
**File:** `ts-demo/` directory structure
**Severity:** CRITICAL
The npm package lives inside `ts-demo/` but the repo root is `agent-jobs/`. Running `npm publish` from `ts-demo/` would work, but:
- GitHub repo will show `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/` at root -- confusing
- Contributors don't know where the "real" project is
- CI/CD has to `cd ts-demo/` before every command

**Fix:** Move `ts-demo/*` to repo root. Delete all other top-level directories.

### C3. [NEW] `setup.ts` writes settings.json without backup
**File:** `ts-demo/src/cli/setup.ts:52`
**Severity:** CRITICAL
`saveSettings()` calls `writeFileSync(SETTINGS_PATH, ...)` directly. If the write fails mid-operation (disk full, permissions), the user's `~/.claude/settings.json` is corrupted. This is the user's Claude Code configuration -- data loss here is severe.

**Fix:** Use the same atomic write pattern already used in `detect.ts:saveJobs()`: write to temp file, then `renameSync`.

```typescript
function saveSettings(settings: Settings): void {
  const tmpPath = SETTINGS_PATH + `.${process.pid}.tmp`;
  writeFileSync(tmpPath, JSON.stringify(settings, null, 2) + "\n");
  renameSync(tmpPath, SETTINGS_PATH);
}
```

---

## High Priority (should fix)

### H1. [CARRIED] Zero tests
**Severity:** HIGH
No test files anywhere. `detect.ts` is the most critical code path -- false positives register junk, false negatives miss real services. Without tests, any refactor is a gamble.

**Fix:** Add `vitest` to devDependencies and at minimum test:
- `detect()` true positives for each `BASH_PATTERNS` entry
- `detect()` true negatives (simple `ls`, `cat`, etc.)
- `detect()` edge cases (empty input, missing `tool_input`, multiline commands)
- `extractPort()` with various flag positions
- `registerJob()` deduplication
- `setup()`/`teardown()` on mock settings file

### H2. [CARRIED] No LaunchAgent scanner
**Severity:** HIGH
The hook correctly detects when Claude Code creates a LaunchAgent (`launchctl load`), but the TUI has no scanner to show the live status of launchd services. Users register a service via hook but can't see if it's actually running.

### H3. [CARRIED] `scanLiveProcesses()` uses sync `execFileSync`
**File:** `ts-demo/src/scanner.ts:68`
**Severity:** HIGH
`execFileSync("lsof", ...)` blocks the Node.js event loop. During the 5-second timeout, the TUI is completely frozen -- no keyboard input, no rendering. This runs every 10 seconds.

**Fix:** Replace with `execFile` (callback) or `child_process.spawn` with async collection.

### H4. [CARRIED] Registry write race condition
**File:** `ts-demo/src/cli/detect.ts:128-135`
**Severity:** HIGH
The `saveJobs()` function uses atomic rename (good), but `loadJobs()` + `saveJobs()` is not atomic as a pair. Two concurrent hook invocations can:
1. Both read the same `jobs.json`
2. Both add their job
3. Second write overwrites first write, losing the first job

**Fix:** Use `flock` via `fs.openSync()` with exclusive flag, or use a lock file.

### H5. [CARRIED] `detect.ts` reads stdin with `readFileSync(0)`
**File:** `ts-demo/src/cli/detect.ts:264`
**Severity:** HIGH (downgraded from v002's C4)
Works in practice but is the non-standard pattern. The existing Claude Code hooks use `process.stdin.on('data'/'end')`. If Claude Code ever changes hook invocation to keep the pipe open longer, this will hang.

### H6. [NEW] `tsup.config.ts` does not generate `dts` output
**File:** `ts-demo/tsup.config.ts`
**Severity:** HIGH
No `dts: true` in the tsup config. The `tsconfig.json` has `"declaration": true` but tsup ignores that. If anyone imports `agent-jobs` as a library (e.g., to programmatically use `detect()`), they get no type information.

**Fix:** Add `dts: true` to tsup config, or accept this is CLI-only and document it.

### H7. [NEW] Build script shebang injection is fragile
**File:** `ts-demo/package.json:13`
```json
"build": "tsup && node -e \"const fs=require('fs');...\""
```
**Severity:** HIGH
The inline Node script that injects the shebang:
1. Uses `require()` which may fail in ESM-only Node versions
2. Only injects into `dist/cli/index.js`, not `dist/cli/detect.js` (though detect.js already has the shebang from tsup -- need to verify consistency)
3. Is unreadable and unmaintainable as an inline string

**Fix:** Use tsup's built-in `banner` option:
```typescript
export default defineConfig({
  // ...
  banner: { js: '#!/usr/bin/env node' },
});
```
This is cleaner and applies to all entry points.

### H8. [NEW] `loader.ts:12` calls sync functions inside async wrapper
**File:** `ts-demo/src/loader.ts:11-14`
```typescript
loadRegisteredJobs().then((registered) => {
  const live = scanLiveProcesses();     // SYNC - blocks
  const cron = scanClaudeScheduledTasks(); // SYNC - blocks
  resolve([...registered, ...cron, ...live]);
});
```
**Severity:** HIGH
`loadAllJobs()` is nominally async (returns Promise) but `scanLiveProcesses()` inside it is synchronous and blocks. The Promise wrapper gives a false sense of async safety. The TUI calls this every 10 seconds, freezing for up to 5 seconds each time.

---

## Medium Priority (nice to have)

### M1. [CARRIED] Comment says 15s, code uses 10s
**File:** `ts-demo/src/app.tsx:69-70`
Comment: "Auto-refresh live processes every 15 seconds". Code: `setInterval(refresh, 10_000)`.

### M2. [CARRIED] Tab "live" includes "cron"
**File:** `ts-demo/src/app.tsx:19`
```typescript
case "live":
  return jobs.filter((j) => j.source === "live" || j.source === "cron");
```
Confusing -- "live" tab shows cron tasks. Either rename tab to "System" or split into separate tabs.

### M3. [CARRIED] `JobsFile` type duplicated
**File:** `ts-demo/src/cli/detect.ts:112-115` vs `ts-demo/src/types.ts:23-26`
Two different `JobsFile` interfaces. `detect.ts` version has `Array<Record<string, unknown>>`, `types.ts` version has `Array<Omit<Job, "source">>`. They will drift.

### M4. [CARRIED] No onboarding empty state
When no jobs exist and no live processes are found, the dashboard shows "No jobs in this category" -- no guidance on how to get started.

### M5. [CARRIED] Only watches `jobs.json`, not `scheduled_tasks.json`
**File:** `ts-demo/src/loader.ts:47`
Changes to `~/.claude/scheduled_tasks.json` won't trigger a refresh until the next 10-second poll.

### M6. [CARRIED] `utils.ts` functions accept `string` not typed unions
`statusIcon(status: string)` and `resultColor(result: string)` should accept `JobStatus` and `JobResult` respectively.

### M7. [CARRIED] Dedup uses `name` not richer key
**File:** `ts-demo/src/cli/detect.ts:162`
Two different services resolving to the same label will silently deduplicate.

### M8. [NEW] `isAgentJobsHook` has incorrect operator precedence
**File:** `ts-demo/src/cli/setup.ts:56-57`
```typescript
return inner.command.includes(HOOK_TAG) ||
  inner.command.includes("agent-jobs") && inner.command.includes("detect");
```
Due to `&&` binding tighter than `||`, this evaluates as:
```typescript
includes(HOOK_TAG) || (includes("agent-jobs") && includes("detect"))
```
This happens to be the intended behavior, but is fragile and unclear. Should use explicit parentheses.

### M9. [NEW] `postinstall` runs before build in development
**File:** `ts-demo/package.json:19`
```json
"postinstall": "node dist/cli/index.js setup || true"
```
When a developer clones the repo and runs `npm install`, `postinstall` fires before `npm run build`, so `dist/cli/index.js` doesn't exist yet. The `|| true` swallows this error, but it means the hook isn't installed after a fresh clone. The developer must manually run `npm run build && npm run setup`.

**Fix:** Only run postinstall for global installs, or use `prepublishOnly` + check if dist exists.

### M10. [NEW] `setup.ts` doesn't validate existing settings structure
**File:** `ts-demo/src/cli/setup.ts:48`
`JSON.parse(readFileSync(...)) as Settings` does an unchecked cast. If the settings file is malformed (not an object, missing expected structure), the code will throw at `settings.hooks?.PostToolUse` access or silently corrupt the file structure.

### M11. [NEW] `detect.ts` shebang is source-level, not build-level
**File:** `ts-demo/src/cli/detect.ts:1`
Both `detect.ts` and `index.ts` have `#!/usr/bin/env node` in source. This is harmless but technically wrong -- shebangs should only appear in build output. The build script also injects one, potentially creating a double shebang.

---

## Low Priority (polish)

### L1. [CARRIED] Monotone magenta color scheme
### L2. [CARRIED] Footer separator missing -- footer sits directly against last table row
### L3. [CARRIED] Detail view doesn't show log paths (stdout/stderr)
### L4. [CARRIED] `shared/jobs.json` has hardcoded user paths
### L5. [CARRIED] List command reimplements job loading instead of reusing `loader.ts`
### L6. [NEW] No `--version` flag
CLI has `help` command but no `--version` or `version` command. Should read from `package.json`.
### L7. [NEW] `index.tsx` is a 2-line file
**File:** `ts-demo/src/index.tsx`
```typescript
import App from "./app.js";
render(React.createElement(App));
```
Could be inlined into the `dashboard` case in `cli/index.ts`.
### L8. [NEW] `package.json` `dev` script uses `npx tsx`
**File:** `ts-demo/package.json:15`
`"dev": "npx tsx --watch src/index.tsx"` -- `tsx` is a devDependency, so `npx` is unnecessary. Should be just `tsx --watch src/index.tsx`.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | YES | Comprehensive pattern matching for Bash and file ops |
| Hook auto-installation (`setup`) | YES | Correctly injects into `~/.claude/settings.json` |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | YES | Inline expansion |
| Live process scanning (lsof) | YES | Works but sync/blocking |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| LaunchAgent scanner | NO | Primary gap -- can't show launchd service status |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | YES | New in v003 |
| npm publish ready | PARTIAL | `bin`/`files`/`engines` correct but nested in `ts-demo/` |
| `postinstall`/`preuninstall` | YES | New in v003 |
| `.gitignore` | YES | New in v003 |
| Tests | NO | |
| README | NO | |
| LICENSE file | NO | `"license": "MIT"` in package.json but no LICENSE file |
| CI/CD | NO | |
| `--version` | NO | |
| `agent-jobs doctor` | NO | |

---

## Progress Tracking

| v001 Issue | v002 Status | v003 Status | Notes |
|------------|-------------|-------------|-------|
| C1. bin->ts | OPEN | FIXED | tsup build + shebang |
| C2. Go binary | OPEN | OPEN | Still in `agent-jobs/` dir |
| C3. No .gitignore | OPEN | FIXED | Added at `ts-demo/.gitignore` |
| C4. No stdin echo | FIXED | FIXED | Was fixed in v002 |
| C5. No postinstall | OPEN | FIXED | With `\|\| true` fallback |
| C6. Package name | OPEN | FIXED | Now `agent-jobs` |
| H1. Demo dirs | OPEN | OPEN | |
| H2. No launchd scanner | OPEN | OPEN | |
| H3. npx tsx hook | OPEN | FIXED | Now `node detect.js` |
| H4. No tests | OPEN | OPEN | |
| H5. Sync lsof | OPEN | OPEN | |
| H6. Race condition | OPEN | OPEN | atomic rename helps but not sufficient |
| H7. Broad patterns | OPEN | OPEN | |

**Issues introduced:** 0 regressions, 7 new issues found (C3, H6-H8, M8-M11, L6-L8)
**Issues resolved:** 7 (C1, C3, C5, C6, H3, H8-from-v002, M1)

---

## Actionable Next Steps (prioritized)

1. **[5 min] Delete demo directories** -- `rm -rf go-demo/ python-demo/ agent-jobs/ shared/` -- do this first to avoid committing 5.1MB binary
2. **[5 min] Move ts-demo/ to root** -- `mv ts-demo/* ts-demo/.gitignore . && rm -rf ts-demo/`
3. **[5 min] Fix setup.ts atomic write** -- use temp+rename pattern like detect.ts already does
4. **[5 min] Fix tsup banner** -- add `banner: { js: '#!/usr/bin/env node' }` to tsup.config.ts, remove inline shebang script from build command
5. **[5 min] Fix comment** -- change "15 seconds" to "10 seconds" in app.tsx:69
6. **[5 min] Add explicit parens** in `isAgentJobsHook`
7. **[10 min] Add README.md** -- project description, install, usage, screenshots
8. **[5 min] Add LICENSE file** (MIT, matching package.json)
9. **[30 min] Make lsof scan async** -- `execFile` callback or `spawn`
10. **[1 hr] Add detect.ts tests** -- vitest, cover all BASH_PATTERNS and edge cases
11. **[2 hr] Implement LaunchAgent scanner**
12. **[30 min] Add atomic registry locking** -- `open(path, O_EXCL)` or lock file
13. **[5 min] First clean git commit** -- after steps 1-8

---

## Summary

v003 represents meaningful progress. The build pipeline is the single biggest improvement -- the project can now actually be installed via `npm install -g` and produce a working CLI. The package.json metadata is solid. The hook setup correctly resolves compiled output.

The remaining blockers are:
1. **Repo structure** -- demo directories and `ts-demo/` nesting must be cleaned up before the first commit
2. **Settings.json corruption risk** -- `setup.ts` must use atomic writes
3. **Zero tests** -- a single test file for `detect.ts` would dramatically improve confidence
4. **Sync blocking** -- `execFileSync` in the scanner freezes the TUI every 10 seconds

The project has gone from "doesn't install" (v001-v002) to "installs and works" (v003). The next milestone is "safe to commit and share publicly."
