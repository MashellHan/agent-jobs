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

    /// AC-F-13: every bucket constructible by a wired provider must be
    /// reachable via the union of `defaultRegistry()`'s providers — so
    /// chip counts in M02 strip never silently drop a case. The five
    /// buckets in `allCases` correspond 1:1 to the five wired providers
    /// (registered, claudeScheduled, claudeSession, launchd, liveProcess).
    /// Placeholder mappings (cron/at, brewServices, loginItem) collapse
    /// onto a wired bucket per ServiceSource.bucket switch — documented
    /// so future providers replacing those placeholders don't surprise
    /// the strip.
    @Test("AC-F-13: every wired-provider bucket is reachable and stable")
    func wiredProviderBucketsConsistent() {
        // Each row: a (ServiceSource, expected Bucket) pair representing
        // what an actual wired provider emits today.
        let wired: [(ServiceSource, ServiceSource.Bucket)] = [
            (.agentJobsJson,                          .registered),       // AgentJobsJsonProvider
            (.claudeScheduledTask(durable: true),     .claudeScheduled),  // ClaudeScheduledTasksProvider
            (.claudeLoop(sessionId: "abc"),           .claudeSession),    // ClaudeSessionCronProvider
            (.launchdUser,                            .launchd),          // LaunchdUserProvider
            (.process(matched: "node"),               .liveProcess),      // LsofProcessProvider
        ]
        let reached = Set(wired.map { $0.0.bucket })
        #expect(reached == Set(ServiceSource.Bucket.allCases),
                "wired providers must cover every bucket once")
        for (src, expected) in wired {
            #expect(src.bucket == expected,
                    "\(src) drifted from expected wired bucket \(expected)")
        }
    }

    @Test("AC-F-13: placeholder sources collapse to a wired bucket (documented)")
    func placeholderCollapseDocumented() {
        // These cases are NOT produced by any wired provider yet. They
        // collapse onto a real bucket so the chip strip never has a "??"
        // column. If you wire up a real provider for one of these, update
        // both the switch in ServiceSource.bucket AND this test.
        #expect(ServiceSource.cron.bucket == .launchd)
        #expect(ServiceSource.at.bucket == .launchd)
        #expect(ServiceSource.brewServices.bucket == .liveProcess)
        #expect(ServiceSource.loginItem.bucket == .registered)
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
