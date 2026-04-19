import Foundation
import os

/// Reads `~/.agent-jobs/jobs.json` produced by the existing TS scanner.
/// Schema kept in sync with src/types.ts.
public struct AgentJobsJsonProvider: ServiceProvider {
    public static let providerId = "agent-jobs.json"
    public static let displayName = "Agent Jobs (local)"
    public static let category = ServiceSource.Category.agentJobs

    public let jobsPath: URL
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "AgentJobsJsonProvider")

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
            // Resilient: return empty rather than crash, but log diagnostic
            // so silent failure doesn't hide real bugs (code-review-001 H1).
            logger.error("Malformed jobs.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
        if let v = payload.schemaVersion, v > Self.supportedSchemaVersion {
            logger.warning("jobs.json schemaVersion=\(v) exceeds supported \(Self.supportedSchemaVersion); attempting best-effort parse")
        }
        return payload.jobs.map { $0.toService() }
    }

    public static let supportedSchemaVersion = 1
}

// MARK: - Wire format (mirrors src/types.ts)

private struct JobsFile: Decodable {
    let schemaVersion: Int?
    let jobs: [JobEntry]
}

private struct JobEntry: Decodable {
    let id: String
    let name: String
    let project: String?
    let command: String?
    let status: String?
    let pid: Int32?
    let createdAt: Date?
    let startedAt: Date?
    let finishedAt: Date?
    let schedule: String?
    let origin: String?

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
            command: command ?? "",
            schedule: schedule,
            status: status,
            createdAt: createdAt ?? startedAt ?? Date(),
            lastRun: finishedAt ?? startedAt,
            nextRun: nil,
            pid: pid,
            metrics: nil,
            logsPath: nil,
            owner: .user,
            history: [],
            origin: origin.map { ServiceOrigin(agent: .custom($0)) }
        )
    }
}

