import Foundation
import os

/// Aggregates services from multiple providers. Actor-isolated so concurrent
/// refreshes from menubar + dashboard don't race.
public actor ServiceRegistry {
    private let providers: [any ServiceProvider]
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "ServiceRegistry")

    public init(providers: [any ServiceProvider]) {
        self.providers = providers
    }

    /// Discover from all providers concurrently. A failing provider does not
    /// poison the rest — its error is logged and its slice is empty.
    public func discoverAll() async -> [Service] {
        await withTaskGroup(of: [Service].self, returning: [Service].self) { group in
            for provider in providers {
                group.addTask { [logger] in
                    do {
                        return try await provider.discover()
                    } catch {
                        logger.error("provider \(type(of: provider).providerId, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                        return []
                    }
                }
            }
            var all: [Service] = []
            for await chunk in group { all.append(contentsOf: chunk) }
            return all
        }
    }

    /// Default registry for production: ships with the providers we have today.
    /// New providers slot in here without touching the view model.
    public static func defaultRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [AgentJobsJsonProvider()])
    }
}
