# Design Review 002
**Date:** 2026-04-19T23:50:00Z
**Reviewer perspective:** Senior product designer (FAANG-tier)
**Files scanned:** 3 .swift views (MenuBarViews, AutoRefreshIndicator, DashboardView), 1 token module (DesignTokens)
**Git HEAD:** 2915a4b
**Screenshots:** none — code-only inspection (still no rendered build attached); flagged where visual confirmation is required

## Overall Score: 82/100  (+11 vs design-001's 71)

Solid lift since baseline. The three P0s I called out in design-001 are all addressed at the code level: hover state on `ServiceRowCompact` is real (lines 161, 180-185), `StatusBadge` carries an SF Symbol prefix + accessibilityLabel (DashboardView 109-121), and a SkeletonRow loading state with reduce-motion guard exists (MenuBarViews 238-262). Tokens still excellent. Remaining lift is in the Inspector (still segmented Picker + flat tiles), Dashboard table chrome, and a few empty-state copy holes.

## Category Scores

| Category | Score | Prev | Delta | Notes |
|---|---:|---:|---:|---|
| Visual hierarchy | 12/15 | 11 | +1 | Header now "title3 rounded semibold" — clean. Inspector still lacks a quiet subtitle (project · source) under the name (D-M3 from last round still open). |
| Information density | 12/15 | 12 | 0 | Unchanged; column priority still missing (D-H5 still open). |
| Aesthetics | 12/15 | 11 | +1 | Hover background using `Color.primary.opacity(0.06)` over `RoundedRectangle(cornerRadius: Radius.s)` is exactly right. MetricTiles unchanged — still flat `.quaternary.opacity(0.4)`, no inner border or shadow. |
| Interaction | 12/15 | 8 | +4 | Big jump. Hover wired with 120ms ease-out. `.contentShape(Rectangle())` makes the full row hittable. Refresh button still `.buttonStyle(.plain)` with no hover background (D-H3 still open). |
| Accessibility | 9/10 | 6 | +3 | StatusBadge: ✓ symbol + label. ServiceRowCompact: ✓ `accessibilityElement(children: .combine)` + composite label. SkeletonRow: ✓ `accessibilityHidden(true)` + reduce-motion guard. AutoRefreshIndicator: ✓ pulse gated by reduce-motion. Remaining gap: `MemoryBadge` and `SummaryChip` lack labels — VoiceOver reads "memorychip, 1.2 GB" awkwardly. |
| Empty / Error / Loading | 8/10 | 5 | +3 | SkeletonRow lands. Empty messages differentiated ("No services running right now." vs "Nothing scheduled in the next hour."). **Still missing**: error state on `.error(String)` LoadPhase — registry.phase is set but no view branches on `.error` to show it (silent failure in UI). Dashboard `Table` still has zero empty/zero-filter state. |
| macOS-native feel | 7/10 | 7 | 0 | Popover background still default (no `.regularMaterial`). Dashboard Table still missing `.tableStyle(.inset(alternatesRowBackgrounds: true))`. Footer buttons still default — feel toolbar-ish. |
| Information completeness | 10/10 | 10 | 0 | CPU + MEM still visible at all three altitudes. CronHumanizer maps cron→human across menubar + dashboard. Created column with relative + tooltip absolute remains best-in-class. |

**Total:** 12+12+12+12+9+8+7+10 = **82/100** (+11 vs 71)

## Top 3 actions for implementer

1. **[P0] DashboardView.swift `ServiceInspector` (lines 159-164) — replace segmented Picker for the 4-tab inspector.** Segmented controls scale poorly past 3 items and feel iOS-y; Linear/Things/Tower would use a chip row or icon-toolbar. *Fix:* swap for `HStack(spacing: 4)` of `Capsule()`-backed buttons with SF symbols (`Overview` 􀉪 `Logs` 􀉆 `Config` 􀍟 `Metrics` 􀙗); selected = `.tint.opacity(0.15)` background + tint foreground; unselected = transparent + secondary; `accessibilityLabel(t.rawValue)`. *Principle: Refactoring UI — "don't make people read more than they need to scan".*

