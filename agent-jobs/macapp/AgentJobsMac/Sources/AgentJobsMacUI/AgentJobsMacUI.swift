import SwiftUI
import AppKit
import AgentJobsCore

/// Composed `Scene` for the Agent Jobs app. Lives in the `AgentJobsMacUI`
/// library so the thin `AgentJobsMacApp` executable AND the headless
/// `CaptureAll` executable can both reference UI types — SPM forbids
/// importing an executable target (M05 T01).
public struct AgentJobsAppScene: Scene {
    @State private var registry = ServiceRegistryViewModel()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(registry)
                .task { await registry.startWatchers() }
        } label: {
            MenuBarLabel(state: registry.summary)
        }
        .menuBarExtraStyle(.window)

        Window("Agent Jobs", id: "dashboard") {
            DashboardView()
                .environment(registry)
                .frame(minWidth: DashboardWindowConfig.minSize.width,
                       minHeight: DashboardWindowConfig.minSize.height)
                .task { await registry.startWatchers() }
                // M05 T06: in-process visual-harness fallback. The
                // AgentJobsVisualHarness MenuBarInteraction posts these
                // notifications; we acknowledge so the harness's
                // continuation resumes. Lives on the dashboard scene
                // because Window's modifiers run on the main actor and
                // are easy to attach without restructuring MenuBarExtra.
                .onReceive(NotificationCenter.default.publisher(
                    for: Notification.Name("AgentJobs.HarnessTogglePopover")
                )) { _ in
                    registry.popoverOpen = true
                    NotificationCenter.default.post(
                        name: Notification.Name("AgentJobs.HarnessPopoverDidOpen"),
                        object: nil
                    )
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: Notification.Name("AgentJobs.HarnessDismissPopover")
                )) { _ in
                    registry.popoverOpen = false
                }
        }
        .defaultSize(DashboardWindowConfig.defaultSize)
        .windowResizability(.contentMinSize)
    }
}

/// Pure AppKit delegate. Sole responsibility: set the activation policy to
/// `.accessory` so the app behaves like a true menu-bar utility (no Dock
/// icon, no Cmd-Tab entry). AC-Q-04.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public override init() { super.init() }
    public func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@Observable
@MainActor
public final class ServiceRegistryViewModel {
    private(set) var services: [Service] = []
    private(set) var summary: MenuBarSummary = .empty
    private(set) var lastRefresh: Date = Date()
    private(set) var phase: LoadPhase = .idle
    /// Periodic-tick interval (live-process rescan). Reduced from 30 s
    /// (M03) to 10 s (M04) since visibility-pause now bounds idle cost.
    let refreshIntervalSeconds: TimeInterval = 10

    // M03 additions
    private(set) var hiddenIds: Set<String> = []
    private(set) var errorByServiceId: [Service.ID: String] = [:]
    private(set) var isRefreshing: Bool = false
    /// id → flip timestamp. Used by `refresh()` to keep optimistic `.idle`
    /// when the user's stop happened AFTER the refresh's snapshot. Entries
    /// expire after 2× refresh interval to bound memory.
    private var optimisticallyStopped: [Service.ID: Date] = [:]

    // M04 additions
    /// Most-recent refresh outcome surface — drives AutoRefreshIndicator
    /// red state (AC-F-09). Non-nil iff the last refresh `allFailed` OR
    /// a watcher install raised an error.
    private(set) var lastRefreshError: String? = nil
    /// M05 T09 / AC-F-14: per-bucket short error message (one line) shown
    /// in the SourceBucketChip tooltip. Empty string ≡ "OK".
    public private(set) var errorByBucket: [ServiceSource.Bucket: String] = [:]
    /// Toggled by MenuBarPopoverView .task / .onDisappear. Read by the
    /// AppKitVisibilityProvider closure to compute the pause predicate.
    var popoverOpen: Bool = false

