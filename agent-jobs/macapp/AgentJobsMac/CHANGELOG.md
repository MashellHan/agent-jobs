# Changelog — AgentJobsMac

All notable changes to the Mac app live here. Format: Keep a Changelog.

## [Unreleased]

### Added
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
