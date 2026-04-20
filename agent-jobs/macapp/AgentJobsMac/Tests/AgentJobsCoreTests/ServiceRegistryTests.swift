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

    @Test("all providers failing → empty result, no propagation")
    func allFailingProvidersReturnEmpty() async {
        let registry = ServiceRegistry(providers: [
            StubFailingProvider(),
            StubFailingProvider(),
            StubFailingProvider()
        ])
        let result = await registry.discoverAll()
        // No throw, just empty — failure isolation must hold even when every
        // provider fails. UI sees "no services" instead of a crash.
        #expect(result.isEmpty)
    }

    @Test("preserves order-independent set semantics across many providers")
    func aggregatesAcrossManyProviders() async {
        let services = (0..<10).map { Self.makeService(id: "svc\($0)") }
        let providers: [any ServiceProvider] = services.map { svc in
            StubGoodProvider(services: [svc])
        }
        let registry = ServiceRegistry(providers: providers)
        let result = await registry.discoverAll()
        #expect(result.count == 10)
        #expect(Set(result.map { $0.id }) == Set(services.map { $0.id }))
    }

    // MARK: - DiscoverResult contract (M-007 fix coverage / strict-iter-008 M-008)

    @Test("discoverAllDetailed: every provider failing → allFailed == true")
    func detailed_allFailing_setsAllFailed() async {
        let registry = ServiceRegistry(providers: [
            StubFailingProvider(),
            StubFailingProvider(),
            StubFailingProvider()
        ])
        let result = await registry.discoverAllDetailed()
        #expect(result.totalCount == 3)
        #expect(result.succeededCount == 0)
        #expect(result.allFailed == true)
        #expect(result.services.isEmpty)
    }

    @Test("discoverAllDetailed: partial success → allFailed == false")
    func detailed_partialSuccess_clearsAllFailed() async {
        let svc = Self.makeService(id: "ok")
        let registry = ServiceRegistry(providers: [
            StubGoodProvider(services: [svc]),
            StubFailingProvider()
        ])
        let result = await registry.discoverAllDetailed()
        #expect(result.totalCount == 2)
        #expect(result.succeededCount == 1)
        #expect(result.allFailed == false)
        #expect(result.services.count == 1)
    }

    @Test("discoverAllDetailed: every provider succeeds with empty slice → allFailed == false")
    func detailed_allEmptySuccess_doesNotMisreportAsFailed() async {
        // The M-007 false-positive scenario: every provider runs cleanly but
        // returns no services. UI must show "loaded with 0 results", NOT an
        // error banner.
        let registry = ServiceRegistry(providers: [
            StubGoodProvider(services: []),
            StubGoodProvider(services: [])
        ])
        let result = await registry.discoverAllDetailed()
        #expect(result.totalCount == 2)
        #expect(result.succeededCount == 2)
        #expect(result.allFailed == false)
        #expect(result.services.isEmpty)
    }

    @Test("discoverAllDetailed: empty registry → allFailed == false (no providers, no error)")
    func detailed_emptyRegistry_isNotAFailure() async {
        let registry = ServiceRegistry(providers: [])
        let result = await registry.discoverAllDetailed()
        #expect(result.totalCount == 0)
        #expect(result.succeededCount == 0)
        #expect(result.allFailed == false)
    }
}
