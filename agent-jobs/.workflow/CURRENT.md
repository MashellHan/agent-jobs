---
milestone: M03
phase: ARCHITECTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T07:30:00Z
last_actor: pm
---

# Current Workflow State

**Milestone:** M03 — Actions (stop / hide / refresh)
**Phase:** ARCHITECTING
**Cycle:** 1
**Owner:** none — architect pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 SHIPPED 2026-04-24T06:40:00Z (26/26 ACs PASS, pushed)
- M02 RETRO 2026-04-24T06:55:00Z (E001 implementer perf-gate, E002 architect test-framework check)
- M03 SPECCED 2026-04-24T07:30:00Z (pm: 26 ACs, 3 products surveyed, action-button placement decided = both row-hover + inspector)

## M03 priorities (PM should respect)
- Stop action: SIGTERM for live processes; `launchctl unload` for launchd; safe-guard against killing self/system PIDs
- Hide action: persist hidden set to `~/.agent-jobs/hidden.json` (atomic write); filtered out of Dashboard but visible behind a "Show hidden" toggle
- Refresh: manual button forces re-discovery; visual feedback (spinner/disabled state)
- Confirmation dialog for destructive actions (stop) — use `NSAlert` or SwiftUI `.confirmationDialog`
- Visual ACs continue to be MANDATORY — add baselines for: confirm dialog, hidden-toggle on/off, disabled action button states
- Tester WILL exercise actions on a stub registry (do NOT actually kill real processes in tests)

## Open questions for architect (from spec.md)
1. Where does `HiddenStore` live? (PM recommends `AgentJobsCore/Persistence/`)
2. Does `StopExecutor` belong in Core or Mac? (PM recommends Core)
3. Confirm SwiftUI Table row-hover affordance works on macOS 14
4. Optimistic UI vs await-then-render against in-flight auto-refresh

## Next
- architect: read `.workflow/m03/{spec,acceptance,competitive-analysis}.md`, write `.workflow/m03/architecture.md` + `.workflow/m03/tasks.md`, transition phase=IMPLEMENTING.
