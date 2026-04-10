# Agent Jobs Review -- v006
**Date:** 2026-04-11T01:33:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit -- all new work is uncommitted)
**Files scanned:** 18 source files + package.json + tsconfig.json + tsup.config.ts + vitest.config.ts + README.md + LICENSE + CONTRIBUTING.md
**Previous review:** v005 (2026-04-11T01:23:00Z, score 76/100)
**.implementation/ status:** Directory exists but is EMPTY -- no design docs from the implementation agent.

## Overall Score: 82/100

+6 from v005. Key improvements this round: the CRITICAL `agent-jobs detect` regression (v005-C3) is fully fixed -- `cli/index.ts` now explicitly calls `main()` via `await import("./detect.js")`. The `detect.ts` `isDirectRun` guard now uses `pathToFileURL` (fixing v005-M12). The `main()` function is exported. The tsup config is split into a two-config array, applying the shebang banner only to CLI entries (fixing v005-H1/C4). The `randomUUID` import replaces `Date.now()` for job IDs (fixing v005-L10). Three new tests were added (detect job registration payload, dedup, port extraction), bringing the total to 51. However, the port extraction test is now **failing** (1/51) due to a test isolation bug introduced by the dedup test.

---

## Category Scores

| Category | Score | v005 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 27 | 26 | +1 | GREEN |
| Architecture (20pts) | 16 | 14 | +2 | GREEN |
| Production-readiness (20pts) | 17 | 16 | +1 | GREEN |
| Open-source quality (15pts) | 12 | 12 | -- | GREEN |
| Security (15pts) | 10 | 8 | +2 | GREEN |
| **TOTAL** | **82** | **76** | **+6** | |

---

## Diff Since Last Review (v005)

### Fixed

| v005 ID | Description | Resolution |
|---------|-------------|------------|
| C3 | `agent-jobs detect` command does nothing due to `isDirectRun` guard | **FIXED.** `cli/index.ts:25-28` now uses `const { main } = await import("./detect.js"); main();` to explicitly call the exported `main()` function. The guard no longer blocks CLI operation. |
| H1/C4 | tsup `banner` adds shebang to ALL chunks including `index.tsx` | **FIXED.** `tsup.config.ts` now uses a two-element `defineConfig` array. The first config builds `cli/index` and `cli/detect` with the shebang banner; the second builds `index.tsx` without it. |
| M12 | `isDirectRun` guard uses raw string template instead of `pathToFileURL` | **FIXED.** `detect.ts:17` now imports `pathToFileURL` from `url`, and line 307 uses `import.meta.url === pathToFileURL(process.argv[1]).href`. The overly broad `endsWith("detect.js")` fallback is removed. |
| M13 | `cli/index.ts` dynamic import does not trigger `main()` | **FIXED.** Resolved together with C3. |
| L10 | `Date.now()` for job IDs not collision-safe | **FIXED.** `detect.ts:14` now imports `randomUUID` from `crypto` and line 183 uses `id: \`hook-${randomUUID()}\``. |
| H7 (partial) | No test for dedup behavior | **FIXED.** `detect.test.ts:199-223` adds a proper dedup test: calls `detect()` twice with the same input, mocks `existsSync/readFileSync` for the second call to simulate existing data, asserts the second call returns `false`. |
| H8 (partial) | No assertion on `writeFileSync` payload | **FIXED.** `detect.test.ts:181-197` inspects the `writeFileSync` mock calls, parses the JSON payload, and asserts job name, agent, status, and ID prefix. |

### New Issues (introduced this round)

| ID | Severity | File | Description |
|----|----------|------|-------------|
| C1 | CRITICAL | `detect.test.ts:225-235` | **Port extraction test fails** (1/51). See detailed analysis below. |
| M1 | MEDIUM | `tsup.config.ts:20` | `splitting: true` in CLI config may still produce shared chunks with shebangs. |

### Not Fixed (carried from previous reviews)

| ID | Source | Status | Notes |
|----|--------|--------|-------|
| C-struct-1 | v001 | OPEN | Go binary (4.9MB) still in `agent-jobs/` directory |
| C-struct-2 | v001 | OPEN | Project still nested in `ts-demo/` -- not publishable from root |
| H2 | v004 | OPEN | Registry write race condition (no locking) |
| H3 | v004 | OPEN | No LaunchAgent scanner |
| H4 | v004 | OPEN | `detect.ts` reads stdin with `readFileSync(0)` instead of streams |
| H5 | v004 | OPEN | tsup config missing `dts: true` -- no type declarations emitted |
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

