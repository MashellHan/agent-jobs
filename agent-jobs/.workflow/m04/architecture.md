# M04 Architecture — Auto-refresh + fs.watch

> Reuse-first. Discovery (M01/M01.5) FROZEN. Actions + persistence (M03) FROZEN.
> M04 introduces a new `AgentJobsCore/Refresh/` layer (RefreshScheduler +
> file watchers + visibility provider) and replaces the view-model's
> 30 s polling loop with an event-driven `startWatchers()` entry point.
> The existing `refresh()`, `refreshNow()`, `stop()`, optimistic-overlay,
> and M03 actions all stay byte-identical at their call signatures.
>
> Tests use **swift-testing** (`@Suite`, `@Test`, `#expect`) per E002.
> Perf-sensitive ACs gated behind `AGENTJOBS_PERF=1` per E001 — the strict
> spec assertion is the only one in the test, no relaxed fallback.

---

## Open questions — resolved

### Q1. Where does `RefreshScheduler` live? → **`AgentJobsCore/Refresh/RefreshScheduler.swift` as an `actor`**
Concur with PM. An `actor` owns the debounce state (`pending: DispatchWorkItem?`,
`isFlushing: Bool`, `lastTriggers: [RefreshTrigger]`) and exposes:

```swift
public actor RefreshScheduler {
    public typealias Sink = @Sendable () async -> Void
    public init(debounce: Duration = .milliseconds(250), sink: @escaping Sink)
    public func trigger(_ reason: RefreshTrigger)
    public func flushNow() async             // for tests + manual button
    public func cancel()                     // tear-down
}
```

The view model owns ONE scheduler, instantiated in `startWatchers()`. The
sink closure captures `self` weakly and calls `await self?.refresh()`. The
scheduler does not know the view model exists — it only owns timing. Keeps
the debounce primitive testable in isolation against an injected counting
sink (AC-F-01, AC-P-02).

Concurrency note: the actor's serial executor is the natural mutual-exclusion
boundary for the in-flight guard (AC-F-14). When a trigger arrives while
the sink is awaiting, the actor queues the next trigger; we only schedule
ONE downstream `refresh()` after the current one resolves, regardless of
how many triggers piled up — implementation pattern in §"Debounce design".

### Q2. `Combine.Debounce` vs hand-rolled `DispatchWorkItem` → **Hand-rolled `DispatchWorkItem`**
Concur with PM that both are correct. We pick `DispatchWorkItem` because:

1. **Zero Combine surface in Core.** Core currently does not import
   Combine (grep confirms). Pulling Combine in for one debounce primitive
   is a heavier dependency-shape move than the AC requires.
2. **Lifecycle is explicit.** `cancel()` + `perform()` semantics on a
   `DispatchWorkItem` map 1:1 onto the test seam (`flushNow()`); a Combine
   `Publishers.Debounce` requires plumbing a `DispatchQueue.SchedulerType`
   stand-in for the test clock, which is more code than the primitive.
3. **No allocation per trigger.** A single `DispatchWorkItem` is reused
   (cancelled + reassigned) across the trigger storm; `Subjects` allocate.

The actor protects the `DispatchWorkItem` reference; the work item itself
posts back to the actor when it fires (`Task { await self.flush() }`).

### Q3. Visibility-pause signal source — **`NSApplication.didChangeOcclusionStateNotification` + an explicit `MenuBarPopoverPresence` boolean fed by `MenuBarPopoverView.task`**
Concur with PM that occlusion handles the dashboard window cleanly and
that SwiftUI does not expose `MenuBarExtra` popover state. Resolution:

- Define a `VisibilityProvider` protocol (one method: `isVisible: Bool`,
  one Combine-free async sequence: `func changes() -> AsyncStream<Bool>`).
