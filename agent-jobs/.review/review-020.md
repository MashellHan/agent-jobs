# Agent Jobs Review -- v020
**Date:** 2026-04-11T14:20:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 8177b56 + unstaged changes (main)
**Files scanned:** job-table.tsx, job-detail.tsx, utils.ts, utils.test.ts, fixtures.ts
**Previous review:** v019 (score 92/100, user UX feedback)

## Overall Score: 88/100 (-4)

The implementation agent has started addressing the 5 UX issues from review-019 but the work is **incomplete**: 8 tests are failing because `job-table.test.tsx` was not updated to match the new column layout. The source changes themselves are correct — table redesign, detail panel improvements, `sourceToHuman()` utility — but shipping with broken tests drops the score.

---

## What Was Done (Correct)

### 1. Table columns redesigned (`job-table.tsx`) — UX-1, UX-2, UX-3, UX-4 ✅

**Before:**
```
[▶] [ST] [JOB NAME] [AGENT] [SCHEDULE] [SOURCE] [AGE] [RESULT]
```

**After:**
```
[▶] [ST] [SERVICE] [COMMAND] [SCHEDULE] [LAST RUN] [RESULT] [CREATED]
```

Changes made:
- `JOB NAME` → `SERVICE` (22 chars) — **UX-1 addressed**
- New `COMMAND` column (34 chars, shows `job.description`) — **UX-2 addressed**
- `AGENT` removed from table — moved to detail panel
- `SOURCE` removed from table — moved to detail panel
- `AGE` → `LAST RUN` (shows `job.last_run` relative time) — **UX-3 addressed**
- New `CREATED` column (12 chars, shows `job.created_at` relative time) — **UX-4 addressed**
- Description sub-row removed (command is now a proper column)
- `SCHEDULE` column dimColor removed (now regular text — more readable)

### 2. Detail panel improved (`job-detail.tsx`) — UX-5 ✅

Changes made:
- `Description` → `Command` (same data, clearer label)
- `Source` now shows `sourceToHuman(job.source)` instead of raw enum
- `Last Run` field added with full timestamp + relative time
- "Run History" section at bottom with last run entry and "... and N earlier runs" summary
- Fields reordered logically

### 3. `sourceToHuman()` utility added (`utils.ts`) — UX-3 ✅

```typescript
export function sourceToHuman(source: string): string {
  switch (source) {
    case "registered": return "Hook-registered";
    case "live": return "Live process";
    case "cron": return "Cron schedule";
    case "launchd": return "macOS launchd";
    default: return source;
  }
}
```

5 tests added in `utils.test.ts`. All pass.

### 4. Fixtures expanded (`fixtures.ts`)

Added 2 new fixtures:
- `openclawJob` — OpenClaw agent with `*/30 * * * *` schedule
- `neverRunJob` — Job with `last_run: null` testing the `-` fallback

---

## What Is BROKEN — 8 Failing Tests

**File:** `src/job-table.test.tsx` — NOT updated for new column layout.

| # | Test | Failure Reason |
|---|------|----------------|
| 1 | `renders all column headers` | Expects `"JOB NAME"` — now `"SERVICE"` |
| 2 | `renders a normal job with correct columns` | Expects `"claude-cod"` (agent column) — removed |
| 3 | `truncates long names with ellipsis` | Expects `"…"` in first line — column wider, no truncation needed |
| 4 | `renders live source label` | Expects `"live"` — SOURCE column removed from table |
| 5 | `displays 'pew sync' service name` | Expects `"claude-cod"` — agent column removed |
| 6 | `shows description under the job name row` | Expects full description string — sub-row removed, now COMMAND column |
| 7 | `shows description for live process job` | Same — sub-row removed |
| 8 | `header and rows have matching column starts` | Column positions shifted |

**All 8 failures are test assertions that haven't been updated, not code bugs.** The source code changes are correct.

---

## Category Scores

