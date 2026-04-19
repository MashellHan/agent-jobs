import SwiftUI
import AgentJobsCore

@main
struct AgentJobsMacApp: App {
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

@Observable
@MainActor
final class ServiceRegistryViewModel {
    private(set) var services: [Service] = []
    private(set) var summary: MenuBarSummary = .empty
    private(set) var lastRefresh: Date = Date()
    private(set) var phase: LoadPhase = .idle
    let refreshIntervalSeconds: TimeInterval = 30

    private let registry: ServiceRegistry
    private var autoRefreshTask: Task<Void, Never>?

    init(registry: ServiceRegistry = .defaultRegistry()) {
        self.registry = registry
    }

    enum LoadPhase: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    func refresh() async {
        if case .loaded = phase { } else { phase = .loading }
        let discovered = await registry.discoverAll()
        services = discovered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        summary = MenuBarSummary.from(services: services)
        lastRefresh = Date()
        phase = .loaded
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
