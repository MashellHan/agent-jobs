import Testing
import Foundation
import Darwin
@testable import AgentJobsCore

/// AC-F-09 / AC-F-10 / AC-P-02: LiveResourceSampler — own pid, ESRCH,
/// perf gate.
@Suite("LiveResourceSampler (M05 T04 / closes T-006)")
struct LiveResourceSamplerTests {

    @Test("AC-F-09: sample(pid:) for own pid returns non-nil RSS > 0")
    func ownPidSample() async {
        let sampler = LiveResourceSampler()
        let myPid = getpid()
        let m = await sampler.sample(pid: myPid)
        #expect(m != nil, "sample for self pid should not be nil")
        if let m {
            #expect(m.memoryRSS > 0, "RSS must be positive")
            #expect(m.cpuPercent >= 0)
            #expect(m.pid == myPid)
        }
    }

    @Test("AC-F-10: sample(pid:) for dead pid returns nil, never throws")
    func deadPidSwallowed() async {
        let sampler = LiveResourceSampler()
        // pid 99999 is essentially never alive on a fresh boot.
        let m = await sampler.sample(pid: 99_999)
        #expect(m == nil)
    }

    @Test("AC-F-09 follow-up: second sample on own pid yields delta-CPU ≥ 0")
    func deltaCpu() async {
        let sampler = LiveResourceSampler()
        _ = await sampler.sample(pid: getpid())
        // Burn a tiny bit of CPU between samples.
        var x: UInt64 = 1
        for _ in 0..<200_000 { x = x &* 2654435761 }
        _ = x
        let second = await sampler.sample(pid: getpid())
        #expect(second != nil)
        if let second { #expect(second.cpuPercent >= 0) }
    }

    @Test("AC-F-11 partial: sampleAll keys metrics by Service.id and skips no-pid services")
    func sampleAllWiring() async {
        let withPid = Service(id: "self", source: .process(matched: "self"),
                              kind: .daemon, name: "self",
                              command: "self", pid: getpid())
        let noPid = Service(id: "schedule-only", source: .agentJobsJson,
                            kind: .scheduled, name: "no pid")
        let sampler = LiveResourceSampler()
        let result = await sampler.sampleAll([withPid, noPid])
        #expect(result["self"] != nil)
        #expect(result["schedule-only"] == nil)
    }

    @Test("AC-P-02: sampleAll over 100 PIDs < 100ms (AGENTJOBS_PERF=1)")
    func perfGate() async throws {
        guard ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1" else { return }
        // Build 100 services all using own pid (worst case is the syscall;
        // pid identity is irrelevant for cost).
        let myPid = getpid()
        let svcs = (0..<100).map { i in
            Service(id: "p\(i)", source: .process(matched: "x"),
                    kind: .daemon, name: "x", command: "x", pid: myPid)
        }
        let sampler = LiveResourceSampler()
        let start = DispatchTime.now().uptimeNanoseconds
        _ = await sampler.sampleAll(svcs)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        #expect(elapsedMs < 100, "took \(elapsedMs)ms ≥ 100ms spec budget")
    }
}
