import Testing
@testable import AgentJobsCore

/// AC-F-05: chip ordering and per-source bucket mapping.
@Suite("ServiceSource.Bucket mapping")
struct SourceBucketTests {

    @Test("allCases order matches the spec's chip strip order")
    func bucketOrder() {
        #expect(ServiceSource.Bucket.allCases == [
            .registered,
            .claudeScheduled,
            .claudeSession,
            .launchd,
            .liveProcess,
        ])
    }

    @Test("every ServiceSource maps to expected bucket")
    func mappingExhaustive() {
        // Exhaustive switch defensively forces a compile error if a new
        // ServiceSource case is added without a bucket assignment.
        for source in allSources() {
            let expected: ServiceSource.Bucket
            switch source {
            case .agentJobsJson:        expected = .registered
            case .claudeScheduledTask:  expected = .claudeScheduled
            case .claudeLoop:           expected = .claudeSession
            case .launchdUser:          expected = .launchd
            case .process:              expected = .liveProcess
            case .cron, .at:            expected = .launchd
            case .brewServices:         expected = .liveProcess
            case .loginItem:            expected = .registered
            }
            #expect(source.bucket == expected,
                    "\(source) expected \(expected), got \(source.bucket)")
        }
    }

    @Test("displayName + sfSymbol non-empty for every bucket")
    func metadataIsPopulated() {
        for b in ServiceSource.Bucket.allCases {
            #expect(!b.displayName.isEmpty)
            #expect(!b.sfSymbol.isEmpty)
        }
    }

    private func allSources() -> [ServiceSource] {
        [
            .agentJobsJson,
            .claudeScheduledTask(durable: true),
            .claudeScheduledTask(durable: false),
            .claudeLoop(sessionId: "x"),
            .launchdUser,
            .cron,
            .brewServices,
            .at,
            .loginItem,
            .process(matched: "foo"),
        ]
    }
}
