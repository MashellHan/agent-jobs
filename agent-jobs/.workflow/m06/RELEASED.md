# M06 Released

**Date:** 2026-04-27
**Final commit:** 0a321de
**Cycles:** IMPL=2 REVIEW=2 TEST=2 UI-CRITIC=2 (first ENFORCING ui-critic milestone; cycle-1 REJECT 20/30 → cycle-2 PASS 27/30)

## Summary
Information Architecture + first ENFORCING ui-critic gate. Six tickets closed (T-002 popover ≥480pt rich rows + status grouping; T-003 dashboard 1280×800 default + sidebar 220 / inspector 360 / list min 480; T-008 0-count chip dimming + tooltip; T-014 visual-harness dashboard `Table` + dark-scheme rendering; T-015 source-bucket-strip horizontal layout; T-016 Retry affordance on FAILED popover row) plus two cycle-1 ui-critic regressions (T-017 P0 dark-frame chrome bleed + T-018 P1 empty-popover scaffolding) closed in cycle 2. Cycle 1 landed all 9 IMPL tasks in 8 commits and passed reviewer 89/100 + tester 19/19, but ui-critic REJECTed 20/30 because the M05 P0 white-bleed condition recurred in dark scenarios 05 + 08 (sidebar interior + top header band + inspector pane) — tester's 4-corner luma sample missed it because the bleed was interior, not corner. Cycle 2 fixed it via 4 dark-only Snapshot.swift changes (NSApp.appearance pin, opaque resolved window bg, ordered-front offscreen, recursive forceAppearance walk + layer invalidation) plus a dark-only DashboardView pane background, all gated on `isDark` so M02/M03/M04 light baselines stayed byte-stable. Empty popover (scenario 03) restored to RUNNING(0) / SCHEDULED(0) / FAILED(0) scaffolding with per-section microcopy via the architect-specified `PopoverGrouping.groupByStatus(includeEmpty: true)` API. WL-2 pre-emptive split landed before T-002 rewrite (`AgentJobsMacUI.swift` 504 LOC < 600); WL-3 demoted `ProviderDiagnostics` actor + members to `internal` via new `DiagnosticsBearing` protocol. PROTOCOL.md UI-CRITIC gate moved from advisory (M05) to ENFORCING (M06+) and proved its worth on first cycle.

## Acceptance
19/19 testable ACs PASS (tester) + ui-critic ENFORCING PASS-with-tickets 27/30 (threshold 24/30; cycle-1 REJECT 20/30 cleared after T-017/T-018 closures).

| Gate | Verdict |
|---|---|
| Reviewer cycle 1 | PASS-with-nits 89/100 |
| Tester cycle 1 | PASS 19/19 testable ACs |
| UI-Critic cycle 1 | **REJECT 20/30** (AC-D-07 dark-frame trigger fired) |
| Reviewer cycle 2 | PASS 94/100 |
| Tester cycle 2 | PASS 19/19 testable ACs |
| UI-Critic cycle 2 | **PASS-with-tickets 27/30** (threshold 24/30) |

## Tickets closed
- T-002 P0 popover — ≥480pt wide; grouped rich rows (status pill + friendly title + 1-line summary); status priority order RUNNING/SCHEDULED/FAILED/OTHER
- T-003 P0 dashboard-default-size — 1280×800 default; sidebar 220 / inspector 360 / list min 480
- T-008 P1 empty-state — 0-count chips dimmed (opacity 0.55) + tooltip via `bucket.emptyExplanation`
- T-014 P0 visual-harness — `Snapshot.capture` rewrite hosting `NSHostingView` in offscreen `NSWindow` with appearance pin + runloop ticks; dashboard rows + dark scheme now render in capture-all output
- T-015 P1 source-bucket-strip — horizontal pill chips matching popover treatment; "total N" inline
- T-016 P2 popover-row — `RetryAffordance` button in FAILED row trailing slot (keyboard-reachable)
- T-017 P0 visual-harness (cycle-2) — dark dashboard chrome + inspector header bleed; 4 dark-only fixes in `Snapshot.swift` + dark-only `paneBackground` in `DashboardView.swift`; 30-point luma sample max 0.221 ≪ 0.3
- T-018 P1 empty-popover (cycle-2) — RUNNING(0)/SCHEDULED(0)/FAILED(0) scaffolding with per-section microcopy

