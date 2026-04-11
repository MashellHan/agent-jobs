# Agent Jobs Review -- v028
**Date:** 2026-04-11T16:45:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 948e450 + unstaged changes (main)
**Files scanned:** (no source changes — user feedback review)
**Previous review:** v027 (score 97/100, all action items resolved)

## Overall Score: 97/100 (unchanged)

**No source code changes since v027.** This review documents a **user feedback item** received during the monitoring cycle: the AGENT column is missing from the main dashboard table and needs to be restored.

---

## User Feedback: FB-5 — Add AGENT column back to the table

**User request (verbatim):**
> dashboard 上面没有 agent 了呀 需要加一列 agent

**Translation:** "There's no agent column on the dashboard anymore — need to add an AGENT column."

**Context:** During the UX redesign (plan: `elegant-meandering-diffie.md`), the AGENT column was intentionally removed from the main table and moved to the detail panel only. The rationale was "rarely needed at a glance." The user disagrees — they want to see which agent (claude-code, openclaw, manual, etc.) launched each job directly in the table.

**Priority:** P1 — User-visible UX gap.

---

## Action Items for Implementation Agent

### P1: Add AGENT column to job-table.tsx

**File:** `src/components/job-table.tsx`

Add an `agent` column to the `COL` object and render it in both `TableHeader` and `JobRow`. Suggested placement: after COMMAND, before SCHEDULE.

```
Current:  [▶] [ST] [SERVICE] [COMMAND] [SCHEDULE] [LAST RUN] [RESULT] [CREATED]
Proposed: [▶] [ST] [SERVICE] [COMMAND] [AGENT] [SCHEDULE] [LAST RUN] [RESULT] [CREATED]
```

Implementation steps:

1. **`src/components/job-table.tsx`** — Add `agent: 12` to `COL`. Add `<Box width={COL.agent}><Text bold color="magenta">{"AGENT"}</Text></Box>` to `TableHeader`. Add `<Box width={COL.agent}><Text>{truncate(job.agent, COL.agent - 1)}</Text></Box>` to `JobRow`. May need to reduce `command` width from 28 to ~22 to fit within 120-char terminal.

2. **`src/job-table.test.tsx`** — Add assertion for AGENT column header. Add test for agent display in rows (e.g., `normalJob` shows "claude-code", `liveProcessJob` shows "manual", `openclawJob` shows "openclaw").

3. **`src/__snapshots__/job-table.test.tsx.snap`** — Will auto-update when tests run with `--update` flag.

### P2: Keep AGENT in detail panel too

The detail panel (`job-detail.tsx`) already shows Agent — keep it there. No changes needed.

---

## Category Scores

| Category | Score | v027 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 30 | 30 | 0 | No code changes. 230/230 tests still pass. |
| Architecture (20pts) | 20 | 20 | 0 | No architectural changes. |
| Production-readiness (20pts) | 19 | 20 | **-1** | User-reported UX gap: AGENT column missing. |
| Open-source quality (15pts) | 14 | 14 | 0 | No changes. |
| Security (15pts) | 14 | 13 | **+1** | Re-evaluated: no security concerns after full review cycle. |
| **TOTAL** | **97** | **97** | **0** | |

---

## Communication

### To the implementation agent

#### User feedback received: add AGENT column to the dashboard table

The user noticed the AGENT column is missing from the main table. During the UX redesign, we moved it to the detail panel only — but the user wants it visible at a glance.

**What to do:**

1. Add an `agent` column (width ~12) to `job-table.tsx` — between COMMAND and SCHEDULE
2. Reduce `command` column width from 28 to ~22 to make room (total must fit 120-char terminal)
3. Display `job.agent` values: `claude-code`, `openclaw`, `manual`, etc.
4. Update `job-table.test.tsx`: add AGENT header assertion, add agent value assertions for key fixtures
5. Run `npx vitest run --update` to regenerate snapshots
6. Verify all tests pass

**Column widths after change:**
```typescript
const COL = {
  indicator: 2,
  status: 2,
  service: 18,
  command: 22,     // reduced from 28
  agent: 12,       // NEW
  schedule: 14,
  lastRun: 12,
  result: 7,
  created: 10,
};
```

Keep the Agent field in the detail panel too (it's already there — no change needed).

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
v028: 97  ████████████████  ← user feedback: add AGENT column
```

---

## Summary

v028 scores **97/100** (unchanged). No source code changes since v027. This review documents user feedback FB-5: the AGENT column was removed from the main dashboard table during the UX redesign and needs to be restored. The implementation agent should add an `agent` column (width 12) between COMMAND and SCHEDULE in `job-table.tsx`, reduce COMMAND width from 28 to 22, update tests, and regenerate snapshots. One remaining trivial issue from v027: unused `plutilCallIndex` variable in scanner.test.ts.
