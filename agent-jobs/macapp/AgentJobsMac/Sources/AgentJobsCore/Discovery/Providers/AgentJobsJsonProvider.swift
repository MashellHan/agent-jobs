import Foundation

/// Reads `~/.agent-jobs/jobs.json` produced by the existing TS scanner.
/// Schema kept in sync with src/types.ts.
public struct AgentJobsJsonProvider: ServiceProvider {
    public static let providerId = "agent-jobs.json"
    public static let displayName = "Agent Jobs (local)"
    public static let category = ServiceSource.Category.agentJobs

    public let jobsPath: URL

    public init(jobsPath: URL? = nil) {
        if let p = jobsPath {
            self.jobsPath = p
        } else {
            self.jobsPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".agent-jobs/jobs.json")
        }
    }

    public func discover() async throws -> [Service] {
        guard FileManager.default.fileExists(atPath: jobsPath.path) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: jobsPath)
        } catch {
            throw ProviderError.ioError("read \(jobsPath.path): \(error.localizedDescription)")
        }
        guard !data.isEmpty else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: JobsFile
        do {
            payload = try decoder.decode(JobsFile.self, from: data)
        } catch {
            // Malformed input: return empty rather than crash; surface via diagnostics later.
            return []
        }
        return payload.jobs.map { $0.toService() }
    }
}

// MARK: - Wire format (mirrors src/types.ts)

private struct JobsFile: Decodable {
    let jobs: [JobEntry]
}

private struct JobEntry: Decodable {
    let id: String
    let name: String
    let project: String?
    let command: String?
    let status: String?
    let pid: Int32?
    let startedAt: Date?
    let finishedAt: Date?
    let schedule: String?

    func toService() -> Service {
        let status: ServiceStatus = {
            switch (self.status ?? "").lowercased() {
            case "running": return .running
            case "done", "completed": return .done
            case "failed", "error": return .failed
            case "scheduled", "pending": return .scheduled
            case "paused": return .paused
            default: return .unknown
            }
        }()

        let schedule: Schedule = {
            guard let s = self.schedule, !s.isEmpty else { return .onDemand }
            return .cron(s)
        }()

        return Service(
            id: "agent-jobs:\(id)",
            source: .agentJobsJson,
            kind: schedule == .onDemand ? .oneshot : .scheduled,
            name: name,
            project: project,
            command: command,
            schedule: schedule,
            status: status,
            lastRun: finishedAt ?? startedAt,
            nextRun: nil,
            pid: pid,
            metrics: nil,
            logsPath: nil,
            owner: .user
        )
    }
}
