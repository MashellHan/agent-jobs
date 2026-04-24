# M02 Architecture — Functional UI baseline

> Reuse-first. The discovery layer (Core) is frozen. The UI layer already has
> `DashboardView`, `MenuBarPopoverView`, `ServiceInspector`, atoms in
> `Components/`. M02 adds: a `SourceBucket` enum + chip strip, an inspector
> field that always renders provenance, an LSUIElement activation policy, a
> deterministic stub registry for visual ACs, and a screenshot harness.

---

## Modules touched

| Module | Change |
|---|---|
| `AgentJobsCore/Domain/ServiceSource.swift` | **Add** `bucket: Bucket` accessor + nested `enum Bucket` (5 cases). No change to existing `Category`. |
| `AgentJobsCore/Discovery/ServiceRegistry.swift` | No code change. Reuse `defaultRegistry()` and `providerCount`. |
| `AgentJobsMac/AgentJobsMacApp.swift` | Add `applicationDidFinishLaunching` hook to set `NSApp.setActivationPolicy(.accessory)` (LSUIElement equivalent for SPM exec). Inject optional registry override for tests. |
| `AgentJobsMac/Features/Dashboard/DashboardView.swift` | Add `SourceBucketStrip` above `serviceTable`. Add `bucketFilter: SourceBucket?` state. Update `filteredServices` to AND `categoryFilter` + `bucketFilter`. Enrich `ServiceInspector.overviewContent` with a Provenance group (origin agent / sessionId / file path or scheduled-task id). |
| `AgentJobsMac/Features/Dashboard/SourceBucketStrip.swift` | **New** view — horizontal `HStack` of `SourceBucketChip` + total chip. ≤120 LOC. |
| `AgentJobsMac/Features/Dashboard/SourceBucketChip.swift` | **New** atom — icon + label + count, supports `isSelected` + `isZero` styling. ≤80 LOC. |
| `AgentJobsCore/Testing/StubServiceRegistry.swift` | **New** — non-actor `ServiceProvider`-array fed into `ServiceRegistry.init(providers:)`, plus `Service.fixtures(frozen:)` returning 5 deterministic services (one per bucket). Lives in Core under a `#if DEBUG` guard so tests + SwiftUI previews can both consume. ≤150 LOC. |
| `AgentJobsCoreTests/SourceBucketTests.swift` | **New** unit test — every `ServiceSource` case maps to expected bucket. |
| `AgentJobsCoreTests/DashboardFilterTests.swift` | **New** — exercises `filteredServices` with combinations of `categoryFilter` × `bucketFilter`. Uses `MainActor` and constructs `ServiceRegistryViewModel(registry:)` with a stub. |
| `AgentJobsCoreTests/Visual/ScreenshotHarness.swift` | **New** — in-process renderer that produces PNGs from a SwiftUI view tree (see "Screenshot strategy" below). |
| `AgentJobsCoreTests/Visual/VisualBaselineTests.swift` | **New** — six tests, one per AC-V-0N. Each renders the view, writes `.workflow/m02/screenshots/cycle-NNN/<name>.png`, then either records or compares to `baseline/<name>.png`. |
| `scripts/visual-diff.sh` | **New** — wraps ImageMagick `compare -metric AE -fuzz 2% A B diff.png`; exits non-zero on > 2% diff. Used by Tester. |

---

## New types (with module placement)

### `AgentJobsCore`

```swift
public extension ServiceSource {
    /// User-facing data-source bucket. ORTHOGONAL to `Category`.
    /// Category groups by *kind of scheduler* (Claude/launchd/cron/...).
    /// Bucket groups by *which discovery provider produced this row* — what
    /// the spec's summary strip displays.
    var bucket: Bucket {
        switch self {
        case .agentJobsJson:        return .registered
        case .claudeScheduledTask:  return .claudeScheduled
        case .claudeLoop:           return .claudeSession
        case .launchdUser:          return .launchd
        case .process:              return .liveProcess
        // Cases not produced by any wired provider in M02 fall back to
        // the closest bucket; they will not appear in the strip's counts
        // unless a future provider emits them.
        case .cron, .at:            return .launchd       // placeholder
        case .brewServices:         return .liveProcess   // placeholder
        case .loginItem:            return .registered    // placeholder
        }
    }

    enum Bucket: String, CaseIterable, Sendable, Hashable {
        case registered        // AgentJobsJsonProvider
        case claudeScheduled   // ClaudeScheduledTasksProvider
        case claudeSession     // ClaudeSessionCronProvider
        case launchd           // LaunchdUserProvider
        case liveProcess       // LsofProcessProvider

        public var displayName: String { ... }   // "registered", "claude-sched", "claude-loop", "launchd", "live-proc"
        public var sfSymbol: String { ... }      // doc.badge.gearshape, brain.head.profile, terminal, desktopcomputer, bolt.horizontal
    }
}
```

