---
milestone: M06
phase: SPECCING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T19:15:00Z
last_actor: human
---

# Current Workflow State

**Milestone:** M06 — Information Architecture
**Phase:** SPECCING
**Cycle:** 1
**Owner:** none — pm pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z
- M01.5 SHIPPED 2026-04-24T01:30:00Z
- M02 SHIPPED 2026-04-24T06:40:00Z
- M03 SHIPPED 2026-04-24T10:30:00Z
- M04 SHIPPED 2026-04-24T12:55:00Z
- M05 SHIPPED 2026-04-27T19:00:00Z (first multi-deliverable + first ui-critic milestone)
- M05 RETRO complete (zero new evolutions; E001/E002 settled; 3 watch-list items)

## M06 priorities (PM should respect)
**This is the first milestone with ui-critic in ENFORCING mode** (per PROTOCOL.md §UI-CRITIC). UI quality issues found in critique can REJECT the milestone back to IMPLEMENTING.

**Tickets to close (from DESIGN-TICKETS.md):**
- T-002 P0  Popover too cramped, list rows information-poor — ≥480pt wide; rich rows: program-friendly title primary, status pill, 1-line summary; group by status
- T-003 P0  Dashboard default size too small — ≥1280x800 default; sidebar 220 / inspector 360 / list gets the rest
- T-008 P1  0-count chips need explanation — hover tooltip + subtle dimming
- T-014 P0  **Dashboard Table rows + dark scheme not rendering in capture-all** (foundational — without this fix, ui-critic enforcing mode is structurally blind to half the surface area)
- T-015 P1  SourceBucketStrip vertical-stripe layout in DashboardView
- T-016 P2  Failed-row Retry affordance

**Carry-forward watch-list from M05 retro:**
- "Tester waving past visual quirks" — ui-critic should be the gate, not tester. Spec must clearly delineate visual ACs (tester verifies) from design ACs (ui-critic verifies).
- `AgentJobsMacUI.swift` is 530 LOC — split candidate, do it as one of the M06 tasks if architect agrees.
- `ProviderDiagnostics` actor public surface widening — clean up if PM agrees it's M06 scope.

**Constraints:**
- T-014 must be the FIRST task fixed (gates ui-critic enforcement). If `capture-all` can't render dashboard rows + dark scheme honestly, every visual finding M06+ is suspect.
- Spec must produce updated `capture-all` scenarios reflecting the new IA (≥480pt popover, ≥1280x800 dashboard).

## Next
- pm: read DESIGN.md + DESIGN-TICKETS.md (esp. T-002/T-003/T-008/T-014/T-015/T-016) + M05 ui-review.md. Brief competitive scan on dashboard IA (Activity Monitor 3-pane sizing, Things 3 popover anatomy, Linear list density). Write spec/acceptance/competitive-analysis.
