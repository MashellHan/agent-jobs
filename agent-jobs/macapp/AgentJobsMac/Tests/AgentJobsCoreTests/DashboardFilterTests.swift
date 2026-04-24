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
}
