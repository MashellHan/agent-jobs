import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMacUI

@Suite("PopoverGrouping (M06 T-002)")
struct PopoverGroupingTests {

    private func svc(_ id: String, _ status: ServiceStatus) -> Service {
        Service(id: id, source: .agentJobsJson, kind: .scheduled, name: id, status: status)
    }

    @Test("AC-F-05: groups appear in canonical priority order")
    func priorityOrder() {
        // Input intentionally scrambled — output order must be running,
        // scheduled, failed, other.
        let svcs = [
            svc("d-failed", .failed),
            svc("a-other", .done),
            svc("b-scheduled", .scheduled),
            svc("c-running", .running),
        ]
        let groups = PopoverGrouping.groupByStatus(svcs)
        #expect(groups.map { $0.group } == [.running, .scheduled, .failed, .other])
    }

    @Test("input order preserved within each group")
    func intraGroupOrder() {
        let svcs = [
            svc("r1", .running),
            svc("s1", .scheduled),
            svc("r2", .running),
            svc("r3", .running),
        ]
        let groups = PopoverGrouping.groupByStatus(svcs)
        let running = groups.first { $0.group == .running }?.services ?? []
        #expect(running.map { $0.id } == ["r1", "r2", "r3"])
    }

    @Test("empty groups dropped by default; emitted when includeEmpty=true")
    func emptyGroupHandling() {
        let svcs = [svc("r", .running)]
        let trimmed = PopoverGrouping.groupByStatus(svcs)
        #expect(trimmed.count == 1)
        #expect(trimmed.first?.group == .running)

        let full = PopoverGrouping.groupByStatus(svcs, includeEmpty: true)
        #expect(full.count == PopoverGrouping.StatusGroup.allCases.count)
    }

    @Test("idle/paused/done/unknown collapse to .other")
    func otherBucket() {
        #expect(PopoverGrouping.bucket(for: .idle) == .other)
        #expect(PopoverGrouping.bucket(for: .paused) == .other)
        #expect(PopoverGrouping.bucket(for: .done) == .other)
        #expect(PopoverGrouping.bucket(for: .unknown) == .other)
    }
}
