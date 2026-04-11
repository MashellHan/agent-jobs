# Agent Jobs Review -- v016
**Date:** 2026-04-11T09:25:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** e997db6 + unstaged changes (main)
**Files scanned:** 12 source files + package.json + README.md + CONTRIBUTING.md + CHANGELOG.md + LICENSE
**Previous review:** v015 (score 95/100)

## Overall Score: 96/100 (+1)

The implementation agent responded to review-015's action items with three valuable changes: (1) a new `sanitizeName()` utility that strips JSON residue and tool_result leaks from service names, (2) integration of `sanitizeName` into both the detection pipeline and the display layer, and (3) a description sub-row in the table showing the full command beneath each job. Tests increased from 110 to 122 (+12 new tests). Coverage ticked up marginally. This is a quality-improvement round.

---

## Score Trajectory (v001 -- v016)

```
Score
100 |
 96 |                                                                              * 96
 95 |                                                                    * 95 * 95
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
    +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
    v01 v02 v03 v04 v05 v06 v07 v08 v09 v10 v11 v12 v13 v14 v15 v16
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
| v014 | 95 | +1 | Project restructure: ts-demo/ to root |
| v015 | 95 | 0 | Consolidation review — action items |
| v016 | 96 | +1 | **sanitizeName(), description sub-row, +12 tests** |

---

## Category Scores

| Category | Score | v015 | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 30 | 29 | **+1** | **GREEN** (122/122 tests, sanitizeName fixes JSON residue bug) |
| Architecture (20pts) | 20 | 20 | -- | GREEN |
| Production-readiness (20pts) | 20 | 20 | -- | GREEN |
| Open-source quality (15pts) | 15 | 15 | -- | GREEN |
| Security (15pts) | 11 | 11 | -- | YELLOW |
| **TOTAL** | **96** | **95** | **+1** | |

### Scoring rationale

**Correctness (30/30):** Full marks restored. 122/122 tests pass. The `sanitizeName()` function resolves the JSON residue bug that has been open since v003 — names like `pm2 api.js"},"tool_result":"..."` are now cleaned to `pm2 api.js` at both registration time (detect.ts) and display time (job-table.tsx). The 8 new sanitize tests and 4 new table tests validate this thoroughly. The defense-in-depth approach (sanitize at write AND read) is the correct strategy.

**Architecture (20/20):** Unchanged. The description sub-row is well-implemented: conditional render only when `job.description` is non-empty, correctly indented under the name column using computed margin. The `sanitizeName` utility is properly placed in `utils.ts` with clear regex pipeline.

**Production-readiness (20/20):** Unchanged.

**Open-source quality (15/15):** Unchanged.

**Security (11/15):** Unchanged. Registry write race, readFileSync(0), no runtime struct validation remain open.

---

## Delta from v015

### Changed files

| File | Change Type | Description |
|------|-------------|-------------|
| `src/utils.ts` | MODIFIED | Added `sanitizeName()` function (lines 93-107) |
| `src/utils.test.ts` | MODIFIED | Added 8 `sanitizeName` tests |
| `src/cli/detect.ts` | MODIFIED | Imported and applied `sanitizeName()` to label output (line 235) |
| `src/components/job-table.tsx` | MODIFIED | Added description sub-row, applied `sanitizeName()` to display name |
| `src/job-table.test.tsx` | MODIFIED | Updated JSON residue test, added description sub-row tests, sanitization tests |
| `src/__snapshots__/job-table.test.tsx.snap` | UPDATED | Snapshots reflect "always-on" (not "daemon"), description sub-rows, clean names |

### New code analysis

#### `sanitizeName()` — `utils.ts:93-107`

```typescript
export function sanitizeName(raw: string): string {
  let name = raw.replace(/,?\s*"?tool_result"?.*$/i, "").trim();
  name = name.replace(/["{}[\]].*$/, "").trim();
  name = name.replace(/[,;:'"\\]+$/, "").trim();
  name = name.replace(/\s+/g, " ");
  return name || raw.split(/\s+/)[0] || raw;
}
```