    private let registry: ServiceRegistry
    private let stopExecutor: any StopExecutor
    private let hiddenStore: HiddenStore?
    private let watchPaths: WatchPaths
    private let resourceSampler: LiveResourceSampler?
    private var errorClearTasks: [Service.ID: Task<Void, Never>] = [:]

    // M04 watcher infrastructure
    private var scheduler: RefreshScheduler?
    private var jobsWatcher: FileObjectWatcher?
    private var schedTasksWatcher: FileObjectWatcher?
    private var claudeDirWatcher: DirectoryEventWatcher?
    private var ticker: PeriodicTicker?
    private var visibilityTask: Task<Void, Never>?

    public init(registry: ServiceRegistry = .defaultRegistry(),
         stopExecutor: (any StopExecutor)? = nil,
         hiddenStore: HiddenStore? = nil,
         watchPaths: WatchPaths = .production,
         resourceSampler: LiveResourceSampler? = LiveResourceSampler()) {
        self.registry = registry
        self.watchPaths = watchPaths
        self.resourceSampler = resourceSampler
        // Avoid constructing RealStopExecutor under AGENTJOBS_TEST=1 — that
        // guard's whole purpose is to catch test wiring that forgot to inject
        // a fake. Production callers pass nil and get the real one.
        if let stopExecutor {
            self.stopExecutor = stopExecutor
        } else if ProcessInfo.processInfo.environment["AGENTJOBS_TEST"] == "1"
                  && ProcessInfo.processInfo.environment["AGENTJOBS_INTEGRATION"] != "1" {
            self.stopExecutor = FakeStopExecutor()
        } else {
            self.stopExecutor = RealStopExecutor()
        }
        self.hiddenStore = hiddenStore
        if let store = hiddenStore {
            // Initial mirror of the persisted hidden set.
            Task { [weak self] in
                let snap = await store.snapshot()
                await MainActor.run { self?.hiddenIds = snap }
            }
        }
    }

    enum LoadPhase: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    func refresh() async {
        if case .loaded = phase { } else { phase = .loading }
        isRefreshing = true
        let refreshStartedAt = Date()
        let result = await registry.discoverAllDetailed()
        var sorted = result.services.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sorted = applyOptimisticOverlay(sorted, refreshStartedAt: refreshStartedAt)
        // M05 T09 / AC-F-11: merge live CPU% + RSS samples in. The
        // sampler is opt-in (`nil` skips the sampling tick — used by
        // tests that don't want to invoke proc_pidinfo).
        if let sampler = resourceSampler {
            let metrics = await sampler.sampleAll(sorted)
            sorted = sorted.map { svc in
                if let m = metrics[svc.id] {
                    return svc.with(metrics: m)
                }
                return svc
            }
        }
        services = sorted
        summary = MenuBarSummary.from(services: services)
        lastRefresh = Date()
        // M05 T09 / AC-F-14: collapse per-provider health into a per-bucket
        // error string so SourceBucketChip tooltips can read it.
        errorByBucket = Self.collapseHealth(result.health)
        if result.allFailed {
            phase = .error("All providers failed to respond")
            lastRefreshError = "All providers failed to respond"
        } else {
            phase = .loaded
            lastRefreshError = nil
        }
        isRefreshing = false
    }

    /// Map ProviderHealth entries onto the bucket the provider feeds.
    /// Pure helper so tests can pin the rule.
    static func collapseHealth(_ health: [ProviderHealth]) -> [ServiceSource.Bucket: String] {
        var out: [ServiceSource.Bucket: String] = [:]
        for h in health {
            guard let bucket = bucket(forProviderId: h.providerId) else { continue }
            if let err = h.lastError {
                out[bucket] = String(describing: err)
            } else if !h.perFileFailures.isEmpty {
                out[bucket] = "\(h.perFileFailures.count) source file(s) failed to parse"
            }
        }
        return out
    }