- Production impl `AppKitVisibilityProvider` lives in **`AgentJobsMac`**
  (it touches `NSApplication`/`NSWindow`). Reads:
    - dashboard window occlusion via `NSApplication.didChangeOcclusionStateNotification`
      (filtered to the window with `id == "dashboard"`), AND
    - the popover-open boolean exposed by the view model (set true inside
      `MenuBarPopoverView.task { ... }` and `false` in `.onDisappear`,
      with a 1 s grace per spec to absorb SwiftUI's task-cancel jitter).
- The combined "is anything user-visible" predicate is `dashboardVisible || popoverOpen`.
- Test impl `FakeVisibilityProvider` is a `final class` whose `set(_:)`
  call drives a continuation. Used by AC-F-07 / AC-F-08 / AC-P-03.
- **Hard upper bound**: even when "paused", a 5-minute keepalive tick
  fires `RefreshScheduler.trigger(.periodic)`. This bounds worst-case
  staleness if the visibility signal somehow gets stuck. (AC implicitly
  satisfied — spec risk row "visibility-pause deadlock".)

### Decision: AC-F-15 → **DROP**
**Rationale.** AC-F-15 asserts the M03 optimistic-overlay still works
under the M04 cadence. The view model's `applyOptimisticOverlay()` already
runs inside `refresh()` regardless of who called it (file event, periodic,
manual). The overlay's TTL of `2 × refreshIntervalSeconds` collapses from
60 s to 20 s under M04 — strictly tighter, still well above the 250 ms
debounce + the median 500 ms latency, so no functional regression is
plausible. The existing M03 `ServiceRegistryViewModelActionsTests` already
covers the overlay merge behavior; running them against the M04 view model
(AC-Q-01 + AC-P-05) is sufficient. Adding a bespoke "10 s tick interleaved"
test buys a 0.5-cycle confidence increment for ~30 LOC of test scaffolding
and one new task. **PM flagged it as a drop candidate; architect concurs.**

### Decision: AC-V-05 → **KEEP**
**Rationale.** AC-V-05 asserts the indicator is rendered in BOTH the
menu-bar popover AND the dashboard toolbar. PM flagged it as a drop
candidate because "AC-V-01..03 cover the indicator conceptually". I
disagree: the indicator visibility tests cover its rendering in *one*
location (the popover). The dashboard-toolbar placement is **new UI
surface in M04** (today the dashboard toolbar holds only the M03 Refresh
button), and "I'm refreshing right now" feedback is meaningless if the
user is looking at the dashboard and the indicator is hidden in the menu
bar. This is the single best UX justification for M04 over the M03
status quo (cf. SwiftBar issue #321 in competitive-analysis.md). Cost of
keeping: ~80 LOC of view code in DashboardView toolbar + 2 baseline PNGs
(popover + dashboard-toolbar). Worth it. **KEEP.**

Final AC count: F=14 + V=5 + P=5 = 24 (within the 15-25 spec window) + 6 quality.

---

## Modules touched

| Module | Change |
|---|---|
| `AgentJobsCore/Refresh/WatchPaths.swift` | **New** — `Sendable` struct + `static let production` factory resolving the three default paths under `NSHomeDirectory()`. ≤60 LOC. |
| `AgentJobsCore/Refresh/RefreshTrigger.swift` | **New** — `enum RefreshTrigger: Sendable, Equatable { case fileEvent(WatchedSource), periodic, manual }` with nested `enum WatchedSource { case jobsJson, scheduledTasks, claudeProjects }`. ≤40 LOC. |
| `AgentJobsCore/Refresh/RefreshScheduler.swift` | **New** — `actor` owning the 250 ms trailing debounce + the in-flight guard (AC-F-01, AC-F-14, AC-P-02). ≤120 LOC. |
| `AgentJobsCore/Refresh/FileObjectWatcher.swift` | **New** — `final class` wrapping `DispatchSource.makeFileSystemObjectSource` + atomic-rename re-open logic (AC-F-02, AC-F-03, AC-F-04, AC-F-13). ≤150 LOC. |
| `AgentJobsCore/Refresh/DirectoryEventWatcher.swift` | **New** — `final class` wrapping `FSEventStreamCreate` for `~/.claude/projects/` recursive (AC-F-05, AC-F-13). ≤120 LOC. |
| `AgentJobsCore/Refresh/PeriodicTicker.swift` | **New** — `actor` owning a cancellable `Task` that sleeps `interval` and re-fires; pause/resume API (AC-F-06, AC-F-07, AC-F-12). ≤80 LOC. |
| `AgentJobsCore/Refresh/VisibilityProvider.swift` | **New** — `protocol VisibilityProvider: Sendable` + `final class FakeVisibilityProvider` (test impl) (AC-F-07, AC-F-08, AC-P-03). ≤80 LOC. |
| `AgentJobsMac/Features/MenuBar/AutoRefreshIndicator.swift` | **Modify** — replace clock-driven label with three-state rendering (idle / refreshing / error) driven by `viewModel.isRefreshing` + `viewModel.lastRefreshError` + `viewModel.lastRefresh`. ≤120 LOC after rewrite (was 35 LOC). |
| `AgentJobsMac/Refresh/AppKitVisibilityProvider.swift` | **New** — production impl observing `NSApplication.didChangeOcclusionStateNotification` for the dashboard window + `popoverOpen` from the view model. ≤120 LOC. |
| `AgentJobsMac/AgentJobsMacApp.swift` | **Modify** — `ServiceRegistryViewModel` gains `lastRefreshError: String?`, `popoverOpen: Bool`, `watchPaths: WatchPaths`, `startWatchers(visibility:)`, replaces `startAutoRefresh()`. `stop()` extends to cancel scheduler + watchers + ticker + visibility task. `refresh()` sets `isRefreshing = true` for the duration of the call (currently only `refreshNow()` does). The popover `.task` and dashboard `.task` both call `startWatchers()` (idempotent). MenuBarPopoverView toggles `popoverOpen`. Dashboard toolbar gets the indicator inserted left of the Refresh button (AC-V-05). |
| `AgentJobsMac/Features/MenuBar/MenuBarViews.swift` | **Modify** — set `popoverOpen` in `.task` / clear in `.onDisappear`. Indicator already rendered here (M02). |
| `AgentJobsMac/Features/Dashboard/DashboardView.swift` | **Modify** — insert `AutoRefreshIndicator` into `dashboardToolbar` left of the existing Refresh button. ~20 LOC. |
| `Tests/AgentJobsCoreTests/Refresh/RefreshSchedulerTests.swift` | **New** — debounce, in-flight guard, multi-trigger collapse, flushNow (AC-F-01, AC-F-14, AC-P-02). |
| `Tests/AgentJobsCoreTests/Refresh/FileObjectWatcherTests.swift` | **New** — write detection, atomic-rename re-open, install-fail surfaces error (AC-F-02, AC-F-03, AC-F-04, AC-F-13). |
| `Tests/AgentJobsCoreTests/Refresh/DirectoryEventWatcherTests.swift` | **New** — nested-jsonl creation triggers, no spurious history-replay (AC-F-05). |
| `Tests/AgentJobsCoreTests/Refresh/PeriodicTickerTests.swift` | **New** — tick cadence, pause/resume cancellation, no leaks (AC-F-06, AC-F-12, AC-P-03). |
| `Tests/AgentJobsCoreTests/ServiceRegistryViewModelWatchersTests.swift` | **New** — wires the view model with a `FakeVisibilityProvider` + a temp `WatchPaths`, drives end-to-end (AC-F-07, AC-F-08, AC-F-09, AC-F-10, AC-F-11, AC-F-12, AC-P-01, AC-P-04). |
| `Tests/AgentJobsCoreTests/Visual/AutoRefreshIndicatorVisualTests.swift` | **New** — 3 indicator state baselines + popover + dashboard-toolbar placement (AC-V-01..V-05). Reuses M02 ScreenshotHarness. |
| `Tests/AgentJobsCoreTests/Visual/SelectionPersistenceVisualTests.swift` | **New** — 10× refresh stress with selected row #3 (AC-V-04, AC-F-10). |
| `Tests/AgentJobsCoreTests/StaticGrepRogueRefsTests.swift` | **Extend** — add patterns asserting no test file string-references `.agent-jobs/`, `.claude/scheduled_tasks.json`, `.claude/projects`, or `NSHomeDirectory()` outside an allow-list (AC-Q-04, AC-Q-06). |

---

## New types

### `AgentJobsCore/Refresh/WatchPaths.swift`

```swift
public struct WatchPaths: Sendable, Hashable {
    public let jobsJson: URL
    public let scheduledTasks: URL
    public let claudeProjectsDir: URL
    public init(jobsJson: URL, scheduledTasks: URL, claudeProjectsDir: URL)

    /// Default production paths, resolved from `NSHomeDirectory()`.
    /// View model passes `nil` to get this; tests pass an explicit
    /// `WatchPaths(...)` rooted under `FileManager.default.temporaryDirectory`.
    public static var production: WatchPaths { ... }
}
```

### `AgentJobsCore/Refresh/RefreshTrigger.swift`

```swift
public enum RefreshTrigger: Sendable, Equatable, Hashable {
    public enum WatchedSource: Sendable, Equatable, Hashable {
        case jobsJson
        case scheduledTasks
        case claudeProjects
    }
    case fileEvent(WatchedSource)
    case periodic
    case manual
}
```

### `AgentJobsCore/Refresh/RefreshScheduler.swift`

```swift
public actor RefreshScheduler {
    public typealias Sink = @Sendable () async -> Void

    private let debounce: Duration
    private let sink: Sink
    private var pendingItem: DispatchWorkItem?
    private var isFlushing: Bool = false
    private var coalescedQueued: Bool = false       // a trigger arrived during a flush
    private(set) public var lastTriggers: [RefreshTrigger] = []
    private let logger = Logger(subsystem: "dev.agentjobs", category: "RefreshScheduler")

    public init(debounce: Duration = .milliseconds(250), sink: @escaping Sink)
    public func trigger(_ reason: RefreshTrigger)   // schedules; cancels any pending
    public func flushNow() async                    // skip debounce — used by manual + tests
    public func cancel()                            // for tear-down

    // private:
    private func scheduleFire()                     // arms a DispatchWorkItem on a global queue
    private func fire() async                       // invokes sink with in-flight guard
}
```

**Trigger handling sequence** (this is the AC-F-14 contract):

1. `trigger(_:)` records the reason in `lastTriggers` (cap at 32 for memory),
   logs at debug level, then:
   - If `isFlushing == true`: set `coalescedQueued = true` and return.
     The currently-running flush will re-arm on completion.
   - Else: cancel any pending `DispatchWorkItem` and arm a new one
     `debounce` ms in the future.
2. The fired work item posts back into the actor (`Task { await self.fire() }`).
3. `fire()`:
   - Sets `isFlushing = true`, clears `pendingItem`, snapshots and clears `coalescedQueued`.
   - `await sink()` (the view model's `refresh()`).
   - Sets `isFlushing = false`.
   - If `coalescedQueued` was true: arm a fresh `scheduleFire()` so triggers
     received during the flush still produce one downstream call.

This guarantees: between the moment the storm starts and the moment the
storm dies down, exactly N+1 sink calls happen, where N is the number of
non-empty debounce windows fully observed. In the typical "5 triggers in
100 ms" case (AC-P-02), N=0 (all 5 collapse into one window), so exactly
1 sink call fires.

### `AgentJobsCore/Refresh/FileObjectWatcher.swift`

```swift
public final class FileObjectWatcher: @unchecked Sendable {
    public typealias OnEvent = @Sendable () -> Void

    public init(url: URL,
                queue: DispatchQueue = .global(qos: .utility),
                onEvent: @escaping OnEvent,
                onInstallFailure: @escaping @Sendable (Error) -> Void)

    public func start()                  // opens fd + arms DispatchSource
    public func stop()                   // cancels source + closes fd

    // private:
    // fd: Int32, source: DispatchSourceFileSystemObject?
    // mask: [.write, .extend, .delete, .rename, .revoke]
    // event handler:
    //   if .delete or .rename or .revoke:
    //     stop()
    //     schedule a re-open after 50 ms via DispatchQueue.asyncAfter
    //     on re-open success, fire onEvent() once (file effectively changed)
    //     on re-open failure, exponential backoff capped at 5 s; after 3
    //     consecutive failures, call onInstallFailure(...)
    //   else (.write, .extend):
    //     fire onEvent()
}
```

The `@unchecked Sendable` is justified because all mutable state is touched
only on `queue` (which is fixed at init); we annotate that invariant in a
doc comment. The class is reference-typed so `start()` / `stop()` can mutate
the source/fd without escaping a `mutating` actor boundary into the
`DispatchSource` event handler closure (which captures `self`).

### `AgentJobsCore/Refresh/DirectoryEventWatcher.swift`

```swift
public final class DirectoryEventWatcher: @unchecked Sendable {
    public typealias OnEvent = @Sendable () -> Void

    public init(directory: URL,
                latency: CFTimeInterval = 0.25,
                onEvent: @escaping OnEvent,
                onInstallFailure: @escaping @Sendable (Error) -> Void)

    public func start()                  // FSEventStreamCreate + Schedule + Start
    public func stop()                   // Stop + Invalidate + Release

    // FSEventStreamCreate flags: kFSEventStreamCreateFlagFileEvents
    //                          | kFSEventStreamCreateFlagNoDefer
    //                          | kFSEventStreamCreateFlagUseCFTypes
    // sinceWhen: kFSEventStreamEventIdSinceNow  (no history replay — AC-F-05)
    // path filter (in callback): only fire onEvent() if at least one event
    //   path ends in ".jsonl" — keeps spurious `.DS_Store` writes from
    //   churning refresh.
}
```

The `OnEvent` callback is debounced upstream by `RefreshScheduler`, so we
do NOT add another debounce layer here — the FSEvents `latency` param is
purely the kernel coalescing window; we let our 250 ms `RefreshScheduler`
window cover application-level coalescing.

### `AgentJobsCore/Refresh/PeriodicTicker.swift`

```swift
public actor PeriodicTicker {
    private let interval: Duration
    private let onTick: @Sendable () async -> Void
    private var task: Task<Void, Never>?
    private var isPaused: Bool = false
    private let keepaliveInterval: Duration   // 5 min — survives a stuck visibility signal

    public init(interval: Duration = .seconds(10),
                keepalive: Duration = .seconds(300),
                onTick: @escaping @Sendable () async -> Void)

    public func start()                  // arms the loop; idempotent
    public func pause()                  // stops firing onTick at `interval`; keepalive still fires
    public func resume() async           // immediate catch-up tick + re-arm to interval
    public func cancel()                 // tears down task entirely (for view-model `stop()`)
}
```

Loop body (pseudocode):

```swift
while !Task.isCancelled {
    let sleep = isPaused ? keepaliveInterval : interval
    try? await Task.sleep(for: sleep)
    if Task.isCancelled { break }
    await onTick()
}
```

`pause()` and `resume()` flip `isPaused`; the next loop iteration picks up
the new sleep duration. `resume()` first calls `onTick()` directly (the
"immediate catch-up" required by AC-F-07).

### `AgentJobsCore/Refresh/VisibilityProvider.swift`

```swift
public protocol VisibilityProvider: Sendable {
    /// Snapshot. Production reads NSApp + popover state.
    var isVisible: Bool { get async }
    /// Stream of changes. The view model awaits this and pauses/resumes
    /// the PeriodicTicker accordingly.
    func changes() -> AsyncStream<Bool>
}

public final class FakeVisibilityProvider: VisibilityProvider, @unchecked Sendable {
    public init(initial: Bool = true)
    public func set(_ visible: Bool)             // test driver
    public var isVisible: Bool { get async }
    public func changes() -> AsyncStream<Bool>
}
```

### `AgentJobsMac/Refresh/AppKitVisibilityProvider.swift` (App-side production impl)

```swift
@MainActor
public final class AppKitVisibilityProvider: VisibilityProvider {
    public init(popoverOpen: @MainActor @Sendable @escaping () -> Bool)

    public var isVisible: Bool { get async }     // dashboardOccluded == false || popoverOpen()
    public func changes() -> AsyncStream<Bool>   // observes didChangeOcclusionState +
                                                 // a poll of popoverOpen() every 1 s (the 1 s
                                                 // grace from spec — absorbs SwiftUI .task
                                                 // cancellation jitter)
}
```

The view model passes `popoverOpen: { [weak self] in self?.popoverOpen ?? false }`.
SwiftUI `MenuBarPopoverView.task` sets `self.popoverOpen = true` on enter and
`.onDisappear { self.popoverOpen = false }`.

### `ServiceRegistryViewModel` additions

```swift
@Observable @MainActor final class ServiceRegistryViewModel {
    // existing M01..M03 state preserved.

    // NEW (M04):
    private(set) var lastRefreshError: String? = nil
    var popoverOpen: Bool = false                    // mutated by MenuBarPopoverView
    private let watchPaths: WatchPaths
    private var scheduler: RefreshScheduler?
    private var jobsWatcher: FileObjectWatcher?
    private var schedTasksWatcher: FileObjectWatcher?
    private var claudeDirWatcher: DirectoryEventWatcher?
    private var ticker: PeriodicTicker?
    private var visibilityTask: Task<Void, Never>?
    private var visibility: (any VisibilityProvider)?

    init(registry: ServiceRegistry = .defaultRegistry(),
         stopExecutor: (any StopExecutor)? = nil,
         hiddenStore: HiddenStore? = nil,
         watchPaths: WatchPaths = .production)         // NEW

    /// REPLACES startAutoRefresh(). Idempotent — guarded by scheduler != nil.
    /// Wires file watchers + periodic ticker + visibility observer through a
    /// shared RefreshScheduler whose sink is `await self.refresh()`.
    func startWatchers(visibility: any VisibilityProvider = AppKitVisibilityProvider(...)) async

    /// Now cancels: scheduler, all 3 watchers, ticker, visibilityTask.
    /// Existing autoRefreshTask cancel is removed (no more loop).
    func stop()

    // existing refresh() body extended:
    //   - sets isRefreshing = true at entry, defer { isRefreshing = false }
    //     for ALL refresh paths (not just refreshNow()) — AC-F-09.
    //   - on completion, sets lastRefreshError = result.allFailed ? "..." : nil — AC-F-09.
    //   - in-place mutation of services preserved (already in-place; no change needed).

    // existing refreshNow() routes through scheduler.flushNow() now — AC-F-01,
    // so the M03 Refresh button funnels into the same debounce path with
    // immediate flush semantics.
}
```

Backwards-compat: `startAutoRefresh()` is **REMOVED**; both call sites
(menu-bar `.task` and dashboard `.task`) switch to `startWatchers()`. This
is a one-line edit per call site (still inside `.task { await ... }`).

### `AutoRefreshIndicator` rewrite

```swift
struct AutoRefreshIndicator: View {
    @Environment(ServiceRegistryViewModel.self) private var viewModel
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            iconView
            Text(label).font(DesignTokens.Typography.caption.monospacedDigit())
                       .foregroundStyle(textColor)
        }
        .onReceive(timer) { now = $0 }
        .help(tooltip)
        .accessibilityLabel("Auto-refresh status: \(label)")
    }

    private enum State { case idle, refreshing, error(String) }
    private var state: State {
        if let err = viewModel.lastRefreshError { return .error(err) }
        if viewModel.isRefreshing { return .refreshing }
        return .idle
    }
    // iconView, label, textColor, tooltip switch on state.
    // refreshing → SF "arrow.clockwise.circle" accent + .symbolEffect(.pulse)
    //              gated by !reduceMotion.
    // error     → SF "exclamationmark.triangle" red.
    // idle      → SF "arrow.clockwise.circle" secondary + "updated Ns ago".
}
```

The "next in Ns" tail is dropped per spec — event-driven refresh makes
"next in" misleading.

---

## Protocols / interfaces

| Protocol | Module | Purpose |
|---|---|---|
| `VisibilityProvider` | Core (Refresh) | Inject window/popover visibility into the view model so tests don't need NSApp. Production impl lives in App layer. |

`RefreshScheduler.Sink`, `FileObjectWatcher.OnEvent`, `DirectoryEventWatcher.OnEvent`,
`PeriodicTicker.onTick`, `AppKitVisibilityProvider.popoverOpen` are all
`@Sendable` closure typealiases — lighter than full protocols since each
is one method.

---

## Data flow diagram

```
   ┌─ FileObjectWatcher(jobs.json)        ─┐
   ├─ FileObjectWatcher(scheduled_tasks)  ─┤
   ├─ DirectoryEventWatcher(claude/proj/) ─┤
   ├─ PeriodicTicker(10s, paused on hide) ─┼─→ RefreshScheduler.trigger(reason)
   └─ Manual: vm.refreshNow()             ─┘                    │
                                                                 │ (250 ms trailing
                                                                 │  debounce; in-flight
                                                                 │  guard collapses
                                                                 │  storm to one call)
                                                                 ▼
                                                  ServiceRegistryViewModel.refresh()
                                                  ├ isRefreshing = true
                                                  ├ result = await registry.discoverAllDetailed()
                                                  ├ services = sorted (in place — keys stable)
                                                  ├ apply M03 optimistic overlay
                                                  ├ lastRefreshError = result.allFailed ? msg : nil
                                                  └ isRefreshing = false
                                                                 │
                              ┌──────────────────────────────────┘
                              ▼
                AutoRefreshIndicator (popover + dashboard toolbar)
                  state derived from viewModel.{isRefreshing, lastRefreshError}

   ┌─ AppKitVisibilityProvider ────┐
   │  observes:                     │
   │   - NSApplication.didChangeOcclusionStateNotification (dashboard window)
   │   - popoverOpen flag (set by MenuBarPopoverView .task / .onDisappear)
   │  emits AsyncStream<Bool>        │──→ vm.visibilityTask awaits stream:
   └────────────────────────────────┘       false → ticker.pause()
                                            true  → ticker.resume() (immediate tick)
```

---

## Watcher topology — per-source rationale

| Source | Primitive | Rationale |
|---|---|---|
| `~/.agent-jobs/jobs.json` | `DispatchSource.makeFileSystemObjectSource(O_EVTONLY)` | One file, atomic-rename pattern, kqueue is the cheapest thing. |
| `~/.claude/scheduled_tasks.json` | Same | Same. |
| `~/.claude/projects/**/*.jsonl` | `FSEventStreamCreate(recursive, latency=0.25s, sinceWhen=NowId)` | Directory tree with potentially thousands of jsonls; per-fd watching would (a) blow the per-process fd budget (~256 default) and (b) need re-watch on every new session file. CoreServices is the right tool. Path filter `.jsonl` keeps spurious events from `.DS_Store`/swap files quiet. |
| Live processes (lsof) | `PeriodicTicker(10s)` paused when hidden | lsof has no file-event surface; we must poll. 10 s is twice as conservative as Activity Monitor's default 5 s, plenty fresh while UI is open, zero cost while hidden. |

### Atomic-rename handling (binding code path — AC-F-04)

When `HiddenStore` (and the Node CLI, and every well-behaved editor)
writes via `write tmp; rename(tmp, target)`, the kernel sends `.delete`
or `.rename` on the original fd. `FileObjectWatcher` event handler:

```
on event:
    if mask intersects [.delete, .rename, .revoke]:
        stop()                                   // cancels source + closes fd
        DispatchQueue.global().asyncAfter(50 ms):
            try open(O_EVTONLY) → install fresh source
            on success: fire onEvent() once, reset backoff
            on failure:
                backoff = min(backoff * 2, 5 s)
                attempts += 1
                if attempts >= 3: onInstallFailure(...)
                else: schedule another retry
    else (.write, .extend):
        fire onEvent()
```

The 50 ms delay is the spec's chosen value — long enough for the writer's
`rename(2)` syscall to settle, short enough to land well within the AC-P-01
500 ms latency budget.

---

## Debounce design

- **Window:** 250 ms trailing.
- **Why trailing:** read-after-write semantics. We want `discoverAll()` to
  observe the post-storm state, not a mid-storm snapshot.
- **Coalescing:** every trigger from every source contributes to one
  pending sink call. No per-source debouncing (correct + cheap).
- **In-flight guard (AC-F-14):** described in §"RefreshScheduler" above.
  The guarantee: at most one `sink()` is awaiting at any time, and at
  least one additional `sink()` will fire if any trigger arrived during
  the in-flight call.
- **Test seam:** `flushNow()` skips the debounce timer and runs the sink
  directly (still respecting the in-flight guard). Used by:
  - `vm.refreshNow()` — manual button feels instant.
  - `RefreshSchedulerTests` — deterministic without `Task.sleep`.

---

## Visibility-pause hook

Lifecycle:

1. `vm.startWatchers(visibility:)` stores the provider, starts the
   `PeriodicTicker`, and spawns `visibilityTask`:
   ```swift
   visibilityTask = Task { [weak self, ticker, visibility] in
       for await visible in visibility.changes() {
           if visible {
               await ticker.resume()             // immediate tick + re-arm
           } else {
               await ticker.pause()              // periodic stops; keepalive still fires
           }
       }
   }
   ```
2. `vm.stop()` cancels `visibilityTask` (which terminates the for-await
   loop), then calls `ticker.cancel()` and the watchers' `stop()`.

Production wiring of the provider:

- `AppKitVisibilityProvider` observes
  `NSApplication.didChangeOcclusionStateNotification` and filters to the
  window with id `"dashboard"` (matched by `NSWindow.identifier`).
- It also reads `vm.popoverOpen` via the closure passed at init time;
  a 1 s polling timer covers the gap between SwiftUI cancelling the
  popover's `.task` and our `.onDisappear` (the spec's grace).
- The combined predicate `dashboardVisible || popoverOpen` flips the
  AsyncStream.

Hard upper bound: the `PeriodicTicker`'s `keepaliveInterval` of 5 minutes
keeps the worst case at "5 minutes of staleness", not "infinite", even if
the visibility signal somehow gets stuck (spec risk row "visibility-pause
deadlock").

---

## Test seam — `WatchPaths` injection

Production:

```swift
ServiceRegistryViewModel()                    // watchPaths defaults to .production
ServiceRegistryViewModel(watchPaths: .production)
```

Tests (mandatory):

```swift
let tempRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("agentjobs-watch-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
let paths = WatchPaths(
    jobsJson: tempRoot.appendingPathComponent("jobs.json"),
    scheduledTasks: tempRoot.appendingPathComponent("scheduled_tasks.json"),
    claudeProjectsDir: tempRoot.appendingPathComponent("claude-projects"))
let vm = ServiceRegistryViewModel(
    registry: ServiceRegistry.fixtureRegistry(),
    watchPaths: paths)
defer { vm.stop(); try? FileManager.default.removeItem(at: tempRoot) }
```

The `StaticGrepRogueRefsTests` extension (AC-Q-04) string-greps the test
target for the literals `.agent-jobs/`, `.claude/scheduled_tasks.json`,
`.claude/projects`, and `NSHomeDirectory()`. Allow-list documented in the
test itself (e.g., the test for default-paths-resolution in
`ServiceRegistryViewModelWatchersTests` is the only file allowed to assert
on the production paths).

---

## Concurrency model

| Component | Isolation | Rationale |
|---|---|---|
| `RefreshScheduler` | `actor` | Mutual exclusion for debounce/in-flight state. |
| `FileObjectWatcher` | `final class @unchecked Sendable`, all mutable state on a fixed `DispatchQueue` | `DispatchSource` event handlers are queue-isolated; an actor would impedance-mismatch. |
| `DirectoryEventWatcher` | Same as above | Same. |
| `PeriodicTicker` | `actor` | Owns a `Task` whose cancellation flag is read across pause/resume calls. |
| `AppKitVisibilityProvider` | `@MainActor` | Touches NSApp + NSWindow. |
| `FakeVisibilityProvider` | `final class @unchecked Sendable` | Test driver is set from the test thread. |
| `ServiceRegistryViewModel` | `@MainActor` (existing) | Drives `@Observable` properties. |

Main-thread budget (AC-P-04): `discoverAll()` already runs on the
`ServiceRegistry` actor (off main); `services = sorted` is the only main
hop and is O(n) on n ≤ a few hundred. Sort happens off main inside
`refresh()` where convenient. The unit test posts `Date()` every 8 ms via
`DispatchQueue.main.asyncAfter` during a refresh and asserts no
inter-checkpoint gap exceeds 16 ms.

---

## Persistence schema changes

None. M04 is read-only from disk for the watcher paths; HiddenStore (M03)
is unchanged.

---

## Testing strategy

Per E002: tests use **swift-testing** (`@Suite`, `@Test`, `#expect`,
`#expect(throws:)`, `.enabled(if:)`). Confirmed by reading
`Tests/AgentJobsCoreTests/HiddenStoreTests.swift` (lines 1-50).

| Layer | Suite | Covers ACs |
|---|---|---|
| Pure unit — debounce | `RefreshSchedulerTests` | AC-F-01, AC-F-14, AC-P-02 |
| Pure unit — file watcher | `FileObjectWatcherTests` | AC-F-02, AC-F-03, AC-F-04, AC-F-13 |
| Pure unit — directory watcher | `DirectoryEventWatcherTests` | AC-F-05 |
| Pure unit — periodic ticker | `PeriodicTickerTests` | AC-F-06, AC-F-12, AC-P-03 |
| View-model wiring | `ServiceRegistryViewModelWatchersTests` | AC-F-07, F-08, F-09, F-10, F-11, F-12, P-01, P-04 |
| Visual baselines | `AutoRefreshIndicatorVisualTests` | AC-V-01, V-02, V-03, V-05 |
| Visual stress | `SelectionPersistenceVisualTests` | AC-V-04 |
| Quality / static-grep | `StaticGrepRogueRefsTests` (extend) | AC-Q-04, AC-Q-06 |
| Build / coverage / no new deps | existing CI flags | AC-Q-01, AC-Q-02, AC-Q-03, AC-Q-05 |

### Gating per E001

Strict assertions only (no relaxed fallbacks). Gated behind
`AGENTJOBS_PERF=1` via `.enabled(if: ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1")`:

- AC-P-01 (500 ms median latency): asserts `<= 500 ms` over 20 runs.
- AC-P-02 (debounce within 250+50 ms of LAST trigger): strict bound.
- AC-P-03 (zero periodic ticks during 60 s of hidden state): strict 0.
- AC-P-04 (no main-thread block > 16 ms during refresh): strict 16 ms.

### Test count (AC-Q-03)

Target: ≥ M03 final (226) + 20 = 246. Estimated +30 across:

- RefreshSchedulerTests: 6 tests
- FileObjectWatcherTests: 6 tests
- DirectoryEventWatcherTests: 4 tests
- PeriodicTickerTests: 4 tests
- ServiceRegistryViewModelWatchersTests: 6 tests
- AutoRefreshIndicatorVisualTests: 4 tests (3 states + 2 placement, sharing baselines)
- SelectionPersistenceVisualTests: 1 test (10× refresh inside one)
- StaticGrepRogueRefsTests: +1 test

= +32. Comfortable margin.

### Coverage (AC-Q-02)

`AgentJobsCore/Refresh/` and the AutoRefreshIndicator state branches are
new code surface — must hit ≥ 80 %. Measured by
`swift test --enable-code-coverage` (existing CI flag). The `xcrun llvm-cov`
report is filtered to changed lines and posted by tester.

---

## Open risks

| Risk | Severity | Mitigation |
|---|---|---|
| `DispatchSource` fd dies on first atomic save (regression on user's first action) | Critical | Atomic-rename re-open is a binding code-path AC (AC-F-04). Test does TWO consecutive temp+rename writes and asserts watcher fires twice. |
| FSEventStream history-replay floods on first arm | Medium | `kFSEventStreamEventIdSinceNow` ensures arm-time-forward only. Test asserts no spurious refresh in the first 250 ms after install. |
| Watcher leaks across `swift test` runs | Medium | View-model `stop()` cancels EVERYTHING (scheduler, 3 watchers, ticker, visibility task). `StaticGrepRogueRefsTests` asserts every test that constructs a view model also calls `.stop()` (AC-Q-06). |
| Tests touch real `~/.agent-jobs/` / `~/.claude/` | Critical | `WatchPaths` is the only path entry point; production resolves to `.production`, tests pass temp dirs. Static-grep test asserts no test file references those literals (AC-Q-04). |
| Selection / scroll lost on refresh | High | `services = sorted` is in-place, table keyed by stable `Service.ID` (M01.5). AC-V-04 stress test runs 10 refreshes and asserts pixel-equal frames. |
| Vim-style fast writes trigger N refreshes | High | 250 ms trailing debounce. AC-P-02 fires 5 triggers in 100 ms and asserts exactly 1 sink call. |
| Watcher install fails on fresh machine (no `~/.agent-jobs/`) | High | Install is best-effort, non-throwing. Failure surfaces as `lastRefreshError` (red indicator); other watchers continue (AC-F-13). |
| Visibility-pause stuck → infinite staleness | Medium | `PeriodicTicker.keepaliveInterval = 5 min` upper bound while paused. |
| `lsof` enumeration > 16 ms on main thread | Medium | `discoverAllDetailed()` runs on registry actor; only `services = ...` is main-isolated. AC-P-04 asserts. |
| AC-F-15 dropped — M03 overlay regression | Low | `applyOptimisticOverlay()` is unchanged in M04 view model. M03's existing tests still run under AC-Q-01 + AC-P-05. TTL collapses to 20 s (still >> 250 ms debounce + 500 ms median latency). No code path divergence. |
| AC-V-05 kept — extra dashboard toolbar surface | Low | ~20 LOC view edit + 1 baseline PNG. Worth it because the dashboard user otherwise has zero "refreshing now" feedback (the M03 button is pre-press affordance, not in-flight feedback). |
| MenuBarExtra popover state observation jitter | Low | 1 s polling grace inside `AppKitVisibilityProvider` absorbs SwiftUI's `.task` cancellation timing. Worst-case: 1 s of "thought it was open, kept ticker running" — still cheap. |
