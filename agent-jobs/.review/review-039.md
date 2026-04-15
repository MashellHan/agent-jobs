# Agent Jobs Review — v039
**Date:** 2026-04-15T09:59:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** f43eada (main)
**Previous review:** v038 (score 97/100)
**Test results:** 336/336 pass | Coverage: 90.7% stmts, 83.9% branch, 88.4% funcs, 92.2% lines

## Overall Score: 97/100

No production code changes since v038. Fourth consecutive review at 97. The project is in a mature steady state — 336 tests, 90%+ coverage, no known bugs. This review focuses on maturity assessment and the final brainstorm direction.

---

## Changes Since v038

| Commit | Type | Summary |
|--------|------|---------|
| `f43eada` | docs | Visual review v038 — snapshot-based layout verification |

No production code changes.

### Maturity Assessment

The project has been at score 96-97 for **seven consecutive reviews** (v033-v039). Key indicators of maturity:

| Indicator | Status |
|-----------|--------|
| Test suite | 336 tests, 0 failures, 10 test files |
| Coverage | 90.7% stmts, 83.9% branches (all above 85% threshold except 2 modules) |
| Known bugs | 0 (flicker fixed, store guard fixed, all P2+ resolved) |
| Carried issues | 2 P3 only (dedup key scope, test regex fragility) |
| Architecture | Stable — no structural changes needed |
| Production-readiness | 20/20 — no known production issues |
| Last code change | v038 (+2 tests), last feature: v036 (flicker fix) |

**Recommendation:** The project is ready for its next feature phase. The review series has identified 9 feature directions through brainstorming. The highest-impact, most-feasible next steps are:

1. **Text search/filter** (`/` key) — v036 brainstorm, ~1 day effort, immediate user value
2. **Sort toggle** (`o` key) — v036 brainstorm, ~0.5 day effort, quick win
3. **Project grouping** — v037 brainstorm, ~1.5 day effort, helps multi-project users

---

## Category Scores

### Correctness: 30/30
336 tests, components at 100%.

### Architecture: 20/20
Clean 15-file structure with layered design.

### Production-readiness: 20/20
No known issues.

### Open-source quality: 14/15
1. **LOW (carried) — Narrow terminal test regex fragility.**

### Security: 13/15
2. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** Informational.

---

## Feature Brainstorming: Job Health Metrics & Historical Tracking

### Current State

The dashboard shows current job state (active/stopped/error) and basic history (last_run, run_count, last_result). There's no historical trend data — users can't see if a job has been flaky, when failures started, or how uptime has changed over time.

### Proposed: Job Health Store

```typescript
// New file: src/health.ts

interface JobHealthRecord {
  jobId: string;
  timestamp: string;
  status: JobStatus;
  result: string;
  durationMs?: number;
}

interface JobHealthSummary {
  jobId: string;
  uptimePercent: number;      // Active time / total observed time
  successRate: number;         // Successful runs / total runs
  avgDurationMs: number;       // Mean run duration
  failureStreak: number;       // Current consecutive failures
  lastFailure?: string;        // Timestamp of most recent failure
  healthScore: number;         // 0-100 composite score
}

// Append-only health log
const HEALTH_LOG_PATH = join(homedir(), ".agent-jobs", "health.jsonl");

export function recordHealthSnapshot(jobs: Job[]): void {
  const entries = jobs.map(j => ({
    jobId: j.id,
    timestamp: new Date().toISOString(),
    status: j.status,
    result: j.last_result,
  }));
  
  const lines = entries.map(e => JSON.stringify(e)).join("\n") + "\n";
  appendFileSync(HEALTH_LOG_PATH, lines);
}
```

### Health Score Calculation

```typescript
function computeHealthScore(records: JobHealthRecord[]): number {
  if (records.length === 0) return 100; // No data = assume healthy
  
  const recentRecords = records.slice(-100); // Last 100 snapshots
  const successCount = recentRecords.filter(r => r.result === "success").length;
  const activeCount = recentRecords.filter(r => r.status === "active").length;
  
  const successRate = successCount / recentRecords.length;
  const uptimeRate = activeCount / recentRecords.length;
  
  // Weighted: 60% success rate, 40% uptime
  return Math.round(successRate * 60 + uptimeRate * 40);
}
```

### TUI Integration

**Health indicator in table:**
```
ST  SERVICE            AGENT        HEALTH  SOURCE   SCHEDULE
●   my-web-server      claude-code  98%     hook     always-on
●   backup-script      claude-code  45%     cron     daily 2am
✗   flask-server       claude-code  12%     hook     always-on
```

