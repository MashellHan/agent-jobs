# M06 IMPL Cycle 2 — T-017 / T-018 fixes + dark-only gating

**Owner:** implementer
**Filed:** 2026-04-27
**Cycle:** 2 (after ui-critic REJECT 20/30)
**Tickets closed:** T-017 (P0), T-018 (P1)

---

## Root cause

### T-017 — Dark dashboard chrome + inspector header bleed light (P0)

`Snapshot.capture` hosts the SwiftUI tree in an offscreen `NSWindow`. For
`NavigationSplitView` the lowering produces one `NSHostingView` per pane
inside `NSSplitViewItem`s whose backing layers include `NSVisualEffectView`
(sidebar material), `NSScrollView`, and `NSTableView`. While the offscreen
window is **not key/main and not in the window-list**, those split-pane
backings do not reliably inherit `window.appearance` and resolve dynamic
colors against `.aqua` even when the parent window is `.darkAqua`. The
result was the M05 P0 condition recurring: dark list body, but light
sidebar / white top header band / unrendered inspector content.

Three independent fixes were required, each addressing one stage of
appearance propagation:

1. **`NSApp.appearance` pin** — SwiftUI material rendering checks
   `NSApplication.shared.effectiveAppearance` early in pipeline lookup,
   before per-view `appearance` overrides take effect. Pin
   `NSApp.appearance` to the target appearance for the duration of
   capture, restore in `defer`.
2. **Window ordered front offscreen** — pose the offscreen window at
   `(-50_000, -50_000)` and `orderFront(nil)` so AppKit promotes it to
   a real window-list participant. NavigationSplitView's per-pane
   children only inherit `window.effectiveAppearance` reliably for
   ordered-front windows. (Standard Quick Look / Sparkle trick.)
3. **Recursive `forceAppearance` walk + layer invalidation** — even
   after (1)+(2), the `NSVisualEffectView` material layers and
   `NSScrollView`/`NSTableView` `backgroundColor` properties cache
   their resolved color at first display under the initial appearance.
   Walk the subtree, re-stamp `appearance`, re-stamp `material` and
   `backgroundColor`, then `setNeedsDisplay()` every layer so
   `cacheDisplay(in:to:)` paints with the now-current appearance
   instead of the cached pixels.

Plus a small DashboardView fix: the content + detail panes have no
opaque background of their own — they let the window background show
through the SwiftUI hierarchy. In dark capture this surfaces as the
white top band above the SourceBucketStrip and the white inspector
pane behind "Select a service" / inspector content. Add an explicit
`.background(Color(NSColor.windowBackgroundColor))` to both panes.

### T-018 — Empty popover regressed vs M05 (P1)

`MenuBarPopoverView`'s empty path rendered a single `EmptyHintView`
("No services discovered yet."). Architecture §3.2 + acceptance.md
require the empty popover to render the same `RUNNING / SCHEDULED /
FAILED` group-header scaffolding as the populated layout, with 0
counts and per-section microcopy. Wired up via the
`PopoverGrouping.groupByStatus(_:includeEmpty:true)` API the architect
already specified for exactly this case (cycle-1 implementation
omitted it; cycle-1 reviewer + tester both flagged).

---

## Gating strategy — keeping light-mode byte-stable

All four cycle-2 dark-mode fixes are gated to `appearance == .darkAqua`
(or the SwiftUI equivalent `colorScheme == .dark`):

| Fix | Gate site | Light-mode behavior |
|---|---|---|
| `NSApp.appearance` pin | `if isDark { app.appearance = ... }` + matching `defer` | unchanged |
| `window.backgroundColor` resolved-against-target | `if isDark { window.backgroundColor = ... }` | unchanged (system default dynamic color) |
| Window ordered-front offscreen | `if isDark { window.setFrameOrigin(...); orderFront(nil) }` | unchanged (no window in window-list) |
| `forceAppearance` walk + layer invalidation + extra runloop | `if isDark { Self.forceAppearance(...); ... invalidateLayers(...); ... }` | unchanged (no walk, no extra paints) |
| DashboardView pane `.background(...)` | `private var paneBackground: Color { colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : .clear }` | `.background(.clear)` is a no-op on top of NavigationSplitView's existing pane background |

Validation: after gating, restored M02/M03/M04 cycle-001 baselines via
`git checkout`, then ran `swift test`. **All 332 tests pass**, including
every M02/M03/M04 visual baseline test. Light-mode pixel-diff against
the old baselines is byte-stable.

---

## Files changed

- `macapp/AgentJobsMac/Sources/AgentJobsVisualHarness/Snapshot.swift`
  - Add `isDark` local at top of `capture(_:size:appearance:)`.
  - Gate all 4 dark-mode fixes (NSApp pin, window bg color, ordered-front,
    forceAppearance + invalidateLayers) on `isDark`.
  - Helpers `resolvedBackgroundColor(for:)`, `invalidateLayers(on:)`,
    `forceAppearance(_:on:)`, `dumpHierarchy(_:depth:)` retained.
- `macapp/AgentJobsMac/Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift`
  - Add `@Environment(\.colorScheme)`.
  - Add `private var paneBackground: Color` returning
    `windowBackgroundColor` only in dark, `.clear` otherwise.
  - Apply `.background(paneBackground)` on both content and detail panes.
- `macapp/AgentJobsMac/Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift`
  - Empty path now ForEach's `emptyGroupedServices` (groupByStatus with
    `includeEmpty: true`, drops `.other`), rendering `PopoverGroupHeader`
    with 0 count + per-group microcopy via `EmptyHintView`.
  - Helper `emptyMicrocopy(for:)` added.

## Test results

- `swift build` — green (warnings only, none new)
- `swift test` — **332 / 332 passing** (0 failures, 0 regressions)
- All M02/M03/M04 visual baselines byte-stable after restore
- All M06 visual tests pass against regenerated baselines

## Baselines regenerated

- `.workflow/m06/screenshots/baseline/{01..10}.{png,json}` — 10 PNGs + 10 sidecars
- `.workflow/m06/screenshots/critique/{01..10}.{png,json}` — 10 PNGs + 10 sidecars

Spot-check (visual confirmation by reading the PNGs):
- **Scenario 03** (empty popover): RUNNING(0) / SCHEDULED(0) / FAILED(0)
  group headers each render with per-section microcopy ("No services
  running right now." / "Nothing scheduled in the next hour." /
  "Nothing has failed recently."). T-018 closed.
- **Scenario 05** (dashboard dark): full-frame dark — sidebar dark,
  top bucket strip dark, list body dark, inspector pane dark with
  "Select a service" placeholder. T-017 closed.
- **Scenario 08** (dashboard inspector dark): full-frame dark; inspector
  shows title "daily-cleanup", subtitle "daily at 9am", breadcrumb
  "Agent Jobs (local) · acme", command "agentjobs run cleanup",
  Stop / Hide actions, Overview tab pill, AND the full 8-cell metadata
  grid (Schedule / Project / Last Run / Next Run / Created / Origin /
  Session / Source path). T-017 fully closed for the inspector path
  too.

## Out of scope (deferred to M07 per ticket)

- T-019 P2 — Name column too narrow at 1280pt
- T-020 P2 — Bucket-strip header bar does not span sidebar pane