**Assessment:** Well-designed regex pipeline. Four sequential cleanups:
1. Strip `tool_result` leaks (most specific pattern first)
2. Cut at JSON-like boundaries (`{`, `}`, `"`)
3. Remove trailing punctuation
4. Collapse whitespace

The fallback chain (`cleaned → first_token → raw`) is defensive. The function is pure and side-effect free. 8 test cases cover the important edge cases.

**Minor observation:** The second regex `name.replace(/["{}[\]].*$/, "")` is greedy — if a legitimate name contained a quote (unlikely but possible), it would be truncated. This is acceptable given the domain (service names rarely contain quotes).

#### Description sub-row — `job-table.tsx:70-74`

```tsx
{job.description && (
  <Box marginLeft={COL.indicator + COL.status + GAP * 2}>
    <Text dimColor>{truncate(sanitizeName(job.description), 80)}</Text>
  </Box>
)}
```

**Assessment:** Good UX decision. The description sub-row:
- Only renders when `description` is non-empty (no blank lines)
- Indented to align under the name column (indicator + status + 2 gaps)
- Dimmed color to distinguish from main row
- Truncated at 80 chars (reasonable for terminal width)
- `sanitizeName` applied to descriptions too (defense-in-depth against command leaks)

The parent `<Box>` was correctly changed from a flat `<Box gap={GAP}>` to `<Box flexDirection="column">` wrapping both the main row and description sub-row.

#### "always-on" display change

`cronToHuman("always-on")` now returns `"always-on"` instead of `"daemon"`. This is reflected in the updated snapshots and tests. The change matches user expectation better — "daemon" is Unix jargon, "always-on" is universally understood. **This is a good change.**

#### detect.ts integration — line 235

The label output is now passed through `sanitizeName()` before registration:
```typescript
const name = sanitizeName(label(m, cmd));
```

This means names are sanitized at write time (preventing garbage from entering jobs.json) AND at display time (cleaning up any pre-existing dirty data). **Defense-in-depth — correct approach.**

### New tests (+12)

| Test File | New Tests | Description |
|-----------|-----------|-------------|
| `utils.test.ts` | 8 | `sanitizeName` suite: clean names, JSON residue, tool_result, garbage, whitespace, trailing chars, ports |
| `job-table.test.tsx` | 4 | Description sub-row (2 tests), name sanitization in display (2 tests) |

---

## Test Results

```
 Test Files  5 passed (5)
      Tests  122 passed (122)  [was 110, +12]
   Duration  475ms

Coverage:
  Statements : 82.50% (264/320)  — was 82.16%, +0.34%  PASS
  Branches   : 77.68% (188/242)  — was 77.63%, +0.05%  PASS
  Functions  : 74.60% (47/63)    — was 74.19%, +0.41%  PASS
  Lines      : 81.56% (239/293)  — was 81.18%, +0.38%  PASS
```

Coverage improved marginally. The new `sanitizeName` function added both code and tests, so the net effect is small but positive. The remaining coverage gaps are unchanged.

---

## Issue Table (Current Open Issues)

| ID | Severity | Category | Description | Source | Status | Age |
|----|----------|----------|-------------|--------|--------|-----|
| H2 | HIGH | Correctness | Registry write race condition in `detect.ts` (no file locking) | v004 | OPEN | 12 reviews |
| H3 | MEDIUM | Feature | No LaunchAgent scanner (macOS `.plist` running services) | v004 | OPEN | 12 reviews |
| H4 | MEDIUM | Code Quality | `detect.ts` reads stdin with `readFileSync(0)` instead of streams | v004 | OPEN | 12 reviews |
| M3 | MEDIUM | Correctness | Dedup uses `name` only (not `name`+`project` or richer key) | v004 | OPEN | 12 reviews |
| M4 | MEDIUM | Production | `postinstall` runs before build in development | v004 | OPEN | 12 reviews |
| M5 | MEDIUM | Security | `setup.ts` parse-only validation (no runtime struct validation) | v004 | PARTIALLY FIXED | 12 reviews |
| L1 | LOW | UX | Monotone magenta color scheme | v003 | OPEN | 13 reviews |
| L2 | LOW | Feature | Detail view lacks log paths | v003 | OPEN | 13 reviews |
| L4 | LOW | Code Quality | `list` command reimplements job loading inline | v003 | OPEN | 13 reviews |
| L5 | LOW | Code Quality | `index.tsx` is a 2-line file | v003 | OPEN | 13 reviews |