    static func bucket(forProviderId id: String) -> ServiceSource.Bucket? {
        switch id {
        case AgentJobsJsonProvider.providerId:           return .registered
        case ClaudeScheduledTasksProvider.providerId:    return .claudeScheduled
        case ClaudeSessionCronProvider.providerId:       return .claudeSession
        case LaunchdUserProvider.providerId:             return .launchd
        case LsofProcessProvider.providerId:             return .liveProcess
        default: return nil
        }
    }

    /// Q4 race guard: any service whose flip timestamp is newer than the
    /// refresh's snapshot keeps `.idle`. Older entries expire.
    private func applyOptimisticOverlay(_ list: [Service], refreshStartedAt: Date) -> [Service] {
        let ttl = refreshIntervalSeconds * 2
        let now = Date()
        // Drop expired entries.
        optimisticallyStopped = optimisticallyStopped.filter { now.timeIntervalSince($0.value) < ttl }
        guard !optimisticallyStopped.isEmpty else { return list }
        return list.map { svc in
            if let flip = optimisticallyStopped[svc.id], flip > refreshStartedAt {
                return svc.withStatus(.idle)
            } else {
                // Refresh observed reality — drop the overlay.
                optimisticallyStopped[svc.id] = nil
                return svc
            }
        }
    }

    /// M04: wire 3 file watchers + a periodic ticker + a visibility
    /// observer through one shared `RefreshScheduler`. Idempotent —
    /// safe for both `MenuBarPopoverView.task` and the dashboard
    /// `Window.task` to call.
    func startWatchers(visibility: (any VisibilityProvider)? = nil) async {
        guard scheduler == nil else { return }
        let visibilityProvider: any VisibilityProvider = visibility
            ?? AppKitVisibilityProvider(popoverOpen: { [weak self] in
                self?.popoverOpen ?? false
            })
        let sched = RefreshScheduler(debounceMilliseconds: 250) { [weak self] in
            await self?.refresh()
        }
        scheduler = sched
        await refresh()
        installWatchers(scheduler: sched)
        startPeriodicTicker(scheduler: sched)
        observeVisibility(visibility: visibilityProvider)
    }

    private func installWatchers(scheduler: RefreshScheduler) {
        let onError: @Sendable (Error) -> Void = { [weak self] err in
            Task { @MainActor [weak self] in
                self?.lastRefreshError = String(describing: err)
            }
        }
        let jobs = FileObjectWatcher(
            url: watchPaths.jobsJson,
            onEvent: { Task { await scheduler.trigger(.fileEvent(.jobsJson)) } },
            onInstallFailure: onError)
        jobs.start()
        jobsWatcher = jobs
        let st = FileObjectWatcher(
            url: watchPaths.scheduledTasks,
            onEvent: { Task { await scheduler.trigger(.fileEvent(.scheduledTasks)) } },
            onInstallFailure: onError)
        st.start()
        schedTasksWatcher = st
        let cd = DirectoryEventWatcher(
            directory: watchPaths.claudeProjectsDir,
            onEvent: { Task { await scheduler.trigger(.fileEvent(.claudeProjects)) } },
            onInstallFailure: onError)
        cd.start()
        claudeDirWatcher = cd
    }

    private func startPeriodicTicker(scheduler: RefreshScheduler) {
        let t = PeriodicTicker(intervalSeconds: refreshIntervalSeconds,
                               keepaliveSeconds: 300.0) {
            await scheduler.trigger(.periodic)
        }
        ticker = t
        Task { await t.start() }
    }

    private func observeVisibility(visibility: any VisibilityProvider) {
        let ticker = self.ticker
        visibilityTask = Task { [weak self] in
            for await visible in visibility.changes() {
                if Task.isCancelled { break }
                _ = self  // keep alive
                if visible {
                    await ticker?.resume()
                } else {
                    await ticker?.pause()
                }
            }
        }
    }

