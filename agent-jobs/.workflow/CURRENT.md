---
milestone: M08
phase: SPECCING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-27T15:00:00Z
last_actor: workflow-coordinator
---

# Current Workflow State

**Milestone:** M08 — Hook migration to Swift
**Phase:** SPECCING
**Cycle:** 1
**Owner:** (unlocked)

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
- M06 REVIEWING cycle-2 complete 2026-04-27T23:55:00Z (reviewer) — verdict **PASS 94/100**; T-017 P0 + T-018 P1 both verified closed in source; 6/6 light M06 baselines pixel-identical to cb31392; M02/M03/M04 directories show empty diff since milestone start; 332/332 tests green; dark-frame luma sample at 10 points across scenarios 02/05/08 (incl. top header band + inspector pane) all 31–46/255 — well under the 0.3 rubric threshold; 4 nits filed — none blocking; advances to TESTING cycle 2.
- M06 UI-CRITIC cycle-2 complete 2026-04-28T00:30:00Z (ui-critic) — verdict **PASS-with-tickets 27/30** (threshold 24/30); axes Clarity 5 / Density 4 / Identity 5 / Affordance 4 / Empty-Error 5 / Polish 4; AC-D-07 rubric REJECT trigger cleared; T-017 P0 + T-018 P1 visually verified closed; T-019 + T-020 remain open P2 carry-forward to M07; no new tickets filed; M06 advances to ACCEPTED.
- M06 TESTING cycle-2 complete 2026-04-28T00:10:00Z (tester) — verdict **PASS 19/19 testable ACs**; build green, 332 tests pass on clean run, capture-all 10/10 byte-stable across two reruns, 10/10 PNGs byte-identical to committed cycle-2 baselines (0% pixel diff); dark-frame luma sampling **expanded to 30 points across scenarios 02/05/08** — max luma 0.221 ≪ 0.3 threshold; advances to UI-CRITIC cycle 2.
- M06 SHIPPED 2026-04-27T01:00:00Z (workflow-coordinator) — first ENFORCING ui-critic milestone; cycle-1 REJECT 20/30 → cycle-2 PASS 27/30; 8 tickets closed; 0 new tickets; T-019/T-020 P2 carry-forward to M07.
- M07 SPECCING cycle-1 complete 2026-04-27T08:22:49Z (pm) — spec/acceptance/competitive-analysis written; T-001 P0 sequenced as gating task #1 (custom `agent-jobs.icns` + 16pt menubar template + count-badge variant); T-019 + T-020 P2 carry-forward folded in; **density modes deferred to M14** to keep M07 focused (documented cut); E003 baked into AC verification language (luma probes must be holistic, ≥8-point sample, named regions); ui-critic threshold held at 24/30; new capture-all scenarios for icon variants (idle / count-1 / count-N / count-0 dimmed) + token swatches added to scenario list (10 → 14).
- M07 ARCHITECTING cycle-1 complete 2026-04-27T09:25:00Z (architect) — `m07/architecture.md` + `m07/tasks.md` written; 5 ordered tasks, T-001 gating as Task 1; asset catalog placed in `Sources/AgentJobsMacApp/Resources/Assets.xcassets/` (AppIcon.appiconset + MenuBarIcon.imageset, raw PNG path chosen over `.symbolset` for SPM compat); 9 color sets duplicated into `Sources/AgentJobsCore/Resources/Assets.xcassets/` so `Bundle.module` resolves from non-app targets; `scripts/build-icns.sh` regenerates assets from committed SVG sources via `rsvg-convert` + `iconutil`; `DesignTokens.SemanticColor`/`SourceColor` added additively (existing `StatusColor` deprecated-typealiased — no breaking renames); `Typography.display` + `Spacing.{sm,md,lg}` aliases added to existing namespaces; T-020 resolved as **option (b) sidebar header heightens** (40pt) — no toolbar hoist; capture-all renumber 10→14 with 4 new icon scenarios + 1 swatch (`HarnessScenes.menuBarIconOnly` + `tokensSwatch`); WL-D resolved as **option B (document impl schema in DESIGN.md)** — no sidecar field renames; WL-A renames `forceAppearance` → `forceDarkAppearance` + adds dark-only precondition; WL-B short-circuits PNG/sidecar writes when bytes match prior; WL-C deletes `MenuBarPopoverView.{activeServices,upcomingServices,section(...)}` + entire `ServiceRowCompact.swift`; WL-E replaces wallpaper-sampling test with deterministic asset-catalog + offscreen-render check; ≥13 new tests planned (target 332→345+); placeholder SVG acceptable in cycle 1 if final glyph design lags (real glyph in cycle 2 is the expected REJECT-recovery path).
- M07 IMPLEMENTING cycle-1 complete 2026-04-27T11:30:00Z (implementer) — all 5 tasks landed in 6 commits; tests 332 → 358 (+26); placeholder monoline-stack SVG glyph per architecture §7 cycle-1 authorization; 6 older-milestone baselines regenerated; capture-all renumbered to 14 scenarios; WL-A..E all landed.
- M07 REVIEWING cycle-1 complete 2026-04-27T12:15:00Z (reviewer) — verdict PASS-with-nits 91/100; 358/358 tests pass; 14/14 byte-stable; 7 findings none blocking.
- M07 TESTING cycle-1 complete 2026-04-27T12:55:00Z (tester) — verdict **REJECT 24/26**; AC-V-01 (placeholder glyph central-8×8 luma 0.631 over white) + AC-V-04 (dark idle glyph captures fully transparent) both FAIL; cycle-1 REJECT-recovery path expected per architecture §7.
- M07 IMPLEMENTING cycle-2 complete 2026-04-27T13:30:00Z (implementer) — both tester FAILs closed: real service-tray glyph (central luma 0.000 light, 0.968 dark); private `MenuBarIconOnlyView` with SwiftUI `Canvas` mirror in dark branch; F1 resources warning resolved.
- M07 REVIEWING cycle-2 complete 2026-04-27T13:50:00Z (reviewer) — verdict PASS 93/100; 358/358 tests; 14/14 byte-stable; 4 nits, none blocking.
- M07 TESTING cycle-2 complete 2026-04-27T14:15:00Z (tester) — verdict PASS 18/18 testable ACs; AC-V-01 luma 0.186 < 0.2; AC-V-04 luma 0.968 > 0.7; capture-all 14/14 byte-stable; E003 holistic luma sampling expanded to 17 named regions (max 0.254 ≪ 0.3).
- M07 UI-CRITIC cycle-2 complete 2026-04-27T14:30:00Z (ui-critic) — verdict **PASS 25/30** (threshold 24/30); axes Clarity 4 / Density 4 / Identity 5 / Affordance 4 / Empty-Error 4 / Polish 4; T-001 cycle-1→cycle-2 round-trip closed exactly as architecture §7 anticipated; M06 dark-frame win holds across 03/06/09/13; 2 new P2 tickets filed (T-021 + T-022) → M14; M07 advances to ACCEPTED.
- **M07 SHIPPED 2026-04-27T15:00:00Z (workflow-coordinator)** — second ENFORCING ui-critic milestone; cycles IMPL=2 REVIEW=2 TEST=2 UI-CRITIC=1 (cycle-1 ui-critic skipped per protocol after tester REJECT); 10 tickets closed (T-001 + T-019 + T-020 + T-T01..T-T03 + WL-A..E); 2 new P2 tickets filed (T-021/T-022 → M14); +26 tests (332 → 358). Final commit `d47a2b0`.

## Next
- pm picks up M08 SPECCING cycle 1.
