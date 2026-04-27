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
        /// Per-provider health snapshot (empty array if no provider exposes
        /// diagnostics). Populated by `discoverAllDetailed()` and surfaced
        /// in the source-bucket-chip tooltip. Closes T-004.
        public let health: [ProviderHealth]
        public var allFailed: Bool { totalCount > 0 && succeededCount == 0 }

        public init(
            services: [Service],
            succeededCount: Int,
            totalCount: Int,
            health: [ProviderHealth] = []
        ) {
            self.services = services
            self.succeededCount = succeededCount
            self.totalCount = totalCount
            self.health = health
        }
    }

    /// Same as `discoverAll()` but also reports how many providers succeeded.
    public func discoverAllDetailed() async -> DiscoverResult {
        let total = providers.count
        let perProvider: [(slice: [Service], ok: Bool, health: ProviderHealth?)] = await withTaskGroup(
            of: (slice: [Service], ok: Bool, health: ProviderHealth?).self,
            returning: [(slice: [Service], ok: Bool, health: ProviderHealth?)].self
        ) { group in
            for provider in providers {
                group.addTask { [logger] in
                    let pid = type(of: provider).providerId
                    do {
                        let svcs = try await provider.discover()
                        let health = await Self.snapshot(provider: provider, providerId: pid)
                        return (svcs, true, health)
                    } catch {
                        logger.error("provider \(pid, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                        let fallback = ProviderHealth(
                            providerId: pid,
                            lastError: (error as? ProviderError) ?? .ioError(String(describing: error)),
                            lastSuccessAt: nil,
                            perFileFailures: [:]
                        )
                        let health = await Self.snapshot(provider: provider, providerId: pid) ?? fallback
                        return ([], false, health)
                    }
                }
            }
            var collected: [(slice: [Service], ok: Bool, health: ProviderHealth?)] = []
            for await item in group { collected.append(item) }
            return collected
        }
        let services = perProvider.flatMap { $0.slice }
        let succeeded = perProvider.filter { $0.ok }.count
        let health = perProvider.compactMap { $0.health }
        return DiscoverResult(
            services: services,
            succeededCount: succeeded,
            totalCount: total,
            health: health
        )
    }

    private static func snapshot(
        provider: any ServiceProvider,
        providerId: String
    ) async -> ProviderHealth? {
        guard let diag = provider.diagnostics else { return nil }
        let snap = await diag.snapshot()
        return ProviderHealth(
            providerId: providerId,
            lastError: snap.0,
            lastSuccessAt: snap.1,
            perFileFailures: snap.2
        )
    }

    /// Default registry for production: ships with the providers we have today.
    /// New providers slot in here without touching the view model.
    public static func defaultRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [
            AgentJobsJsonProvider(),
            LaunchdUserProvider(),
            LsofProcessProvider(),
            ClaudeScheduledTasksProvider(),
            ClaudeSessionCronProvider()
        ])
    }
}
