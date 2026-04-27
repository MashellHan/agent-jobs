# Retrospective M06

**Date:** 2026-04-27
**Cycles:** IMPL=2 REVIEW=2 TEST=2 UI-CRITIC=2 (first ENFORCING ui-critic milestone; cycle-1 REJECT 20/30 → cycle-2 PASS 27/30)
**Test count delta:** 317 → 332 (+15)
**Verdicts:** Reviewer cycle-1 89/100, cycle-2 94/100; Tester cycle-1 19/19, cycle-2 19/19; UI-Critic cycle-1 REJECT 20/30, cycle-2 PASS 27/30
**Tickets:** 8 closed (T-002/T-003/T-008/T-014/T-015/T-016/T-017/T-018); 0 new this milestone (T-019/T-020 P2 carry-forward existed already since cycle-1 ui-critic)

## Headline

First milestone where ui-critic ENFORCING actually wielded REJECT — and the loop worked exactly as designed. Cycle-1 IMPL/REVIEW/TEST all green (reviewer 89/100, tester 19/19), but ui-critic correctly flipped to REJECT 20/30 because the M05 P0 white-bleed condition recurred in dark scenarios 05 + 08. Cycle-2 implementer fixed it via 4 dark-only Snapshot.swift changes plus a dark-only DashboardView pane background, all gated on `isDark` so M02/M03/M04 light baselines stayed byte-stable. Cycle-2 ui-critic PASS 27/30 with all six axes ≥4/5. The M06 milestone existed precisely to prevent this gate from being structurally blind to dark-frame defects; the gate caught one and the milestone shipped honest.

## What went well

- **First ENFORCING ui-critic gate justified its existence on cycle 1.** The cycle-1 REJECT 20/30 was correctly grounded in AC-D-07's explicit rubric REJECT trigger ("half-rendered or white-bleed dark frame — M05 P0 condition recurs"). Per-scenario notes were concrete (sidebar interior light grey, top ~25pt band white, inspector pane shows only "Scheduled" pill + "Overview" tab pill on partial dark frame). 4 tickets filed (T-017 P0, T-018 P1, T-019 P2, T-020 P2) — none double-filed against existing tickets, all correctly prioritized. This is exactly the "the new gate finds gaps the old gates were structurally blind to" pattern from M05 retro, now paying dividends in enforcing mode.
- **REJECT → IMPLEMENTING cycle++ loop worked as designed.** PROTOCOL.md §8 transition fired cleanly; cycle-2 implementer picked up against T-017 P0 + T-018 P1 with clear scope; cycle-2 reviewer + tester + ui-critic all re-verified independently. No human intervention needed; no STUCK escalation.
- **Dark-only gating preserved older baselines flawlessly.** Every cycle-2 fix sits behind `if isDark` (Snapshot.swift) or `colorScheme == .dark` (DashboardView.swift). Reviewer cycle-2 ran `git diff cb31392..HEAD -- .workflow/m02 .workflow/m03 .workflow/m04` → empty diff. All 6 light M06 baselines (01, 04, 06, 07, 09, 10) byte-identical to cycle-1. This is the right discipline for a milestone that touches the rendering pipeline at root: don't bet "the right answer" against unrelated regressions; gate the change.
- **WL-2 pre-emptive split landed BEFORE the T-002 rewrite** (commit `8c56b5f` before `e8cc09d`), making the move-only diff cleanly reviewable. Architect §3.7 sequencing held; `AgentJobsMacUI.swift` ended at 504 LOC (< 600).
- **WL-3 demoted `ProviderDiagnostics` to internal** via new `internal protocol DiagnosticsBearing` — a cleaner factoring than the cycle-1 architect doc proposed. Public ABI surface shrank by one symbol. Reviewer cycle-1 confirmed `grep public.*ProviderDiagnostics → 0 matches`.
- **Architect deviations were documented and accepted.** Implementer cycle-1 listed 4 deviations in `impl-cycle-001.md` (popoverWidth stays internal, ProviderDiagnostics init reshape, tests live under AgentJobsCoreTests, Tasks 5+6 merged). Reviewer accepted all 4 with rationale. This addresses the M05 watch-list item #2 ("implementer surface drift surfaceability") — implementer correctly surfaced shape changes in impl-notes. **Watch-list item resolved.**
- **Tester cycle-2 expanded luma sampling** in direct response to the cycle-1 ui-critic finding: from 4 corners to 30 points (corners + top header band y≈30 left/mid/right + sidebar mid + inspector mid) across scenarios 02/05/08. Max luma 0.221 ≪ 0.3. The methodology delta makes the AC-F-14 numeric verification structurally robust against the same blind spot recurring.

