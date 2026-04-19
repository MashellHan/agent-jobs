import SwiftUI
import AgentJobsCore

@main
struct AgentJobsMacApp: App {
    @State private var registry = ServiceRegistryViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environment(registry)
                .frame(width: 340)
        } label: {
            MenuBarLabel(state: registry.summary)
        }
        .menuBarExtraStyle(.window)

        Window("Agent Jobs", id: "dashboard") {
            DashboardView()
                .environment(registry)
                .frame(minWidth: 900, minHeight: 560)
        }
    }
}

@Observable
final class ServiceRegistryViewModel {
    var services: [Service] = []
    var summary: MenuBarSummary = .empty
    var lastRefresh: Date = Date()
    let refreshIntervalSeconds: TimeInterval = 30

    init() {
        // Wire actual ServiceRegistry in M2 cycle.
    }

    @MainActor
    func refresh() async {
        // Stub: real Provider orchestration lands in M2 cycle 3.
        lastRefresh = Date()
    }
}

struct MenuBarSummary: Sendable, Hashable {
    let running: Int
    let scheduled: Int
    let failed: Int
    let totalMemoryBytes: UInt64

    static let empty = MenuBarSummary(running: 0, scheduled: 0, failed: 0, totalMemoryBytes: 0)
}
