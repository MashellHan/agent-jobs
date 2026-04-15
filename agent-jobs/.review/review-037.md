# Agent Jobs Review — v037
**Date:** 2026-04-15T08:39:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 590b3c1 (main)
**Previous review:** v036 (score 97/100)
**Test results:** 334/334 pass | Coverage: 90.3% stmts, 83.5% branch, 87.8% funcs, 92.0% lines

## Overall Score: 97/100

No production code changes since v036. Stability checkpoint — 334 tests pass, coverage stable across all dimensions. Score holds at 97. The project has been stable at 96-97 for five consecutive reviews (v033-v037), with the last code changes being the flicker fix and detail coverage improvements in v036.

---

## Changes Since v036

| Commit | Type | Summary |
|--------|------|---------|
| `590b3c1` | docs | Visual review v036 notes — TUI not in viewport |

No production code changes.

### Stability Report

**Consecutive stable reviews:** 5 (v033-v037)
**Last production code change:** v036 (`1e44603` flicker fix, `ebfc01c` store guard + detail tests)
**Test stability:** 334/334 pass across 2 consecutive identical runs

**Coverage by module (unchanged from v036):**

| Module | Stmts | Branch | Assessment |
|--------|-------|--------|-----------|
| job-table.tsx | 100% | 91.7% | ✅ Perfect |
| job-detail.tsx* | 100% | 100% | ✅ Perfect (up from 76.5% in v034) |
| setup.ts | 100% | 94.1% | ✅ Perfect |
| scanner.ts | 94.1% | 84.6% | ✅ Excellent |
| loader.ts | 88.2% | 70.0% | ⚠️ Low branch coverage |
| store.ts | 89.1% | 87.5% | ✅ Good |
| utils.ts | 88.5% | 81.5% | ✅ Good |
| detect.ts | 83.2% | 81.0% | ⚠️ Lowest — platform branches |
| app.tsx | 86.5% | 78.6% | ⚠️ UI interaction branches |

*job-detail.tsx is now included in the components aggregate (100%).

**Weakest branches:**
- `loader.ts` at 70% branch — the `catch` path for failed job loading (lines 48-49) is not tested
- `app.tsx` at 78.6% branch — keyboard handler branches for edge cases (lines 123-130, 156-157)
- `detect.ts` at 81% branch — platform detection conditional paths

---

## Category Scores

### Correctness: 30/30
Unchanged. 334 tests, components at 100%.

### Architecture: 20/20
Unchanged. Clean separation of concerns across 15 source files.

### Production-readiness: 20/20
Unchanged. Flicker fix resolved. No production bugs known.

### Open-source quality: 14/15
1. **LOW (carried) — Narrow terminal test regex fragility.** `toMatch(/succe/)` pattern.

### Security: 13/15
2. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** Informational.

---

## Feature Brainstorming: Project Grouping & Multi-Workspace Support

### Context

Visual review v036 showed the user working across multiple projects simultaneously (RAVEN planning doc, agent-jobs dashboard, Claude Session Monitor). This suggests a need for project-aware features.

### Current Project Handling

Jobs already have a `project` field (filesystem path to the project directory):
```typescript
interface Job {
  // ...
  project: string;  // e.g., "/Users/dev/my-project"
  // ...
}
```

But the dashboard treats all jobs as a flat list — no grouping, filtering, or project-level aggregation.

### Proposed: Project-Aware Dashboard

**Level 1: Project Column Enhancement**
```typescript
// Show short project name instead of full path
function shortProjectName(project: string): string {
  if (!project) return "-";
  const parts = project.split("/");
  return parts[parts.length - 1] || parts[parts.length - 2] || project;
}
```

Currently the PROJECT column doesn't exist in the table — it's only in the detail panel. Adding it would require column width rebalancing.

**Level 2: Project Filter Tab**
Add project-based filtering alongside the existing tab system:
```typescript
// New state
const [projectFilter, setProjectFilter] = useState<string | null>(null);

// Filter chain: tab → project → hidden
const projectFiltered = projectFilter
  ? filtered.filter(j => shortProjectName(j.project) === projectFilter)
  : filtered;
```

Navigation: Use `p` key to cycle through discovered projects, or show a project picker overlay.

