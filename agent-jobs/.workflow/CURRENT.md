---
milestone: M04
phase: IMPLEMENTING
cycle: 1
owner: implementer
lock_acquired_at: 2026-04-24T11:35:00Z
lock_expires_at: 2026-04-24T12:20:00Z
last_transition: 2026-04-24T11:30:00Z
last_actor: architect
---

# Current Workflow State

**Milestone:** M04 — Auto-refresh + fs.watch
**Phase:** IMPLEMENTING
**Cycle:** 1
**Owner:** none — implementer pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 SHIPPED 2026-04-24T06:40:00Z (26/26 ACs PASS, pushed)
- M02 RETRO 2026-04-24T06:55:00Z (E001 perf-gate, E002 framework-check)
- M03 SHIPPED 2026-04-24T10:30:00Z (26/26 ACs PASS first-try, pushed)
- M03 RETRO 2026-04-24T10:45:00Z (E001 + E002 → ACCEPTED)
- M04 ARCHITECTING → IMPLEMENTING 2026-04-24T11:30:00Z (architect: 8 tasks, AC-F-15 dropped, AC-V-05 kept)

## M04 architect decisions
- AC-F-15 DROPPED (M03 overlay continuity covered indirectly)
- AC-V-05 KEPT (dashboard-toolbar indicator placement is new UX surface)
- RefreshScheduler is an `actor` in `AgentJobsCore/Refresh/`, hand-rolled `DispatchWorkItem` debounce (no Combine)
- VisibilityProvider protocol in Core; `AppKitVisibilityProvider` production impl in App layer
- WatchPaths injection is the test seam; static-grep enforces no real `~/` literals

## Next
- implementer: read `.workflow/m04/architecture.md` + `tasks.md`, work T01..T08 in dependency order. Tests use swift-testing per E002. Perf ACs gated behind `AGENTJOBS_PERF=1` per E001.
