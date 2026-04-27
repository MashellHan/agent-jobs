---
milestone: M05
phase: IMPLEMENTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T13:55:00Z
last_actor: architect
---

# Current Workflow State

**Milestone:** M05 — Content fidelity + Visual Harness library
**Phase:** IMPLEMENTING
**Cycle:** 1
**Owner:** none — implementer pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z
- M01.5 SHIPPED 2026-04-24T01:30:00Z
- M02 SHIPPED 2026-04-24T06:40:00Z
- M03 SHIPPED 2026-04-24T10:30:00Z
- M04 SHIPPED 2026-04-24T12:55:00Z
- 2026-04-27: roadmap reshape — visual harness promoted to first-class pillar; ui-critic agent added; 8 design tickets filed (6 P0)
- 2026-04-24T13:30:00Z: M05 SPECCING → ARCHITECTING (pm; spec + acceptance + competitive analysis + T-004 root cause written)
- 2026-04-24T13:55:00Z: M05 ARCHITECTING → IMPLEMENTING (architect; architecture.md + tasks.md written, 11 tasks planned)

## M05 priorities (PM should respect)
**This is the first milestone under the new UI-quality regime.** Read `.workflow/DESIGN.md` and `.workflow/DESIGN-TICKETS.md` BEFORE writing the spec.

Four bundled deliverables:
1. **`AgentJobsVisualHarness` SwiftPM library** (new target alongside Core + Mac). Modules: `Snapshot`, `MenuBarInteraction` (closes T-007), `WindowInteraction`, `CritiqueReport`, `DiffReport`. Plus `swift run capture-all` CLI.
2. **`ServiceFormatter`** — friendly title + 1-line summary derived from Label/Program/process name (closes T-005). Applied across popover row, dashboard row, inspector header.
3. **`LiveResourceSampler`** — populates Service.metrics CPU% + RSS via `proc_pid_taskinfo` for live processes (closes T-006). Wired into refresh tick.
4. **Cron data root-cause + fix** (closes T-004) — investigate why claude-sched + cron buckets render 0; could be provider wiring, bucket mapping, or path resolution.

**Constraints:**
- ui-critic gate is ACTIVE for the first time. Spec must include scenarios for `capture-all` CLI to produce.
- Each Service must have stable identity across refresh ticks even after formatter rewrites the displayed name.
- `LiveResourceSampler` must NOT block the main thread; use background task + actor.
- No `~/.agent-jobs/` writes from tests (carry over E001/E002 + WatchPaths discipline).

## Architecture summary (architect → implementer handoff)

- **Package surgery is T01 and lands first.** `AgentJobsMac` executable splits into `AgentJobsMacUI` (library) + `AgentJobsMacApp` (thin executable). Two new targets: `AgentJobsVisualHarness` (library) + `CaptureAll` (executable). Test imports update from `AgentJobsMac` → `AgentJobsMacUI`.
- **PM Q1 resolved:** keep 5 buckets; collapse placeholder mappings to `fatalError` so the model is honest. AC-F-13 enforces.
- **PM Q2 resolved:** `capture-all` is a separate executable target.
- **PM Q3 resolved:** sampler invoked inside the existing refresh tick; visibility-pause inherited transitively (no new subscription).
- 11 tasks. Every AC mapped. Each task ≤ 150 LOC.

## Next
- implementer: read `.workflow/m05/architecture.md` + `.workflow/m05/tasks.md`. Start with T01 (package surgery) before anything else — it gates the rest. swift-testing per E002. Spec budgets gated by `AGENTJOBS_PERF=1` per E001.