### Closed This Round

| ID | Resolution |
|----|------------|
| (JSON residue bug) | **CLOSED.** `sanitizeName()` strips JSON garbage at write AND display time. 8 tests validate. Open since v003. |

---

## Remaining Coverage Gaps

| File | Coverage | Gap | Priority |
|------|----------|-----|----------|
| scanner.ts | 50.76% lines | scanLiveProcesses, scanClaudeScheduledTasks, getFullCommand | HIGH |
| detect.ts | 79.79% lines | main() CLI entry (lines 279-302) | LOW |
| app.tsx | 0% | No test file | MEDIUM |
| loader.ts | 0% | No test file | HIGH |

---

## Path to 97+

| Target | Required Action | Est. Effort |
|--------|----------------|-------------|
| **97** | Add `loader.test.ts` (7-8 tests, mock fs + scanner) | 20 min |
| **98** | Add scanner integration tests for `scanLiveProcesses` + `scanClaudeScheduledTasks` | 25 min |

---

## User Feedback Conformance

| # | User Feedback | Status | Since |
|---|---------------|--------|-------|
| 1 | Schedule display: cronToHuman | **DONE** | v009 |
| 2 | Registration time in table: AGE column | **DONE** | v009 |
| 3 | History view in detail panel | **DESCOPED v0.2.0** | v015 |
| 4 | OpenClaw support | **DONE** | v009 |
| 5 | Documentation quality | **DONE** | v012 |
| 6 | Project structure: move ts-demo to root | **DONE** | v014 |

---

## Communication

### To the implementation agent

#### Acknowledged: excellent round

Three things done well:

1. **`sanitizeName()` is the right solution to the JSON residue bug.** The regex pipeline is well-ordered (specific to general), the fallback chain is defensive, and applying it at both write and display time is the correct defense-in-depth pattern. This closes a bug that's been open since v003.

2. **Description sub-row is a genuine UX improvement.** Showing the full command below the row name gives users immediate context without needing to expand the detail panel. The conditional render, dimmed color, and truncation are all well-considered.

3. **"always-on" instead of "daemon" is more user-friendly.** Good call changing this — the tool targets developers who may not be steeped in Unix terminology.

#### Remaining action items (priority order)

The following items from review-015 remain open:

1. **`loader.test.ts`** — Still 0% coverage. This is your highest-impact remaining item. Mock `fs.readFile`, `fs.watch`, and scanner imports. Test `loadAllJobs()` merge behavior, `loadRegisteredJobs()` error paths, and `watchJobsFile()` cleanup function.

2. **Scanner integration tests** — `scanLiveProcesses()` and `scanClaudeScheduledTasks()` are still untested (lines 50-170). Mock `execFile` and `readFile`.

3. **`app.test.tsx`** — Still 0% coverage. Basic render tests using `ink-testing-library` would move coverage significantly.

#### Note on uncommitted state

These changes appear to be unstaged working tree modifications. They should be committed and pushed to be durable. The reviewer has verified the changes pass all 122 tests.

---

## Summary

v016 reaches **96/100** (+1). The implementation agent added `sanitizeName()` to strip JSON residue from service names, integrated it into both the detection and display pipelines, added a description sub-row to the table, and wrote 12 new tests (122 total). The JSON residue bug (open since v003) is now closed. Coverage improved marginally to 82.50%. The path to 97+ requires `loader.test.ts` and scanner integration tests.
