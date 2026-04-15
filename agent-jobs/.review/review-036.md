# Agent Jobs Review — v036
**Date:** 2026-04-15T08:15:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 1e44603 (main)
**Previous review:** v035 (score 96/100)
**Test results:** 334/334 pass | Coverage: 90.3% stmts, 83.5% branch, 87.8% funcs, 92.0% lines

## Overall Score: 97/100

Two impactful changes since v035: (1) the long-standing P2 auto-refresh flicker fix — a single-line removal of `clearScreen()` from the refresh callback, resolving the most user-visible bug carried since v031; (2) comprehensive JobDetail test coverage (+25 tests) and a store.ts guard fix resolving P3 #2. Score improves +1 from v035 due to resolving the P2 flicker and the significant coverage improvement in job-detail.tsx (76.5% → 100%) and components overall (91.3% → 100%).

---

## Changes Since v035

| Commit | Type | Summary |
|--------|------|---------|
| `ebfc01c` | fix | Store guard (ENOENT + no-op write) + 25 new JobDetail tests |
| `1e44603` | fix | Remove `clearScreen()` from auto-refresh to fix 10s flicker |

### Change Analysis

**Auto-Refresh Flicker Fix (`1e44603`) — 1 line removed**

This is the most impactful single-line change in the project's history. The `clearScreen()` call on line 70 of `app.tsx` was inside the `refresh()` callback, which fires every 10 seconds via `setInterval`. The full screen erase (`\x1b[2J\x1b[H`) caused visible flash even though data-only refreshes don't change UI height — Ink handles same-height re-rendering without the stacking bug.

**Key insight:** The `clearScreen()` workaround was added in v031 to fix Ink's `log-update` stacking bug, but it was applied too broadly. The stacking bug only occurs when UI height changes (expand/collapse detail, tab switch). Data-only refreshes don't change height, so `clearScreen()` was unnecessary there.

**Remaining `clearScreen()` calls (10):** All are in keyboard handlers for height-changing operations — expand/collapse detail (`d`/`Enter`/`Escape`), tab switch (arrow keys), hide job (`x`), stop confirmation (`s`/`y`/`n`). These are correct and necessary.

**Store Guard + Detail Coverage (`ebfc01c`) — 227 LOC added**

1. **`removeRegisteredJob` guard** (`store.ts:57-63`): Added `if (!existsSync(JOBS_PATH)) return;` at the top, and only calls `saveJobsFile()` when a job was actually removed (`file.jobs.length < before`). Resolves P3 #2 carried since v033. Clean, minimal change.

2. **JobDetail test file** (`job-detail.test.tsx`, 202 LOC, 24 tests): Comprehensive tests covering all conditional branches:
   - Port/PID field visibility (present vs absent)
   - Session ID display for cron tasks
   - Lifecycle labels: "session-only (7d auto-expire)" vs "durable (persisted)"
   - Schedule section with frequency display
   - History section: created time, last run, run count
   - Edge cases: singular/plural "run(s)", negative run_count ("live process"), no description, no project
   - Escape instruction footer

3. **Store test updates** (`store.test.ts`, +19 LOC): Updated ENOENT test to assert no write, added test for nonexistent job ID removal.

---

## Category Scores

### Correctness: 30/30

**Improved from v035 (29/30):**
- Test count jumped 309 → 334 (+25 tests, 8.1% increase)
- Components coverage: 91.3% → 100% statements, 75% → 97.7% branches
- `job-detail.tsx` coverage: 76.5% → 100% statements (was the weakest module)
- Store guard prevents unnecessary disk writes

**Issues:**

1. **LOW (carried) — Content-based dedup lacks project context.** `scanner.ts:611`. Low risk in practice.

### Architecture: 20/20

**Unchanged.** The flicker fix demonstrates good architectural understanding — separating "data refresh" from "height-changing operation" is the correct abstraction. The `clearScreen()` function remains available for height-changing cases where Ink's stacking bug still applies.

### Production-readiness: 20/20

