# M06 Acceptance Criteria

> Each AC has a single verifier: `tester` or `ui-critic`.
> - **Functional ACs** (tester): behavior, code structure, test counts. Pass = green build/tests + observed behavior matches.
> - **Visual ACs** (tester): pixel-diff against committed baselines under `.workflow/m06/screenshots/baseline/`. Pass = diff < 1%.
> - **Design ACs** (ui-critic): rubric-scored on `.workflow/m06/screenshots/critique/` PNGs. Pass = rubric expectation met per surface.

Total: 26 ACs. Tester: 19. UI-critic: 7.

---

## A. Functional ACs (tester)

**AC-F-01** `swift build` is green for all 5 targets (`AgentJobsCore`, `AgentJobsMacUI`, `AgentJobsMacApp`, `AgentJobsVisualHarness`, `capture-all`). [tester]

**AC-F-02** `swift test` is green; total test count ≥ 330 (M05 ended at 317; M06 adds ≥13 new unit/visual tests). [tester]

**AC-F-03** App launches without crash; menu bar icon click opens popover; popover renders ≥1 row when fixture registry is populated. [tester]

**AC-F-04** Popover content view declares default width ≥ 480pt (verified by reading the SwiftUI `.frame(minWidth:)` modifier in the popover root view; must not be < 480). [tester]

**AC-F-05** Popover rows are grouped by status: `running` group first, then `scheduled`, then `failed`, then any other. Group order is deterministic and tested. [tester]

**AC-F-06** Each popover row exposes (a) program-friendly title (from `ServiceFormatter.title`), (b) status pill view, (c) one-line summary (from `ServiceFormatter.summary`). All three are rendered and non-empty for the populated fixture; tested via view-tree introspection or snapshot text scan. [tester]

**AC-F-07** Dashboard window opens at default size ≥ 1280 × 800. Verified via `NSWindow.contentRect(forFrameRect:)` or window-config code path. [tester]

**AC-F-08** Dashboard `NavigationSplitView` columns: sidebar = 220pt (preferred), inspector = 360pt (preferred), list = remaining. Verified via SwiftUI column-width modifiers. [tester]

**AC-F-09** Dashboard list pane has `minWidth = 480`; below that the inspector hides (or collapses), not the list. Tested via resize unit test. [tester]

**AC-F-10** `SourceBucketStrip` in `DashboardView` renders horizontally (chips laid out along the X axis); chip count = source count; "total N" label fits on one line. Tested by snapshot of the strip alone in dashboard context. [tester]

**AC-F-11** 0-count source chip carries (a) `accessibilityHelp` / `.help()` tooltip text describing why it's zero (e.g., "No claude-loop crons found in ~/.claude/projects/"), (b) reduced opacity (≤ 0.6). Tested by chip view introspection. [tester]

**AC-F-12** When a `Service.status == .failed` is rendered in popover, its row trailing slot exposes a `Retry` affordance (button or `Image(systemName: "arrow.clockwise")` tap target). Affordance is reachable via keyboard. Tested via row view-tree assertion. [tester]

**AC-F-13** T-014 fix: `capture-all` produces dashboard PNGs (04/05/07/08) where the `Table` body contains ≥3 rendered rows for the populated fixture. Verified by image content check (non-blank rectangle within list bounds) or pixel-histogram test. [tester]

**AC-F-14** T-014 fix: dashboard dark scenarios (05, 08) render with a single dark background across the entire frame — no white bleed. Verified by sampling 4 corners of the PNG and asserting background-luminance < 0.3. [tester]

**AC-F-15** All 10 capture-all scenarios from `spec.md` produce PNG + JSON sidecars; JSON metadata includes `width`, `height`, `scheme`, `scenario`, `commit`. [tester]

**AC-F-16** Committed visual baselines under `.workflow/m06/screenshots/baseline/` are regenerated for all 10 scenarios at new sizes (popover ≥480, dashboard 1280×800). M05 baselines must not be reused. [tester]

**AC-F-17** (WL-2, non-blocking — soft pass) If `AgentJobsMacUI.swift` exceeds 600 LOC after IMPL, it MUST be split into ≥2 files (`MenuBarPopoverView.swift` + at least one of `MenuBarRowViews.swift` / `SourceBucketStrip.swift`). If under 600 LOC, no action required. Tester reports LOC + decision. [tester]

