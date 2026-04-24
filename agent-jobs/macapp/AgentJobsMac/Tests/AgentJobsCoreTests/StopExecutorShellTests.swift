import Testing
import Foundation
import Darwin
@testable import AgentJobsCore

/// AC-F-04 + AC-F-03 tests. These exercise the `RealStopExecutor` action
/// path WITHOUT touching the OS by injecting `ShellRunner` / `KillRunner`
/// closures that record argv. The single live-SIGTERM integration test is
/// gated behind `AGENTJOBS_INTEGRATION=1` so default `swift test` runs are
/// provably side-effect-free against the OS (AC-Q-05).
///
/// Note: we pass `AGENTJOBS_INTEGRATION=1` ourselves when constructing the
/// executor in this test bundle so the `init` guard does not abort. The
/// guard's purpose is to catch ACCIDENTAL real-executor construction in
/// suites that should be using `FakeStopExecutor`. Construction here is
/// intentional and isolated to the injected closures.
@Suite("RealStopExecutor.stop (shell + kill argv shapes)")
struct StopExecutorShellTests {

    private static func ensureIntegrationEnv() {
        // Belt: T08's bootstrap sets AGENTJOBS_TEST=1 for the bundle.
        // For this suite we must also opt INTO integration so the init
        // guard doesn't fatal on real-executor construction. The injected
        // closures still mean no OS side effect happens.
        setenv("AGENTJOBS_INTEGRATION", "1", 1)
    }

    @Test(".process source → killRun called once with (pid, SIGTERM)")
    func processCallsKill() async throws {
        Self.ensureIntegrationEnv()
        let calls = CallBox<(pid_t, Int32)>()
        let exec = RealStopExecutor(
            shellRun: { _, _ in Shell.Result(exitCode: 0, stdout: "", stderr: "") },
            killRun: { pid, sig in calls.append((pid, sig)); return 0 },
            plistURL: { _ in nil },
            selfPid: 99999
        )
        let svc = Service(id: "p.1", source: .process(matched: "x"),
                          kind: .interactive, name: "x", pid: 4321)
        try await exec.stop(service: svc)
        let recorded = calls.snapshot()
        #expect(recorded.count == 1)
        #expect(recorded.first?.0 == 4321)
        #expect(recorded.first?.1 == SIGTERM)
    }

    @Test(".process kill returning non-zero → StopError.signalFailed")
    func processSignalFailed() async {
        Self.ensureIntegrationEnv()
        let exec = RealStopExecutor(
            shellRun: { _, _ in Shell.Result(exitCode: 0, stdout: "", stderr: "") },
            killRun: { _, _ in -1 },
            plistURL: { _ in nil },
            selfPid: 99999
        )
        let svc = Service(id: "p.bad", source: .process(matched: "x"),
                          kind: .interactive, name: "x", pid: 4321)
        do {
            try await exec.stop(service: svc)
            Issue.record("expected throw")
        } catch let StopError.signalFailed(_) {
            // OK
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test(".launchdUser source → shellRun called with (/bin/launchctl, [unload, plist])")
    func launchdShellShape() async throws {
        Self.ensureIntegrationEnv()
        let argv = CallBox<(String, [String])>()
        let plistFake = URL(fileURLWithPath: "/tmp/com.example.x.plist")
        let exec = RealStopExecutor(
            shellRun: { exe, args in
                argv.append((exe, args))
                return Shell.Result(exitCode: 0, stdout: "", stderr: "")
            },
            killRun: { _, _ in 0 },
            plistURL: { _ in plistFake },
            selfPid: 99999
        )
        let svc = Service(id: "ld.x", source: .launchdUser, kind: .daemon,
                          name: "com.example.x")
        try await exec.stop(service: svc)
        let calls = argv.snapshot()
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "/bin/launchctl")
        #expect(calls.first?.1 == ["unload", plistFake.path])
    }

    @Test(".launchdUser nonzero exit → StopError.shellFailed with stderr")
    func launchdShellFailed() async {
        Self.ensureIntegrationEnv()
        let exec = RealStopExecutor(
            shellRun: { _, _ in Shell.Result(exitCode: 1, stdout: "", stderr: "boom") },
            killRun: { _, _ in 0 },
            plistURL: { _ in URL(fileURLWithPath: "/tmp/x.plist") },
            selfPid: 99999
        )
        let svc = Service(id: "ld.bad", source: .launchdUser, kind: .daemon, name: "com.example.bad")
        do {
            try await exec.stop(service: svc)
            Issue.record("expected throw")
        } catch let StopError.shellFailed(code, stderr) {
            #expect(code == 1)
            #expect(stderr == "boom")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("FakeStopExecutor records call and returns scripted success")
    func fakeRecordsAndSucceeds() async throws {
        let fake = FakeStopExecutor()
        let svc = Service(id: "fixture.x", source: .process(matched: "x"),
                          kind: .interactive, name: "x", pid: 1234)
        try await fake.stop(service: svc)
        try await fake.stop(service: svc)
        #expect(fake.calls.count == 2)
        #expect(fake.calls.first?.serviceId == "fixture.x")
    }

    @Test("FakeStopExecutor replays a scripted failure")
    func fakeReplaysFailure() async {
        let fake = FakeStopExecutor()
        fake.scriptedResult = .failure(.refused(reason: "scripted"))
        let svc = Service(id: "fixture.y", source: .process(matched: "y"),
                          kind: .interactive, name: "y", pid: 9)
        do {
            try await fake.stop(service: svc)
            Issue.record("expected throw")
        } catch let StopError.refused(reason) {
            #expect(reason == "scripted")
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    /// Live SIGTERM integration test. Spawns `/bin/sleep 60` and verifies
    /// our executor reaps it within 1s. Gated by AGENTJOBS_INTEGRATION=1
    /// AND additionally by AGENTJOBS_LIVE_KILL=1 so default integration
    /// runs do NOT spawn child processes either. AC-F-03.
    @Test("AC-F-03: live SIGTERM (gated AGENTJOBS_LIVE_KILL=1)")
    func liveSigterm() async throws {
        guard ProcessInfo.processInfo.environment["AGENTJOBS_LIVE_KILL"] == "1" else {
            return
        }
        Self.ensureIntegrationEnv()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sleep")
        proc.arguments = ["60"]
        try proc.run()
        defer { if proc.isRunning { kill(proc.processIdentifier, SIGKILL) } }
        let pid = proc.processIdentifier
        let exec = RealStopExecutor()
        let svc = Service(id: "live.\(pid)", source: .process(matched: "sleep"),
                          kind: .interactive, name: "sleep", pid: pid)
        try await exec.stop(service: svc)
        // Allow up to 1s to be reaped.
        for _ in 0..<20 {
            if !proc.isRunning { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!proc.isRunning)
    }
}

/// Tiny sendable buffer for recording closure calls from a `@Sendable`
/// context without importing a heavyweight test double.
final class CallBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []
    func append(_ t: T) { lock.lock(); items.append(t); lock.unlock() }
    func snapshot() -> [T] { lock.lock(); defer { lock.unlock() }; return items }
}
