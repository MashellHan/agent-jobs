# M03 Architecture — Actions (stop / hide / refresh)

> Reuse-first. Discovery layer (M01/M01.5) is **frozen**. M02 dashboard,
> inspector, sidebar, `SourceBucketStrip`, and screenshot harness stay
> unchanged. M03 adds an Actions layer in Core, a Persistence layer for
> hidden ids, action affordances on rows + inspector + dashboard toolbar,
> and a confirmation dialog. Five new visual baselines.

---

## Open questions — resolved

### Q1. Where does `HiddenStore` live? → **`AgentJobsCore/Persistence/HiddenStore.swift`**
Concur with PM. Implemented as an `actor` for serialized writes; UI consumes
via a `@MainActor`-mirrored `Set<String>` on `ServiceRegistryViewModel`. Keeps
the durable file IO out of the App layer; lets `swift test` exercise hide/
unhide round-trips without importing AppKit.

### Q2. Does `StopExecutor` belong in Core or Mac? → **Core (`AgentJobsCore/Actions/`)**
Concur with PM. The protocol, the `RealStopExecutor`, the `FakeStopExecutor`,
and the six refusal predicates are all pure value-/Foundation-only logic.
Living in Core lets unit tests cover every refusal path without an AppKit
import. The launchd unload path uses the existing `Shell` (already Core).

### Q3. SwiftUI Table row-hover on macOS 14 — **CONFIRMED with caveat**
`Table` row content can host `.onHover { isHovered = $0 }`; the modifier
fires reliably on Sonoma. The wrinkle is that hover updates a `@State`
*inside the row content closure*, which means **each visible row needs its
own row-view struct** (so hover state is isolated per row). The existing
inline `TableColumn { svc in HStack {...} }` closures cannot host per-row
`@State`. Mitigation:

- Extract a `ServiceRowNameCell: View` struct that owns `@State isHovered`
  and renders the icon + name + the hover-revealed action stack as a
  trailing element. Existing column composition stays the same; only the
  Name column's content is replaced.
- Selected-state fallback (per spec UX): the row-view also reads the table
  selection from a binding so the action stack reveals when the row is
  selected even if the pointer is elsewhere — this guarantees keyboard
  users discover the affordance.

### Q4. Optimistic UI vs await-then-render with in-flight auto-refresh → **Optimistic, with a guard**
Concur with PM. The race PM flagged is real but bounded: an auto-refresh
that started **before** the user hit Stop could land **after** the optimistic
flip and overwrite `.idle` with `.running`. Guard:

- View model stores `optimisticallyStopped: [Service.ID: Date]` (id → flip
  timestamp).
- `refresh()` applies a post-merge step: any service whose id is in
  `optimisticallyStopped` AND whose flip-timestamp is **newer than**
  `refreshStartedAt` keeps `.idle` (the user's stop is more recent than the
  refresh's snapshot). Older flips are discarded (the refresh has had a
  chance to observe the real state — either `.idle` confirmed it or the
  process is genuinely still running, in which case the user can stop again).
- Map entries auto-expire after `2 × refreshIntervalSeconds` (60s default)
  to avoid unbounded growth.

This is ~15 LOC in the view model and is unit-testable with a stub
`ServiceRegistry` that controls when `discoverAll()` returns.

---

## Modules touched

