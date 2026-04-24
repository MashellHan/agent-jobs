import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-01 / AC-F-02 / AC-F-13 — six refusal predicates from spec
/// §"Safety rules" plus one positive (`canStop == true`) case. Pure unit
/// tests: no `Process` invocation, no `kill(2)`, no filesystem writes.
@Suite("RealStopExecutor.refusalReason (six predicates)")
struct StopExecutorRefusalTests {

    private func liveProc(pid: Int32?) -> Service {
        Service(
            id: "live.\(pid.map(String.init) ?? "nil")",
            source: .process(matched: "x"),
            kind: .interactive,
            name: "x",
            pid: pid
        )
    }

    private let neverPlist: (String) -> URL? = { _ in nil }
    private let havePlist:  (String) -> URL? = { _ in URL(fileURLWithPath: "/tmp/x.plist") }
    private let selfPid: pid_t = 99999

    @Test("refuses when .process pid is missing")
    func processNoPid() {
        let r = RealStopExecutor.refusalReason(for: liveProc(pid: nil), selfPid: selfPid, plistURL: neverPlist)
        #expect(r == "no PID to send SIGTERM")
    }

    @Test("refuses pid == 0 (kernel scheduler)")
    func processPid0() {
        let r = RealStopExecutor.refusalReason(for: liveProc(pid: 0), selfPid: selfPid, plistURL: neverPlist)
        #expect(r == "PID 0 is the kernel scheduler")
    }

    @Test("refuses pid == 1 (launchd)")
    func processPid1() {
        let r = RealStopExecutor.refusalReason(for: liveProc(pid: 1), selfPid: selfPid, plistURL: neverPlist)
        #expect(r == "PID 1 is launchd; refusing")
    }

    @Test("refuses pid == self pid")
    func processSelfPid() {
        let r = RealStopExecutor.refusalReason(for: liveProc(pid: selfPid), selfPid: selfPid, plistURL: neverPlist)
        #expect(r == "refusing to kill self")
    }

    @Test("refuses .launchdUser when plist URL is unresolvable")
    func launchdMissingPlist() {
        let svc = Service(id: "ld.x", source: .launchdUser, kind: .daemon, name: "com.example.x")
        let r = RealStopExecutor.refusalReason(for: svc, selfPid: selfPid, plistURL: neverPlist)
        #expect(r == "plist path unknown; cannot launchctl unload")
    }

    @Test("refuses .agentJobsJson source with 'not implemented' message")
    func unsupportedAgentJobs() {
        let svc = Service(id: "aj.x", source: .agentJobsJson, kind: .scheduled, name: "x")
        let r = RealStopExecutor.refusalReason(for: svc, selfPid: selfPid, plistURL: havePlist)
        #expect(r?.hasPrefix("stop not implemented for") == true)
    }

    @Test("refuses .claudeScheduledTask with 'not implemented' message")
    func unsupportedClaudeScheduled() {
        let svc = Service(id: "cs.x", source: .claudeScheduledTask(durable: true),
                          kind: .scheduled, name: "x")
        let r = RealStopExecutor.refusalReason(for: svc, selfPid: selfPid, plistURL: havePlist)
        #expect(r?.contains("not implemented") == true)
    }

    @Test("allows a clean .process service with a valid PID")
    func processClean() {
        let r = RealStopExecutor.refusalReason(for: liveProc(pid: 12345), selfPid: selfPid, plistURL: neverPlist)
        #expect(r == nil)
    }

    @Test("allows a .launchdUser service when plist URL resolves")
    func launchdResolves() {
        let svc = Service(id: "ld.ok", source: .launchdUser, kind: .daemon, name: "com.example.ok")
        let r = RealStopExecutor.refusalReason(for: svc, selfPid: selfPid, plistURL: havePlist)
        #expect(r == nil)
    }

    // AC-F-13 — Service.canStop bridges UI to the same predicates.
    @Test("Service.canStop is false for a refused service")
    func serviceCanStopFalse() {
        let svc = liveProc(pid: 0)
        #expect(svc.canStop == false)
    }

    @Test("Service.canStop is true for a valid live process")
    func serviceCanStopTrue() {
        // Pick a PID guaranteed not to equal our own.
        let pid = ProcessInfo.processInfo.processIdentifier &+ 1
        let svc = liveProc(pid: pid)
        #expect(svc.canStop == true)
    }
}