| Category | Score | v019 | Delta | Reason |
|----------|-------|------|-------|--------|
| Correctness (30pts) | 22 | 30 | **-8** | 8/167 tests failing — build is RED |
| Architecture (20pts) | 20 | 20 | -- | Column redesign is architecturally sound |
| Production-readiness (20pts) | 18 | 15 | **+3** | UX issues being addressed (table, detail, source labels) |
| Open-source quality (15pts) | 14 | 13 | **+1** | Better column naming, sourceToHuman, expanded fixtures |
| Security (15pts) | 14 | 14 | -- | Unchanged |
| **TOTAL** | **88** | **92** | **-4** | |

---

## Action Items for Implementation Agent

### P0: Fix failing tests (BLOCKING)

Update `src/job-table.test.tsx` to match the new column layout. Specific fixes needed:

1. **Header test:** Replace `"JOB NAME"` → `"SERVICE"`, remove `"AGENT"` and `"SOURCE"` assertions, add `"COMMAND"`, `"LAST RUN"`, `"CREATED"`

2. **Normal job test:** Remove `"claude-cod"` (agent) and `"registered"` (source) assertions. Add assertion for command text.

3. **Truncation test:** Adjust for new `service` column width (22 chars). The long name `my-very-long-container-image-name-that-exceeds-column-width` should still truncate at 21 chars.

4. **Live source test:** Remove — SOURCE column no longer in table. Or rewrite to verify COMMAND column shows the live process command.

5. **Pew sync test:** Remove `"claude-cod"` assertion. Keep `"pew sync"` and `"success"`.

6. **Description sub-row tests (2):** Rewrite to test COMMAND column instead of sub-row. The command text is now in the COMMAND column, not a sub-row.

7. **Column alignment test:** Update column indices for new layout.

### P1: Snapshot regeneration

After fixing tests, run `npx vitest run -u` to update snapshots.

### P2: Consider section headers in detail panel

Review-019 suggested section headers (`── Schedule ──`, `── History ──`) for visual grouping in the detail panel. The current implementation has "Run History:" but no section headers for the other groups. Consider adding them for consistency. This is optional — the current layout is functional.

---

## UX Feedback Conformance

| # | User Feedback | Status | Notes |
|---|---------------|--------|-------|
| UX-1 | name 不清晰 | **DONE** | `JOB NAME` → `SERVICE` |
| UX-2 | 没有执行的命令 | **DONE** | New `COMMAND` column (34 chars) |
| UX-3 | schedule/source/age 不清晰 | **DONE** | SOURCE removed from table, AGE→LAST RUN, source has human labels |
| UX-4 | 创建时间不清楚 | **DONE** | New `CREATED` column |
| UX-5 | detail 没有 history | **DONE** | Run History section added with "... and N earlier runs" |

All 5 user UX issues are addressed in the code. **Only the tests need updating.**

---

## Communication

### To the implementation agent

#### Good progress, just finish the tests

The table redesign and detail panel improvements are exactly what review-019 requested. All 5 user UX issues are addressed in the source code. The column layout is clean and the `sourceToHuman()` utility is well-implemented.

**The only blocker is 8 failing tests in `job-table.test.tsx`.** These are straightforward assertion updates — the test logic doesn't need to change, just the expected strings and column references. This should take about 10 minutes.

After fixing:
1. Run `npx vitest run --coverage` to verify all green
2. Run `npx vitest run -u` if snapshots need updating
3. Commit all changes together

#### Nice touches

- The `openclawJob` and `neverRunJob` fixtures are good additions for testing edge cases
- The "Run History" section with "... and N earlier runs" is a thoughtful UX pattern
- Removing dimColor from SCHEDULE makes it more readable

---

## Summary

v020 scores **88/100** (-4). Implementation agent started addressing all 5 user UX issues from review-019: table columns redesigned (SERVICE, COMMAND, LAST RUN, CREATED), detail panel improved (sourceToHuman, Last Run, Run History), `sourceToHuman()` utility added. However, 8 tests in `job-table.test.tsx` are failing because they weren't updated for the new column layout. The code changes are correct — only test assertions need updating. Expected recovery to 97+ once tests are green.