| Module | Change |
|---|---|
| `AgentJobsCore/Domain/Service.swift` | **Add** computed `canStop: Bool` (pure derived; six refusal predicates from spec). No stored field, no migration. |
| `AgentJobsCore/Discovery/Providers/LaunchdPlistReader.swift` | **Add** small `static func plistURL(forLabel:)` helper that walks the same `~/Library/LaunchAgents` + `/Library/LaunchAgents` candidate list and returns the first existing URL (or nil). Powers refusal predicate #5 and `RealStopExecutor` launchd path. ≤30 LOC. |
| `AgentJobsCore/Actions/StopExecutor.swift` | **New** — `protocol StopExecutor`, `struct StopError`, `RealStopExecutor` impl, `FakeStopExecutor` impl. ≤200 LOC; will be split if it bleeds over. |
| `AgentJobsCore/Persistence/HiddenStore.swift` | **New** — `actor HiddenStore` with `load()`, `add(_:)`, `remove(_:)`, `contains(_:)`, `snapshot() -> Set<String>`. Atomic write via temp + `FileManager.replaceItemAt`. JSON schema `{ "version": 1, "hiddenIds": [...] }`. ≤150 LOC. |
| `AgentJobsMac/AgentJobsMacApp.swift` | **Modify** `ServiceRegistryViewModel` — inject `StopExecutor` + `HiddenStore` (default-initialized in production), add `hiddenIds: Set<String>`, `errorByServiceId: [Service.ID: String]`, `isRefreshing: Bool`, `optimisticallyStopped: [Service.ID: Date]`, plus methods `stop(_:)`, `hide(_:)`, `unhide(_:)`, `refreshNow()`. Existing `refresh()` gains the optimistic-merge step. |
| `AgentJobsMac/Features/Dashboard/DashboardView.swift` | **Modify** — extract Name-column row content into `ServiceRowNameCell` (hover state + action stack), add toolbar group `[Show hidden Toggle] [Refresh button]`, thread `showHidden` state, extend `filteredServices` to consult `hiddenIds`. Empty-state branch when all rows hidden. |
| `AgentJobsMac/Features/Dashboard/ServiceRowNameCell.swift` | **New** — per-row hover-aware name cell with trailing action icons (Stop / Hide or Unhide). ≤120 LOC. |
| `AgentJobsMac/Features/Dashboard/RowActionStack.swift` | **New** — small `View` rendering the icon-only stack used by both the row cell and (with text labels) the inspector. Disabled-state styling, tooltips. ≤100 LOC. |
| `AgentJobsMac/Features/Dashboard/StopConfirmationDialog.swift` | **New** — wrapper view that hangs a `.confirmationDialog` modifier on its content; takes a `Binding<Service?>` for the pending-stop target. ≤80 LOC. |
| `AgentJobsMac/Features/Dashboard/DashboardView.swift` (`ServiceInspector` portion) | **Modify** — add an action bar above `TabChipRow` that hosts text-labeled Stop and Hide/Unhide buttons (reuses `RowActionStack` content). Also surfaces the per-id error string from the view model when present. |
| `AgentJobsCore/Testing/StubServiceRegistry.swift` | **Modify** — add `Service.fixtures(includingHidden:withStopError:)` overload that produces a known mix of stoppable and non-stoppable rows for visual ACs. Existing `fixtures()` API preserved. |
| `AgentJobsCoreTests/StopExecutorRefusalTests.swift` | **New** — unit tests for the six refusal predicates AND for `Service.canStop` (AC-F-01, AC-F-02, AC-F-13). |
| `AgentJobsCoreTests/StopExecutorShellTests.swift` | **New** — `RealStopExecutor` constructed with a `ShellRecorder` (a fake `Shell`-runner protocol injected via init); asserts the launchctl invocation shape (AC-F-04). Live SIGTERM test (AC-F-03) lives here too, gated by `AGENTJOBS_INTEGRATION=1`. |
| `AgentJobsCoreTests/HiddenStoreTests.swift` | **New** — load/add/remove/snapshot, atomic write, corrupt-file recovery, perf budget (AC-F-08, F-10, F-11, P-01). |
| `AgentJobsCoreTests/ServiceRegistryViewModelActionsTests.swift` | **New** — drives `stop(_:)`, `hide(_:)`, `unhide(_:)`, `refreshNow()` against `FakeStopExecutor` + `HiddenStore` over a temp HOME, asserts optimistic flip, error auto-clear, refresh idempotence (AC-F-05, F-06, F-07, F-09, F-12, F-13). |
| `AgentJobsCoreTests/DashboardFilterTests.swift` | **Extend** — add cases for `hiddenIds` filtering with `showHidden=true|false` (AC-F-09, AC-P-03 perf row also lives here under `AGENTJOBS_PERF=1`). |
| `AgentJobsCoreTests/Visual/VisualBaselineTests.swift` | **Extend** — add five tests: row-hover, show-hidden on/off, confirm dialog, inspector enabled/disabled stop, refresh-spinner (AC-V-01..V-05). Uses existing `ScreenshotHarness`. |
| `AgentJobsCoreTests/StopExecutorIsolationTests.swift` | **New** — static-grep self-test scanning `Tests/` for any non-gated reference to `RealStopExecutor`, plus a runtime `RealStopExecutor` construction guarded by `AGENTJOBS_TEST=1` env that proves the `fatalError` guard fires (we trap with `fatalError` only in DEBUG via `precondition` so the test can `#expect` with a captured exit signal — concrete approach: don't call `stop()`; instead the constructor takes a `dryRun: Bool` flag whose `true` value makes `stop()` exit the refusal-check path early, and a separate xfail test under a child Process verifies a real `stop()` call aborts. See AC-Q-05 below.). |

---

## New types

### `AgentJobsCore/Actions/StopExecutor.swift`

```swift
public protocol StopExecutor: Sendable {
    func stop(service: Service) async throws
}

public enum StopError: Error, Equatable, Sendable {
    case refused(reason: String)
    case shellFailed(exitCode: Int32, stderr: String)
    case signalFailed(errno: Int32)
}

public struct RealStopExecutor: StopExecutor {
    /// Test-injection seam for the launchd unload path. Production passes
    /// `Shell.run` bound; tests pass a `ShellRecorder.run` that captures
    /// argv without touching the OS.
    public typealias ShellRunner = @Sendable (_ exe: String, _ args: [String]) async throws -> Shell.Result

    /// Test-injection seam for the live-process kill path. Production passes
    /// the real `Darwin.kill`; tests pass a recorder closure.
    public typealias KillRunner = @Sendable (_ pid: pid_t, _ sig: Int32) -> Int32

    private let shellRun: ShellRunner
    private let killRun: KillRunner
    private let plistURL: @Sendable (_ label: String) -> URL?
    private let selfPid: pid_t

    public init(
        shellRun: @escaping ShellRunner = { try await Shell.run($0, args: $1) },
        killRun: @escaping KillRunner = { kill($0, $1) },
        plistURL: @escaping @Sendable (String) -> URL? = LaunchdPlistReader.plistURL(forLabel:),
        selfPid: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        // Belt + braces (spec risk row #4): if the test harness forgot to
        // inject FakeStopExecutor, this guard refuses to construct a real
        // executor under the test environment.
        if ProcessInfo.processInfo.environment["AGENTJOBS_TEST"] == "1"
            && ProcessInfo.processInfo.environment["AGENTJOBS_INTEGRATION"] != "1" {
            fatalError("RealStopExecutor must not be constructed under AGENTJOBS_TEST=1; inject FakeStopExecutor.")
        }
        self.shellRun = shellRun
        self.killRun  = killRun
        self.plistURL = plistURL
        self.selfPid  = selfPid
    }

    public func stop(service: Service) async throws {
        // Defense in depth — recheck refusals at action time even though
        // canStop already gated the UI button.
        if let reason = Self.refusalReason(for: service, selfPid: selfPid, plistURL: plistURL) {
            throw StopError.refused(reason: reason)
        }
        switch service.source {
        case .process:
            let rc = killRun(service.pid!, SIGTERM)
            if rc != 0 { throw StopError.signalFailed(errno: errno) }
        case .launchdUser:
            guard let url = plistURL(service.name) else {
                throw StopError.refused(reason: "plist path unknown; cannot launchctl unload")
            }
            let result = try await shellRun("/bin/launchctl", ["unload", url.path])
            if !result.succeeded {
                throw StopError.shellFailed(exitCode: result.exitCode, stderr: result.stderr)
            }
        default:
            throw StopError.refused(reason: "stop not implemented for \(service.source)")
        }
    }

    /// Pure refusal predicate — exposed `internal` so tests + `Service.canStop`
    /// can both consume it. Returns `nil` when the service is stoppable.
    static func refusalReason(
        for service: Service,
        selfPid: pid_t,
        plistURL: (String) -> URL?
    ) -> String? { /* the six predicates from spec §"Safety rules" */ }
}

public final class FakeStopExecutor: StopExecutor, @unchecked Sendable {
    public struct Call: Equatable, Sendable { public let serviceId: String }
    public private(set) var calls: [Call] = []
    public var scriptedResult: Result<Void, StopError> = .success(())
    public init() {}
    public func stop(service: Service) async throws {
        calls.append(Call(serviceId: service.id))
        switch scriptedResult {
        case .success: return
        case .failure(let err): throw err
        }
    }
}
```

### `AgentJobsCore/Persistence/HiddenStore.swift`

```swift
public actor HiddenStore {
    public struct File: Codable, Equatable, Sendable {
        public let version: Int          // currently 1
        public let hiddenIds: [String]   // sorted on write for git-friendly diffs (also stable for visual ACs)
    }

    private let url: URL                 // ~/.agent-jobs/hidden.json (or temp HOME under test)
    private var ids: Set<String>
    private let logger: Logger

    /// `homeDir` defaults to `FileManager.default.homeDirectoryForCurrentUser`.
    /// Tests pass a temp directory.
    public init(homeDir: URL = FileManager.default.homeDirectoryForCurrentUser) async {
        self.url = homeDir.appendingPathComponent(".agent-jobs/hidden.json")
        self.logger = Logger(subsystem: "dev.agentjobs", category: "HiddenStore")
        self.ids = Self.loadOrEmpty(url: url, logger: logger)
    }

    public func snapshot() -> Set<String> { ids }
    public func contains(_ id: String) -> Bool { ids.contains(id) }
    public func add(_ id: String) async throws    { ids.insert(id); try writeAtomic() }
    public func remove(_ id: String) async throws { ids.remove(id); try writeAtomic() }

    private func writeAtomic() throws { /* temp file + FileManager.replaceItemAt */ }
    private static func loadOrEmpty(url: URL, logger: Logger) -> Set<String> {
        // 1. file missing → empty set, no error
        // 2. JSON decode fails → log + empty set (file will be overwritten on next mutate)
        // 3. version != 1     → log + empty set
    }
}
```

### `Service.canStop` (extension on `Service`)

```swift
public extension Service {
    /// Pure derived gate. UI uses it to pre-disable the Stop button. The
    /// executor re-checks the same predicates at action time.
    /// Self-PID check uses `ProcessInfo.processInfo.processIdentifier`; that
    /// is fine for production but tests should use the executor's static
    /// helper directly with an injected `selfPid` for deterministic coverage.
    var canStop: Bool {
        RealStopExecutor.refusalReason(
            for: self,
            selfPid: ProcessInfo.processInfo.processIdentifier,
            plistURL: LaunchdPlistReader.plistURL(forLabel:)
        ) == nil
    }
}
```

### `ServiceRegistryViewModel` additions (in `AgentJobsMacApp.swift`)

```swift
@Observable @MainActor final class ServiceRegistryViewModel {
    // existing: services, summary, lastRefresh, phase, refreshIntervalSeconds

    // NEW (M03):
    private(set) var hiddenIds: Set<String> = []
    private(set) var errorByServiceId: [Service.ID: String] = [:]
    private(set) var isRefreshing: Bool = false
    private var optimisticallyStopped: [Service.ID: Date] = [:]
    private let stopExecutor: any StopExecutor
    private let hiddenStore: HiddenStore

    init(registry: ServiceRegistry = .defaultRegistry(),
         stopExecutor: any StopExecutor = RealStopExecutor(),
         hiddenStore: HiddenStore? = nil) { ... }

    func stop(_ service: Service) async { /* call executor, optimistic flip, error capture */ }
    func hide(_ id: Service.ID)   async { /* hiddenStore.add then mirror to hiddenIds */ }
    func unhide(_ id: Service.ID) async { /* hiddenStore.remove then mirror */ }
    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await refresh()
    }
}
```

### `RowActionStack` (View)

```swift
struct RowActionStack: View {
    let service: Service
    let isHidden: Bool
    let style: Style                           // .iconOnly | .withLabels
    let onStop: () -> Void
    let onHide: () -> Void
    let onUnhide: () -> Void

    enum Style { case iconOnly, withLabels }
}
```

### `StopConfirmationDialog` (View modifier wrapper)

```swift
struct StopConfirmationDialog: ViewModifier {
    @Binding var pending: Service?
    let onConfirm: (Service) -> Void
    func body(content: Content) -> some View {
        content.confirmationDialog(
            pending.map { "Stop \($0.name)?" } ?? "",
            isPresented: Binding(get: { pending != nil },
                                 set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                if let s = pending { onConfirm(s) }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            if let s = pending { Text(Self.body(for: s)) }
        }
    }

    static func body(for s: Service) -> String {
        switch s.source {
        case .process:     return "This will send SIGTERM to PID \(s.pid.map(String.init) ?? "?")."
        case .launchdUser: return "This will run `launchctl unload` on \(s.name)."
        default:           return ""
        }
    }
}
```

---

## Protocols / interfaces

| Protocol | Module | Purpose |
|---|---|---|
| `StopExecutor` | Core (Actions) | One-method async-throwing stop. `RealStopExecutor` + `FakeStopExecutor`. |

No other new protocols. The `ShellRunner` and `KillRunner` typealiases on
`RealStopExecutor` are functional injection seams — lighter than full
protocols since they have one method each.

---

## Data flow

```
                ┌──────────────────────────────┐
                │  ServiceRegistryViewModel    │
                │  (@Observable, @MainActor)   │
                │   services / hiddenIds /     │
                │   isRefreshing / errors /    │
                │   optimisticallyStopped      │
                └─────┬───────────┬────────────┘
                      │           │
       ┌──────────────┘           └─────────────┐
       ▼                                          ▼
 DashboardView                              ServiceInspector
 ├─ toolbar: [Show hidden] [Refresh]        ├─ action bar (Stop, Hide/Unhide)
 ├─ filteredServices                        └─ inline error banner
 │   = services
 │     .filter(category)
 │     .filter(bucket)
 │     .filter(hidden ⇆ showHidden)
 └─ Table rows → ServiceRowNameCell
                  ├─ @State isHovered
                  └─ RowActionStack(.iconOnly)
                        │
                        │  onStop  → vm.pendingStop = service
                        │  onHide  → Task { await vm.hide(id) }
                        │
                        ▼
        StopConfirmationDialog(pending: $vm.pendingStop)
                        │  user taps Stop
                        ▼
              vm.stop(service) async
                        │
                        ├─ guard service.canStop else { error; return }
                        ├─ try await stopExecutor.stop(service:)
                        │
                        │  RealStopExecutor:
                        │   .process     → kill(pid, SIGTERM)
                        │   .launchdUser → Shell.run("/bin/launchctl",
                        │                             ["unload", plist])
                        │   else         → throw StopError.refused
                        │
                        │  FakeStopExecutor (tests):
                        │   record call; return scriptedResult
                        │
                        ├─ on success: optimisticallyStopped[id] = Date()
                        │              (services[id].status flipped via
                        │               a mapped projection on next render)
                        └─ on failure: errorByServiceId[id] = msg
                                       Task.sleep(4s) → clear

                        for refresh:
              vm.refreshNow() async
                        │
                        ├─ guard !isRefreshing
                        ├─ isRefreshing = true
                        ├─ await refresh()  (existing M02 logic)
                        ├─ merge optimisticallyStopped (see Q4)
                        └─ isRefreshing = false

                        for hide / unhide:
              vm.hide(id) / vm.unhide(id) async
                        ├─ try await hiddenStore.add(id) / .remove(id)
                        └─ hiddenIds = await hiddenStore.snapshot()
```

---

## Concurrency model

- `HiddenStore` is an `actor`; serializes file writes. UI never touches it
  directly — view model awaits and republishes.
- `StopExecutor` is a `Sendable` value/struct; methods are `async throws`.
  Both `kill(2)` and `Shell.run` are bound at construction so the executor
  itself stays free of side-effects until `stop()` is called.
- View model is `@MainActor`-isolated (existing). All new `stop/hide/unhide/
  refreshNow` are `async` and called from SwiftUI button handlers via
  `Task { await vm.foo() }`.
- Race guard for the optimistic flip is described in Q4 above. Concrete
  implementation lives in the existing `refresh()` after the merge.

---

## Persistence schema changes

New file: `~/.agent-jobs/hidden.json`.

```json
{
  "version": 1,
  "hiddenIds": ["<service.id>", "<service.id>", "..."]
}
```

Migration plan:
- File missing → treat as empty set; first hide creates it.
- `version != 1` → log + treat as empty; next mutate overwrites.
- JSON decode fails → log + treat as empty; next mutate overwrites.

Atomic write: write to `~/.agent-jobs/hidden.json.tmp` then call
`FileManager.default.replaceItemAt(...)`. Parent directory is created with
`createDirectory(at:withIntermediateDirectories:true)` first time.

Spec also mentions location `~/.agent-jobs/` (NOT
`~/Library/Application Support/AgentJobs/`). We follow the spec — it's the
existing TUI sibling location and the M01 `AgentJobsJsonProvider` already
reads `~/.agent-jobs/jobs.json` from the same dir.

---

## Testing strategy

Per E002 (M02 retro): tests use **swift-testing** (`@Suite`, `@Test`,
`#expect`). Existing 145+ tests confirm the convention.

| Layer | Suite | Covers ACs |
|---|---|---|
| Pure unit — refusal predicates | `StopExecutorRefusalTests` | AC-F-01, AC-F-02, AC-F-13 |
| Pure unit — hidden store | `HiddenStoreTests` | AC-F-08, F-10, F-11, P-01 |
| Pure unit — view model actions | `ServiceRegistryViewModelActionsTests` | AC-F-05, F-06, F-07, F-09, F-12, F-13 |
| Filter combinatorics | `DashboardFilterTests` (extend) | AC-F-09, AC-P-03 |
| Shell shape (no OS call) | `StopExecutorShellTests` | AC-F-04 |
| Live SIGTERM (gated) | `StopExecutorShellTests` (`AGENTJOBS_INTEGRATION=1`) | AC-F-03 |
| Visual baselines | `VisualBaselineTests` (extend, 5 new) | AC-V-01..V-05 |
| Test-isolation guard | `StopExecutorIsolationTests` | AC-Q-05 |
| Coverage / build | `swift test --enable-code-coverage` | AC-Q-01..Q-04 |

### Safety-AC test strategy (the binding piece)

The six refusal predicates (AC-F-01) are tested via direct calls to
`RealStopExecutor.refusalReason(for:selfPid:plistURL:)` — a `static`,
pure-function helper. Each test constructs a `Service` with the offending
shape and an injected `selfPid` / `plistURL` closure, asserts the returned
reason string contains the expected substring. Six `@Test` cases minimum
(PID 0, PID 1, self-PID, missing PID on `.process`, missing plist on
`.launchdUser`, unsupported source). One additional `@Test` case asserts
`canStop == true` for a well-formed live-process service so we don't
accidentally over-refuse.

The "test suite cannot reach real SIGTERM" guarantee (AC-Q-05) has two
mechanisms:

1. `RealStopExecutor.init` `fatalError`s when `AGENTJOBS_TEST=1` AND
   `AGENTJOBS_INTEGRATION != 1`. The Swift Package's `Tests` target is
   invoked with `AGENTJOBS_TEST=1` set in `swift test` env (added by the
   tasks below — see T08).
2. A `@Test` (in `StopExecutorIsolationTests`) shells out to `git grep -l
   RealStopExecutor Tests/` (via `Shell.run`) and asserts the only file
   matching is the gated integration-test file. Static-grep style.

The integration test (AC-F-03) spawns `/bin/sleep 60` itself, captures the
child's PID, calls `RealStopExecutor` with `AGENTJOBS_INTEGRATION=1` set,
asserts the child reaped within 1s. Cleans up unconditionally in `defer`.

### Visual AC strategy

Reuses the M02 `ScreenshotHarness` in-process renderer + `scripts/visual-
diff.sh` at the default 2% threshold. Five new fixtures:

- `Service.fixtures(includingHidden: 2, withStopError: nil)` — feeds the
  show-hidden-on baseline.
- `Service.fixtures()` augmented with a `.process` row that maps to an
  enabled Stop, plus a `.claudeScheduledTask` row that maps to disabled
  Stop — feeds the inspector enabled/disabled baseline (rendered twice
  with different `selection`).
- A `Service.fixtures()` row with `errorByServiceId[id] = "kill failed"`
  pre-set on the view model — wait, scratch: the dialog baseline doesn't
  need the error path; the dialog is captured with `pendingStop = <fixture>`.

All visual tests run on `@MainActor` (existing harness convention).
Confirmation dialog is captured via the SwiftUI in-process renderer: we
mount `DashboardView().modifier(StopConfirmationDialog(pending: $pending,
onConfirm: { _ in }))` with `pending` pre-set, spin the runloop 100ms (a
beat longer than the 50ms M02 default to absorb the dialog's appear
animation), then capture. The harness captures the SwiftUI dialog content
view — NOT a system NSAlert — per spec risk mitigation.

---

## Open risks

| Risk | Severity | Mitigation |
|---|---|---|
| `.confirmationDialog` doesn't render into `NSHostingView` snapshot consistently across macOS 14 minor versions | Medium | Threshold 2% (existing) + capture only the dialog content view, not the system chrome. If still flaky, fall back to a wrapper `Sheet` with the same buttons; spec allows either. |
| `kill(2)` PID-reuse race (spec risk row #1) | High | View model re-validates `service.pid` against the most recent `services` array immediately before invoking the executor; if the matching service id no longer exists OR its PID changed, we set `errorByServiceId` to "Service changed since you clicked Stop — refresh and try again" and skip. ≤10 LOC in `vm.stop()`. |
| `LaunchdPlistReader.plistURL(forLabel:)` walks user + system LaunchAgents only, missing system Daemons — but spec scopes M03 to user-domain (`launchdUser`), and the M01 provider only enumerates user-domain plists. Consistent. | Low | Document in the helper's doc-comment. No code change. |
| `HiddenStore` write under a non-writable HOME (e.g. some CI sandboxes) | Low | `writeAtomic()` throws; `vm.hide()` catches and surfaces via `errorByServiceId`. Test covers via a HOME pointed at a read-only dir. |
| Optimistic-flip race with auto-refresh (Q4) | Medium | Timestamp comparison guard, see Q4. |
| Implementer accidentally constructs `RealStopExecutor` in a unit test | Critical | `fatalError` in init under `AGENTJOBS_TEST=1` + static-grep test. Belt + braces. |
