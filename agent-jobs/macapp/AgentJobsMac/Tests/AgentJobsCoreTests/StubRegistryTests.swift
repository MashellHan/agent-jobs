import Testing
import Foundation
@testable import AgentJobsCore

@Suite("Service.fixtures + stub registries")
struct StubRegistryTests {

    @Test("fixtures() is deterministic across calls")
    func deterministic() {
        let a = Service.fixtures()
        let b = Service.fixtures()
        #expect(a == b)
        #expect(a.count == 5)
    }

    @Test("fixtures cover all 5 buckets exactly once")
    func bucketCoverage() {
        let buckets = Service.fixtures().map { $0.source.bucket }
        let unique = Set(buckets)
        #expect(unique.count == 5)
        #expect(Set(ServiceSource.Bucket.allCases) == unique)
    }

    @Test("fixtureRegistry.discoverAll returns the 5 fixture services")
    func registryReturnsFixtures() async {
        let registry = ServiceRegistry.fixtureRegistry()
        let services = await registry.discoverAll()
        #expect(services.count == 5)
    }

    @Test("emptyRegistry returns no services and reports loaded (not failed)")
    func emptyRegistry() async {
        let registry = ServiceRegistry.emptyRegistry()
        let result = await registry.discoverAllDetailed()
        #expect(result.services.isEmpty)
        #expect(result.allFailed == false)
    }

    @Test("failingRegistry: every provider fails → allFailed true")
    func failingRegistry() async {
        let registry = ServiceRegistry.failingRegistry()
        let result = await registry.discoverAllDetailed()
        #expect(result.services.isEmpty)
        #expect(result.allFailed == true)
    }

    @Test("defaultRegistry providerCount == 5 (AC-F-04)")
    func defaultRegistryProviderCount() async {
        let registry = ServiceRegistry.defaultRegistry()
        let count = await registry.providerCount
        #expect(count == 5)
    }
}
