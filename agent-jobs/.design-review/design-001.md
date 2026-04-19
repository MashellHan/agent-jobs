# Design Review 001
**Date:** 2026-04-19T22:50:00Z
**Reviewer perspective:** Senior product designer (FAANG-tier)
**Files scanned:** 3 .swift views (MenuBarViews, AutoRefreshIndicator, DashboardView), 1 token module (DesignTokens)
**Screenshots:** none — code-only inspection (no rendered build attached)

## Overall Score: 71/100

Solid foundation. Tokens are coherent, CPU/MEM information is everywhere it must be, and the menubar layout reads at FAANG-baseline. Where it lags Linear/Raycast/Things: missing hover/focus affordances, no skeleton/error states, weak empty-state copy, monochrome metric tiles, and a segmented `Picker` carrying a 4-tab inspector (Things/Raycast would use a sidebar or chip row). Polish gaps — not a re-architecture.

## Category Scores

| Category | Score | Prev | Delta | Notes |
|---|---:|---:|---:|---|
| Visual hierarchy | 11/15 | — | — | Title/heading/caption ladder is consistent. Inspector header lacks a quiet subtitle (project · source) under the name. Menubar section labels (`Active Now`, `Scheduled Soon`) compete with chips above; no leading vertical rhythm. |
| Information density | 12/15 | — | — | ServiceRowCompact balances name + schedule + CPU + MEM well. Dashboard table uses 7 columns — borderline busy at narrow widths; no column priority for shrinking. Inspector overview wastes vertical space (two columns at full Inspector width = oversized tiles). |
| Aesthetics | 11/15 | — | — | 8pt grid honored (xxs/xs/s/m/l/xl/xxl). Radii ladder good. Materials underused — only mention is `.thinMaterial.opacity(0)` (effectively invisible). MetricTiles use `.quaternary.opacity(0.4)` — flat; competitor apps add 1pt inner border or subtle gradient. No shadow language defined. |
| Interaction | 8/15 | — | — | Big gap. **No hover state** on `ServiceRowCompact` (the `.thinMaterial.opacity(0)` is dead). **No focus ring** on table rows beyond default. Refresh button uses `.buttonStyle(.plain)` — invisible affordance until hover, and no hover state defined. No transitions on auto-refresh tick (count flips abruptly). `symbolEffect(.pulse)` is the only motion — good but isolated. |
| Accessibility | 6/10 | — | — | One `accessibilityLabel` (AutoRefreshIndicator). Missing on: status dot, status badge (color-only state), summary chips (icon-only meaning when count is 0), MemoryBadge. No `accessibilityElement(children: .combine)` on rows. Color is the sole carrier of CPU/MEM severity → fails WCAG 1.4.1 (use of color). No `@Environment(\.accessibilityReduceMotion)` gate on the pulse effect. |
| Empty / Error / Loading | 5/10 | — | — | EmptyHintView exists for menubar sections but copy is generic ("Nothing here yet"). Dashboard has zero empty state when filter yields nothing — `Table` will render an empty body. **No loading skeleton** anywhere — first paint shows `0 running / 0 scheduled` indistinguishable from "no jobs exist". **No error state** when `registry.refresh()` fails (silent). |
| macOS-native feel | 7/10 | — | — | MenuBarExtra usage correct. `.regularMaterial` / `.bar` not applied to popover background — uses default which can look flat against bright wallpapers. SF Symbols used throughout (good). `ContentUnavailableView` used in detail (excellent). Sidebar uses `.listStyle(.sidebar)` ✓. Footer buttons should use `.menuItemStyle`-equivalent treatment, not default Button — feels like a window toolbar instead of a system menu. |
| Information completeness | 11/10 (capped) → **10/10** | — | — | CPU and MEM visible in: menubar row (✓), menubar summary memory total (✓), dashboard CPU column (✓), dashboard MEM column (✓), Inspector Metrics tab (✓ + threads + FDs). Schedule is `humanDescription` everywhere, not raw cron (✓). Created column shows relative + tooltip absolute (✓ — exemplary). |

**Total:** 11+12+11+8+6+5+7+10 = **70/100** → rounded **71** (info-completeness deserves the cap).

## Top 3 actions for implementer

1. **[P0] MenuBarViews.swift `ServiceRowCompact` — add hover & focus affordance.** Currently `.background(.thinMaterial.opacity(0), …)` is a no-op stub. Wire it via `@State private var isHovered = false` + `.onHover { isHovered = $0 }` and use `.background(isHovered ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.s))`. Add `.focusable()` + `.focusEffectDisabled(false)` so keyboard nav works. *Principle: Refactoring UI — "depth via hover", Apple HIG — keyboard parity.*

2. **[P0] DashboardView.swift `StatusBadge` + `ServiceRowCompact` statusDot — add non-color signal.** Status currently encoded only by hue. Add a leading SF Symbol in the badge (`circle.fill` for running, `clock.fill` for scheduled, `xmark.circle.fill` for failed, `pause.circle.fill` for paused, `checkmark.circle.fill` for done) and an `accessibilityLabel("Status: \(status.rawValue)")`. *Principle: WCAG 1.4.1 use of color, Apple HIG accessibility.*