## What surprised us

- **Cycle-1 tester missed sidebar/top-band/inspector bleed because corner-only luma sample was structurally blind.** This is the M05 watch-list item #1 ("tester treatment of empty critique-PNG content") in a different shape: not "harness ate the data" but "luma probe missed the defect because it sampled where the bug wasn't." Tester PASSed AC-F-14 at max corner luma 0.141 < 0.3, factually correct against the AC's literal wording. UI-critic caught the bleed by reading the PNGs holistically. Cycle-2 tester self-corrected by expanding sample to 30 points — good. **The pattern is real and recurring** (now 2 occurrences in 2 milestones); see Evolution proposals below.
- **NavigationSplitView per-pane `NSHostingView` children don't reliably inherit window appearance while offscreen + not key/main.** Standard Quick Look / Sparkle workaround (offscreen but ordered-front, NSApp.appearance pin, recursive forceAppearance walk + layer invalidation) was needed. Empirically determined; no SwiftUI/AppKit doc covers this combination directly. This is a systemic risk for any future milestone that adds new pane structure or new dynamic-color materials — the offscreen-capture path is fragile against AppKit appearance propagation rules. Documented in `impl-cycle-002.md` root-cause section but worth pinning to the watch-list.
- **Empty popover regressed strictly worse than M05.** Architect §3.2 explicitly specified `groupByStatus(includeEmpty: true)` for exactly this case, with the architect anticipating the regression vector. Cycle-1 implementer wired the populated path correctly but forgot the empty path, which fell through to `EmptyHintView`. Reviewer cycle-1 caught it as Finding #2 (M-severity, undocumented architect deviation). Tester cycle-1 confirmed visually but didn't fail any AC because no AC explicitly asserted empty-popover headers. UI-critic dropped Empty/Error to 2/5 (single-axis fail). Two failure modes converged to make this slip past tester: (a) no AC mapped to the architect's intent for the empty path, (b) cycle-1 implementer missed it because the populated path worked. Lesson: when the architect specifies behavior that is structurally near a default-fallback path (e.g., `services.isEmpty → EmptyHintView`), the tasks doc should pin a sentinel test for the non-default path.

## Carry-forward watch-list to M07

