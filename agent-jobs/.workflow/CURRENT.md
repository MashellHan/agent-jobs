---
milestone: M06
phase: IMPLEMENTING
cycle: 2
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T22:50:00Z
last_actor: ui-critic
---

# Current Workflow State

**Milestone:** M06 — Information Architecture
**Phase:** IMPLEMENTING
**Cycle:** 2 (after ui-critic REJECT cycle 1)
**Owner:** none — implementer pick up

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

## M06 priorities (cycle 2)
**Cycle 2 blocker (must fix to lift REJECT):**
- **T-017 P0  visual-harness  Dark dashboard chrome + inspector header bleed light** (NEW — opened by ui-critic cycle 1). Scenarios 05 and 08 must render fully dark across sidebar, top header band (bucket strip), inspector header, and inspector grid body. Verify by sampling 3 non-corner regions (sidebar interior, top-of-list-pane band, inspector header band) for luma < 0.3.

**Cycle 2 nice-to-have (not REJECT-blocking):**
- T-018 P1 empty-popover regression (defer to M07 acceptable per ticket)
- T-019 P2 Name column truncation
- T-020 P2 bucket-strip header alignment

**Re-baselining requirement:**
- After T-017 lands, the 10 m06 baselines/critique PNGs must be regenerated. Tester re-runs AC-V-* pixel-diff against new baselines; ui-critic re-scores rubric on cycle-2 critique set.

**Carry-forward (unchanged):**
- WL-1 / WL-2 / WL-3 status from cycle 1 holds (all PASS).

## Next
- implementer cycle 2: read `.workflow/m06/ui-review.md` + DESIGN-TICKETS T-017; reproduce 05/08 locally; trace dark-mode propagation through `DashboardView` snapshot path; ensure `preferredColorScheme(.dark)` (or NSHostingView.appearance config) reaches sidebar + top toolbar + inspector header surfaces; regenerate 10 baselines + critique PNGs; commit; transition to REVIEWING cycle 2.
