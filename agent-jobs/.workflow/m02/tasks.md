# M02 Tasks

> 9 atomic tasks, ordered by dependency. Each = one commit, ≤ 150 LOC diff.
> Every AC in `acceptance.md` is mapped to at least one task.

---

## T01 — Add `ServiceSource.Bucket` accessor [DONE]

- **Files:**
  - modify `macapp/AgentJobsMac/Sources/AgentJobsCore/Domain/ServiceSource.swift`
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/SourceBucketTests.swift`
- **Depends on:** none
- **Acceptance:** AC-F-05 (chip ordering source), AC-Q-01 (tests stay green), AC-Q-02 (≥80% coverage on new code)
- **Detail:** Add `enum Bucket: String, CaseIterable { registered, claudeScheduled, claudeSession, launchd, liveProcess }` with `displayName` + `sfSymbol`. Add `var bucket: Bucket` to `ServiceSource`. Test enumerates every existing `ServiceSource` case (use exhaustive switch in test) and asserts the mapping. Test asserts `Bucket.allCases` order matches the spec's chip order exactly.
- **Estimated diff size:** S (~50 LOC)

## T02 — Stub registry + frozen-date `Service.fixtures()` [DONE]

- **Files:**
  - create `macapp/AgentJobsMac/Sources/AgentJobsCore/Testing/StubServiceRegistry.swift`
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/StubRegistryTests.swift`
- **Depends on:** T01
- **Acceptance:** AC-F-04 (provider count introspection — stub registry validates the path), unblocks AC-V-01..05, AC-F-09, AC-F-12
- **Detail:** Wrap in `#if DEBUG`. Define `FixtureProvider: ServiceProvider`, `ServiceRegistry.fixtureRegistry()` (5 services, one per bucket), `.emptyRegistry()`, `.failingRegistry()`. Provide `Service.fixtures(frozenAt:)` returning exactly 5 deterministic `Service` values: agentJobsJson registered task, claudeScheduledTask(durable: true), claudeLoop(sessionId: "demo"), launchdUser daemon, process(matched: "npm run dev") with metrics. All `Date` values derived from the frozen reference. Test asserts `fixtures()` is deterministic across two calls and exactly covers all 5 buckets.
- **Estimated diff size:** M (~140 LOC)

## T03 — `setActivationPolicy(.accessory)` (LSUIElement equivalent) [DONE]

- **Files:**
  - modify `macapp/AgentJobsMac/Sources/AgentJobsMac/AgentJobsMacApp.swift`
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/AppLaunchTests.swift`
- **Depends on:** none (independent, ship first if possible)
- **Acceptance:** AC-Q-04 (no Dock icon), AC-F-02 (alive 3s after launch), AC-F-03 (menu-bar window present)
- **Detail:** Add `@NSApplicationDelegateAdaptor(AppDelegate.self)` plus a private `final class AppDelegate: NSObject, NSApplicationDelegate` that calls `NSApp.setActivationPolicy(.accessory)` in `applicationWillFinishLaunching(_:)`. Also `NSApp.activate(ignoringOtherApps: true)` right after `openWindow(id: "dashboard")` in the popover footer button (modify `MenuBarPopoverView.footer` — but that's covered in T05; do the activate-after-open in T05). Test in this task: spawn `Process` with `.build/debug/AgentJobsMac`, sleep 3s, assert process still running, then enumerate `CGWindowListCopyWindowInfo` and assert at least one window owned by `AgentJobsMac` exists at `kCGStatusWindowLevel`. Kill subprocess in tearDown.
- **Estimated diff size:** S (~70 LOC, mostly the test)

## T04 — `SourceBucketChip` + `SourceBucketStrip` views [DONE]

- **Files:**
  - create `macapp/AgentJobsMac/Sources/AgentJobsMac/Features/Dashboard/SourceBucketChip.swift`
  - create `macapp/AgentJobsMac/Sources/AgentJobsMac/Features/Dashboard/SourceBucketStrip.swift`
- **Depends on:** T01
- **Acceptance:** AC-F-05 (5 chips in fixed order), AC-F-06 (click filters; click again clears) — view-only piece
- **Detail:** `SourceBucketChip` = capsule with SF Symbol + displayName + count. Active state uses `Color.accentColor.opacity(0.2)` background; zero-count uses `.foregroundStyle(.tertiary)`. `SourceBucketStrip` takes `services: [Service]` and `selection: Binding<ServiceSource.Bucket?>`. Renders `ForEach(ServiceSource.Bucket.allCases)` + a trailing "total: N" label (not a button). Click toggles `selection` (set to bucket if different, nil if same). No tests at this layer — covered by T05.
- **Estimated diff size:** S (~110 LOC)

## T05 — Wire `SourceBucketStrip` into `DashboardView`; add bucket filter; activate-after-open [DONE]

- **Files:**
  - modify `macapp/AgentJobsMac/Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift`
  - modify `macapp/AgentJobsMac/Sources/AgentJobsMac/Features/MenuBar/MenuBarViews.swift` (1-line: `NSApp.activate(...)` after `openWindow(id:)`)
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/DashboardFilterTests.swift`
- **Depends on:** T01, T02, T04
- **Acceptance:** AC-F-05, AC-F-06, AC-F-07 (selection populates inspector in same window), AC-F-10 (Open Dashboard makes window visible)
- **Detail:** Add `@State private var bucketFilter: ServiceSource.Bucket?`. Inject `SourceBucketStrip(services: registry.services, selection: $bucketFilter)` above the existing `serviceTable` in the `content:` slot — wrap both in a `VStack(spacing: 0)`. Update `filteredServices` to AND both filters. Test (`DashboardFilterTests`) constructs `ServiceRegistryViewModel(registry: .fixtureRegistry())`, awaits `refresh()`, then exercises a small struct that mirrors the filter logic (extract `static func filter(_ services: [Service], category: Category?, bucket: Bucket?) -> [Service]` to make it pure-testable). Assert: nil/nil → 5, registered/nil → 1, nil/launchd → 1, claude/claudeScheduled → 1, etc.
- **Estimated diff size:** M (~150 LOC including test)