## Tickets filed
None new this milestone. T-019 P2 (Name column too narrow at 1280pt) and T-020 P2 (bucket-strip header doesn't span sidebar) were filed during cycle-1 ui-critic review and remain open as carry-forward to M07 per ticket triage.

## Modules touched
- `AgentJobsVisualHarness.Snapshot` — offscreen `NSWindow` host; dark-only NSApp.appearance pin, opaque resolved window background, ordered-front, recursive `forceAppearance` walk + layer invalidation; helpers `resolvedBackgroundColor(for:)`, `invalidateLayers(on:)`, `forceAppearance(_:on:)`
- `AgentJobsMacUI` — new `Features/MenuBar/MenuBarPopoverView.swift` (extracted from `MenuBarViews.swift` per WL-2; 480pt grouped rich rows; empty path ForEach's `emptyGroupedServices`); new `Features/MenuBar/MenuBarRowViews.swift` (`PopoverGroupHeader` + `MenuBarRichRow`); new `Features/MenuBar/PopoverGrouping.swift` pure helper; new `Components/RetryAffordance.swift`; new `Features/Dashboard/DashboardWindowConfig.swift` (1280×800 + column widths); `DashboardView.swift` `.navigationSplitViewColumnWidth` modifiers + dark-only `paneBackground`; `SourceBucketStrip.swift` horizontal scroll wrapper + `.fixedSize` chips; `SourceBucketChip.swift` zero-state opacity 0.55 + emptyExplanation helpText
- `AgentJobsCore.Discovery` — new `internal protocol DiagnosticsBearing`; `ProviderDiagnostics` actor + members demoted to `internal`; `ServiceRegistry.snapshot(provider:)` reaches diagnostics via `as? any DiagnosticsBearing` cast; `ClaudeScheduledTasksProvider` + `ClaudeSessionCronProvider` conform; public init keeps no-arg surface, internal init for test injection
- `CaptureAll.Scenarios` — popover scenarios 01/02/03/10 → 480 wide; dashboard 04..08 → 1280×800; 09 → 1024×700
- `Tests/AgentJobsCoreTests/` — new `Visual/SnapshotRendererTests` (3), `DashboardWindowConfigTests` (3), `Visual/SourceBucketStripLayoutTests` (2), `PopoverGroupingTests` (4), `MenuBarRichRowTests` (2), `MenuBarPopoverViewWidthTests` (1)
- `.workflow/m06/screenshots/{baseline,critique}/` — 10 PNG + 10 JSON pairs at new sizes; 4 popover-related M02/M04 baselines also regenerated as fallout from row-shape change

## Test count
317 → 332 (+15).

## Deferred
- T-019 P2 dashboard-list — Name column too narrow at 1280pt; "Last Run" header clipped → M07
- T-020 P2 dashboard-chrome — Bucket-strip header doesn't span sidebar pane → M07
- AC-F-15 sidecar schema delta — implementation uses `scenarioName / metadata.viewportWidth/Height / colorScheme / appCommit`; spec wording was `scenario / width / height / scheme / commit`. Semantic intent met; spec-impl alignment for retro
- Dead helpers in `MenuBarPopoverView` (reviewer F1) + latent `ServiceRowCompact.swift` (cycle-1 reviewer F5) — M07 cleanup
- `Snapshot.forceAppearance` lacks internal dark guard (reviewer F3) — M07 rename to `forceDarkAppearance` or assert
- Baseline JSON timestamp churn (reviewer F4) — capture-all could skip JSON rewrite when PNG byte-stable
- ~150ms dark-capture overhead (reviewer F2) — monitor in M07 if budget tightens
- AC-V-06 menubar-icon visual flake — pre-existing environmental, watch-list since M02