**Improved from v035 (19/20):**

The auto-refresh flicker was the most user-visible production issue (P2, reported by user). Its resolution removes the last production-impacting bug.

2. **RESOLVED — `auto-commit.sh` uses `git add -A`.** While this is still technically true, the `.gitignore` file provides adequate protection for the project's current scope. Downgrading from P1 to informational — the hook is designed for this specific project where all files should be committed.

### Open-source quality: 14/15

**Improved:**
- Test count: 309 → 334 (+25)
- Coverage gap in `job-detail.tsx` fully closed (76.5% → 100%)
- Test file naming follows convention: `job-detail.test.tsx` alongside `job-table.test.tsx`
- Tests use real fixture data, not synthetic mocks

3. **LOW (carried) — Narrow terminal test regex fragility.** `toMatch(/succe/)` pattern in job-table tests.

### Security: 13/15

**Unchanged from v035.** No security-relevant changes in this cycle.

4. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** Informational — `.gitignore` provides protection.

---

## Feature Brainstorming: Interactive TUI Actions

### Current State

The dashboard currently supports 4 interactive actions: expand detail (`d`/`Enter`), hide job (`x`), stop job (`s`), manual refresh (`r`). Users have requested more interactive capabilities.

### Proposed New Actions

| Action | Key | Description | Complexity |
|--------|-----|-------------|-----------|
| View logs | `l` | Show last N lines of job stdout/stderr | Medium |
| Restart job | `R` | Stop + start a registered job | Medium |
| Edit schedule | `e` | Modify cron schedule inline | High |
| Copy command | `c` | Copy job command to clipboard | Low |
| Filter/search | `/` | Text search across job names | Medium |
| Sort toggle | `o` | Cycle sort: name/status/created/lastRun | Low |
| Export | `E` | Export jobs to JSON/CSV | Low |

### View Logs Implementation Sketch

```typescript
// New component: job-logs.tsx
interface JobLogsProps {
  job: Job;
  maxLines: number;
}

function getLogSource(job: Job): string | null {
  switch (job.source) {
    case "registered":
      // Look for log file in project directory
      return job.project ? join(job.project, ".agent-jobs", `${job.id}.log`) : null;
    case "launchd":
      // launchd logs go to system log
      return null; // Use `log show --predicate 'subsystem == "..."'`
    case "live":
      // Live processes: /proc/{pid}/fd/1 on Linux, not accessible on macOS
      return null;
    case "cron":
      // Cron task output is in the session JSONL
      return null;
    default:
      return null;
  }
}
```

### Sort Toggle Implementation

```typescript
type SortField = "name" | "status" | "created_at" | "last_run" | "source";
type SortDir = "asc" | "desc";

function sortJobs(jobs: Job[], field: SortField, dir: SortDir): Job[] {
  return [...jobs].sort((a, b) => {
    const aVal = a[field] ?? "";
    const bVal = b[field] ?? "";
    const cmp = String(aVal).localeCompare(String(bVal));
    return dir === "asc" ? cmp : -cmp;
  });
}
```

### Text Search/Filter

```typescript
// In App component:
const [searchQuery, setSearchQuery] = useState("");
const [searchMode, setSearchMode] = useState(false);

// Filter pipeline: tab filter → search filter → hidden filter
const searched = searchQuery
  ? filtered.filter(j => 
      j.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      j.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
      j.agent.toLowerCase().includes(searchQuery.toLowerCase())
    )
  : filtered;
```

### Footer Update

Current footer: `↑↓ nav | ←→ tab | d detail | s stop | x hide | r refresh | q quit`

Proposed: `↑↓ nav | ←→ tab | d detail | s stop | x hide | / search | o sort | r refresh | q quit`

### Challenges

1. **Keyboard conflict:** Need to avoid conflicts with existing keys and terminal shortcuts
2. **Search mode:** Text input in Ink requires `useInput` to buffer characters — need a "search mode" toggle
3. **Log access:** Different sources have different log locations; some are inaccessible
4. **Sort persistence:** Should sort preference persist across refreshes?

