# Agent Jobs Review — v029
**Date:** 2026-04-11T20:15:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 44a3c17 + unstaged changes (main)
**Files scanned:** 19 changed (17 modified, 2 new)
**Previous review:** v028 (score 97/100, user feedback: add AGENT column)
**Test results:** 268/268 pass | Coverage: 92% stmts, 86% branch, 89% funcs, 93% lines

## Overall Score: 91/100

**Large feature drop** implementing 5 user-requested features: AGENT column restoration, agent-aware service naming, dynamic COMMAND column width, hide (x key), and stop/disable (s key with confirmation). The implementation is **functionally correct** and well-tested, with a few structural issues and a notable test quality concern.

---

## Changes Reviewed

| File | Type | Lines | Summary |
|------|------|-------|---------|
| `src/store.ts` | **NEW** | 90 | Persistence layer: hidden IDs, job mutations, kill/stop |
| `src/store.test.ts` | **NEW** | 202 | Unit tests for all store functions |
| `src/types.ts` | Modified | +10 | Added `HiddenFile`, `ConfirmAction` types |
| `src/scanner.ts` | Modified | +16 | Agent-aware `friendlyLiveName`, generic script skip |
| `src/app.tsx` | Modified | +130 | Hide/stop state, confirmation flow, hidden filtering |
| `src/components/job-table.tsx` | Modified | +24 | AGENT column, dynamic widths, `confirmMessage` prop |
| `src/components/footer.tsx` | Modified | +2 | `x → Hide`, `s → Stop` shortcuts |
| `src/loader.ts` | Modified | +3 | Watch `hidden.json` for changes |
| `src/scanner.test.ts` | Modified | +37 | Agent-aware naming tests |
| `src/job-table.test.tsx` | Modified | +65 | AGENT column, confirmMessage tests |
| `src/app.test.tsx` | Modified | +112 | Hide/stop feature tests |
| `src/loader.test.ts` | Modified | +12 | 3-watcher test update |

---

## Category Scores

### Correctness: 28/30

**Good:**
- All 268 tests pass, up from 230 (v027). 38 new tests added.
- Agent-aware naming correctly handles the openclaw-gateway case: generic scripts (`entry.js`, `index.js`, `main.js`) are skipped when an agent is detected, falling through to the agent+subcommand naming path.
- Confirmation modal correctly blocks all other keys — tested.
- Hidden IDs persist across app restarts via `~/.agent-jobs/hidden.json`.
- Source-specific stop actions: registered → status update, live → SIGTERM, launchd → `launchctl stop`, cron → informational message.

**Issues:**

1. **MEDIUM — `setRegisteredJobStatus` mutates the job object in-place** (`store.ts:66`). The function does `job.status = status` which mutates the object from the parsed JSON. While functional (the object is about to be serialized and discarded), this violates the project's immutability rule. Should use `{...job, status}` spread.

2. **LOW — `genericScripts` Set is re-created on every call** (`scanner.ts:88`). `friendlyLiveName` is called once per live process per refresh cycle (every 10s), so this is not a performance concern, but the Set could be a module-level constant.

### Architecture: 18/20

**Good:**
- Clean separation: `store.ts` for persistence, `app.tsx` for state/UI logic, `job-table.tsx` for presentation.
- Atomic file writes (write to tmp, rename) match existing patterns in `cli/detect.ts`.
- `watchJobsFile` correctly extended to watch 3 files (jobs.json, hidden.json, scheduled_tasks.json).
- `ConfirmAction` type is well-designed — minimal state needed for the confirmation flow.

**Issues:**

3. **MEDIUM — `store.ts` uses synchronous fs operations (`readFileSync`, `writeFileSync`)** while the rest of the codebase uses callback-based async (`readFile`, `readdir`). This creates a mixed I/O pattern. The synchronous calls run inside `useInput` handlers (React render cycle) which is acceptable for small files, but ideally should be async to avoid blocking the event loop during rapid key presses.