2. **[P0] DashboardView.swift `serviceTable` (lines 64-103) — add `.tableStyle(.inset(alternatesRowBackgrounds: true))` and a zero-filter ContentUnavailableView.** Right now a filter that yields zero rows shows a blank `Table` body — disorienting. *Fix:* wrap the Table in `if filteredServices.isEmpty { ContentUnavailableView("No \(categoryFilter?.displayName ?? "") services", systemImage: categoryFilter?.sfSymbol ?? "tray", description: Text("Try clearing the filter.")) } else { Table(...).tableStyle(.inset(alternatesRowBackgrounds: true)) }`. *Principle: Refactoring UI — "design every state".*

3. **[P0] AgentJobsMacApp + MenuBarPopoverView — surface `LoadPhase.error(String)`.** The view-model has the state machine but no UI branch consumes `.error`. A failed `registry.refresh()` is currently silent. *Fix:* In `MenuBarPopoverView.body`, between the divider and the ScrollView, add `if case .error(let msg) = registry.phase { ErrorBanner(message: msg) { Task { await registry.refresh() } } }`. New 25-LOC `ErrorBanner` component: `.systemImage("exclamationmark.triangle.fill")` + monochrome red strip + retry button. *Principle: Apple HIG — "communicate errors clearly and offer next steps".*

## Issues

### CRITICAL (blocks ship)
*(none)*

### HIGH (degrades professional feel)
- **D-H2** *(carried from design-001)* `DashboardView.swift:159-164` — segmented Picker for 4 tabs. **Still open.** See Top-3 #1.
- **D-H3** *(carried from design-001)* `MenuBarViews.swift:57-58` — Refresh button `.buttonStyle(.plain)` invisible until investigated. *Fix:* `.buttonStyle(.borderless)` + hover-revealed `.background(isHovered ? Color.primary.opacity(0.06) : .clear)` ring; `.help` is already present.
- **D-H5** *(carried from design-001)* `DashboardView.swift:64-103` — Table missing `.tableStyle(.inset(alternatesRowBackgrounds: true))` and zero-filter empty state. **Still open.** See Top-3 #2.
- **D-H6 NEW** `MenuBarPopoverView` / `AgentJobsMacApp` — `LoadPhase.error` is settable but never rendered. Refresh failures are invisible to the user. See Top-3 #3.

### MEDIUM
- **D-M2** *(carried)* `DesignTokens.swift:43-66` — Resource thresholds remain hard cliffs. Consider gradient interpolation for cell background tint while keeping discrete text color. (Lower priority now that thresholds are documented.)
- **D-M3** *(carried)* `MenuBarViews.swift:46-60` — Header still lacks app-version / project-root hint. Anchoring affordance.
- **D-M4** *(carried)* `DashboardView.swift / ServiceInspector` — Inspector has no action buttons (`Start`, `Stop`, `Restart`) despite `ServiceAction` existing in `ServiceProvider`. Toolbar at the top of the Inspector header would be the right home: 3 SF-Symbol buttons with `.help` and `.disabled(!provider.supports(action))`.
- **D-M5** *(carried)* `DashboardView.swift:151-154` — `Tab` enum still uses `rawValue` for both display and id. Add a `displayName: LocalizedStringKey` separately.
- **D-M6 NEW** `MenuBarViews.swift:148-157` `MemoryBadge` — VoiceOver reads "memorychip, 1.2 GB". *Fix:* `.accessibilityElement(children: .ignore).accessibilityLabel("Total memory: \(formatted)")`.
- **D-M7 NEW** `MenuBarViews.swift:133-146` `SummaryChip` — same VoiceOver awkwardness. *Fix:* combined label `"\(label)"` (the chip text is already complete; just `.accessibilityElement(children: .combine)`).
- **D-M8 NEW** `DashboardView.swift:251-267` `MetricTile` — flat `.quaternary.opacity(0.4)` background lacks the 1pt inner border or subtle gradient that Linear/Tower use to give tiles depth. *Fix:* add `.overlay(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(.quaternary, lineWidth: 1))`. Alternatively a `LinearGradient` from `.tertiary.opacity(0.25)` to `.quaternary.opacity(0.5)`.

