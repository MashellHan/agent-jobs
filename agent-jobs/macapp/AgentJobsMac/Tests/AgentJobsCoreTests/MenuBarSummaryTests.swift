import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMac

@Suite("MenuBarSummary aggregation")
struct MenuBarSummaryTests {

    private func service(_ id: String, status: ServiceStatus, mem: UInt64? = nil) -> Service {
        let metrics = mem.map { ResourceMetrics(pid: 1, cpuPercent: 0, memoryRSS: $0, memoryVirtual: 0, threadCount: 1, fileDescriptors: 0, startTime: Date(), sampledAt: Date()) }
        return Service(id: id, source: .agentJobsJson, kind: .scheduled, name: id, status: status, metrics: metrics)
    }

    @Test("empty input → zeros")
    func empty() {
        let s = MenuBarSummary.from(services: [])
        #expect(s == .empty)
    }

    @Test("counts running / scheduled / failed only")
    func bucketing() {
        let s = MenuBarSummary.from(services: [
            service("a", status: .running),
            service("b", status: .running),
            service("c", status: .scheduled),
            service("d", status: .failed),
            service("e", status: .done),
            service("f", status: .paused),
        ])
        #expect(s.running == 2)
        #expect(s.scheduled == 1)
        #expect(s.failed == 1)
    }

    @Test("totals memory across services with metrics, ignores nil")
    func memoryTotal() {
        let s = MenuBarSummary.from(services: [
            service("a", status: .running, mem: 100),
            service("b", status: .running, mem: 250),
            service("c", status: .scheduled),  // nil metrics
        ])
        #expect(s.totalMemoryBytes == 350)
    }
}