4. **LOW — `removeRegisteredJob` writes an empty jobs file when `jobs.json` doesn't exist** (`store.ts:58-60`). `loadJobsFile()` returns `{ version: "1.0", jobs: [] }` on ENOENT, then `removeRegisteredJob` filters (no-op) and writes that empty structure. Harmless but creates an unnecessary file write. Consider early-returning when the job isn't found.

### Production-readiness: 18/20

**Good:**
- All user feedback items from v028 resolved: AGENT column restored, service names improved.
- Dynamic COMMAND width (30% of terminal) adapts to different terminal sizes.
- Status message auto-clears after 3 seconds — good UX feedback loop.
- Cursor adjustment on hide prevents out-of-bounds state.
- Footer updated with new keyboard shortcuts.

**Issues:**

5. **MEDIUM — No "unhide" mechanism.** Once a job is hidden via `x`, there's no way to restore it without manually editing `~/.agent-jobs/hidden.json`. For live processes, re-hiding after a PID change creates orphaned entries in the hidden list. Should at minimum document how to unhide, or provide a "clear hidden" command.

6. **LOW — `handleStopConfirm` has a floating promise via `void handleStopConfirm(job)`** (`app.tsx:126`). The `void` operator intentionally discards the promise, but any unhandled rejection from `stopLaunchdService` would be silently swallowed. The function does have try/catch-like error handling within the switch cases, but the launchd case resolves the promise (never rejects), so this is currently safe.

### Open-source quality: 13/15

**Good:**
- New `store.ts` has clear section comments (`── Hidden IDs ──`, `── Registered Jobs mutations ──`, `── Process actions ──`).
- Test descriptions are clear and follow the project's naming pattern.
- Test fixtures are well-organized and cover all job sources.

**Issues:**

7. **MEDIUM — `job-table.test.tsx` has a structural nesting error.** The `"AGENT column display"` and `"confirmMessage display"` describe blocks (lines 335-403) are placed **outside** the `"JobRow"` describe block (which ends at line 333). They are top-level describes that should be nested inside `"JobRow"`. This works because the tests pass, but the describe hierarchy doesn't match the logical structure. Compare:
   ```
   Actual:
     describe("JobRow")  // lines 70-333
     describe("AGENT column display")   // line 335 — orphaned
     describe("confirmMessage display") // line 370 — orphaned
     describe("Column alignment")       // line 405
   
   Expected:
     describe("JobRow")
       describe("AGENT column display")
       describe("confirmMessage display")
     describe("Column alignment")
   ```

8. **LOW — Test assertions weakened due to terminal width.** Several tests use `toMatch(/claude-co/)` instead of `toContain("claude-code")` because the 80-column test terminal truncates content. This is a pragmatic workaround, but the tests no longer verify that the full agent name renders. Consider setting `process.stdout.columns = 160` in test setup to avoid truncation artifacts.

### Security: 14/15

**Good:**
- `killProcess` uses `SIGTERM` (graceful) not `SIGKILL`.
- `stopLaunchdService` has a 5-second timeout to prevent hanging.
- Atomic file writes prevent partial reads of `hidden.json`.
- No user input reaches shell commands — all paths are programmatic.

**Issues:**

9. **LOW — No validation on hidden IDs read from file.** `loadHiddenIds` trusts that `hidden.json` contains `{ hidden: string[] }` but only checks `Array.isArray(raw.hidden)`. If an entry is not a string (e.g., a number or object), it would be added to the Set and could cause unexpected equality comparisons. Low risk since the file is only written by the app itself.

---

## Action Items for Implementation Agent

### P1 (should fix)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 7 | `"AGENT column display"` and `"confirmMessage display"` describe blocks are orphaned at top level | `job-table.test.tsx:335-403` | Move these two describe blocks inside the `"JobRow"` describe (before line 333's closing `});`) |
| 5 | No unhide mechanism | `footer.tsx`, `app.tsx` | At minimum, add a comment in `store.ts` documenting manual unhide via `hidden.json`. Ideally, add a "Show hidden" option or "u" key to undo last hide. |