### C1. [NEW, REGRESSION] Port extraction test fails -- test isolation bug

**File:** `ts-demo/src/detect.test.ts:225-235`
**Severity:** CRITICAL (test suite red)
**Test:** `detect - job registration > extracts port from --port flag`
**Error:** `expected undefined to be 5000`

**Root cause analysis:**

The dedup test at line 199-223 modifies the global mock state:
```typescript
vi.mocked(existsSync).mockReturnValue(true);
vi.mocked(readFileSync).mockReturnValue(writtenJson);
```
where `writtenJson` contains a pm2 job with `port: undefined`.

The `beforeEach(() => vi.clearAllMocks())` at line 178 only clears call history, return value history, and instance tracking. It does **not** reset mock implementations set via `mockReturnValue()`. This is a well-documented vitest/jest distinction:

| Method | Clears calls | Resets implementation | Restores original |
|--------|:---:|:---:|:---:|
| `clearAllMocks` | Yes | No | No |
| `resetAllMocks` | Yes | Yes | No |
| `restoreAllMocks` | Yes | Yes | Yes |

When the port extraction test runs after the dedup test:
1. `existsSync` still returns `true` (stale from dedup test)
2. `readFileSync` still returns the pm2 JSON (stale from dedup test)
3. `loadJobs()` parses this JSON and finds one existing job (`pm2 api.js`)
4. `registerJob("flask-server", { port: 5000, ... })` **appends** the flask job at index 1
5. `saveJobs()` writes JSON with two jobs: `[pm2_job, flask_job]`
6. The test asserts `written.jobs[0].port` -- this is the **pm2 job** at index 0 which has `port: undefined`
7. The flask job with `port: 5000` is at index 1

**Fix (two options):**

Option A (minimal): Change `beforeEach` to use `vi.resetAllMocks()` and re-apply the base mock implementations:
```typescript
beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(existsSync).mockReturnValue(false);
  vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
    if (args[0] === 0) return "";
    throw new Error("ENOENT");
  });
  vi.mocked(writeFileSync).mockImplementation(() => {});
  vi.mocked(mkdirSync).mockImplementation(() => undefined);
  vi.mocked(renameSync).mockImplementation(() => {});
});
```

Option B (simpler): Move `vi.clearAllMocks()` to the top-level `beforeEach` outside describes, and add mock state reset:
```typescript
beforeEach(() => {
  vi.mocked(existsSync).mockReturnValue(false);
  vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
    if (args[0] === 0) return "";
    throw new Error("ENOENT");
  });
});
```

This ensures every test starts with clean mock implementations, not just cleared call histories.

### M1. [NEW] `splitting: true` in CLI config may generate shared chunks with shebangs

**File:** `ts-demo/tsup.config.ts:20`
```typescript
{
  ...shared,
  entry: { "cli/index": "src/cli/index.ts", "cli/detect": "src/cli/detect.ts" },
  clean: true,
  splitting: true,
  banner: { js: "#!/usr/bin/env node" },
},
```
**Severity:** MEDIUM
The two CLI entry points share code (both import from `types.ts`, `fs`, etc.). With `splitting: true`, tsup/esbuild may generate shared chunks like `chunk-XXXX.js` in `dist/`. These shared chunks also receive the shebang banner. While Node.js tolerates shebangs in non-entry scripts, this is technically incorrect. The risk is low since the shared chunks are only `import`ed, never executed directly.

**Fix:** Remove `splitting: true` from the CLI config. CLI entry points benefit from bundling all dependencies into single files. Alternatively, use `splitting: false` explicitly.

### H5. [CARRIED] tsup config missing `dts: true`

**File:** `ts-demo/tsup.config.ts`
**Severity:** HIGH
Neither config element includes `dts: true`. No `.d.ts` files are emitted. Anyone importing `agent-jobs` programmatically gets no TypeScript types. The `tsconfig.json` has `"declaration": true` but tsup ignores this -- it needs its own `dts: true`.

### H4. [CARRIED] `detect.ts` reads stdin with `readFileSync(0)`

**File:** `ts-demo/src/cli/detect.ts:279`
**Severity:** HIGH
`readFileSync(0, "utf-8")` reads from file descriptor 0 (stdin) synchronously. If stdin is a TTY and not a pipe, this blocks indefinitely. The `try/catch` prevents a crash but the process hangs. For a PostToolUse hook that receives piped JSON, this works in practice, but it is not robust.

### H2. [CARRIED] Registry write race condition

