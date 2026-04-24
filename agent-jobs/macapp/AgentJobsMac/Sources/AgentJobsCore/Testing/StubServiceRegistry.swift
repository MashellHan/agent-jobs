import Foundation

/// Test/preview support: a synchronous `ServiceProvider` that returns a fixed
/// list and never throws. Pixel-stable rendering needs deterministic data;
/// this is the seam.
///
/// Exposed in non-DEBUG builds too because SPM doesn't carve a `#if DEBUG`
/// boundary the way Xcode test targets do — keeping it `public` lets tests
/// and SwiftUI previews share one factory with no conditional compilation
/// dance. The cost is ~150 LOC of harmless data sitting in the binary.
public struct FixtureProvider: ServiceProvider {
    public static let providerId = "fixture"
    public static let displayName = "Fixture"
    public static let category: ServiceSource.Category = .agentJobs
    public let services: [Service]
    public init(_ services: [Service]) { self.services = services }
    public func discover() async throws -> [Service] { services }
}

/// Always-throwing provider used by `failingRegistry()` to drive the M02
/// AC-F-12 ErrorBanner state.
public struct AlwaysFailingProvider: ServiceProvider {
    public static let providerId = "fixture.failing"
    public static let displayName = "Failing Fixture"
    public static let category: ServiceSource.Category = .process
    public init() {}
    public func discover() async throws -> [Service] {
        throw ProviderError.ioError("fixture: simulated failure")
    }
}

public extension ServiceRegistry {
    /// Five deterministic fixtures, one per `ServiceSource.Bucket`. All `Date`
    /// values frozen so visual ACs are pixel-stable across runs.
    static func fixtureRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [FixtureProvider(Service.fixtures())])
    }

    /// Empty registry — drives AC-F-11 empty-state visuals.
    static func emptyRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [FixtureProvider([])])
    }

    /// All providers throw — drives AC-F-12 ErrorBanner visuals.
    static func failingRegistry() -> ServiceRegistry {
        ServiceRegistry(providers: [AlwaysFailingProvider()])
    }
}

public extension Service {
    /// Default frozen reference: 2026-01-15T12:00:00Z.
    static let fixtureFrozenDate = Date(timeIntervalSince1970: 1_768_564_800)

    /// Five deterministic services — one per bucket — covering registered,
    /// claudeScheduled, claudeSession, launchd, liveProcess in that order.
    /// Field values fixed; no `Date()` calls anywhere → pixel-deterministic.
    static func fixtures(frozenAt: Date = Service.fixtureFrozenDate) -> [Service] {
        let earlier = frozenAt.addingTimeInterval(-300)   // -5 min
        let later   = frozenAt.addingTimeInterval(900)    // +15 min
        let metricsForLive = ResourceMetrics(
            pid: 4231,
            cpuPercent: 3.2,
            memoryRSS: 201 * 1024 * 1024,
            memoryVirtual: 0,
            threadCount: 8,
            fileDescriptors: 24,
            startTime: earlier,
            sampledAt: frozenAt
        )
        let metricsForLoop = ResourceMetrics(
            pid: 9912,
            cpuPercent: 1.1,
            memoryRSS: 88 * 1024 * 1024,
            memoryVirtual: 0,
            threadCount: 4,
            fileDescriptors: 12,
            startTime: earlier,
            sampledAt: frozenAt
        )
        return [
            Service(
                id: "fixture.registered.daily-cleanup",
                source: .agentJobsJson,
                kind: .scheduled,
                name: "daily-cleanup",
                project: "acme",
                command: "agentjobs run cleanup",
                schedule: .cron("0 9 * * *"),
                status: .scheduled,
                createdAt: earlier,
                lastRun: earlier,
                nextRun: later,
                origin: ServiceOrigin(agent: .claude, sessionId: nil, toolName: "agentjobs.json")
            ),
            Service(
                id: "fixture.claudeSched.task-42",
                source: .claudeScheduledTask(durable: true),
                kind: .scheduled,
                name: "claude-task-42",
                project: "acme",
                command: "claude run report",
                schedule: .cron("*/15 * * * *"),
                status: .scheduled,
                createdAt: earlier,
                lastRun: earlier,
                nextRun: later,
                origin: ServiceOrigin(agent: .claude, sessionId: "sess-1", toolName: "scheduledTask")
            ),
            Service(
                id: "fixture.claudeLoop.session-abc",
                source: .claudeLoop(sessionId: "sess-abc"),
                kind: .interactive,
                name: "claude-loop session-abc",
                project: "acme",
                command: "claude --loop",
                schedule: .onDemand,
                status: .running,
                createdAt: earlier,
                lastRun: frozenAt,
                pid: 9912,
                metrics: metricsForLoop,
                logsPath: "/tmp/claude/sess-abc.log",
                owner: .agent(.claude),
                origin: ServiceOrigin(agent: .claude, sessionId: "sess-abc", toolName: "loop")
            ),
            Service(
                id: "fixture.launchd.com.example.daemon",
                source: .launchdUser,
                kind: .daemon,
                name: "com.example.daemon",
                project: nil,
                command: "/usr/local/bin/example-daemon",
                schedule: .interval(seconds: 3600),
                status: .idle,
                createdAt: nil,
                lastRun: earlier,
                nextRun: later,
                logsPath: "~/Library/Logs/example-daemon.log",
                owner: .user
            ),
            Service(
                id: "fixture.liveProcess.npm-run-dev",
                source: .process(matched: "npm run dev"),
                kind: .interactive,
                name: "npm run dev",
                project: "acme",
                command: "npm run dev",
                schedule: .onDemand,
                status: .running,
                createdAt: earlier,
                lastRun: frozenAt,
                pid: 4231,
                metrics: metricsForLive,
                owner: .user
            ),
        ]
    }
}
