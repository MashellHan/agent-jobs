---
milestone: M06
phase: TESTING
cycle: 2
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T23:55:00Z
last_actor: reviewer
---

# Current Workflow State

**Milestone:** M06 — Information Architecture
**Phase:** TESTING
**Cycle:** 2 (after reviewer cycle-2 PASS 94/100)
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
- M06 TESTING cycle-1 complete 2026-04-27T22:30:00Z (tester) — verdict PASS 19/19 testable ACs (7 AC-D-* deferred to ui-critic); build green, 332 tests pass, capture-all 10/10 byte-stable across two reruns, 10/10 PNGs byte-identical to committed baselines (0% pixel diff vs AC-V-01..05 1% threshold), 4-corner luma on dark scenarios (02/05/08) max 0.141 < 0.3; AC-F-15 sidecar schema delta flagged borderline (semantic intent met; field names diverge from spec wording); empty-popover scenario 03 has no group headers (reviewer Finding #2 carried forward to ui-critic); advances to UI-CRITIC.
- M06 UI-CRITIC cycle-1 complete 2026-04-27T22:50:00Z (ui-critic) — verdict **REJECT 20/30**; AC-D-07 rubric REJECT trigger fires (white-bleed dark frame + half-rendered inspector — M05 P0 condition recurs in scenarios 05 and 08); empty-popover (03) regressed vs. M05 (Empty/Error 2/5); 4 new tickets filed (T-017 P0, T-018 P1, T-019 P2, T-020 P2); cycle 2 IMPLEMENTING required — focus on T-017 (dark dashboard chrome + inspector header). Tester's 4-corner luma sample missed the bleed because it lives in the sidebar interior + top header band + inspector header, not at the corners.
- M06 IMPLEMENTING cycle-2 complete 2026-04-27T23:30:00Z (implementer) — T-017 P0 + T-018 P1 closed; root cause for T-017 was NavigationSplitView per-pane NSHostingView children failing to inherit window appearance while offscreen + not key/main, fixed via 4 dark-only changes (NSApp.appearance pin, opaque resolved-against-target window bg, ordered-front offscreen, recursive forceAppearance walk + layer invalidation) + DashboardView pane `.background(paneBackground)` gated to dark via `@Environment(\.colorScheme)`; T-018 wired `PopoverGrouping.groupByStatus(includeEmpty: true)` so the empty popover renders RUNNING/SCHEDULED/FAILED scaffolding with per-group microcopy; **all 332 tests pass, M02/M03/M04 light baselines byte-stable** after restoring via `git checkout`; 10 m06 baselines + 10 critique PNGs regenerated; visual confirmation of scenarios 03, 05, 08 attached in `.workflow/m06/impl-cycle-002.md`.
- M06 REVIEWING cycle-2 complete 2026-04-27T23:55:00Z (reviewer) — verdict **PASS 94/100**; T-017 P0 + T-018 P1 both verified closed in source (Snapshot.swift `isDark` gating on all 4 fixes; DashboardView dark-only `paneBackground`; MenuBarPopoverView `emptyGroupedServices` ForEach with `includeEmpty: true` and per-group microcopy); 6/6 light M06 baselines pixel-identical to cb31392 (PIL byte-compare); M02/M03/M04 directories show empty diff since milestone start; 332/332 tests green; dark-frame luma sample at 10 points across scenarios 02/05/08 (incl. top header band + inspector pane) all 31–46/255 — well under the 0.3 rubric threshold; 4 nits filed (carry-forward dead code in MenuBarPopoverView; ~150ms dark-capture overhead; `forceAppearance` lacks internal dark guard; baseline JSON timestamp churn) — none blocking; advances to TESTING cycle 2.

## M06 priorities (cycle 2)
- T-017 P0 closed — dark dashboard chrome + inspector header now render fully (verified by reading regenerated baselines 05 + 08).
- T-018 P1 closed — empty popover restores group-header scaffolding + per-section microcopy.
- T-019 P2, T-020 P2 — deferred to M07.

## Carry-forward (unchanged)
- WL-1 / WL-2 / WL-3 status from cycle 1 holds (all PASS).

## Next
- tester cycle 2: re-run capture-all twice for byte-stability; re-execute dark-frame luma rubric on scenarios 02/05/08 sampling top header band y≈30 + inspector mid-pane (not just 4 corners — that was the cycle-1 miss); re-evaluate AC-D-07; advance to UI-CRITIC cycle 2 on PASS.