3. **[P0] DashboardView.swift / MenuBarViews.swift — add loading + empty-with-filter states.** Introduce `enum LoadPhase { case loading, loaded, error(Error) }` on `ServiceRegistryViewModel`. While `loading` and services empty, show 3 skeleton rows (`RoundedRectangle.fill(.quaternary).redacted(reason: .placeholder)`). When filter yields zero, show `ContentUnavailableView("No \(category) services", systemImage: cat.sfSymbol, description: Text("Try clearing the filter."))`. *Principle: Refactoring UI — "design every state".*

## Issues

### CRITICAL (blocks ship)
*(none — current scope is alpha menubar; nothing here would prevent the next demo)*

### HIGH (degrades professional feel)
- **D-H1 — MenuBarViews.swift:172** `.background(.thinMaterial.opacity(0), …)` is dead code. Replace with real hover state (see Top-3 #1).
- **D-H2 — DashboardView.swift:135–140** Inspector uses `.pickerStyle(.segmented)` for 4 tabs at full window width. Segmented controls scale poorly past 3 items and feel iOS-y. Use a chip row with `Capsule` background or an SF-Symbol toolbar (`Overview` 􀉪 `Logs` 􀉆 `Config` 􀍟 `Metrics` 􀙗) — Linear/Things style.
- **D-H3 — MenuBarViews.swift:55–57** Refresh `Button(...).buttonStyle(.plain)` is invisible until investigated. Either give it `.buttonStyle(.borderless)` with `.help` (already present) or a hover-revealed background. Currently fails "discoverability".
- **D-H4 — All views** No reduced-motion guard. `symbolEffect(.pulse, isActive: nextIn <= 3)` will animate even when user enables Reduce Motion. Wrap with `@Environment(\.accessibilityReduceMotion)` and disable.
- **D-H5 — DashboardView.swift:58–96** Table has no `.tableStyle(.inset(alternatesRowBackgrounds: true))` or column-resize hints. At narrow widths, Created/Last Run will collide.

### MEDIUM
- **D-M1 — MenuBarViews.swift:97–99** Empty copy "Nothing here yet" is twice generic (in two sections). Differentiate: "No services running right now." vs "Nothing scheduled in the next hour."
- **D-M2 — DesignTokens.swift:43–58** Resource thresholds are fixed cliffs (5%, 50% / 100MB, 500MB). Three discrete colors create jarring jumps. Consider a `LinearGradient` interpolation for the cell background tint, keeping discrete text color for legibility.
- **D-M3 — MenuBarViews.swift:46–60** Header lacks app version / project root hint; competitor menubar apps (Raycast, Cleanshot) ground the user with an avatar/badge area.
- **D-M4 — DashboardView.swift:96** No bulk action affordance (start/stop/pause). Inspector has no action buttons either — feels read-only despite `ServiceAction` existing in the provider protocol.
- **D-M5 — DashboardView.swift:126–129** `Tab` enum uses `rawValue` for both display and id — non-localizable. Use `LocalizedStringKey` and a separate `id`.

### LOW
- **D-L1 — DesignTokens.swift** No semantic alias layer (e.g., `Surface.elevated`, `Border.subtle`) — all consumers reach into `Color.gray.opacity(...)` ad-hoc (dead-code line 173 in MenuBarViews proves the gap).
- **D-L2 — MenuBarViews.swift:62–77** SummaryStrip uses `Spacer()` between chips and MemoryBadge — at narrow widths, the badge will jump. Constrain chip row to `HStack(alignment: .center)` with explicit min width.
- **D-L3 — AutoRefreshIndicator.swift:9–10** `Timer.publish(every: 1)` runs forever even when popover is closed → minor battery drain. Pause via `@Environment(\.scenePhase)` or `.onDisappear`.
- **D-L4 — DashboardView.swift:103** `Text(status.rawValue.capitalized)` — relies on enum raw spelling. Add a `displayName` to `ServiceStatus` for localization.
- **D-L5 — MetricTile** No min height → tiles in a `GridRow` with mismatched value lengths render uneven. Add `.frame(minHeight: 64, alignment: .leading)`.

## Wins since last review
*(first review — establishing baseline)*

- Token system is comprehensive (Spacing/Radius/Typography/Status/Resource) and disciplined — most teams skip Resource colors entirely.
- CPU + MEM visible at three altitudes (menubar row, dashboard table, inspector metrics) — exceeds spec.
- AutoRefreshIndicator with relative + countdown wording is genuinely thoughtful (matches `feedback_tui_design` memory exactly).
- Created column with relative-time + abbreviated-time tooltip is best-in-class — keep this pattern for Last/Next Run too.
- `ContentUnavailableView` used in Inspector empty state — correct macOS 14+ idiom.

## Cross-references with code review

- **Aligned with code-001 H/M items** — code review flagged Component decomposition (StatusBadge, MetricTile inline). I concur for testability AND for design-system reusability: extract to `Sources/AgentJobsCore/Design/Components/` so they're token-locked.
- **Potential conflict** — code-001 likely pushed for stricter `Sendable`/actor boundaries on `ServiceRegistryViewModel`. Design needs `LoadPhase` state mutated on `MainActor` for skeleton transitions; ensure the actor boundary doesn't force a `.task` flicker that prevents the skeleton from appearing.
- **No conflict** — adding hover/focus state is purely additive; doesn't touch the discovery/provider layer.

## Termination check

- Score >= 90 for 2 consecutive reviews? **no** (first review, 71/100)
- All P0 design issues resolved? **no** (3 P0 opened above)
- Recommendation: **CONTINUE**