1. **T-019 P2 dashboard-list — Name column too narrow at 1280pt; "Last Run" header clipped.** Open since cycle-1 ui-critic; correctly deferred. M07 is the visual-identity / token milestone where layout density work logically lands.
2. **T-020 P2 dashboard-chrome — Bucket-strip header doesn't span sidebar.** Same triage as T-019.
3. **NavigationSplitView dark-mode workaround is a systemic capture-path risk.** The 4-stage dark fix in `Snapshot.swift` (NSApp.appearance pin, opaque resolved window bg, ordered-front offscreen, recursive forceAppearance + layer invalidation) is empirical, not derived from documented AppKit behavior. Any M07+ change that adds new pane structure, new `NSVisualEffectView` material, or new dynamic-color resolution could re-trigger the same bleed in a different region. Mitigation in M07: keep the 30-point luma sample as the standing AC-F-14 methodology, not the 4-corner one.
4. **`Snapshot.forceAppearance` lacks internal dark guard.** Reviewer cycle-2 F3: dark-only by virtue of call-site `if isDark`, but function itself unconditionally re-stamps `NSScrollView.backgroundColor = .windowBackgroundColor` and `drawsBackground = true`. If a future caller invokes from a light path, light-mode baselines could shift silently. M07 cleanup: rename to `forceDarkAppearance` or add `assert(appearance.name == .darkAqua)` at top.
5. **JSON sidecar timestamp churn.** Reviewer cycle-2 F4: all 10 sidecars regenerate even when PNG is byte-stable, producing noisy diffs. M07 capture-all could skip JSON rewrite when PNG bytes match.
6. **Dead helpers in `MenuBarPopoverView`** (`activeServices`, `upcomingServices`, `section(...)` from M05) + latent `ServiceRowCompact.swift` (cycle-1 reviewer F1, F5). Both unreachable after the T-002 rewrite. M07 cleanup commit.
7. **AC-F-15 sidecar schema delta.** Spec wording was `scenario / width / height / scheme / commit`; impl produced `scenarioName / metadata.viewportWidth/Height / colorScheme / appCommit`. Semantic intent met; flagged at cycle-1 by reviewer + tester, carried forward. M07: align spec text to impl OR rename impl fields.
8. **AC-V-06 menubar-icon visual flake** — pre-existing environmental, watch-list since M02 + M05 retro. Still flaking. M07 polish: gate or move to CI-only lane.

## Evolution proposals

**Two proposed.** E001 + E002 still settled (no measurement needed — three milestones running each).

### E003 (proposed) — Tester luma probe must be holistic, not corner-only

**Pattern observed:** 2 occurrences in 2 ENFORCING-ui-critic-eligible milestones (M05 advisory: tester treated empty critique-PNG content as "harness quirk" → ui-critic caught T-014; M06 cycle-1: tester PASSed AC-F-14 at corner luma 0.141 < 0.3 → ui-critic caught T-017 because bleed was interior, not corner). Both are the same root cause: tester probes the AC's literal wording, ui-critic reads the PNG holistically, and the gap is the shape of the bug.

**Proposed change:** Update `.claude/agents/tester.md` so that for any visual AC asserting "full-frame X" (where X is dark / dark frame / fully rendered / etc.), the tester's probe must sample at minimum N=8 points covering corners + interior + chrome bands (top header, sidebar interior, inspector header). The 4-corner-only sample is structurally blind to interior bleed; codify the cycle-2 tester's 30-point methodology as the floor, not the ceiling.

**Rationale:** Two occurrences in two milestones meets the ≥2 rule. Cycle-2 tester already self-corrected to 30 points after the cycle-1 REJECT — formalize that lesson so future testers don't re-discover it under a different visual AC.

**Measurement:** In M07 onward, AC-F-14-class assertions ("full-frame dark", "no white bleed") fail at the 8-point sample if any sample exceeds threshold. If M07 ships with no recurrence of corner-blind sampling, evolution is settled after one milestone of confirmation.

### E004 (proposed) — Architect-specified non-default paths require a sentinel task

**Pattern observed:** 1 occurrence (M06 cycle-1 empty-popover scaffolding fell through to default `EmptyHintView` instead of the architect-specified `groupByStatus(includeEmpty: true)` path). Single occurrence — does NOT clear the ≥2 evolution bar yet. Listed for M07 watch-list; promote to evolution if it recurs.

**Why list it now:** The shape of this near-miss is distinctive. The architect anticipated the regression vector (§3.2 explicitly mentioned `includeEmpty: true`); the cycle-1 implementer wired the populated path and missed the empty branch; no AC mapped to the architect-specified intent; reviewer caught it as M-severity but couldn't block on it; ui-critic graded the visible surface (Empty/Error 2/5). The fix in cycle-2 was trivial (one ForEach clause); the cost was a full IMPL/REVIEW/TEST/UI-CRITIC cycle.

