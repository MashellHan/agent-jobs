import Testing
import Foundation
@testable import AgentJobsCore

@Suite("LaunchdUserProvider parsing")
struct LaunchdUserProviderTests {

    /// Captured `launchctl list` output sample. Real output is tab/space mixed
    /// with three columns: PID, last-exit-status, label. PID = "-" for a job
    /// that's loaded but not running.
    private static let sampleOutput = """
    PID	Status	Label
    1234	0	com.example.agent.runner
    -	0	com.example.agent.scheduled
    -	78	com.example.agent.failedlast
    5678	0	com.apple.Spotlight
    -	0	com.apple.cfprefsd.xpc.agent
    """

    @Test("skips header and Apple system jobs")
    func skipsHeaderAndApple() {
        let services = LaunchdUserProvider.parse(Self.sampleOutput)
        #expect(services.count == 3)
        let labels = services.map { $0.name }
        #expect(!labels.contains { $0.hasPrefix("com.apple.") })
        #expect(!labels.contains("Label"))
    }

    @Test("PID present → status .running")
    func runningWhenPidPresent() {
        let services = LaunchdUserProvider.parse(Self.sampleOutput)
        let runner = services.first { $0.name == "com.example.agent.runner" }
        #expect(runner?.status == .running)
        #expect(runner?.pid == 1234)
    }

    @Test("PID '-' with exit 0 → .scheduled")
    func scheduledWhenIdleAndCleanExit() {
        let services = LaunchdUserProvider.parse(Self.sampleOutput)
        let scheduled = services.first { $0.name == "com.example.agent.scheduled" }
        #expect(scheduled?.status == .scheduled)
        #expect(scheduled?.pid == nil)
    }

    @Test("PID '-' with non-zero exit → .failed")
    func failedWhenLastExitNonZero() {
        let services = LaunchdUserProvider.parse(Self.sampleOutput)
        let failed = services.first { $0.name == "com.example.agent.failedlast" }
        #expect(failed?.status == .failed)
    }

    @Test("source category is launchd, IDs are namespaced")
    func sourceAndIdShape() {
        let services = LaunchdUserProvider.parse(Self.sampleOutput)
        for svc in services {
            #expect(svc.source == .launchdUser)
            #expect(svc.id.hasPrefix("launchd.user:"))
        }
    }

    @Test("empty output returns empty list, no crash")
    func emptyOutput() {
        #expect(LaunchdUserProvider.parse("").isEmpty)
        #expect(LaunchdUserProvider.parse("\n\n  \n").isEmpty)
    }

    @Test("discover() honors injected runner and surfaces parsed services")
    func discoverWithInjectedRunner() async throws {
        let provider = LaunchdUserProvider(runner: { Self.sampleOutput })
        let result = try await provider.discover()
        #expect(result.count == 3)
    }
}
