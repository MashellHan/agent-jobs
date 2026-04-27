---
milestone: M05
phase: SPECCING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T11:00:00Z
last_actor: human
---

# Current Workflow State

**Milestone:** M05 — Content fidelity + Visual Harness library
**Phase:** SPECCING
**Cycle:** 1
**Owner:** none — pm pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z
- M01.5 SHIPPED 2026-04-24T01:30:00Z
- M02 SHIPPED 2026-04-24T06:40:00Z
- M03 SHIPPED 2026-04-24T10:30:00Z
- M04 SHIPPED 2026-04-24T12:55:00Z
- 2026-04-27: roadmap reshape — visual harness promoted to first-class pillar; ui-critic agent added; 8 design tickets filed (6 P0)

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

## Next
- pm: read DESIGN.md + DESIGN-TICKETS.md, do brief competitive scan (Activity Monitor row anatomy, Stats popover row, Things 3 menu bar list — what does a great row look like?), write spec/acceptance/competitive-analysis.
