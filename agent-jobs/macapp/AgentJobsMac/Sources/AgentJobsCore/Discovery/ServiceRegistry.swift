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

    /// Read-only view of how many providers are wired in. Used by the view
    /// model to distinguish "registry empty" (no providers configured → idle)
    /// from "registry has providers but all returned empty" (→ error). See
    /// code-003 M1 / `ServiceRegistryViewModel.refresh()`.
    public var providerCount: Int { providers.count }

    /// Discover from all providers concurrently. A failing provider does not
    /// poison the rest — its error is logged and its slice is empty.
    public func discoverAll() async -> [Service] {
        await discoverAllDetailed().services
    }

    public struct DiscoverResult: Sendable {
        public let services: [Service]
        /// Number of providers that completed without throwing (regardless of
        /// whether they returned services). Used by the view model to tell
        /// "all providers failed" (→ error) from "all providers legitimately
        /// returned empty" (→ loaded). Resolves M-007 false-positive.
        public let succeededCount: Int
        public let totalCount: Int
        public var allFailed: Bool { totalCount > 0 && succeededCount == 0 }
    }

    /// Same as `discoverAll()` but also reports how many providers succeeded.
    public func discoverAllDetailed() async -> DiscoverResult {
        let total = providers.count
        let perProvider: [(slice: [Service], ok: Bool)] = await withTaskGroup(
            of: (slice: [Service], ok: Bool).self,
            returning: [(slice: [Service], ok: Bool)].self
        ) { group in
            for provider in providers {
                group.addTask { [logger] in
                    do {
                        let svcs = try await provider.discover()
                        return (svcs, true)
                    } catch {
                        logger.error("provider \(type(of: provider).providerId, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                        return ([], false)
                    }
                }
            }
            var collected: [(slice: [Service], ok: Bool)] = []
            for await item in group { collected.append(item) }
            return collected
        }
        let services = perProvider.flatMap { $0.slice }
        let succeeded = perProvider.filter { $0.ok }.count
        return DiscoverResult(services: services, succeededCount: succeeded, totalCount: total)
    }

    /// Default registry for production: ships with the providers we have today.
    /// New providers slot in here without touching the view model.
    public static func defaultRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [
            AgentJobsJsonProvider(),
            LaunchdUserProvider()
        ])
    }
}
