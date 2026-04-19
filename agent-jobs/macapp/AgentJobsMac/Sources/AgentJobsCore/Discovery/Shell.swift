import Foundation

/// Wraps `Process` to enforce the safety guarantees promised in
/// `.implementation/sandbox-decision.md`:
///
/// - **argv array, never shell strings** → no shell-injection surface.
/// - **Timeout** → no hung process can stall the registry refresh.
/// - **Captured stdout / stderr separately** → providers see clean payloads.
///
/// This is the only allowed entry point for spawning subprocesses anywhere
/// in the app. Providers should depend on `Shell.run(_:args:timeout:)`.
public enum Shell {

    public struct Result: Sendable, Equatable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String
        public var succeeded: Bool { exitCode == 0 }

        public init(exitCode: Int32, stdout: String, stderr: String) {
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
        }
    }

    public enum Failure: Error, Sendable, Equatable {
        case timeout(seconds: TimeInterval, partialStdout: String)
        case launchFailed(String)
        case nonZeroExit(code: Int32, stderr: String)
    }

    /// Default timeout for read-only discovery commands (`launchctl list`,
    /// `crontab -l`, `brew services list`, etc.).
    public static let defaultTimeoutSeconds: TimeInterval = 5

    /// Run an executable with an argv array. Returns once the process exits
    /// or `Failure.timeout` fires, whichever comes first.
    ///
    /// - Parameters:
    ///   - executable: Absolute path to the binary (e.g. `/bin/launchctl`).
    ///                  Avoid PATH lookup — explicit paths are auditable.
    ///   - args:       Arguments. Each element is one argv entry; whitespace
    ///                  in an entry is preserved verbatim (no shell parsing).
    ///   - timeout:    Wall-clock cap. After it fires, the process is sent
    ///                  SIGTERM and reaped.
    public static func run(
        _ executable: String,
        args: [String] = [],
        timeout: TimeInterval = defaultTimeoutSeconds
    ) async throws -> Result {
        try await withThrowingTaskGroup(of: Result.self) { group in
            group.addTask { try await runProcess(executable: executable, args: args) }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw Failure.timeout(seconds: timeout, partialStdout: "")
            }
            guard let first = try await group.next() else {
                throw Failure.launchFailed("no result")
            }
            group.cancelAll()
            return first
        }
    }

    private static func runProcess(executable: String, args: [String]) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Result, Error>) in
                process.terminationHandler = { proc in
                    let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    cont.resume(returning: Result(
                        exitCode: proc.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    ))
                }
                do {
                    try process.run()
                } catch {
                    cont.resume(throwing: Failure.launchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            // Cancellation arrived (e.g. sibling timeout task threw). Reap the
            // child immediately so the test / caller doesn't block on it.
            if process.isRunning { process.terminate() }
        }
    }
}
