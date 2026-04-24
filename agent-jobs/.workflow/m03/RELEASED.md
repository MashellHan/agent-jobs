# M03 Released

**Date:** 2026-04-24
**Final commit:** 77ae3f8
**Cycles:** IMPL=1 REVIEW=1 TEST=1 (first-try ACCEPTED)

## Summary
Actions: stop / hide / refresh. Adds row-hover and inspector action buttons backed by a `StopExecutor` protocol (real impl uses SIGTERM for live processes / `launchctl unload` for launchd; defense-in-depth refusal for PID 0, PID 1, self-PID, missing PID, missing plist, unsupported sources). Hidden services persist atomically to `~/.agent-jobs/hidden.json` with a "Show hidden" toggle. Manual refresh button forces re-discovery with spinner feedback. Confirmation dialog for destructive stop. Optimistic UI guarded against in-flight auto-refresh races. 7 visual baselines added.

## Acceptance
26/26 ACs PASS (1 SKIP-as-designed: AC-F-03 live SIGTERM double-gated behind `AGENTJOBS_LIVE_KILL=1`). See `test-cycle-001.md`.

| Category | Pass |
|---|---|
| Functional | 13/13 |
| Visual (7 baselines) | 5/5 |
| Performance | 3/3 |
| Quality (incl. 3 safety pillars) | 5/5 |

## Modules touched
- `AgentJobsCore.Actions` — `StopExecutor` protocol + `RealStopExecutor` + `FakeStopExecutor`
- `AgentJobsCore.Persistence` — `HiddenStore` actor (atomic temp+rename)
- `AgentJobsCore.Domain` — `Service.canStop` / `refusalReason` (single source of truth)
- `AgentJobsMac` — `RowActionStack`, `ServiceRowNameCell` (per-row hover state), `StopConfirmationDialog`, refresh button, hidden toggle
- `Tests/` — +48 tests (StopExecutorRefusal, StopExecutorShell, HiddenStore, ServiceRegistryViewModelActions, StaticGrepRogueRefs, plus visual baselines)

## Test count
178 → 226 (+48).

## Deferred to future milestones
- AC-F-03 live SIGTERM end-to-end run (gated on `AGENTJOBS_LIVE_KILL=1`; CI/manual operator only)
- Move `Service.withStatus` extension from App layer to Core (review M2 nit)
- Assert 4s auto-clear in `stopFailureErrorClears` test (review M1 nit)
- SIGKILL escalation (out of M03 scope)