**Watch-list:** If any M07 cycle reproduces "architect specified a non-default branch + impl missed the branch + no AC asserted it," propose at M07 retro: "tasks.md must pin a sentinel test for any non-default path the architect specifies."

## Per-agent notes (brief)

- **pm:** Strong M06 spec. Sequenced T-014 as gating task #1, named WL-1/2/3 explicitly, called out the dark-frame REJECT trigger condition in advance (AC-D-07). Spec.md "Risks/callouts" #4 + #6 explicitly anticipated the dark-frame inspector-pressure issue and the WL-2 split risk. Nothing to evolve.
- **architect:** Decisive on WL-2 (pre-emptive split before T-002 rewrite) and WL-3 (DiagnosticsBearing protocol factoring). §3.2 anticipated empty-popover regression vector. Single near-miss: tasks.md didn't pin a sentinel task for the empty-popover non-default path. See E004.
- **implementer:** Cycle-1 workmanlike across 9 tasks, surfaced 4 deviations in impl-notes (resolves M05 watch-list #2). Cycle-1 missed the empty-popover branch (architect §3.2). Cycle-2 was decisive: 4-stage dark fix grounded in actual root-cause investigation (NSHostingView/NavigationSplitView appearance propagation), all dark-gated to preserve light baselines. M02/M03/M04 baselines byte-stable post-fix.
- **reviewer:** Cycle-1 89/100 with 7 nits, all correctly non-blocking; cycle-2 94/100 with 4 nits, none blocking. Caught the empty-popover Finding #2 + sidecar schema delta + dead-code carry-forward at cycle 1. Cycle-2 reviewer ran `git diff` against M02/M03/M04 baseline directories to confirm zero drift — exactly the kind of byte-stability check the dark-only gating needed.
- **tester:** Cycle-1 PASS 19/19 testable; missed the dark-frame interior bleed because 4-corner luma was the literal AC. Cycle-2 self-corrected to 30-point sampling after the ui-critic REJECT. See E003.
- **ui-critic (first ENFORCING run):** Earned its keep on first invocation of REJECT. Cycle-1 REJECT was concrete (per-scenario notes named the surface regions, AC-D-07 trigger correctly cited); 4 tickets filed with no double-files; ticket priorities held under cycle-2 verification. Cycle-2 PASS 27/30 with axis-by-axis deltas vs cycle-1 (Identity 3→5, Empty/Error 2→5, Polish 3→4, Clarity 4→5) and explicit "PASS-with-tickets, not PASS" framing on T-019/T-020 carry-forward. The agent under-uses neither REJECT (cycle-1) nor PASS (cycle-2) — sensible verdicts at both ends. M05 retro asked "is this signal or noise?" — M06 answers signal.

## Did E001 + E002 still hold?

**Yes, both. No drift.** Three milestones running each:
- **E001 (perf gates):** Snapshot.capture cycle-2 added ~150ms per dark capture (4 dark-only fixes + extra runloop ticks); reviewer F2 noted; capture-all wallclock 2.41–2.50s vs 30s budget — well inside. AGENTJOBS_PERF=1 strict-budget gating unchanged.
- **E002 (swift-testing convention):** All +15 new tests use `@Suite`/`@Test`/`#expect`. Zero XCTest creep across the diff.

Both promoted to "settled practice" at M05 retro; remain settled.

## Watch-list carry-forward summary

8 items (3 P2 design tickets / methodology / cleanup carry-forward to M07: T-019, T-020, AC-V-06; 5 code-hygiene: NavigationSplitView dark workaround as systemic risk, `Snapshot.forceAppearance` no internal guard, JSON sidecar timestamp churn, dead helpers in `MenuBarPopoverView` + `ServiceRowCompact`, AC-F-15 sidecar schema spec-impl alignment).

2 evolution proposals (E003 promoted to evolution-grade by 2-occurrence rule; E004 listed for watch-list, promote at M07 if recurs).
