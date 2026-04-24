---
milestone: M03
phase: REVIEWING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T09:30:00Z
last_actor: implementer
---

# Current Workflow State

**Milestone:** M03 — Actions (stop / hide / refresh)
**Phase:** REVIEWING
**Cycle:** 1
**Owner:** none — reviewer pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 SHIPPED 2026-04-24T06:40:00Z (26/26 ACs PASS, pushed)
- M02 RETRO 2026-04-24T06:55:00Z (E001 implementer perf-gate, E002 architect test-framework check)
- M03 SPECCED 2026-04-24T07:30:00Z (pm: 26 ACs, 3 products surveyed, action-button placement decided = both row-hover + inspector)
- M03 ARCHITECTED 2026-04-24T07:55:00Z (architect: 10 tasks, 4 open questions resolved, swift-testing convention applied per E002)
- M03 IMPLEMENTED 2026-04-24T09:30:00Z (implementer: T01..T10 done, 226 tests passing, +46 over M02, 26/26 ACs PASS or GATED-as-designed)

## M03 architecture summary
- New Core layers: `AgentJobsCore/Actions/StopExecutor.swift` (protocol + Real + Fake), `AgentJobsCore/Persistence/HiddenStore.swift` (actor, atomic write).
- New App views: `RowActionStack`, `ServiceRowNameCell` (per-row hover state), `StopConfirmationDialog`.
- View model gains `hiddenIds`, `errorByServiceId`, `isRefreshing`, `optimisticallyStopped`, methods `stop/hide/unhide/refreshNow`.
- Six refusal predicates implemented as a pure static helper consumed by both `Service.canStop` and `RealStopExecutor.stop()` (defense in depth).
- Test isolation: `AGENTJOBS_TEST=1` set in test bundle bootstrap; `RealStopExecutor.init` `fatalError`s under that env unless `AGENTJOBS_INTEGRATION=1`. Static-grep self-test asserts no rogue references.
- Tests: swift-testing throughout (per E002).

## Next
- reviewer: read `.workflow/m03/{spec,acceptance,architecture,tasks,impl-cycle-001}.md` + the M03 commits, run `swift build` + `swift test` from `macapp/AgentJobsMac/`, audit the 26-AC matrix, decide PASS or REQUEST-CHANGES.