### P2 (nice to fix)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | Mutation in `setRegisteredJobStatus` | `store.ts:66` | Change `job.status = status` to create a new object: `file.jobs = file.jobs.map(j => j.id === id ? {...j, status} : j)` |
| 3 | Sync fs in store.ts | `store.ts` | Low priority — acceptable for small config files. Document the rationale in a comment. |
| 8 | Weakened test assertions | `job-table.test.tsx` | Add `process.stdout.columns = 160` in test `beforeEach` to prevent truncation |
| 2 | `genericScripts` Set re-created per call | `scanner.ts:88` | Move to module scope as `const GENERIC_SCRIPTS = new Set([...])` |

### P3 (trivial)

| # | Issue | File | Fix |
|---|-------|------|-----|
| 4 | `removeRegisteredJob` writes on ENOENT | `store.ts:58` | Add early return if job not found in array |
| 6 | Floating promise | `app.tsx:126` | Add `.catch(() => {})` or wrap in try/catch for safety |
| 9 | No string validation on hidden IDs | `store.ts:29` | Filter: `raw.hidden.filter((id): id is string => typeof id === "string")` |

---

## Diff Summary

```
 19 files changed
 +399 lines added (new store.ts: 90, new store.test.ts: 202, rest: 107)
 -47 lines removed (test adjustments)
 Net: +352 lines
```

**New modules:** `store.ts` (persistence layer), `store.test.ts` (unit tests)
**New features:** Hide (x), Stop (s+y/n), AGENT column, agent-aware naming, dynamic COMMAND width
**New types:** `HiddenFile`, `ConfirmAction`
**Test growth:** 230 → 268 tests (+38, +16.5%)

---

## Communication

### To the implementation agent

Good work resolving all 5 user feedback items in a single implementation pass. The feature set is functionally complete and well-tested. Three things to address before considering this stable:

**1. Fix the orphaned describe blocks in `job-table.test.tsx` (P1, 2-minute fix):**
Lines 335-403 have two `describe` blocks (`"AGENT column display"` and `"confirmMessage display"`) that are siblings of `"JobRow"` instead of children. They should be nested inside the `"JobRow"` describe. The closing `});` on line 333 ends `"JobRow"` too early — move it to after the two new describe blocks (after line 403).

**2. Fix `setRegisteredJobStatus` mutation (P2, 1-minute fix):**
Line 66 of `store.ts` does `job.status = status` — direct mutation. Replace the `find` + mutate pattern with an immutable `map`:
```typescript
export function setRegisteredJobStatus(id: string, status: JobStatus): void {
  const file = loadJobsFile();
  const found = file.jobs.some((j) => j.id === id);
  if (found) {
    file.jobs = file.jobs.map((j) => j.id === id ? { ...j, status } : j);
    saveJobsFile(file);
  }
}
```

**3. Consider adding `process.stdout.columns = 160` to test setup (P2):**
Multiple test assertions had to be weakened from `toContain("claude-code")` to `toMatch(/claude-co/)` because the default 80-column test terminal truncates rendered output. Setting a wider virtual terminal in tests would allow full-text assertions.

The score dropped from 97 to 91 primarily due to the test nesting issue (which affects test organization quality) and the mutation pattern. Both are quick fixes. Once addressed, score should return to 95+.

---

## Score Trajectory

```
v017: 98  ████████████████
v018: 99  ████████████████
v019: 92  ███████████████
v020: 88  ██████████████
v021: 97  ████████████████
v022: 72  ████████████
v023: 80  █████████████
v024: 85  ██████████████
v025: 90  ███████████████
v026: 95  ████████████████
v027: 97  ████████████████
v028: 97  ████████████████
v029: 91  ███████████████  ← 5-feature drop: AGENT, hide, stop, naming, dynamic width
```

---

## Summary

v029 scores **91/100**. Five user-requested features implemented: AGENT column restored, agent-aware service naming (openclaw-gateway instead of node :18789), dynamic COMMAND column width (30%), hide rows (x key with persistence), and stop/disable jobs (s key with inline y/n confirmation). 268 tests pass with 92% statement coverage. Key issues: orphaned test describe blocks (P1), mutation in `setRegisteredJobStatus` (P2), and weakened test assertions due to narrow test terminal (P2). The new `store.ts` module follows existing project patterns with atomic file writes. No security concerns.
