---
milestone: M05
phase: ARCHITECTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T13:30:00Z
last_actor: pm
---

# Current Workflow State

**Milestone:** M05 — Content fidelity + Visual Harness library
**Phase:** ARCHITECTING
**Cycle:** 1
**Owner:** none — architect pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z
- M01.5 SHIPPED 2026-04-24T01:30:00Z
- M02 SHIPPED 2026-04-24T06:40:00Z
- M03 SHIPPED 2026-04-24T10:30:00Z
- M04 SHIPPED 2026-04-24T12:55:00Z
- 2026-04-27: roadmap reshape — visual harness promoted to first-class pillar; ui-critic agent added; 8 design tickets filed (6 P0)
- 2026-04-24T13:30:00Z: M05 SPECCING → ARCHITECTING (pm; spec + acceptance + competitive analysis + T-004 root cause written)

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
- architect: read `.workflow/m05/spec.md` + `acceptance.md` + `competitive-analysis.md`. PM left 3 open questions in spec.md §"Open questions for architect" — resolve before writing tasks.md. T-004 root cause is pre-investigated in spec.md §"Root cause" — do NOT re-investigate; design the fix.
