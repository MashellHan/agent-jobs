import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMac

/// Exercises the static `DashboardView.filter` matrix without spinning up
/// SwiftUI. Validates AC-F-05 / AC-F-06 (sidebar category × bucket-strip
/// filter, AND-ed; nil disables that constraint).
@Suite("DashboardView.filter (category × bucket)")
@MainActor
struct DashboardFilterTests {

    private let services = Service.fixtures()

    @Test("nil/nil returns all 5 fixtures")
    func noFilter() {
        let out = DashboardView.filter(services, category: nil, bucket: nil)
        #expect(out.count == 5)
    }

    @Test("registered bucket only → exactly 1 service")
    func registeredOnly() {
        let out = DashboardView.filter(services, category: nil, bucket: .registered)
        #expect(out.count == 1)
        #expect(out.first?.source.bucket == .registered)
    }

    @Test("launchd bucket only → 1 service")
    func launchdOnly() {
        let out = DashboardView.filter(services, category: nil, bucket: .launchd)
        #expect(out.count == 1)
        #expect(out.first?.source.bucket == .launchd)
    }

    @Test("liveProcess bucket only → 1 service")
    func liveProcessOnly() {
        let out = DashboardView.filter(services, category: nil, bucket: .liveProcess)
        #expect(out.count == 1)
        #expect(out.first?.source.bucket == .liveProcess)
    }

    @Test("claude category alone → 2 services (claudeScheduled + claudeSession)")
    func claudeCategory() {
        let out = DashboardView.filter(services, category: .claude, bucket: nil)
        #expect(out.count == 2)
        #expect(out.allSatisfy { $0.source.category == .claude })
    }

    @Test("claude × claudeScheduled → exactly 1 service")
    func claudeIntersectScheduled() {
        let out = DashboardView.filter(services, category: .claude, bucket: .claudeScheduled)
        #expect(out.count == 1)
    }

    @Test("contradictory filter (claude × launchd) → 0 services")
    func contradictoryFilter() {
        let out = DashboardView.filter(services, category: .claude, bucket: .launchd)
        #expect(out.isEmpty)
    }

    @Test("every bucket appears in fixtures (sanity)")
    func bucketCoverage() {
        for b in ServiceSource.Bucket.allCases {
            let out = DashboardView.filter(services, category: nil, bucket: b)
            #expect(out.count == 1, "bucket \(b) had \(out.count) fixtures")
        }
    }

    // MARK: - M03: hidden-id filtering

    @Test("hidden id is excluded when showHidden is OFF")
    func hiddenExcludedWhenOff() {
        let hidden: Set<String> = ["fixture.launchd.com.example.daemon"]
        let out = DashboardView.filter(services, category: nil, bucket: nil,
                                       hiddenIds: hidden, showHidden: false)
        #expect(out.count == 4)
        #expect(out.allSatisfy { !hidden.contains($0.id) })
    }

    @Test("hidden id is included when showHidden is ON")
    func hiddenIncludedWhenOn() {
        let hidden: Set<String> = ["fixture.launchd.com.example.daemon"]
        let out = DashboardView.filter(services, category: nil, bucket: nil,
                                       hiddenIds: hidden, showHidden: true)
        #expect(out.count == 5)
    }

    @Test("hidden filter composes with category/bucket filters")
    func hiddenComposesWithOther() {
        let hidden: Set<String> = ["fixture.claudeSched.task-42"]
        let out = DashboardView.filter(services, category: .claude, bucket: nil,
                                       hiddenIds: hidden, showHidden: false)
        // Only the .claudeLoop row remains (the .claudeScheduledTask was hidden).
        #expect(out.count == 1)
        #expect(out.first?.source.bucket == .claudeSession)
    }

    /// AC-P-03 — gated per E001. 1000 services with 200 hidden, Show-hidden
    /// OFF, must compute median < 10 ms over 100 runs.
    @Test("AC-P-03: filter 1000 services with 200 hidden < 10 ms median (gated AGENTJOBS_PERF=1)")
    func filterPerf() {
        guard ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1" else {
            return
        }
        var bulk: [Service] = []
        for i in 0..<1000 {
            bulk.append(Service(
                id: "perf.\(i)",
                source: .process(matched: "p\(i)"),
                kind: .interactive,
                name: "perf-\(i)",
                pid: Int32(10000 + i)
            ))
        }
        let hidden = Set((0..<200).map { "perf.\($0)" })
        var samples: [Double] = []
        for _ in 0..<100 {
            let start = Date()
            _ = DashboardView.filter(bulk, category: nil, bucket: nil,
                                     hiddenIds: hidden, showHidden: false)
            samples.append(Date().timeIntervalSince(start) * 1000.0)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        FileHandle.standardError.write(
            Data("[AC-P-03] filter median: \(median) ms\n".utf8))
        #expect(median < 10.0)
    }
}