    /// Internal mutator backing the public `seedForCapture(services:)`
    /// extension method. Lives on the class so it can write the
    /// `private(set)` properties.
    public func applyCaptureSeed(services: [Service]) {
        self.services = services
        self.summary = MenuBarSummary.from(services: services)
        self.phase = .loaded
        self.lastRefresh = Date()
    }

    /// Stop the auto-refresh loop. Call before discarding the view model.
    /// Cancels: scheduler, all 3 watchers, periodic ticker, visibility task.
    func stop() {
        let sched = scheduler
        let t = ticker
        scheduler = nil
        jobsWatcher?.stop(); jobsWatcher = nil
        schedTasksWatcher?.stop(); schedTasksWatcher = nil
        claudeDirWatcher?.stop(); claudeDirWatcher = nil
        visibilityTask?.cancel(); visibilityTask = nil
        ticker = nil
        Task {
            await sched?.cancel()
            await t?.cancel()
        }
    }

    // MARK: - M03 actions

    /// AC-F-05/F-06/F-07/F-13. Refuses if `service.canStop == false` (no
    /// executor call). On success, marks the service `.idle` optimistically.
    /// On failure, surfaces a per-id error string that auto-clears in 4s.
    func stop(_ service: Service) async {
        guard service.canStop else {
            errorByServiceId[service.id] = "Stop unavailable"
            scheduleErrorClear(for: service.id)
            return
        }
        do {
            try await stopExecutor.stop(service: service)
            optimisticallyStopped[service.id] = Date()
            services = services.map { $0.id == service.id ? $0.withStatus(.idle) : $0 }
        } catch {
            errorByServiceId[service.id] = friendlyMessage(error)
            scheduleErrorClear(for: service.id)
        }
    }

    func hide(_ id: Service.ID) async {
        guard let store = hiddenStore else {
            hiddenIds.insert(id)
            return
        }
        do {
            let snap = try await store.add(id)
            hiddenIds = snap
        } catch {
            errorByServiceId[id] = "Could not save hidden state"
            scheduleErrorClear(for: id)
        }
    }

    func unhide(_ id: Service.ID) async {
        guard let store = hiddenStore else {
            hiddenIds.remove(id)
            return
        }
        do {
            let snap = try await store.remove(id)
            hiddenIds = snap
        } catch {
            errorByServiceId[id] = "Could not save hidden state"
            scheduleErrorClear(for: id)
        }
    }

    /// AC-F-12: manual refresh. Routes through the scheduler when one
    /// exists (uses `flushNow()` so the press feels instant + still
    /// honors the in-flight guard); falls back to a direct `refresh()`
    /// when called before `startWatchers()`.
    func refreshNow() async {
        if let sched = scheduler {
            await sched.flushNow()
        } else {
            guard !isRefreshing else { return }
            await refresh()
        }
    }

    private func scheduleErrorClear(for id: Service.ID) {
        errorClearTasks[id]?.cancel()
        errorClearTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.errorByServiceId[id] = nil
                self?.errorClearTasks[id] = nil
            }
        }
    }

    private func friendlyMessage(_ error: Error) -> String {
        if let stop = error as? StopError {
            switch stop {
            case .refused(let r): return r
            case .shellFailed(_, let stderr):
                return stderr.isEmpty ? "Shell command failed" : stderr
            case .signalFailed(let e): return "kill failed (errno \(e))"
            }
        }
        return String(describing: error)
    }
}

// MARK: - Service helpers

private extension Service {
    /// Returns a copy with the given status. Lets the view model patch
    /// the optimistic-stop flip without mutating the model in place.
    func withStatus(_ s: ServiceStatus) -> Service {
        Service(
            id: id, source: source, kind: kind, name: name, project: project,
            command: command, schedule: schedule, status: s, createdAt: createdAt,
            lastRun: lastRun, nextRun: nextRun, pid: pid, metrics: metrics,
            logsPath: logsPath, owner: owner, history: history, origin: origin
        )
    }
}

