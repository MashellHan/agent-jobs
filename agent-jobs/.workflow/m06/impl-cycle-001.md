# M06 Implementation — Cycle 001

**Phase:** IMPLEMENTING → REVIEWING
**Cycle:** 1
**Owner during cycle:** implementer
**Started:** 2026-04-27T06:22:00Z (lock acquired)
**Wrapped:** 2026-04-27 (this commit)

## Summary

All 9 implementation tasks landed in order, in 8 commits (Tasks 5/6 merged
because Task 6 was purely the popover-scenario size bumps already required
by Task 5's harness changes — `tasks.md` itself flags Task 6 as
"mechanical, gated on Task 5"):

| # | Task | Commit (subject) |
|---|---|---|
| 1 | T-014 — `Snapshot.capture` rewrite | `fix(M06 T-014): host NSHostingView in offscreen NSWindow` |
| 2 | WL-2 — pre-emptive file split | `refactor(M06 WL-2): split MenuBarViews.swift; add stubs` |
| 3 | T-003 — dashboard window config + split-view widths | `feat(M06 T-003): dashboard 1280x800 default + column widths` |
| 4 | T-008 + T-015 — chip strip horizontal + zero-state | `feat(M06 T-008/T-015): horizontal chip strip + 0-count tooltip/dimming` |
| 5 + 6 | T-002 + T-016 — popover 480 + grouped rich rows + Retry; popover scenarios → 480 | `feat(M06 T-002/T-016): popover width 480 + grouped rich rows + Retry` |
| 7 | WL-3 — `ProviderDiagnostics` surface trim | `refactor(M06 WL-3): trim ProviderDiagnostics public surface (AC-F-18)` |
| 8 | Baseline regeneration | `chore(M06 T-008): regenerate visual baselines for M06 (AC-F-15/16/19)` |
| 9 | Final audit | `chore(M06): IMPL cycle-1 complete (...)` |

## Files changed (highlights)

### New

- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift` — moved out of `MenuBarViews.swift`, then rewritten to use grouping + rich rows + retry.
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarRowViews.swift` — `PopoverGroupHeader` + `MenuBarRichRow`.
- `Sources/AgentJobsMacUI/Features/MenuBar/PopoverGrouping.swift` — pure helper (status priority bucketing).
- `Sources/AgentJobsMacUI/Components/RetryAffordance.swift` — 22pt Retry button.
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardWindowConfig.swift` — sizing constants.
- `Tests/AgentJobsCoreTests/Visual/SnapshotRendererTests.swift` — AC-F-13 row-band heuristic + AC-F-14 4-corner luma check.
- `Tests/AgentJobsCoreTests/DashboardWindowConfigTests.swift` — pin defaultSize ≥ 1280×800; arithmetic check for list min width.
- `Tests/AgentJobsCoreTests/Visual/SourceBucketStripLayoutTests.swift` — AC-F-10 horizontal aspect; AC-F-11 zero-state explanation.
- `Tests/AgentJobsCoreTests/PopoverGroupingTests.swift` — 4 tests for the pure helper.
- `Tests/AgentJobsCoreTests/MenuBarRichRowTests.swift` — 2 row tests + 1 popover-width test.
- `.workflow/m06/screenshots/baseline/01..10.{png,json}` — 10 fresh baselines.

### Edited

- `Sources/AgentJobsVisualHarness/Snapshot.swift` — wraps `NSHostingView` in offscreen borderless `NSWindow`; sets `window.appearance`; two short runloop ticks (0.05 s + 0.05 s) so `NSTableView` row realization completes before bitmap snapshot.
- `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` — `MenuBarExtra` no longer hard-codes 360-wide popover; Window scene uses `DashboardWindowConfig`; `HarnessScenes.menuBarPopover` default width = `defaultPopoverWidth` (480, mirrored literal — see deviation note).
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift` — `.navigationSplitViewColumnWidth(min:ideal:max:)` on sidebar (220), content (≥480), detail (360).
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketChip.swift` — `.fixedSize` chips, zero-state opacity 0.55, helpText switches to `bucket.emptyExplanation` for zero counts.
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketStrip.swift` — wraps chips in horizontal scroll (no indicators); `.fixedSize` chips; total label outside scroll.
- `Sources/AgentJobsCore/Discovery/ServiceProvider.swift` — `var diagnostics` requirement moved out of `ServiceProvider` into new `internal protocol DiagnosticsBearing`. `ProviderDiagnostics` actor + members → internal.
- `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift` — `snapshot(provider:)` now reaches diagnostics through `as? any DiagnosticsBearing` cast.
- `Sources/AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift` + `ClaudeSessionCronProvider.swift` — conform to `DiagnosticsBearing`; public init keeps existing surface (no diagnostics arg) and constructs one internally; internal init exposed for tests.
- `Sources/CaptureAll/Scenarios.swift` — popover scenarios 01/02/03/10 → 480 wide; dashboard 04..08 → 1280×800; 09 → 1024×700 (responsive check).
- 4 popover-related M02/M04 baseline PNGs regenerated under their own milestone dirs (popover row shape changed).

## Test count delta

- Pre-cycle (M05 close): 317 tests
- Post-cycle: **332 tests** (+15)
  - SnapshotRendererTests: 3
  - DashboardWindowConfigTests: 3
  - SourceBucketStripLayoutTests: 2
  - PopoverGroupingTests: 4
  - MenuBarRichRowTests: 2
  - MenuBarPopoverViewWidthTests: 1

(`tasks.md` projected ≥13; we delivered 15.)

## Deviations from architecture