### LOW
- **D-L1** *(carried)* `DesignTokens.swift` — No semantic alias layer (`Surface.elevated`, `Border.subtle`). Now actively biting: hover background uses `Color.primary.opacity(0.06)` inline (MenuBarViews:181) — that magic number wants to be `Surface.hoverFill`.
- **D-L2** *(carried)* `MenuBarViews.swift:64-79` `summaryStrip` — chips at narrow widths still risk jumping. Constrain min width.
- **D-L3** *(carried)* `AutoRefreshIndicator.swift` — Timer runs while popover is closed. Pause via `.onDisappear` / `scenePhase`.
- **D-L4** *(carried)* `DashboardView.swift:112` `Text(status.rawValue.capitalized)` — non-localizable. Add `displayName`.
- **D-L5** *(carried)* `MetricTile` — no `minHeight`; tile heights drift when one value wraps. `.frame(minHeight: 64, alignment: .leading)`.
- **D-L6 NEW** `MenuBarPopoverView.section` — `SkeletonRow` shows 3 fixed rows during loading. If the previous loaded state had services, the skeleton wipes them — flicker. *Fix:* show skeleton only when `services.isEmpty AND phase == .loading AND !hasEverLoaded`.
- **D-L7 NEW** `DashboardView.swift:21` Detail-pane ContentUnavailableView reads "Pick something from the list to inspect." — perfectly fine, but Tower/Things would say "Choose a service to see its details." (slightly more product-voice). Polish only.

## Wins since last review

- **D-P0-1 (hover state)** ✅ `ServiceRowCompact` has real hover, real animation timing (120ms ease-out), real `.contentShape(Rectangle())`. Exactly as recommended.
- **D-P0-2 (non-color status signal)** ✅ `StatusBadge` carries SF Symbol + `accessibilityLabel`. Symbol mapping is comprehensive (idle → moon.zzz.fill, orphaned → questionmark.circle.fill — nice).
- **D-P0-3 (loading skeleton)** ✅ `SkeletonRow` lives in MenuBarViews; gated by reduce-motion; `accessibilityHidden(true)`. Pulse uses `withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true))` — soft, not strobe.
- **D-H1 (.thinMaterial.opacity(0) dead code)** ✅ Replaced.
- **D-H4 (reduce-motion guard on AutoRefreshIndicator pulse)** ✅ Verified.
- **L-001 (sidebar All count)** ✅ Visible at DashboardView:32-34.
- **D-L4-flavor** Inspector `ContentUnavailableView` for Logs/Config — better than raw text fallback.
- **Composite accessibilityLabel** on row reads "name, status, schedule" — exactly what VoiceOver users want.

## Cross-references with code review

- **Aligned with code-002 M3** (DashboardView 267 LOC; extract `StatusBadge`, `MetricTile`, `SidebarItem`). Doing M3 also unblocks D-M8 (MetricTile inner border/gradient): once MetricTile lives in `Sources/AgentJobsCore/Design/Components/`, it can adopt a token-driven background style without churn in DashboardView.
- **Aligned with code-002 M2** — adding `LoadPhase.error` rendering (Top-3 #3) will need a `ServiceRegistryViewModel` test that asserts the phase transitions through `loading → error(...) → loaded` on a synthetic provider failure. That test naturally extends ServiceRegistryTests.
- **No conflict** with strict-review iter-003 (PASS, no open items) — all P0 items are additive UX polish, not safety/correctness.
- **Memory consistency** — `feedback_tui_design` says "visible auto-refresh" (✓ AutoRefreshIndicator) and "inline detail expansion, no modals" (✓ NavigationSplitView). The proposed chip-row inspector tabs (Top-3 #1) keep this — chips are inline, not modal.

## Termination check

- Score >= 90 for 2 consecutive reviews? **no** (82 this round, was 71 last round; trending toward 90 next cycle if D-H2/H5/H6 land)
- All P0 design issues resolved? **no** (3 P0 still open, but all were carried-forward + 1 new — see Top-3)
- Recommendation: **CONTINUE**

One more cycle that addresses Top-3 (D-H2 chip-row + D-H5 alternating-rows-with-empty-state + D-H6 ErrorBanner) plus D-M6/M7 (VoiceOver labels on chips/badge) should clear the 90 threshold.
