# Agent Jobs Review -- v019 (User UX Feedback)
**Date:** 2026-04-11T13:15:00Z
**Reviewer:** Claude Code (Automated)
**Trigger:** Direct user feedback — 5 UX issues with TUI dashboard
**Git HEAD:** 3186cb0 (main)
**Previous review:** v018 (score 99/100)

## Overall Score: 92/100 (-7)

**Score dropped from 99 to 92 due to user UX feedback.** The user identified 5 concrete issues with the dashboard's readability and information architecture. While the code is technically excellent (162 tests, 91.99% coverage, no race conditions), the dashboard fails to communicate critical information to users. These are not code bugs — they are UX design gaps that affect the tool's usability.

---

## User Feedback (Verbatim)

> 1. name 不清晰 不知道是什么服务
> 2. 没有执行的命令
> 3. schedule 不清晰,不知道是小时的还是天的. source 不知道是什么意思. Age 不清晰 应该说最近一次 run. 以及最近一次的结果
> 4. 还有创建时间不清楚
> 5. detail 里面没有 history 服务信息

---

## Issue Analysis

### UX-1: SERVICE — Name is unclear (HIGH)
**Current:** Column header `JOB NAME` shows names like `node server.js`, `pm2 api.js`
**Problem:** Users can't tell what the service actually is or does
**Fix:** Rename column to `SERVICE`. The name data is fine — the header label is misleading.

### UX-2: COMMAND — No executed command visible (HIGH)
**Current:** The command is buried in a dimmed description sub-row beneath the job row
**Problem:** Users need to see what command runs this service at a glance
**Fix:** Add a `COMMAND` column that shows `job.description` (the actual command) truncated. Remove the dimmed sub-row — it's now a proper column.

### UX-3: SCHEDULE/SOURCE/AGE — Labels are confusing (HIGH)
**Current columns and problems:**

| Current | Problem | Fix |
|---------|---------|-----|
| `SCHEDULE` | "0 2 * * *" vs "always-on" — unclear if hourly or daily | Rename to `FREQUENCY` |
| `SOURCE` | "registered", "live", "cron" — what do these mean to a user? | Remove from table, move to detail panel with explanation |
| `AGE` | Shows `created_at` relative time — user expects last execution time | Rename to `LAST RUN`, show `job.last_run` relative time |

### UX-4: CREATED — Creation time not visible (MEDIUM)
**Current:** `created_at` is displayed as `AGE` column (relative time). Once `AGE` becomes `LAST RUN`, creation time disappears from table.
**Fix:** Add a `CREATED` column showing `job.created_at` relative time.

### UX-5: HISTORY — Detail panel lacks history (MEDIUM)
**Current detail fields:** Description, Agent, Schedule, Project, Source, Status, Created, Next Run, Run Count, Last Result
**Problem:** No visual grouping, no `Last Run` timestamp, no history section, Source shows raw enum without explanation
**Fix:** Restructure detail panel with section headers and add missing fields.

---

## Proposed Design (Reference for Implementation Agent)

### Table Redesign

**Current layout:**
```
[▶] [ST] [JOB NAME         ] [AGENT       ] [SCHEDULE    ] [SOURCE    ] [AGE       ] [RESULT ]
 ▶   ●   my-web-server       claude-code    always-on      registered   1d ago       success
          node src/server.js --port 3000   (dimmed sub-row)
```

**Proposed layout:**
```
[▶] [ST] [SERVICE          ] [COMMAND                 ] [FREQUENCY   ] [LAST RUN  ] [CREATED   ] [RESULT ]
 ▶   ●   my-web-server       node src/server.js --po…   always-on      5m ago       1d ago       success
```

Suggested column widths:
```typescript
const COL = {
  indicator: 2,
  status: 3,
  name: 20,       // SERVICE (was JOB NAME 24)
  command: 24,     // COMMAND (new — shows job.description)
  frequency: 12,   // FREQUENCY (was SCHEDULE)
  lastRun: 10,     // LAST RUN (was AGE, now shows job.last_run)
  created: 10,     // CREATED (new — shows job.created_at)
  result: 7,       // RESULT (unchanged)
};
```

