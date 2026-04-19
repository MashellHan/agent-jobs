# Changelog — AgentJobsMac

All notable changes to the Mac app live here. Format: Keep a Changelog.

## [Unreleased]

### Added
- (cycle 10) `Sources/AgentJobsMac/Components/{MenuBarLabel,SummaryChip,
  MemoryBadge,HoverableIconButton,ErrorBanner,ServiceRowCompact,EmptyHintView,
  SkeletonRow}.swift` — extracted 8 reusable atoms from MenuBarViews.swift.
  MenuBarViews.swift now 120 LOC (was 324, −204) and holds only
  `MenuBarPopoverView` (code-003 P1 #2).
- (cycle 10) `ServiceRegistry.discoverAllDetailed()` returns per-provider
  success/fail counts via new `DiscoverResult` struct. Used by view model to
  distinguish "all providers failed" from "all providers legitimately empty"
  — fixes M-007 false-positive ErrorBanner on a fresh box (strict-iter-007).
- (cycle 9) `Sources/AgentJobsCore/Discovery/Providers/LaunchdUserProvider.swift` —
  parses `launchctl list` 3-column output into Service records, skips Apple
  system jobs, maps PID/exit-status to .running/.scheduled/.failed. Wired into
  `ServiceRegistry.defaultRegistry()` as the second production provider
  (code-003 P1 #3 / architecture-spec coverage).
- (cycle 9) `LaunchdUserProviderTests` — 7 cases including header skipping,
  Apple-prefix filtering, status mapping, injected-runner discover().
- (cycle 9) `ServiceRegistry.providerCount` actor-isolated read-only counter,
  used by the view model to distinguish "no providers configured" (idle) from
  "providers configured but all empty" (error). Enables LoadPhase.error wiring.
- (cycle 9) `ServiceRegistryViewModel.refresh()` now sets
  `phase = .error("No providers responded")` when discovered.isEmpty &&
  providerCount > 0 — the cycle-7 ErrorBanner UI is now reachable
  (code-003 M1 / honest reporting).
- (cycle 8) `Sources/AgentJobsMac/Components/StatusBadge.swift` —
  extracted from DashboardView for reuse + token-locked styling (code-002 M3).
- (cycle 8) `Sources/AgentJobsMac/Components/MetricTile.swift` —
  extracted from DashboardView (code-002 M3).
- (cycle 8) `ServiceRegistryTests` +2 cases: all-providers-failing returns
  empty (failure-isolation under total-failure scenario), and a 10-provider
  aggregation test verifying set semantics.
- (cycle 7) `ErrorBanner` in MenuBarPopoverView — renders when
  `ServiceRegistryViewModel.phase == .error(...)`, includes one-tap Retry,
  composite VoiceOver label. Refresh failures are no longer silent (design D-H6).
- (cycle 7) `HoverableIconButton` — borderless icon button with hover-revealed
  background; replaces `.buttonStyle(.plain)` refresh button (design D-H3).
- (cycle 7) `TabChipRow` + `TabChip` — chip-style tab row replacing
  `pickerStyle(.segmented)` for the inspector, with active/hover states,
  `.isSelected` accessibility trait, and SF Symbol per tab (design D-H2).
- (cycle 7) Zero-filter `ContentUnavailableView` in DashboardView serviceTable
  (design D-H5).
- (cycle 7) VoiceOver labels on `SummaryChip`, `MemoryBadge` (design D-M6/M7).
- (cycle 6) `ServiceRegistryTests` — 3 cases: aggregates across providers,
  failing provider does NOT poison the rest, empty registry. Verifies the
  TaskGroup failure-isolation contract (code-002 P1 #3 / M2).
- (cycle 6) `Shell.sigtermGraceSeconds = 0.5` — bounded SIGTERM→SIGKILL
  escalation in cancellation handler (code-002 P0 #2).
- (cycle 5) `Shell.run(_:args:timeout:)` — argv-array subprocess wrapper with
  default 5s timeout, separate stdout/stderr capture, `withTaskCancellationHandler`
  reaps the child on cancel. Honors `sandbox-decision.md` commitments.
- (cycle 5) `ShellTests` — 5 cases including timeout reap verification.
- (cycle 5) `AgentJobsJsonProvider.readWithTimeout()` — races file read against
  5s timer to prevent NFS / locked-file hangs (strict-review M-003).
- (cycle 4) `SkeletonRow` — reduce-motion aware loading placeholder for menubar sections.
- (cycle 4) Hover state + combined `accessibilityLabel` on `ServiceRowCompact`
  (design D-P0-1, prior dead `.thinMaterial.opacity(0)` replaced).
- (cycle 4) `accessibilityReduceMotion` guard on `AutoRefreshIndicator` pulse
  effect (design D-H4).
- (cycle 4) Documented thresholds on `DesignTokens.ResourceColor.cpu/.memory`
  (strict-review L-002).
- (cycle 4) Expanded README — architecture diagram, modules table, status grid,
  development-loop description (strict-review M-001).
- (cycle 3) `CronHumanizer` — translates 7 common cron patterns to phrases like
  "weekdays at 9am", "every 5 minutes" (strict-review H-001).
- (cycle 3) `ServiceRegistry` actor with `discoverAll()` TaskGroup; wired into
  `ServiceRegistryViewModel.refresh()` + 30s auto-refresh task
  (strict-review C-004).
- (cycle 3) `LoadPhase` enum on view model (idle / loading / loaded / error).
- (cycle 3) `MenuBarSummary.from(services:)` pure aggregator + 3 unit tests
  (strict-review M-002).
- (cycle 3) `CronHumanizerTests` (8 cases).
- (cycle 2) `Service.createdAt`, `Service.history`, `Service.origin`, `AgentKind`,
  `HistoryEvent`, `ServiceOrigin` — TUI parity per strict-review iter-001 §"数据模型".
- (cycle 2) `.implementation/sandbox-decision.md` — Option A (Developer ID,
  sandbox OFF) accepted for v1.
- (cycle 2) `AutoRefreshIndicator` — visible "updated Xs ago • next in Ys" header
  badge; addresses memory `feedback_tui_design`.
- (cycle 2) `Created` column in dashboard table — memory `feedback_tui_history`.
- (cycle 2) `scripts/build-mac.sh` — single command for `swift build && swift test`.
- (cycle 2) Schema-version awareness in `AgentJobsJsonProvider`.
- (cycle 1) Initial scaffold: SwiftPM package, domain models, AgentJobsJsonProvider,
  design tokens, MenuBarExtra entry, NavigationSplitView dashboard, 4 unit tests.

### Changed
- (cycle 7) `MetricTile` — added 1pt `.strokeBorder(.quaternary)` overlay and
  `minHeight: 64` for visual depth + alignment (design D-M8 + D-L5).
- (cycle 7) `ServiceInspector.Tab` gained `sfSymbol` per tab; rendered by
  the new `TabChipRow` instead of segmented Picker.
- (cycle 7) `MenuBarPopoverView` body — inserts `ErrorBanner` between summary
  and section list when in `.error` phase.
- (cycle 6) `Shell.Failure.timeout` — dropped dead `partialStdout` associated
  value (was always `""`). New shape: `.timeout(seconds:)`. (code-002 M1)
- (cycle 6) `Shell.run` — `precondition(executable.hasPrefix("/"))` enforces
  the doc-comment promise of explicit auditable paths (code-002 L2).
- (cycle 5) `Package.swift` → `swift-tools-version: 6.0` (strict-review L-004).
- (cycle 5) `CronHumanizer.dayName(_:)` 8-element array gets explicit comment
  documenting cron BSD/Vixie convention (0 and 7 both = Sunday) (strict-review L-003).
- (cycle 4) MenuBarPopoverView sections accept differentiated `emptyMessage` and
  use symmetric `prefix(8)` limits — strict-review M-004.
- (cycle 4) Sidebar "All" filter shows total service count — strict-review L-001.
- (cycle 4) Inspector Logs/Config tabs use `ContentUnavailableView` instead of
  raw placeholder text — strict-review H-002.
- (cycle 3) `StatusBadge` carries SF Symbol prefix per status + `accessibilityLabel`
  (design D-P0-2; WCAG 1.4.1 use of color).
- (cycle 3) `Schedule.cron(...).humanDescription` delegates to `CronHumanizer`.
- (cycle 3) `ServiceRegistryViewModel` is `@MainActor` with private setters;
  refresh delegates to `ServiceRegistry` actor.
- (cycle 2) `Service.command` is non-optional `String` (empty string when
  source omits it) — code-review-001 H3.
- (cycle 2) `ProcessOwner.agent` now takes typed `AgentKind` instead of `String` —
  code-review-001 L3.
- (cycle 2) `AgentJobsJsonProvider` logs malformed-JSON via `os.Logger` instead
  of silently swallowing — code-review-001 H1.
- (cycle 2) Menubar "Open Dashboard" uses `OpenWindowAction` instead of URL
  scheme — code-review-001 M3.

### Fixed
- (cycle 1→2) `Color(.systemGray3)` reference (NSColor name unavailable on
  SwiftUI Color initializer) → use `.gray.opacity(0.6)`.
