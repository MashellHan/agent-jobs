---
milestone: M06
phase: TESTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T22:00:00Z
last_actor: reviewer
---

# Current Workflow State

**Milestone:** M06 — Information Architecture
**Phase:** TESTING
**Cycle:** 1
**Owner:** none — tester pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z
- M01.5 SHIPPED 2026-04-24T01:30:00Z
- M02 SHIPPED 2026-04-24T06:40:00Z
- M03 SHIPPED 2026-04-24T10:30:00Z
- M04 SHIPPED 2026-04-24T12:55:00Z
- M05 SHIPPED 2026-04-27T19:00:00Z (first multi-deliverable + first ui-critic milestone)
- M05 RETRO complete (zero new evolutions; E001/E002 settled; 3 watch-list items)
- M06 SPECCING complete 2026-04-27T19:45:00Z (pm) — spec/acceptance/competitive-analysis written; T-014 sequenced as gating task #1
- M06 ARCHITECTING complete 2026-04-27T20:15:00Z (architect) — architecture.md + tasks.md written; T-014 is task #1; WL-2 pre-committed to split before T-002 rewrite; WL-3 demotes `ProviderDiagnostics` to internal via new `DiagnosticsBearing` protocol; popover grouping lives in view layer (pure `PopoverGrouping` helper), not view model.
- M06 IMPLEMENTING cycle-1 complete 2026-04-27T21:30:00Z (implementer) — all 9 tasks landed in 8 commits; tests 317 → 332 (+15); AgentJobsMacUI.swift 504 LOC (<600); 10/10 m06 baselines fresh + 10/10 byte-stable; ProviderDiagnostics demoted to internal; implementer self-check 19/19 functional+visual ACs pass, 7 design ACs deferred to ui-critic.
- M06 REVIEWING cycle-1 complete 2026-04-27T22:00:00Z (reviewer) — verdict PASS-with-nits 89/100; all 19 verifiable functional ACs PASS; build/tests green (332 tests); T-014 harness fix verified (rows render + dark-frame corners luma < 0.3); WL-1/2/3 honored; 4 architect deviations accepted; 7 nits flagged (dead code in MenuBarPopoverView; empty-popover skips includeEmpty:true headers; ServiceRowCompact latent dead) — none blocking; advances to TESTING.

## M06 priorities (architect should respect)
**This is the first milestone with ui-critic in ENFORCING mode** (per PROTOCOL.md §UI-CRITIC). UI quality issues found in critique can REJECT the milestone back to IMPLEMENTING.

**Tickets to close (from DESIGN-TICKETS.md):**
- T-002 P0  Popover too cramped, list rows information-poor — ≥480pt wide; rich rows: program-friendly title primary, status pill, 1-line summary; group by status
- T-003 P0  Dashboard default size too small — ≥1280x800 default; sidebar 220 / inspector 360 / list gets the rest
- T-008 P1  0-count chips need explanation — hover tooltip + subtle dimming
- T-014 P0  **Dashboard Table rows + dark scheme not rendering in capture-all** (foundational — without this fix, ui-critic enforcing mode is structurally blind to half the surface area). **Architect MUST sequence as task #1.**
- T-015 P1  SourceBucketStrip vertical-stripe layout in DashboardView
- T-016 P2  Failed-row Retry affordance

**Carry-forward watch-list from M05 retro (PM kept all three in scope):**
- WL-1 Visual ↔ design AC delineation — encoded in `m06/acceptance.md` (tester for AC-F-*/AC-V-*; ui-critic for AC-D-*).
- WL-2 `AgentJobsMacUI.swift` 530 LOC split — non-blocking AC-F-17 (split if >600 LOC after IMPL). **Architect decision: split now (Task 2) BEFORE T-002 rewrite.**
- WL-3 `ProviderDiagnostics` public surface trim — non-blocking AC-F-18. **Architect decision: introduce internal `DiagnosticsBearing` protocol; demote actor to internal.**

**Constraints:**
- T-014 must be the FIRST task fixed (gates ui-critic enforcement). If `capture-all` can't render dashboard rows + dark scheme honestly, every visual finding M06+ is suspect.
- Capture-all scenarios MUST be regenerated at new sizes (popover ≥480pt, dashboard 1280x800). M05 baselines do not transfer.

## Next
- tester: pixel-diff visual baselines (AC-V-01..05); run AC-F-03 launch smoke + AC-F-19 byte-stability rerun; verify JSON sidecar field-name semantics vs `acceptance.md` AC-F-15. See `.workflow/m06/review-cycle-001.md` for findings + followups. After test PASS, transition to UI-CRITIC.