**Health detail in expanded view:**
```
── Health ──
Health Score:   98% (excellent)
Uptime:        99.2% (last 7 days)
Success Rate:  97.5% (last 100 runs)
Avg Duration:  2.3s
Last Failure:  2026-04-08 14:30 (3 days ago)
Fail Streak:   0
```

### Sparkline Trend (optional)

Using Unicode block characters for a mini-chart in the table:

```
HEALTH  TREND (7d)
98%     ▁▂▃▅▇█████
45%     █▇▅▃▂▁▁▁▂▃
12%     ▁▁▁▁▁▁▁▁▁▁
```

### Data Retention

- **JSONL format:** One line per snapshot, ~100 bytes per job per snapshot
- **10-second refresh:** ~8,640 snapshots/day × 100 bytes × N jobs
- **Retention policy:** Keep 7 days, then compact to hourly averages
- **File rotation:** `health-YYYY-MM-DD.jsonl` daily files, auto-cleanup

### Challenges

1. **Storage growth:** 10s interval × many jobs = significant JSONL growth
2. **Snapshot interval vs run interval:** Health snapshots at 10s don't align with job run schedules
3. **Cold start:** No historical data on first run — health score starts at 100%
4. **Clock skew:** Timestamps from different scanners may not align perfectly
5. **Compaction:** Need background task to compact old data without blocking the UI

### Effort/Impact

| Feature | Effort | Impact |
|---------|--------|--------|
| Health JSONL recording | 0.5 day | Foundation |
| Health score calculation | 0.5 day | High — instant insight |
| Health column in table | 0.25 day | High — at-a-glance status |
| Health detail section | 0.25 day | Medium — deeper insight |
| Sparkline trend | 1 day | Medium — visual appeal |
| Data retention/compaction | 1 day | Medium — prevents unbounded growth |

---

## Action Items

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Low risk |
| 3 | Narrow terminal test regex fragility | ⚠️ Carried | Acceptable |

---

## Score Trajectory

```
v027: 97  ████████████████▌
v028: 97  ████████████████▌
v029: 91  ███████████████
v030: 95  ████████████████
v031: 94  ███████████████▌
v032: 94  ███████████████▌
v033: 96  ████████████████   ← session cron scanner
v034: 96  ████████████████
v035: 96  ████████████████
v036: 97  ████████████████▌  ← flicker fix
v037: 97  ████████████████▌
v038: 97  ████████████████▌
v039: 97  ████████████████▌  ← maturity assessment
```

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
| 7 | Interactive TUI actions | v036 | Deep |
| 8 | Project grouping & multi-workspace | v037 | Medium |
| 9 | OpenCode/Cursor multi-assistant | v038 | Deep |
| 10 | Job health metrics & historical tracking | **v039** | **Deep — health store, scoring, sparklines** |

**All 10 brainstorm directions explored.** The review series has comprehensively mapped the project's feature space. Recommended implementation priority:

| Priority | Feature | Review | Effort | Impact |
|----------|---------|--------|--------|--------|
| 1 | Text search/filter | v036 | 1d | High |
| 2 | Sort toggle | v036 | 0.5d | Medium |
| 3 | Project grouping | v037 | 1.5d | High |
| 4 | Health metrics | v039 | 2.5d | High |
| 5 | Notifications | v035 | 2.5d | High |
| 6 | Linux systemd | v034 | 3d | High |
| 7 | Plugin system | v038 | 3d | High |

---

## Codebase Metrics

| Metric | v038 | v039 | Δ |
|--------|------|------|---|
| Production LOC | 2,509 | 2,509 | = |
| Test LOC | 4,228 | 4,228 | = |
| Test-to-code ratio | 1.69:1 | 1.69:1 | = |
| Test count | 336 | 336 | = |
| Coverage (stmts) | 90.7% | 90.7% | = |
| Coverage (branch) | 83.9% | 83.9% | = |
| Coverage (lines) | 92.2% | 92.2% | = |

---

## Summary

v039 scores **97/100** (4th consecutive, 7th in the 96-97 range). No code changes — this is a maturity assessment checkpoint. The project has reached a stable plateau with 336 tests, 90%+ coverage, and zero known bugs. Ten feature directions have been explored through the brainstorm series, providing a comprehensive roadmap for the next development phase. Job health metrics and historical tracking brainstormed as the final direction — JSONL-based health recording with composite scoring and optional sparkline trends. The recommended next implementation is text search/filter (1 day, high impact) followed by sort toggle (0.5 day, quick win).