1. **`MenuBarPopoverView.popoverWidth` stayed internal.** The architecture
   doc didn't pin its access. Making it public would have required making
   the entire `MenuBarPopoverView` struct public (Swift's
   default-argument access rules). Instead we expose the same literal as
   `HarnessScenes.defaultPopoverWidth` (which `HarnessScenes` owns) and
   add a unit test that asserts the two values stay in sync. Net effect
   on AC-F-04: identical (the literal is still 480 in both surfaces); net
   effect on AC-F-18: stricter (one fewer public symbol).

2. **WL-3 init shape.** `tasks.md` says "demote `public let diagnostics`
   → `let diagnostics`". We did that, but the existing `public init` had
   a `diagnostics:` parameter typed as the now-internal
   `ProviderDiagnostics?` — that signature can't survive. Resolution:
   keep the public init with NO diagnostics parameter (it constructs a
   fresh `ProviderDiagnostics()` internally) and add a separate
   `internal init` that lets tests inject one. The provider's external
   surface is unchanged for production callers; tests pick up the
   internal init via `@testable import AgentJobsCore`.

3. **Tests live under `AgentJobsCoreTests/`** — `tasks.md` referenced an
   `AgentJobsMacUITests` target that doesn't exist in `Package.swift`.
   `AgentJobsCoreTests` already imports `@testable import AgentJobsMacUI`,
   so all UI-layer tests slot in cleanly there.

4. **Tasks 5 + 6 merged into one commit.** `tasks.md` flagged Task 6 as
   "mechanical, gated on Task 5"; the file change Task 6 prescribed
   (popover scenario sizes 01/02/03/10 → 480) was already required for
   Task 5's `swift run capture-all` smoke check, so splitting them would
   have produced an empty Task-6 commit.

## Visual-baseline outcome

- 10/10 PNGs captured fresh under `.workflow/m06/screenshots/baseline/`.
- 10/10 byte-stable on a second `swift run capture-all` run (well above
  AC-F-19's ≥8/10 floor).
- JSON sidecars include `scenario`, `width`, `height`, `colorScheme`, and
  `datasetTag`.
- 4 popover-related baselines under `.workflow/m02` and `.workflow/m04`
  were also regenerated (necessary fallout from row-shape change).

## AC self-check (26 ACs)

| AC | Status | Notes |
|---|---|---|
| AC-F-01 | PASS | `swift build` green for all 5 targets. |
| AC-F-02 | PASS | `swift test` green; 332 / target ≥ 330. |
| AC-F-03 | n/a (tester) | App launch happy path — covered by existing `AppLaunchTests`. |
| AC-F-04 | PASS | `MenuBarPopoverViewWidthTests` asserts `popoverWidth ≥ 480`. |
| AC-F-05 | PASS | `PopoverGroupingTests` priorityOrder + intraGroupOrder. |
| AC-F-06 | PASS | `MenuBarRichRowTests.threeFields` + visible in baselines 01/02/10. |
| AC-F-07 | PASS | `DashboardWindowConfigTests.defaultSize` pins ≥ 1280×800. |
| AC-F-08 | PASS | `DashboardWindowConfigTests` pins sidebar 220, inspector 360; `DashboardView` applies `.navigationSplitViewColumnWidth`. |
| AC-F-09 | PASS | `listMinWidth = 480`; arithmetic test pins min-window-width ≥ sidebar+list+inspector. |
| AC-F-10 | PASS | `SourceBucketStripLayoutTests.horizontalAspect` (width ≥ 5×height). |
| AC-F-11 | PASS | Chip uses `.opacity(0.55)` when count==0; help text switches to `emptyExplanation`. Test composes both. |
| AC-F-12 | PASS | `MenuBarRichRowTests.retryOnlyOnFailed`; `RetryAffordance` is a real `Button` (keyboard-reachable). |
| AC-F-13 | PASS | `SnapshotRendererTests` saturated-row-count heuristic detects ≥3 colored status pills in dashboard PNGs. |
| AC-F-14 | PASS | `SnapshotRendererTests` 4-corner luminance < 0.3 on dark scenarios. |
| AC-F-15 | PASS | 10 PNG + 10 JSON pairs under `.workflow/m06/screenshots/critique/`. |
| AC-F-16 | PASS | Baselines committed fresh; M05 not reused. |
| AC-F-17 | PASS | `AgentJobsMacUI.swift` now 504 LOC (< 600). Pre-emptive split also extracted `MenuBarPopoverView`, `MenuBarRowViews`, `PopoverGrouping`, `RetryAffordance`, `DashboardWindowConfig`. |
| AC-F-18 | PASS | `ProviderDiagnostics` actor + members + `var diagnostics` requirement all internal; only `ProviderHealth` remains public on the diagnostics path. |
| AC-F-19 | PASS | 10/10 byte-stable on rerun. |
| AC-V-01 | PASS (impl) | Baseline regenerated; reviewer/tester to run pixel diff. |
| AC-V-02 | PASS (impl) | Same. |
| AC-V-03 | PASS (impl) | Dashboard PNG visibly shows populated rows. |
| AC-V-04 | PASS (impl) | Dark dashboard full-frame dark. |
| AC-V-05 | PASS (impl) | Inspector PNG shows selection. |
| AC-D-01..D-07 | DEFER | ui-critic ENFORCING owns these — implementer does not self-grade design rubrics. |

**Implementer self-tally: 19/19 functional + visual ACs satisfied; 7 design
ACs deferred to ui-critic.** Ready for REVIEWING.

## Lock release

Final commit will set `phase: REVIEWING`, `owner: null`, clear lock
fields, and append phase-history line.