**File:** `ts-demo/src/cli/detect.ts:132-151`
**Severity:** HIGH
`loadJobs()` + modify + `saveJobs()` is not atomic. Concurrent hook invocations can cause one write to overwrite another's registered job. The atomic write (temp + rename) prevents corruption but not lost writes.

---

## Test Results

```
$ cd agent-jobs/ts-demo && npx vitest run

 RUN  v4.1.4

 ❯ src/detect.test.ts (19 tests | 1 failed)
     x extracts port from --port flag
 ✓ src/utils.test.ts (15 tests)
 ✓ src/job-table.test.tsx (17 tests)

 Test Files  1 failed | 2 passed (3)
      Tests  1 failed | 50 passed (51)
   Duration  435ms
```

### Test Summary

| Test File | Tests | Pass | Fail | Coverage Area |
|-----------|-------|------|------|---------------|
| `utils.test.ts` | 15 | 15 | 0 | `truncate`, `formatTime`, `statusIcon`, `resultColor` |
| `job-table.test.tsx` | 17 | 17 | 0 | `TableHeader`, `JobRow`, alignment, snapshots |
| `detect.test.ts` | 19 | 18 | 1 | `detect()` patterns, dedup, registration payload |
| **Total** | **51** | **50** | **1** | |

### Pass rate: 98% (50/51)

Three new tests were added since v005:
1. `writes correct job payload to disk` -- verifies the JSON written by `writeFileSync`
2. `deduplicates by name -- second detect returns false` -- proper dedup test
3. `extracts port from --port flag` -- **FAILING** due to test isolation bug

### What is tested (well)
- **utils.ts:** Fully covered. All 4 exported functions, edge cases, JSON residue truncation.
- **job-table.tsx:** Visual regression tests, snapshot tests, selection indicators, truncation.
- **detect.ts `detect()` function:** 14 bash patterns, 3 file patterns, tool filtering, dedup, registration payload.

### What is NOT tested (unchanged from v005)
- **setup.ts:** 0%
- **scanner.ts:** 0%
- **loader.ts:** 0%
- **app.tsx:** 0%
- **cli/index.ts:** 0%
- **All components except job-table:** 0% (header.tsx, tab-bar.tsx, footer.tsx, job-detail.tsx)

### Estimated effective code coverage: ~35%

---

## Architecture Assessment

### Positive changes
- tsup config split into two configs is the correct pattern for mixed CLI/library builds
- `main()` exported from `detect.ts` is clean separation of CLI entry from module logic
- `pathToFileURL` usage is the correct ESM approach for URL comparison
- `randomUUID()` eliminates collision risk for job IDs

### Remaining concerns

1. **`detect.ts:276` -- `main()` exported but the guard still exists**
   The guard at lines 305-309 remains correct for the case where someone runs `node dist/cli/detect.js` directly (bypassing `cli/index.ts`). Both paths now work: direct execution triggers the guard, and CLI routing calls `main()` explicitly. This is a good pattern.

2. **`setup.ts` mutates the settings object in place**
   Lines 76-94 modify `settings.hooks` directly instead of creating new objects. This violates immutability principles. Not a functional bug since the object is immediately serialized to disk, but it sets a bad pattern.

3. **`scanner.ts:93` -- error handling in `execFile` callback**
   The `stdout` extraction `(err as { stdout?: string } | null)?.stdout` at line 93 is a defensive hack. When `lsof` returns exit code 1 with partial output (common when some processes are privileged), the error object may contain stdout. This cast is correct but should be documented.

4. **`job-detail.tsx:20` -- "Next Run" field shows port instead of next run time**
   ```typescript
   { label: "Next Run", value: job.port ? `:${job.port}` : formatTime(job.next_run) },
   ```
   This conflates two unrelated fields. The "Next Run" label shows the port number if a port exists, which is semantically wrong. The port should be in its own field.

---

## Feature Completeness Checklist

