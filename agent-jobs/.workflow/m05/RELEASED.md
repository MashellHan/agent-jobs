# M05 Released

**Date:** 2026-04-27
**Final commit:** b020b7a
**Cycles:** IMPL=1 REVIEW=1 TEST=1 UI-CRITIC=1 (first-try ACCEPTED across all 4 gates)

## Summary
Content fidelity + Visual Harness library — first milestone under the new UI-quality regime. Four bundled deliverables shipped: (1) new `AgentJobsVisualHarness` SwiftPM library (`Snapshot`/`MenuBarInteraction`/`WindowInteraction`/`CritiqueReport`/`DiffReport`) plus `capture-all` executable producing 10 PNG+JSON pairs in <2s. (2) `ServiceFormatter` (friendly title + 1-line summary) wired across popover row, dashboard row, inspector header — closes T-005. (3) `LiveResourceSampler` actor populating CPU%/RSS via `proc_pid_taskinfo` off main thread — closes T-006. (4) Cron T-004 root-cause fix: `ClaudeSessionCronProvider` no longer silently swallows per-file parse failures; `ProviderDiagnostics` actor surfaces `lastError` + per-file failure map; chip-tooltip plumbing added. Package surgery: `AgentJobsMac` executable renamed to `AgentJobsMacApp`; new `AgentJobsMacUI` library extracted; 5-target package compiles cleanly. PROTOCOL.md gains UI-CRITIC phase (advisory in M05, enforcing from M06).

## Acceptance
24/24 ACs PASS (tester) + ui-critic PASS-with-tickets 22/30 advisory.

| Gate | Verdict |
|---|---|
| Reviewer | PASS 91/100 |
| Tester | PASS 24/24 ACs |
| UI-Critic | PASS-with-tickets 22/30 (advisory mode) |

## Tickets closed
- T-004 Cron empty buckets — diagnostics surface, root cause documented (no scheduled_tasks.json on user's machine)
- T-005 Unreadable job names — ServiceFormatter applied 3 sites
- T-006 Missing CPU/Memory — LiveResourceSampler populates metrics
- T-007 Visual harness can't drive popover — MenuBarInteraction shipped (AX + CGEvent)

## Tickets filed (during ui-critic review)
- T-014 P0 Dashboard Table rows + dark scheme not rendering in capture-all → M06
- T-015 P1 Source-bucket-strip vertical-stripe layout in DashboardView → M06
- T-016 P2 Failed-row Retry affordance → M06

## Modules touched
- New SwiftPM target: `AgentJobsVisualHarness` library
- New SwiftPM target: `capture-all` executable
- Target rename: `AgentJobsMac` exe → `AgentJobsMacApp` exe
- New SwiftPM target: `AgentJobsMacUI` library (extracted from old executable)
- `AgentJobsCore.Domain` — `ServiceFormatter` (formatted: title/subtitle/summary)
- `AgentJobsCore.Resources` — `LiveResourceSampler` actor
- `AgentJobsCore.Discovery` — `ProviderDiagnostics` actor; provider error surfacing
- `AgentJobsMacUI` — formatter applied at row + inspector; chip-tooltip with errorMessage
- `Tests/` — +51 tests (Harness, Formatter, Sampler, Diagnostics, CollapseHealth, UICriticSmoke, etc.)
- `scripts/ui-critic-smoke.sh` — end-to-end harness CLI smoke
- `.workflow/PROTOCOL.md` — UI-CRITIC phase node + 60min lock TTL

## Test count
266 → 317 (+51).

## Deferred
- T-014 dashboard rendering in critique CLI (P0 → M06)
- T-015 source-bucket strip layout (P1 → M06)
- T-016 retry affordance (P2 → M06)
- M2: ProviderDiagnostics public surface widening (review nit → M06)
- AC-V-06 menubar-icon visual flake — pre-existing environmental, watch-list
