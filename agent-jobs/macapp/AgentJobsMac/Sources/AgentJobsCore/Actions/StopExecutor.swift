import Foundation
import Darwin

/// One-method async-throwing protocol for stopping a discovered service.
/// Production: `RealStopExecutor` (kill / launchctl unload).
/// Tests: `FakeStopExecutor` (records calls, returns scripted result).
public protocol StopExecutor: Sendable {
    func stop(service: Service) async throws
}

/// Errors thrown by `RealStopExecutor.stop`. Equatable so unit tests can
/// `#expect(error == .refused(...))` without string-comparing.
public enum StopError: Error, Equatable, Sendable {
    case refused(reason: String)
    case shellFailed(exitCode: Int32, stderr: String)
    case signalFailed(errno: Int32)
}

/// Production stop executor. The unit-test surface is the static
/// `refusalReason(for:selfPid:plistURL:)` helper — it lets `Service.canStop`
/// and the executor share one implementation of the six refusal predicates
/// (defense in depth: predicates run in `canStop` to pre-disable UI AND
/// again in `stop()` before any side effect).
public struct RealStopExecutor: StopExecutor {

    /// Test-injection seam for the launchd path. Production passes a closure
    /// bound to `Shell.run`; tests pass a recorder that captures argv.
    public typealias ShellRunner = @Sendable (_ exe: String, _ args: [String]) async throws -> Shell.Result

    /// Test-injection seam for the live-process path. Production passes a
    /// closure bound to `Darwin.kill`; tests pass a recorder.
    public typealias KillRunner = @Sendable (_ pid: pid_t, _ sig: Int32) -> Int32

    private let shellRun: ShellRunner
    private let killRun: KillRunner
    private let plistURL: @Sendable (_ label: String) -> URL?
    private let selfPid: pid_t

    public init(
        shellRun: @escaping ShellRunner = { try await Shell.run($0, args: $1) },
        killRun: @escaping KillRunner = { kill($0, $1) },
        plistURL: @escaping @Sendable (String) -> URL? = LaunchdPlistReader.plistURL(forLabel:),
        selfPid: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        let env = ProcessInfo.processInfo.environment
        if env["AGENTJOBS_TEST"] == "1" && env["AGENTJOBS_INTEGRATION"] != "1" {
            fatalError("RealStopExecutor must not be constructed under AGENTJOBS_TEST=1; inject FakeStopExecutor.")
        }
        self.shellRun = shellRun
        self.killRun = killRun
        self.plistURL = plistURL
        self.selfPid = selfPid
    }

    /// `stop()` body lands in T03; declared here so the type compiles for T02.
    public func stop(service: Service) async throws {
        if let reason = Self.refusalReason(for: service, selfPid: selfPid, plistURL: plistURL) {
            throw StopError.refused(reason: reason)
        }
        // T03 will fill in the kill / launchctl branches.
        throw StopError.refused(reason: "stop not implemented for \(service.source)")
    }

    /// Pure refusal predicate. Returns the reason string when the service is
    /// NOT stoppable, or `nil` when it is. Six predicates from spec
    /// §"Safety rules". Order matters only for the message users see.
    public static func refusalReason(
        for service: Service,
        selfPid: pid_t,
        plistURL: (String) -> URL?
    ) -> String? {
        switch service.source {
        case .process:
            guard let pid = service.pid else {
                return "no PID to send SIGTERM"
            }
            if pid == 0 { return "PID 0 is the kernel scheduler" }
            if pid == 1 { return "PID 1 is launchd; refusing" }
            if pid == selfPid { return "refusing to kill self" }
            return nil
        case .launchdUser:
            if plistURL(service.name) == nil {
                return "plist path unknown; cannot launchctl unload"
            }
            return nil
        case .agentJobsJson, .claudeScheduledTask, .claudeLoop,
             .cron, .at, .brewServices, .loginItem:
            return "stop not implemented for \(service.source)"
        }
    }
}