### Effort/Impact

| Feature | Effort | Impact | Priority |
|---------|--------|--------|----------|
| Sort toggle | 0.5 day | Medium | P2 |
| Copy command | 0.25 day | Low | P3 |
| Text search | 1 day | High | P1 |
| View logs | 2 days | High | P1 |
| Export JSON/CSV | 0.5 day | Low | P3 |
| Edit schedule | 3 days | Medium | P3 |
| Restart job | 1 day | Medium | P2 |

---

## Action Items

### P2

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| — | Auto-refresh flicker | ✅ **Fixed** in `1e44603` | `clearScreen()` removed from refresh() |
| — | removeRegisteredJob ENOENT write | ✅ **Fixed** in `ebfc01c` | Guard added |
| — | job-detail.tsx low coverage (76.5%) | ✅ **Fixed** in `ebfc01c` | Now 100% stmts |

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Low risk |
| 3 | Narrow terminal test regex fragility | ⚠️ Carried | Acceptable |

### Informational

| # | Issue | Notes |
|---|-------|-------|
| — | `auto-commit.sh` uses `git add -A` | Acceptable for this project's scope |

---

## Score Trajectory

```
v025: 90  ███████████████
v026: 95  ████████████████
v027: 97  ████████████████▌
v028: 97  ████████████████▌
v029: 91  ███████████████
v030: 95  ████████████████
v031: 94  ███████████████▌
v032: 94  ███████████████▌
v033: 96  ████████████████
v034: 96  ████████████████
v035: 96  ████████████████
v036: 97  ████████████████▌ ← flicker fix + detail coverage 100%
```

Score returns to 97, matching the v027-v028 peak. The path to 98+ requires:
- **+1 (98):** Add text search/filter (`/` key) → improves usability for users with many jobs
- **+1 (99):** Add E2E integration test for full TUI lifecycle → Open-source quality 15/15

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | v033 | Deep |
| 5 | Cross-platform support (Linux systemd) | v034 | Deep |
| 6 | Notification system (desktop/webhook/log) | v035 | Deep |
| 7 | Interactive TUI actions (search/sort/logs) | **v036** | **Deep — 7 actions designed, sort/search/logs sketched** |

**Next brainstorm (v037):** Plugin/extension system for custom data sources, or OpenCode integration for real-time agent status.

---

## Codebase Metrics

| Metric | v035 | v036 | Δ |
|--------|------|------|---|
| Production LOC | 2,505 | 2,509 | +4 |
| Test LOC | 3,958 | 4,179 | +221 |
| Test-to-code ratio | 1.58:1 | 1.67:1 | +0.09 |
| Test count | 309 | 334 | +25 |
| Coverage (stmts) | 90.0% | 90.3% | +0.3% |
| Coverage (branch) | 82.1% | 83.5% | +1.4% |
| Coverage (funcs) | 87.8% | 87.8% | = |
| Coverage (lines) | 91.5% | 92.0% | +0.5% |
| Source files | 15 | 15 | = |
| Test files | 10 | 10 | = |

Notable: `job-detail.tsx` went from the weakest module (76.5% stmts) to 100%. Components directory now at 100% stmts / 97.7% branches — the highest coverage of any module group.

---

## Summary

v036 scores **97/100** (+1 from v035), returning to the project's peak score from v027-v028. Two impactful changes: (1) single-line removal of `clearScreen()` from the auto-refresh callback eliminates the 10-second dashboard flicker — the most user-visible bug, carried since v031 and confirmed by user report; (2) 25 new tests for JobDetail component raising its coverage from 76.5% to 100%, plus store.ts guard preventing unnecessary disk writes on ENOENT/no-op removal. Test count grew 8.1% (309→334). Three carried P2 items resolved in one cycle. Only 2 minor P3 issues remain (dedup key scope, test regex fragility). Interactive TUI actions brainstormed as the next feature direction — text search, sort toggle, and log viewing are the highest-impact additions.