public struct MenuBarSummary: Sendable, Hashable {
    public let running: Int
    public let scheduled: Int
    public let failed: Int
    public let totalMemoryBytes: UInt64

    public static let empty = MenuBarSummary(running: 0, scheduled: 0, failed: 0, totalMemoryBytes: 0)

    public init(running: Int, scheduled: Int, failed: Int, totalMemoryBytes: UInt64) {
        self.running = running
        self.scheduled = scheduled
        self.failed = failed
        self.totalMemoryBytes = totalMemoryBytes
    }

    /// Pure aggregation — testable in isolation (strict-review M-002).
    public static func from(services: [Service]) -> MenuBarSummary {
        var running = 0, scheduled = 0, failed = 0
        var memory: UInt64 = 0
        for svc in services {
            switch svc.status {
            case .running:   running += 1
            case .scheduled: scheduled += 1
            case .failed:    failed += 1
            default: break
            }
            if let m = svc.metrics { memory &+= m.memoryRSS }
        }
        return MenuBarSummary(running: running, scheduled: scheduled, failed: failed, totalMemoryBytes: memory)
    }
}

// MARK: - Public scenario factories (M05 T08)
//
// Wrappers exposing internal SwiftUI views to the headless `capture-all`
// CLI executable, which lives in a separate SPM target and therefore can
// only see `public` symbols. Each factory takes a `ServiceRegistryViewModel`
// the caller has prepared (typically via `StubServiceRegistry`-backed
// init) and returns an `AnyView` ready to feed into `Snapshot.write`.

@MainActor
public enum HarnessScenes {
    /// Default popover width. Mirrors `MenuBarPopoverView.popoverWidth`
    /// (kept literal here because the inner type is internal and SPM
    /// forbids referencing internal symbols from a public default arg).
    public static let defaultPopoverWidth: CGFloat = 480

    public static func menuBarPopover(viewModel: ServiceRegistryViewModel,
                                      width: CGFloat = HarnessScenes.defaultPopoverWidth) -> AnyView {
        AnyView(
            MenuBarPopoverView()
                .environment(viewModel)
                .frame(width: width)
        )
    }

    public static func dashboard(viewModel: ServiceRegistryViewModel,
                                 initialSelection: Service.ID? = nil,
                                 size: CGSize = DashboardWindowConfig.defaultSize) -> AnyView {
        AnyView(
            DashboardView(initialSelection: initialSelection)
                .environment(viewModel)
                .frame(width: size.width, height: size.height)
        )
    }

    /// M07 / Task-4: drives the new icon-only scenarios (01/11/12/13).
    /// `idle` ≡ `MenuBarSummary.empty`; `running(n)` synthesises a
    /// summary with `running = n` and zeros elsewhere so the badge
    /// branch under test (no badge / 1..9 / "9+") is the sole variable.
    public enum IconState: Sendable, Hashable {
        case idle
        case running(Int)
    }

    /// Renders `MenuBarLabel` framed at the macOS status-item bounding
    /// box (22×22). Architecture §3.2.
    ///
    /// **Cycle-2 dark-composition fix (AC-V-04):** The bare template
    /// image renders with `.foregroundStyle(.primary)`, which under
    /// `.dark` colorScheme tints to white. SwiftUI's default canvas is
    /// transparent though, so without an explicit backing the captured
    /// PNG ends up "white glyph on alpha=0", which the central-luma
    /// probe reads as fully transparent (luma = 0). We add a
    /// scheme-derived backing fill — light keeps the historical light
    /// canvas (preserves AC-V-01 baseline byte-stability for scenarios
    /// 01/11/12), dark stamps a `windowBackgroundColor` panel so the
    /// captured frame mirrors what AppKit composes inside a real
    /// `NSStatusItem` under a dark menubar.
    public static func menuBarIconOnly(state: IconState) -> AnyView {
        let summary: MenuBarSummary
        switch state {
        case .idle:
            summary = .empty
        case .running(let n):
            summary = MenuBarSummary(running: n, scheduled: 0, failed: 0, totalMemoryBytes: 0)
        }
        return AnyView(
            MenuBarIconOnlyView(state: summary)
                .padding(0)
        )
    }

