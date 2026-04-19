# Changelog — AgentJobsMac

All notable changes to the Mac app live here. Format: Keep a Changelog.

## [Unreleased]

### Added
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
