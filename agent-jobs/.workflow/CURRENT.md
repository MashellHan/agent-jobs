---
milestone: M04
phase: ARCHITECTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T11:15:00Z
last_actor: pm
---

# Current Workflow State

**Milestone:** M04 — Auto-refresh + fs.watch
**Phase:** ARCHITECTING
**Cycle:** 1
**Owner:** none — architect pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 SHIPPED 2026-04-24T06:40:00Z (26/26 ACs PASS, pushed)
- M02 RETRO 2026-04-24T06:55:00Z (E001 perf-gate, E002 framework-check)
- M03 SHIPPED 2026-04-24T10:30:00Z (26/26 ACs PASS first-try, pushed)
- M03 RETRO 2026-04-24T10:45:00Z (E001 + E002 → ACCEPTED)

## M04 priorities (PM should respect)
- jobs.json change → UI updates within 500ms (use DispatchSource file monitor)
- lsof rescan periodically (every 10s) — debounced, paused when window not visible to save battery
- Visual feedback: AutoRefreshIndicator (already exists) shows "live" pulse when refresh tick happens
- Must not introduce flicker, scroll-position loss, or selection loss when re-rendering
- Watch all 3 source files: `~/.agent-jobs/jobs.json`, `~/.claude/scheduled_tasks.json`, `~/.claude/projects/**/*.jsonl` (latest mtime debounced)
- Visual ACs MANDATORY: AutoRefreshIndicator states (idle/refreshing/error)
- Tester MUST verify a real file mutation triggers UI update (write to temp file under `~/.agent-jobs-test/`, NOT real ~/.agent-jobs/)

## Next
- architect: read m04/spec.md + m04/acceptance.md, write architecture.md + tasks.md (E002: skim Tests/ for swift-testing convention before authoring tasks)