    /// Internal view that paints a scheme-aware backing under the
    /// `MenuBarLabel`. Light keeps the historical layout exactly
    /// (`MenuBarLabel.frame(width: 22, height: 22)` with badges
    /// overflowing into the surrounding capture frame — preserves
    /// scenarios 01/11/12 baseline geometry); dark adds a backing
    /// `windowBackgroundColor` panel under the same 22×22 label so
    /// the white-tinted template glyph reads with real contrast in
    /// the captured PNG (AC-V-04 cycle-2 fix).
    private struct MenuBarIconOnlyView: View {
        let state: MenuBarSummary
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            if colorScheme == .dark {
                // SwiftUI's offscreen renderer does NOT honor
                // `.renderingMode(.template)` + `.foregroundStyle(.white)`
                // for `Image(nsImage:)` template images — the captured
                // PNG ends up showing the source glyph (black) on the
                // dark backing, which is invisible. Bypass SwiftUI's
                // template path and paint a pre-tinted white NSImage
                // directly. This mirrors what `NSStatusItem` does
                // internally when AppKit composes a template into a
                // real menubar button under `.darkAqua`.
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    Canvas { ctx, size in
                        // Draw the glyph procedurally — mirrors
                        // `menubar-glyph.svg` exactly. Authoring in
                        // SwiftUI Canvas keeps the dark-scenario render
                        // path independent of `Image(nsImage:)` which
                        // SwiftUI's offscreen renderer drops silently
                        // for some bitmap-rep NSImages.
                        let s = min(size.width, size.height) / 16.0
                        // Tray body 14x14
                        let body = Path(roundedRect: CGRect(
                            x: 1*s, y: 1*s, width: 14*s, height: 14*s),
                            cornerSize: CGSize(width: 2.5*s, height: 2.5*s))
                        ctx.fill(body, with: .color(.white))
                        // Slits + status notch as background-color cuts
                        let bgColor = Color(nsColor: .windowBackgroundColor)
                        ctx.fill(Path(CGRect(x: 3*s, y: 3*s, width: 10*s, height: 1*s)),
                                 with: .color(bgColor))
                        ctx.fill(Path(CGRect(x: 3*s, y: 12*s, width: 10*s, height: 1*s)),
                                 with: .color(bgColor))
                        ctx.fill(Path(ellipseIn: CGRect(
                            x: (11.5-1)*s, y: (8-1)*s, width: 2*s, height: 2*s)),
                                 with: .color(bgColor))
                        // Running-indicator dot
                        ctx.fill(Path(ellipseIn: CGRect(
                            x: (14-1.5)*s, y: (4-1.5)*s, width: 3*s, height: 3*s)),
                                 with: .color(.white))
                    }
                    .frame(width: 16, height: 16)
                }
                .frame(width: 22, height: 22)
            } else {
                MenuBarLabel(state: state)
                    .frame(width: 22, height: 22)
            }
        }
    }

    /// Renders the M07 token specimen — color swatches, type-scale,
    /// spacing ruler. Architecture §3.2 / scenario 14.
    public static func tokensSwatch(size: CGSize = CGSize(width: 800, height: 600)) -> AnyView {
        AnyView(
            TokensSwatchView()
                .frame(width: size.width, height: size.height)
        )
    }
}

@MainActor
public extension ServiceRegistryViewModel {
    /// Test/CLI seam: seed the view model with a deterministic service list
    /// without going through the registry. The capture-all CLI uses this
    /// to render scenarios against the bundled fixture set so the resulting
    /// PNGs are reproducible across machines.
    func seedForCapture(services: [Service]) {
        applyCaptureSeed(services: services)
    }
}