**AC-F-18** (WL-3, non-blocking) `ProviderDiagnostics` public surface trimmed: any symbol made `public` in M05 only for chip-tooltip wiring is reduced to `internal` if M06 chip-tooltip path doesn't need it. Tester diffs public API symbols against M05 baseline. [tester]

**AC-F-19** Re-running `swift run capture-all --out .workflow/m06/screenshots/critique/` twice yields byte-stable outputs for at least 8/10 scenarios (allowing 2 known-flaky environmental scenarios — e.g., menubar coordinate sampling — per M05 watch). [tester]

---

## B. Visual ACs (tester — pixel diff)

**AC-V-01** `01-menubar-popover-light.png` matches committed baseline within 1% pixel diff at 480 × auto. [tester]

**AC-V-02** `02-menubar-popover-dark.png` matches baseline within 1% at 480 × auto, dark scheme. [tester]

**AC-V-03** `04-dashboard-populated-light.png` matches baseline within 1% at 1280 × 800 — INCLUDING populated row bodies (i.e., baseline itself is not blank, per AC-F-13). [tester]

**AC-V-04** `05-dashboard-populated-dark.png` matches baseline within 1% at 1280 × 800 dark — full-frame dark background. [tester]

**AC-V-05** `07-dashboard-inspector-light.png` matches baseline within 1% at 1280 × 800 with row selected. [tester]

---

## C. Design ACs (ui-critic — rubric)

Score the 10 critique PNGs against the 6-axis rubric in `.workflow/DESIGN.md`. Total ≥ 24/30 to PASS (M05 was 22/30 advisory; M06 enforcing raises bar). Per-surface expectations:

**AC-D-01** **Popover Clarity ≥ 4/5**: rich rows readable in 2s; status pill, friendly title, 1-line summary all present and parsed; no truncation at 480pt for the populated fixture. [ui-critic]

**AC-D-02** **Popover Density ≥ 4/5**: rows grouped by status with section headers; no wasted whitespace at 480pt; "running"/"scheduled"/"failed" hierarchy reads instantly. Rubric REJECT trigger: row visual hierarchy ambiguous (title vs summary same size/weight). [ui-critic]

**AC-D-03** **Dashboard Density & Hierarchy ≥ 4/5** at 1280 × 800: middle list claims the bulk of horizontal space; sidebar 220 + inspector 360 don't dominate; row content is readable without truncation at default. Rubric REJECT trigger: middle list still pinned narrow (M05 P0 condition recurs). [ui-critic]

**AC-D-04** **Bucket strip Identity ≥ 4/5** in dashboard: chips render horizontally with parity to popover treatment; "total N" reads on one line. Rubric REJECT trigger: vertical-stripe regression. [ui-critic]

**AC-D-05** **Empty / Error states ≥ 4/5**: 0-count chips visibly dimmed; tooltip surfaces an actionable explanation; failed-row Retry affordance reads as recoverable, not as an error chip. [ui-critic]

**AC-D-06** **Affordance ≥ 4/5**: Retry on failed row is discoverable (visible, not hover-only-without-cue); group headers in popover read as labels not as buttons; resizing dashboard below 1280 still feels intentional (no broken collapse). [ui-critic]

**AC-D-07** **Dark-scheme parity ≥ 4/5**: scenarios 02, 05, 08 are full-frame dark, hierarchy and semantic colors preserved vs. light counterparts. Rubric REJECT trigger: half-rendered or white-bleed dark frame (M05 P0 condition recurs). [ui-critic]

---

## Verifier counts

| Verifier | Count |
|---|---|
| tester (functional) | 19 |
| tester (visual diff) | 5 (subset of AC-V-* — these run alongside functional) |
| ui-critic (design) | 7 |
| **Total ACs** | **26** (19 functional + 7 design; 5 of the 19 functional are visual-diff under AC-V-*) |

Note on counting: AC-V-01..05 are tester-owned visual-diff ACs that complement (not duplicate) AC-F-13/F-14/F-16. AC-F-* and AC-V-* together = 24 tester ACs. Plus 7 design ACs = **31 verifier-claims across 26 unique ACs**. Restating cleanly: **26 distinct ACs; ≥20 satisfied**.