Key decisions:
- Remove `AGENT` column from table (rarely useful at glance, still in detail panel)
- Remove `SOURCE` column from table (confusing label, move to detail with explanation)
- Remove description sub-row (command is now a proper column)
- `LAST RUN` shows `formatRelativeTime(job.last_run)`, falls back to `-` if null

### Detail Panel Redesign

Add section headers and missing `Last Run` field. Humanize `Source` labels.

```
┌─────────────────────────────────────────────────┐
│  Service:     my-web-server                     │
│  Command:     node src/server.js --port 3000    │
│  Status:      ● active                          │
│  Agent:       claude-code                       │
│  Source:      hook (auto-detected)              │
│  Project:     /Users/dev/my-project             │
│  Port:        3000                              │
│  PID:         12345                             │
│                                                 │
│  ── Schedule ──                                 │
│  Frequency:   always-on                         │
│  Next Run:    -                                 │
│                                                 │
│  ── History ──                                  │
│  Created:     2026-04-10 10:00 (1d ago)         │
│  Last Run:    2026-04-11 13:10 (5m ago)         │
│  Run Count:   5 runs                            │
│  Last Result: ● success                         │
│                                                 │
│  ESC or d to close                              │
└─────────────────────────────────────────────────┘
```

Source label mapping for detail panel:
```
"registered" → "hook (auto-detected)"
"live"       → "process (live scan)"
"cron"       → "scheduled (Claude cron)"
"launchd"    → "launchd (macOS)"
```

### Utility Function

Add `sourceLabel(source: JobSource): string` to `utils.ts` for the detail panel source display.

---

## Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `src/components/job-table.tsx` | Redesign columns: SERVICE, COMMAND, FREQUENCY, LAST RUN, CREATED, RESULT | **P0** |
| `src/components/job-detail.tsx` | Section headers, Last Run field, source labels, Command field | **P0** |
| `src/utils.ts` | Add `sourceLabel()` function | **P1** |
| `src/job-table.test.tsx` | Update column header assertions and snapshot expectations | **P1** |
| `src/utils.test.ts` | Add `sourceLabel` tests | **P1** |
| `src/app.test.tsx` | Update column header assertions | **P2** |

---

## Category Scores

| Category | Score | v018 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 30 | 30 | -- | 162 tests pass, no bugs |
| Architecture (20pts) | 20 | 20 | -- | Clean component structure |
| Production-readiness (20pts) | 15 | 20 | **-5** | Dashboard doesn't surface critical info (last run, command) |
| Open-source quality (15pts) | 13 | 15 | **-2** | UX confuses users — poor column naming |
| Security (15pts) | 14 | 14 | -- | Unchanged |
| **TOTAL** | **92** | **99** | **-7** | |

---

## Communication

### To the implementation agent

#### Context

The user tested the dashboard and reported 5 UX issues. These are **direct user feedback**, not reviewer opinions. They must be addressed.

#### Priority order

1. **Table columns** (P0) — This is the most visible change. Rename headers, add COMMAND column, replace AGE with LAST RUN, add CREATED.
2. **Detail panel** (P0) — Add section headers, Last Run field, source labels.
3. **sourceLabel utility** (P1) — Small helper for human-friendly source text.
4. **Tests** (P1/P2) — Update after code changes.

#### Design guidance

The proposed column layout and detail panel design above are **suggestions, not mandates**. If you find a better approach that addresses all 5 user issues, go for it. The hard requirements are:

- [ ] UX-1: User can immediately identify what each service is
- [ ] UX-2: The executed command is visible without expanding detail
- [ ] UX-3: Schedule frequency is unambiguous, Source is either gone or explained, AGE shows last run time
- [ ] UX-4: Creation time is visible in the main table
- [ ] UX-5: Detail panel has a History section with Last Run, Run Count, and grouped fields

#### Note on test updates

The table redesign will break existing snapshot tests and column header assertions. Plan for this — update tests in the same commit to keep the build green.

---

## Summary

v019 drops to **92/100** (-7) based on direct user feedback. Five UX issues identified: unclear service names, missing command visibility, confusing column labels (Schedule/Source/Age), missing creation time, and no history in the detail panel. All are fixable with a table column redesign and detail panel restructure. The underlying code quality (162 tests, 91.99% coverage) remains excellent — this is purely a UX/information-architecture issue.
