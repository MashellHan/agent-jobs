import SwiftUI
import AppKit
import AgentJobsCore

@main
struct AgentJobsMacApp: App {
    // AC-Q-04: SPM executables don't ship an Info.plist, so we can't set
    // LSUIElement=true in plist. The canonical workaround is an
    // NSApplicationDelegate that calls setActivationPolicy(.accessory) in
    // applicationWillFinishLaunching — runs before the menu bar is built,
    // suppresses the Dock icon, leaves MenuBarExtra free to claim its slot.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var registry = ServiceRegistryViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(registry)
                .frame(width: 360)
                .task { await registry.startAutoRefresh() }
        } label: {
            MenuBarLabel(state: registry.summary)
        }
        .menuBarExtraStyle(.window)

        Window("Agent Jobs", id: "dashboard") {
            DashboardView()
                .environment(registry)
                .frame(minWidth: 900, minHeight: 560)
                .task { await registry.refresh() }
        }
    }
}

/// Pure AppKit delegate. Sole responsibility: set the activation policy to
/// `.accessory` so the app behaves like a true menu-bar utility (no Dock
/// icon, no Cmd-Tab entry). AC-Q-04.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@Observable
@MainActor
final class ServiceRegistryViewModel {
    private(set) var services: [Service] = []
    private(set) var summary: MenuBarSummary = .empty
    private(set) var lastRefresh: Date = Date()
    private(set) var phase: LoadPhase = .idle
    let refreshIntervalSeconds: TimeInterval = 30

    // M03 additions
    private(set) var hiddenIds: Set<String> = []
    private(set) var errorByServiceId: [Service.ID: String] = [:]
    private(set) var isRefreshing: Bool = false
    /// id → flip timestamp. Used by `refresh()` to keep optimistic `.idle`
    /// when the user's stop happened AFTER the refresh's snapshot. Entries
    /// expire after 2× refresh interval to bound memory.
    private var optimisticallyStopped: [Service.ID: Date] = [:]

    private let registry: ServiceRegistry
    private let stopExecutor: any StopExecutor
    private let hiddenStore: HiddenStore?
    private var autoRefreshTask: Task<Void, Never>?
    private var errorClearTasks: [Service.ID: Task<Void, Never>] = [:]

    init(registry: ServiceRegistry = .defaultRegistry(),
         stopExecutor: (any StopExecutor)? = nil,
         hiddenStore: HiddenStore? = nil) {
        self.registry = registry
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
        let refreshStartedAt = Date()
        let result = await registry.discoverAllDetailed()
        var sorted = result.services.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sorted = applyOptimisticOverlay(sorted, refreshStartedAt: refreshStartedAt)
        services = sorted
        summary = MenuBarSummary.from(services: services)
        lastRefresh = Date()
        if result.allFailed {
            phase = .error("All providers failed to respond")
        } else {
            phase = .loaded
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

    /// Begin a background loop that refreshes every `refreshIntervalSeconds`.
    /// Idempotent — safe to call from multiple `.task` modifiers.
    func startAutoRefresh() async {
        guard autoRefreshTask == nil else { return }
        await refresh()
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let interval = self.refreshIntervalSeconds
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self.refresh()
            }
        }
    }

    /// Stop the auto-refresh loop. Call before discarding the view model.
    func stop() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
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

    /// AC-F-12: manual refresh. No-op if already in flight.
    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await refresh()
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