`Bucket.allCases` is the authoritative ORDER for the chip strip (registered → claudeScheduled → claudeSession → launchd → liveProcess), pinning AC-F-05.

### `AgentJobsCore/Testing/StubServiceRegistry.swift` (DEBUG only)

```swift
#if DEBUG
public struct FixtureProvider: ServiceProvider {
    public static let providerId = "fixture"
    public let services: [Service]
    public init(_ services: [Service]) { self.services = services }
    public func discover() async throws -> [Service] { services }
}

public extension ServiceRegistry {
    /// Five deterministic fixtures, one per bucket. All Dates frozen to
    /// `2026-01-15T12:00:00Z`. Pixel-stable for visual ACs.
    static func fixtureRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [FixtureProvider(Service.fixtures())])
    }
    static func emptyRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [FixtureProvider([])])
    }
    static func failingRegistry() -> ServiceRegistry { ... }   // throws from every provider
}

public extension Service {
    static func fixtures(frozenAt: Date = Date(timeIntervalSince1970: 1_768_564_800)) -> [Service]
}
#endif
```

### `AgentJobsMac/Features/Dashboard/SourceBucketStrip.swift`

```swift
struct SourceBucketStrip: View {
    let services: [Service]
    @Binding var selection: ServiceSource.Bucket?
    var body: some View { ... }   // HStack of 5 chips + total chip
}
```

### `AgentJobsCoreTests/Visual/ScreenshotHarness.swift`

```swift
@MainActor
enum ScreenshotHarness {
    /// Render any SwiftUI view at a fixed CGSize into a PNG file.
    /// Uses `NSHostingView` → `bitmapImageRepForCachingDisplay(in:)`.
    static func capture<V: View>(_ view: V, size: CGSize, scale: CGFloat = 1.0,
                                  appearance: NSAppearance.Name) throws -> Data
    /// Convenience: capture and write to URL.
    static func write<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name,
                                to url: URL) throws
}
```

---

## Protocols / interfaces

No new protocols. `FixtureProvider` conforms to existing
`ServiceProvider`. `Service.fixtures(frozenAt:)` is a pure factory; no
protocol needed.

---

## Data flow diagram

```
                  ┌────────────────────────┐
                  │  ServiceRegistryView-  │
                  │  Model (@Observable)   │
                  │  services: [Service]   │
                  └──┬─────────────────────┘
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
   MenuBarPopover  Dashboard     Inspector
   (existing)     (modified)     (modified)
                     │
        ┌────────────┼─────────────┐
        ▼            ▼             ▼
   sidebar       SourceBucket-   Table
   (Category     Strip (NEW)    rows
    filter)       (Bucket
                   filter)
        │            │             │
        └────┬───────┘             │
             ▼                     │
       filteredServices ◀──────────┘
       = services
         .filter(category)
         .filter(bucket)
```

Both filters are AND'd. Either being `nil` disables that constraint.

---

## Concurrency model

Unchanged from M01.5:
- `ServiceRegistry` is an `actor`.
- `ServiceRegistryViewModel` is `@MainActor`-isolated, holds `services`.
- Auto-refresh is a single `Task` owned by the view model; `stop()` cancels.

New: visual tests run on `@MainActor` because `NSHostingView` requires it.
The screenshot harness must drive a one-shot layout pass; we'll spin the
runloop briefly (`RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))`)
so async layout settles before capturing the bitmap.

LSUIElement: handled imperatively in `AgentJobsMacApp` via
`NSApplication.shared.setActivationPolicy(.accessory)` inside an
`AppDelegateAdaptor` (or a `.onAppear` hook on a hidden Settings scene).
SPM executables don't ship an Info.plist by default; this is the
canonical workaround and avoids introducing an Xcode project (AC-Q-04).

---

## Persistence schema changes

None. M02 is read-only UI work.

---

## Screenshot / visual-AC strategy (Open Question #1 → DECISION)

**Decision: in-process `NSHostingView` render, NOT XCUITest.** Rationale:

- XCUITest requires a full Xcode UITest target, which `swift test` doesn't
  drive natively for SPM packages. Adding it would mean either an Xcode
  project (rejected — keep SPM-only) or `xcodebuild test -scheme` plumbing
  (Tester complexity surge).
- We don't actually need to assert the OS menu-bar item exists at the
  *system* level for visual ACs — AC-F-03 (functional) is satisfied by
  enumerating `CGWindowListCopyWindowInfo` from a tiny launch-and-probe
  test. AC-V-06 is the menu-bar *strip* visibility, also via
  `CGWindowListCreateImage` after launching the real binary.
- Visual ACs V-01..V-05 can render the SwiftUI view tree (popover and
  Dashboard) in-process against a `StubServiceRegistry` with fixed dates,
  forced color scheme, fixed frame. Pixel-deterministic on a single
  developer machine; threshold of 2% absorbs cross-Sonoma font-renderer
  micro-jitter.