## T06 — Inspector enrichment: Provenance group, PID-only-when-set [DONE]

- **Files:**
  - modify `macapp/AgentJobsMac/Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift` (only `ServiceInspector` section)
- **Depends on:** T02 (fixtures help previews)
- **Acceptance:** AC-F-07 (all required fields populated), AC-F-08 (PID/Owner tiles only when `pid != nil`)
- **Detail:** Add a third `GridRow` in `overviewContent` for Provenance: file path / scheduled-task id (derive from `service.logsPath` for now since no scheduled-task-id field exists; spec says "render '—'" for missing fields), `createdAt` (formatted), origin agent + sessionId. Verify the existing `if let pid = service.pid` guard is correct (it already is — confirm and add a code comment citing AC-F-08). No new test needed — visual ACs in T08 will cover it.
- **Estimated diff size:** S (~60 LOC)

## T07 — Screenshot harness (in-process `NSHostingView` capture) [DONE]

- **Files:**
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/Visual/ScreenshotHarness.swift`
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/Visual/ScreenshotHarnessTests.swift`
  - create `scripts/visual-diff.sh` (executable)
- **Depends on:** T02
- **Acceptance:** unblocks AC-V-01..06; AC-Q-01 (harness self-tests pass)
- **Detail:** `@MainActor enum ScreenshotHarness` with `capture<V: View>(_ view: V, size: CGSize, scale: CGFloat = 1.0, appearance: NSAppearance.Name) throws -> Data`. Implementation: `NSHostingView(rootView: view.environment(\.colorScheme, ...))`, set `frame`, set `appearance = NSAppearance(named: appearance)`, call `layoutSubtreeIfNeeded`, spin runloop 50ms, `bitmapImageRepForCachingDisplay(in: bounds)`, `cacheDisplay(in:to:)`, return PNG via `representation(using: .png)`. Self-test: capture a 100×100 `Color.red.frame(...)` view, assert PNG > 0 bytes and decoded image's center pixel is red. `scripts/visual-diff.sh` per architecture doc — wraps `compare -fuzz 2%` and exits non-zero if pixel-diff ratio ≥ threshold (default 0.02, env override).
- **Estimated diff size:** M (~130 LOC across 3 files)

## T08 — Visual baseline tests (AC-V-01..05) [DONE]