**Level 3: Project Grouping View**
```
┌─ agent-jobs (3 jobs) ─────────────────────────┐
│ ● my-web-server    claude-code  hook  always-on│
│ ○ cron-review      claude-code  cron  daily 2am│
│ ● pew sync         claude-code  hook  always-on│
├─ openclaw (2 jobs) ───────────────────────────┤
│ ● openclaw-monitor openclaw     hook  every 30m│
│ ● gateway          openclaw     launchd always │
├─ (no project) (1 job) ────────────────────────┤
│ ● node server.js   manual       live  always-on│
└───────────────────────────────────────────────┘
```

### Implementation Approach

| Feature | Effort | Impact | Files |
|---------|--------|--------|-------|
| Short project name in detail | 0.25d | Low | utils.ts, job-detail.tsx |
| Project column in table | 0.5d | Medium | job-table.tsx, width rebalancing |
| `p` key project filter | 0.5d | High | app.tsx, new state |
| Grouped view mode | 1.5d | High | New component, app.tsx |

### Multi-Workspace Considerations

If different VS Code windows are open for different projects, each running its own Claude Code session:
- The dashboard already aggregates across all projects (scanner reads `~/.claude/projects/*/`)
- Project grouping would make this cross-project data more navigable
- Could add a "current project" indicator based on `process.cwd()` or an env var

---

## Action Items

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Low risk |
| 3 | Narrow terminal test regex fragility | ⚠️ Carried | Acceptable |

### Coverage Opportunities

| Module | Current Branch | Target | Approach |
|--------|---------------|--------|----------|
| loader.ts | 70% | 85%+ | Test error/catch path |
| app.tsx | 78.6% | 85%+ | Test keyboard edge cases |
| detect.ts | 81% | 85%+ | Mock platform detection |

---

## Score Trajectory

```
v025: 90  ███████████████
v026: 95  ████████████████
v027: 97  ████████████████▌
v028: 97  ████████████████▌
v029: 91  ███████████████   ← 5-feature drop
v030: 95  ████████████████
v031: 94  ███████████████▌
v032: 94  ███████████████▌
v033: 96  ████████████████
v034: 96  ████████████████
v035: 96  ████████████████
v036: 97  ████████████████▌ ← flicker fix + detail coverage
v037: 97  ████████████████▌ ← stability checkpoint
```

**Plateau analysis:** Score has been at 96-97 for 5 reviews. The path to 98+ requires new feature work (text search, project grouping) or closing the remaining branch coverage gaps. The project is in a mature maintenance phase.

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | v033 | Deep |
| 5 | Cross-platform support (Linux systemd) | v034 | Deep |
| 6 | Notification system | v035 | Deep |
| 7 | Interactive TUI actions (search/sort/logs) | v036 | Deep |
| 8 | Project grouping & multi-workspace | **v037** | **Medium — 3-level design, effort estimates** |

**Next brainstorm (v038):** OpenCode/Cursor integration — how to read agent status from non-Claude AI coding assistants.

---

## Codebase Metrics

| Metric | v036 | v037 | Δ |
|--------|------|------|---|
| Production LOC | 2,509 | 2,509 | = |
| Test LOC | 4,179 | 4,179 | = |
| Test-to-code ratio | 1.67:1 | 1.67:1 | = |
| Test count | 334 | 334 | = |
| Coverage (stmts) | 90.3% | 90.3% | = |
| Coverage (branch) | 83.5% | 83.5% | = |
| Coverage (lines) | 92.0% | 92.0% | = |
| Source files | 15 | 15 | = |
| Test files | 10 | 10 | = |

All metrics unchanged — no code changes this cycle.

---

## Summary

v037 scores **97/100** (unchanged from v036, 2nd consecutive review at this level). No production code changes — stability checkpoint confirming 334/334 tests pass with identical coverage. The project has been at 96-97 for five consecutive reviews (v033-v037), indicating a mature maintenance phase. Branch coverage remains the weakest metric (83.5%) with `loader.ts` (70%), `app.tsx` (78.6%), and `detect.ts` (81%) as the lowest modules. Project grouping and multi-workspace support brainstormed as the next feature direction, motivated by visual review observation of the user working across multiple projects simultaneously. Eight feature directions have now been explored across the review series.