- AC-V-06 (menu-bar icon visible) requires a launched process. Test
  launches `swift run AgentJobsMac` as a subprocess, polls
  `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` for
  `kCGWindowLayer == kCGStatusWindowLevel` owned by `AgentJobsMac`,
  then `CGWindowListCreateImage` on the menu-bar strip. 5% threshold
  per spec.

Recording flow:
1. First time tester runs and `baseline/<name>.png` is missing → harness
   writes `cycle-NNN/<name>.png` AND copies it to `baseline/`. Test
   passes with `[BASELINE_RECORDED]` marker in stderr. Implementer
   commits the baselines.
2. Subsequent runs → harness writes `cycle-NNN/<name>.png` and shells
   out to `scripts/visual-diff.sh baseline/X.png cycle-NNN/X.png`.
   Exit code 0 = pass.

## Source-bucket grouping (Open Question #2 → DECISION)

**Decision: YES, add `ServiceSource.Bucket` enum + accessor.** PM
recommended this; architect confirms. `Category` already has 7 cases
serving the sidebar; conflating sidebar grouping with summary-strip
grouping would force ugly compromises (claudeScheduled vs claudeLoop
collapsing into one chip — explicitly rejected by spec AC-F-05). The
two enums stay orthogonal. Cost: ~15 LOC + one unit test.

## Image diff tool (Open Question #3 → DECISION)

**Decision: ImageMagick `compare`.** Already installed on the dev box
(`/opt/homebrew/bin/compare`). odiff would require `brew install odiff`
+ a Tester onboarding step. `compare -metric AE -fuzz 2% A B null:`
returns the count of pixels exceeding the fuzz threshold; we divide by
total pixel count and gate at < 2%. Wrapped in `scripts/visual-diff.sh`
so we can swap to odiff later without touching tests.

```bash
# scripts/visual-diff.sh
#!/usr/bin/env bash
set -euo pipefail
THRESHOLD="${THRESHOLD:-0.02}"   # 2% default; visual AC-V-06 overrides to 0.05
diff_count=$(compare -metric AE -fuzz 2% "$1" "$2" /tmp/diff.png 2>&1 || true)
total=$(magick identify -format "%[fx:w*h]" "$1")
ratio=$(python3 -c "print($diff_count / $total)")
python3 -c "import sys; sys.exit(0 if $ratio < $THRESHOLD else 1)"
```

---

## Testing strategy

| Layer | Tool | What it covers |
|---|---|---|
| Pure unit | `XCTest` (existing AgentJobsCoreTests) | `ServiceSource.bucket` mapping, `Service.fixtures()` determinism, view-model filter combinatorics |
| View binding | `XCTest` + direct view-model probing | `DashboardView.filteredServices` returns expected counts under category × bucket cross product |
| Visual | `XCTest` + `ScreenshotHarness` (in-process `NSHostingView`) | All 6 AC-V-0N scenarios; deterministic via stub registry + frozen Date |
| Process-level | `XCTest` that spawns `swift run AgentJobsMac` as `Process` | AC-F-02 (alive after 3s), AC-F-03 (menu-bar window present), AC-F-10 (Open Dashboard makes window visible) |
| Performance | `XCTestCase.measure` + signposts | AC-P-01 cold launch, AC-P-04 scroll 100 items |

Tester ownership: visual + process-level + performance. Implementer:
unit + view-binding + the harness itself.

Coverage: `swift test --enable-code-coverage` already in pipeline. Net-new
files in `Features/Dashboard/SourceBucketStrip*` and `Domain/ServiceSource`
extension must hit ≥ 80% (AC-Q-02).

---

## Open risks

| Risk | Mitigation |
|---|---|
| `NSHostingView.bitmapImageRepForCachingDisplay` produces blank PNGs if layout hasn't settled | Spin runloop 50ms before capture; if still blank, force `view.layoutSubtreeIfNeeded()` (the AppKit underlay supports this). |
| `NSAppearance.name = .darkAqua` on a hosting view doesn't actually flip SwiftUI color scheme | Wrap the rendered view in `.environment(\.colorScheme, .dark)` AND set the appearance — both are required. |
| `setActivationPolicy(.accessory)` + `Window` scene results in the dashboard window being un-focusable | Verified pattern: call `NSApp.activate(ignoringOtherApps: true)` immediately after `openWindow(id:)`. Add to footer button handler. |
| Spawning `swift run` in tests rebuilds the world | Tests reuse `.build/debug/AgentJobsMac` directly; `swift build` is the prerequisite (already AC-F-01). |
| ImageMagick fuzz semantics differ from "% pixels diff" → false positives | Harness uses `-fuzz 2%` (per-channel tolerance) AND counts pixels exceeding it; we report ratio, not raw AE. Tested on identical images → ratio 0.0. |
| Dashboard window doesn't auto-open with `.accessory` policy | Already handled by spec — tester opens via menu-bar "Open Dashboard" or directly via `openWindow(id: "dashboard")`. |