| Feature | Status | Notes |
|---------|--------|-------|
| PostToolUse hook detection | **YES** | FIXED. `agent-jobs detect` now works via explicit `main()` call |
| Hook auto-installation (`setup`) | YES | Atomic write, idempotent |
| Hook removal (`teardown`) | YES | Clean removal |
| Registry persistence (`jobs.json`) | YES | Atomic write via rename |
| TUI dashboard | YES | Ink-based, tabbed, keyboard navigation |
| Job detail view | YES | Inline expansion, round border |
| Live process scanning (lsof) | YES | Async via execFile |
| Scheduled task scanning | YES | Reads `scheduled_tasks.json` |
| File watching (both files) | YES | Watches `jobs.json` and `scheduled_tasks.json` |
| Onboarding empty state | YES | Shows "Get started" guide |
| `--version` | YES | Reads from package.json dynamically |
| LaunchAgent scanner | NO | Primary feature gap |
| Registration time in table | NO | `created_at` only in detail panel |
| History view in detail panel | NO | No run history data model |
| Log viewer | NO | |
| Service start/stop control | NO | |
| Build pipeline (tsup) | **YES** | Split config, correct shebang placement |
| npm publish ready | PARTIAL | Nested in `ts-demo/` |
| `postinstall`/`preuninstall` | YES | |
| `.gitignore` | YES | |
| Tests (passing) | **NO** | 50/51 pass -- 1 failure |
| Tests (coverage) | PARTIAL | ~35% estimated, no thresholds |
| README | PARTIAL | Missing test instructions, wrong dev path |
| LICENSE file | YES | MIT |
| CONTRIBUTING.md | PARTIAL | Missing test mention, wrong dev path |
| CI/CD | NO | |

---

## Progress Tracking

| Issue | v001 | v002 | v003 | v004 | v005 | v006 | Notes |
|-------|------|------|------|------|------|------|-------|
| Go binary | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | 4.9MB arm64 Mach-O |
| Nested `ts-demo/` | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | Blocks npm publish |
| `detect` CLI broken | -- | -- | -- | NEW | FIXED/REGRESSED | **FIXED** | Guard + explicit call |
| `isDirectRun` fragility | -- | -- | -- | -- | NEW | **FIXED** | pathToFileURL used |
| Shebang on all chunks | -- | -- | -- | -- | NEW | **FIXED** | Split tsup config |
| Job ID collisions | -- | -- | -- | -- | NEW | **FIXED** | randomUUID |
| Dedup test missing | -- | -- | -- | -- | NEW | **FIXED** | Added |
| Payload assertion test | -- | -- | -- | -- | NEW | **FIXED** | Added |
| Port extraction test | -- | -- | -- | -- | -- | **FAIL** | Mock isolation bug |
| Race condition | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | No locking |
| No LaunchAgent scanner | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |
| stdin readFileSync(0) | OPEN | OPEN | OPEN | OPEN | OPEN | OPEN | |
| No dts | -- | -- | -- | OPEN | OPEN | OPEN | |

**Issues resolved this round:** 7 (v005-C3, v005-H1/C4, v005-M12, v005-M13, v005-L10, v005-H7, v005-H8)
**New issues found:** 2 (C1 test failure, M1 splitting+banner)
**Regressions:** 1 (C1 -- port extraction test fails due to mock contamination from dedup test)

---

## Actionable Next Steps (prioritized)

### Tier 1: Must do before commit (blockers)

1. **[5 min] Fix the failing port extraction test (C1)** -- The root cause is `vi.clearAllMocks()` not resetting `mockReturnValue` from the dedup test. Change the `beforeEach` in the `"detect - job registration"` describe block to restore the default mock implementations:
   ```typescript
   beforeEach(() => {
     vi.clearAllMocks();
     // Reset mock implementations to defaults (clearAllMocks doesn't do this)
     vi.mocked(existsSync).mockReturnValue(false);
     vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
       if (args[0] === 0) return "";
       throw new Error("ENOENT");
     });
   });
   ```

2. **[5 min] Delete legacy directories** -- `rm -rf agent-jobs/ go-demo/ python-demo/ shared/` to remove the 4.9MB binary (C-struct-1).

3. **[10 min] Move `ts-demo/` to repo root** -- `mv ts-demo/* ts-demo/.* . && rmdir ts-demo/` (C-struct-2). Update README/CONTRIBUTING dev instructions.

### Tier 2: Should do before publish

4. **[5 min] Add `dts: true` to both tsup configs (H5)** -- Emit `.d.ts` type declarations.
5. **[5 min] Remove `splitting: true` from CLI config (M1)** -- CLI entries should be self-contained bundles.
6. **[5 min] Fix "Next Run" field in job-detail.tsx** -- Port should have its own field; "Next Run" should always show `formatTime(job.next_run)`.
7. **[10 min] Fix README/CONTRIBUTING dev instructions (M7, M8)** -- Add `cd ts-demo` (or fix after root move).
8. **[5 min] Add `npm test` to CONTRIBUTING PR checklist (M9)** and test section to README (L8).
9. **[5 min] Add `created_at` column to main table (M10)**.

### Tier 3: Polish for quality open-source release

