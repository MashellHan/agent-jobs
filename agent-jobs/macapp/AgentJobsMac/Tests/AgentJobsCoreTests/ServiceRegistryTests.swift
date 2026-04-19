import Testing
import Foundation
@testable import AgentJobsCore

/// Verifies the central architectural promise of `ServiceRegistry`:
/// - all providers run concurrently
/// - one provider failing does NOT poison the others
/// - aggregate result preserves both provider's emitted services
@Suite("ServiceRegistry orchestration")
struct ServiceRegistryTests {

    /// Returns a fixed list of services — the happy path.
    private struct StubGoodProvider: ServiceProvider {
        static var providerId: String { "stub.good" }
        static var displayName: String { "Stub Good" }
        static var category: ServiceSource.Category { .agentJobs }
        let services: [Service]
        func discover() async throws -> [Service] { services }
    }

    /// Always throws — exercises the failure-isolation path.
    private struct StubFailingProvider: ServiceProvider {
        static var providerId: String { "stub.failing" }
        static var displayName: String { "Stub Failing" }
        static var category: ServiceSource.Category { .process }
        func discover() async throws -> [Service] {
            throw ProviderError.ioError("boom")
        }
    }

    /// Sleeps briefly then returns — used to verify the failing provider
    /// doesn't short-circuit the slow one (TaskGroup runs them in parallel).
    private struct StubSlowProvider: ServiceProvider {
        static var providerId: String { "stub.slow" }
        static var displayName: String { "Stub Slow" }
        static var category: ServiceSource.Category { .cron }
        let services: [Service]
        func discover() async throws -> [Service] {
            try await Task.sleep(for: .milliseconds(50))
            return services
        }
    }

    private static func makeService(id: String) -> Service {
        Service(
            id: id,
            source: .agentJobsJson,
            kind: .daemon,
            name: "svc-\(id)",
            command: "/usr/bin/true",
            schedule: .onDemand,
            status: .running,
            createdAt: Date(),
            owner: .os,
            history: [],
            origin: nil
        )
    }

    @Test("aggregates services from multiple providers")
    func aggregatesAcrossProviders() async {
        let a = Self.makeService(id: "a")
        let b = Self.makeService(id: "b")
        let registry = ServiceRegistry(providers: [
            StubGoodProvider(services: [a]),
            StubGoodProvider(services: [b])
        ])
        let result = await registry.discoverAll()
        #expect(result.count == 2)
        #expect(Set(result.map { $0.id }) == Set(["a", "b"]))
    }

    @Test("failing provider does NOT poison the rest")
    func failingProviderIsolated() async {
        let a = Self.makeService(id: "a")
        let b = Self.makeService(id: "b")
        let registry = ServiceRegistry(providers: [
            StubGoodProvider(services: [a]),
            StubFailingProvider(),
            StubSlowProvider(services: [b])
        ])
        let result = await registry.discoverAll()
        // The two healthy providers contribute their slices; the failing one
        // is logged + dropped (empty slice). Total = 2, not 0 and not crash.
        #expect(result.count == 2)
        #expect(Set(result.map { $0.id }) == Set(["a", "b"]))
    }

    @Test("empty provider list returns empty without crashing")
    func emptyRegistry() async {
        let registry = ServiceRegistry(providers: [])
        let result = await registry.discoverAll()
        #expect(result.isEmpty)
    }
}
