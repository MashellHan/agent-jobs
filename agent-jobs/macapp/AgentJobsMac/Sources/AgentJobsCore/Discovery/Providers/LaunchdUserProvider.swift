import Foundation
import os

/// Discovers user-domain launchd jobs by parsing `launchctl list` output.
///
/// `launchctl list` prints three columns: PID, last-exit-status, label.
/// PID is `-` when the job is loaded but not running. Exit-status is `0`
/// for healthy or never-run jobs, non-zero when the last invocation failed.
///
/// We only parse the user domain (`gui/<uid>`) — system jobs require root
/// and aren't relevant for the agent-job use case.
///
/// Surface the results as `Service` records so they show up in the menubar
/// alongside agent-jobs.json entries.
public struct LaunchdUserProvider: ServiceProvider {
    public static let providerId = "launchd.user"
    public static let displayName = "launchd (user)"
    public static let category = ServiceSource.Category.launchd

    /// Optional injection seam for tests. When `nil`, runs the real
    /// `/bin/launchctl list` via `Shell.run`.
    public typealias Runner = @Sendable () async throws -> String
    private let runner: Runner?
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "LaunchdUserProvider")

    public init(runner: Runner? = nil) {
        self.runner = runner
    }

    public func discover() async throws -> [Service] {
        let raw: String
        if let runner {
            raw = try await runner()
        } else {
            do {
                let result = try await Shell.run("/bin/launchctl", args: ["list"])
                guard result.succeeded else {
                    throw ProviderError.ioError("launchctl list exited \(result.exitCode): \(result.stderr.prefix(200))")
                }
                raw = result.stdout
            } catch let failure as Shell.Failure {
                throw ProviderError.ioError("launchctl: \(failure)")
            }
        }
        return Self.parse(raw)
    }

    /// Parse `launchctl list` 3-column output into `Service` records.
    ///
    /// Header line ("PID Status Label") and blank lines are skipped.
    /// Labels prefixed `com.apple.` are filtered out — those are system
    /// jobs that pollute the user view without being actionable here.
    static func parse(_ output: String) -> [Service] {
        var services: [Service] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let cols = trimmed.split(whereSeparator: \.isWhitespace)
            guard cols.count >= 3 else { continue }
            let pidField = String(cols[0])
            let statusField = String(cols[1])
            let label = String(cols[2..<cols.count].joined(separator: " "))

            // Skip header.
            if pidField == "PID" && statusField == "Status" { continue }
            // Skip Apple system jobs — keep the view focused on user agents.
            if label.hasPrefix("com.apple.") { continue }

            let pid: Int32? = Int32(pidField)
            let lastExit = Int32(statusField) ?? 0

            let status: ServiceStatus = {
                if pid != nil { return .running }
                if lastExit != 0 { return .failed }
                return .scheduled
            }()

            services.append(Service(
                id: "launchd.user:\(label)",
                source: .launchdUser,
                kind: pid != nil ? .daemon : .scheduled,
                name: label,
                command: "",
                schedule: .onDemand,
                status: status,
                createdAt: Date(),
                pid: pid,
                owner: .user,
                history: [],
                origin: nil
            ))
        }
        return services
    }
}