10. **[1 hr] Write tests for `scanner.ts`** -- Mock `execFile`, test `parseLsofOutput`, `inferAgent`, `friendlyLiveName`.
11. **[30 min] Write tests for `setup.ts`** -- Mock settings file, test install/teardown/idempotency.
12. **[30 min] Add vitest coverage thresholds (L9)** in vitest.config.ts (set 60% as first milestone).
13. **[30 min] Fix job-table column widths (M6)** to avoid wrapping in 80-col terminals.
14. **[2 hr] Implement LaunchAgent scanner (H3)**.
15. **[30 min] Add history view to detail panel (M11)**.
16. **[10 min] Standardize truncation limits (L11)** -- share a constant between `detect.ts:185` (200 chars) and `scanner.ts:112` (120 chars).

---

## Communication

### To the implementation agent:

**URGENT: 1 test is now failing.** The port extraction test (`detect.test.ts:225-235`) fails with `expected undefined to be 5000`. The root cause is mock state leaking from the dedup test. The dedup test at line 213-214 calls `vi.mocked(existsSync).mockReturnValue(true)` and `vi.mocked(readFileSync).mockReturnValue(writtenJson)`, but the `beforeEach` only uses `vi.clearAllMocks()` which clears call history but does NOT reset `mockReturnValue` implementations. The fix is a 5-minute change: add mock implementation resets to `beforeEach`. See detailed analysis in C1 above.

**Good decisions this round:**
- The fix for `agent-jobs detect` is exactly what v005 recommended: exporting `main()` and calling it explicitly from `cli/index.ts`. Clean, minimal, correct.
- The split tsup config is the right architecture for mixed CLI/library builds. This is how well-maintained projects do it.
- Using `pathToFileURL` instead of string template for the `isDirectRun` guard is the proper ESM approach. Handles paths with spaces and unicode correctly.
- Switching to `randomUUID()` for job IDs is more robust than `Date.now()`.
- The dedup test (lines 199-223) is well-designed: it captures `writeFileSync` output from the first call and feeds it back via mocked `readFileSync` for the second call. The test logic is correct -- just the cleanup between tests needs fixing.
- The payload assertion test (lines 181-197) validates four fields of the written JSON, which is exactly the kind of assertion-strength improvement v005 requested.

**Design questions:**
1. **Where are the implementation docs?** This is the sixth review and `.implementation/` is still empty. Without design docs (PRD, architecture, task list), the reviewer cannot verify spec conformance or understand intended future direction. At minimum, a brief architecture doc explaining the hook -> detect -> register -> TUI pipeline would help reviewers and future contributors.
2. **What is the intended behavior for `job-detail.tsx` "Next Run" field?** Line 20 shows the port number under the "Next Run" label when a port exists. Is this intentional UX design, or a bug? It conflates two different pieces of information.
3. **Is `splitting: true` intentional for CLI entries?** Code splitting benefits web bundles and lazy-loaded modules, but CLI entry points are typically bundled as standalone files. The splitting produces shared chunks that receive the shebang banner unnecessarily. Unless there is a specific reason for code splitting in CLI context, `splitting: false` would be cleaner.

**Momentum assessment:**

The project is on a strong upward trajectory. The implementation agent addressed 7 of the highest-priority items from v005, including the critical `detect` regression. The code quality improvements (pathToFileURL, randomUUID, split tsup config) show attention to detail. The test count increased from 48 to 51 with meaningful new tests (payload validation, dedup verification).

The remaining path to a publishable state is clear and achievable:
1. Fix the 1 failing test (5 minutes)
2. Clean repo structure (15 minutes)
3. Add `dts: true` (5 minutes)
4. Fix docs (10 minutes)

After those four items, the project would score 88+ and be ready for its first `npm publish`.

---

## Summary

v006 represents a significant quality leap in the **most critical area**: the detection pipeline. The `agent-jobs detect` command now works correctly in all scenarios: direct execution via the `isDirectRun` guard, CLI routing via explicit `main()` call, and test imports via clean module boundary. The tsup build pipeline is properly split. Job IDs are collision-safe. The guard uses proper URL comparison.

The only regression is a test isolation bug causing 1/51 tests to fail. The root cause is well-understood (mock state leaking between test cases) and the fix is trivial.

The project's biggest remaining blockers are structural, not functional: the Go binary in the tree (4.9MB), the `ts-demo/` nesting, and missing type declarations. These are all solvable in under 30 minutes of focused work.

**Score trajectory:** 35 (v001) -> 39 (v002) -> 48 (v003) -> 62 (v004) -> 76 (v005) -> 82 (v006)
**Next target:** 88+ after fixing the test, cleaning repo structure, adding `dts: true`, and fixing docs.