- **Files:**
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/Visual/VisualBaselineTests.swift`
  - create initial baseline PNGs at `.workflow/m02/screenshots/baseline/{menubar-popover-light,menubar-popover-dark,dashboard-empty-light,dashboard-populated-light,dashboard-inspector-populated-light}.png` (generated by first run; implementer commits)
- **Depends on:** T02, T04, T05, T06, T07
- **Acceptance:** AC-V-01, AC-V-02, AC-V-03, AC-V-04, AC-V-05, AC-F-09 (running count), AC-F-11 (empty state), AC-F-12 (error state via failingRegistry)
- **Detail:** Five `XCTestCase` methods. Each: build a `ServiceRegistryViewModel(registry: .fixtureRegistry())` (or `.emptyRegistry()` / `.failingRegistry()`), `await viewModel.refresh()`, instantiate the view (`MenuBarPopoverView().environment(viewModel).frame(width: 360)` or `DashboardView().environment(viewModel).frame(width: 1200, height: 700)`), capture via harness, compare with baseline via `scripts/visual-diff.sh` (use `Process` to run it). On missing baseline, copy capture → baseline + log `[BASELINE_RECORDED]` and pass. AC-V-05 additionally sets `selection` to the first fixture's id before capture (use a small `@Bindable` test wrapper, or pre-set via a `previewSelection` parameter on `DashboardView` — see T05 for adding the optional init param).
- **Estimated diff size:** M (~150 LOC)

## T09 — Process-launch test (AC-V-06 menu-bar icon screenshot, AC-P-01 perf, AC-P-03 leak check) [DONE]

- **Files:**
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/Visual/MenuBarIconVisualTest.swift`
  - create `macapp/AgentJobsMac/Tests/AgentJobsCoreTests/PerformanceTests.swift`
- **Depends on:** T03, T07
- **Acceptance:** AC-V-06, AC-P-01, AC-P-02, AC-P-03, AC-P-04
- **Detail:** `MenuBarIconVisualTest`: spawn `.build/debug/AgentJobsMac`, poll up to 2s for a window at `kCGStatusWindowLevel` owned by `AgentJobsMac`, then `CGWindowListCreateImage(menuBarRect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution)`, save PNG, diff against baseline at 5% threshold. `PerformanceTests`: AC-P-01 measures cold-launch (spawn process, capture timestamps via signpost log), AC-P-04 builds a 100-element fixture and calls `ScrollViewProxy.scrollTo` programmatically inside a hosted Dashboard, asserts wall-clock < 250 ms. AC-P-03 starts auto-refresh, waits 95s, counts `Task` instances via Mirror introspection on the view model — assert it's still exactly 1.
- **Estimated diff size:** M (~140 LOC)

---

## Coverage matrix

| AC | Task(s) |
|---|---|
| AC-F-01 | every task (build must stay green) |
| AC-F-02 | T03 |
| AC-F-03 | T03 |
| AC-F-04 | T01 (existing `providerCount` already meets it; T01 adds a test guard if missing) |
| AC-F-05 | T01, T04, T05 |
| AC-F-06 | T04, T05 |
| AC-F-07 | T05, T06 |
| AC-F-08 | T06 |
| AC-F-09 | T08 (assert running count via stub) |
| AC-F-10 | T03 (activate), T05 |
| AC-F-11 | T08 (empty state visual + behavioral assertion) |
| AC-F-12 | T08 (failingRegistry → ErrorBanner) |
| AC-V-01..05 | T08 |
| AC-V-06 | T09 |
| AC-P-01..04 | T09 |
| AC-Q-01 | every task |
| AC-Q-02 | T01, T02, T04, T05 (new code coverage) |
| AC-Q-03 | every task (no new warnings) |
| AC-Q-04 | T03 |

All 26 ACs covered.

## Notes for implementer

- Commit one task per commit. Use commit prefix `impl(M02-T0N): <summary>`.
- T01, T02, T03, T07 have no UI dependencies and may be done in parallel if you want — but commit them in numerical order so Reviewer's diff is linear.
- Do NOT modify Discovery providers. Do NOT extend `Service` model. Spec says "render '—'" for missing fields.
- If a task balloons past 150 LOC, stop and split it; ping back to architect via `architect-pushback.md` if structural.
- If `setActivationPolicy(.accessory)` + `Window` scene cannot be made to focus the Dashboard, fall back to `NSWindow.makeKeyAndOrderFront(nil)` from the AppDelegate after `openWindow(id:)` — but try the activate-after-open path first.
- Baseline PNGs land in T08; commit them with the T08 commit so the next cycle has something to compare against.
