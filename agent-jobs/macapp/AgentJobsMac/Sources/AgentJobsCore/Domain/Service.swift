import Foundation

/// A normalized representation of any background "service" we discover —
/// OS daemons, cron entries, brew services, login items, Claude scheduled
/// tasks, or live agent loops. Every Provider returns these.
public struct Service: Identifiable, Hashable, Sendable {
    public let id: String
    public let source: ServiceSource
    public let kind: ServiceKind
    public let name: String
    public let project: String?
    public let command: String?
    public let schedule: Schedule
    public let status: ServiceStatus
    public let lastRun: Date?
    public let nextRun: Date?
    public let pid: Int32?
    public let metrics: ResourceMetrics?
    public let logsPath: String?
    public let owner: ProcessOwner

    public init(
        id: String,
        source: ServiceSource,
        kind: ServiceKind,
        name: String,
        project: String? = nil,
        command: String? = nil,
        schedule: Schedule = .onDemand,
        status: ServiceStatus = .unknown,
        lastRun: Date? = nil,
        nextRun: Date? = nil,
        pid: Int32? = nil,
        metrics: ResourceMetrics? = nil,
        logsPath: String? = nil,
        owner: ProcessOwner = .user
    ) {
        self.id = id
        self.source = source
        self.kind = kind
        self.name = name
        self.project = project
        self.command = command
        self.schedule = schedule
        self.status = status
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.pid = pid
        self.metrics = metrics
        self.logsPath = logsPath
        self.owner = owner
    }
}

public enum ServiceKind: String, Codable, Sendable, Hashable {
    case daemon
    case scheduled
    case eventDriven
    case oneshot
    case interactive
}

public enum ServiceStatus: String, Codable, Sendable, Hashable {
    case running
    case idle
    case scheduled
    case done
    case failed
    case paused
    case orphaned
    case unknown
}

public enum ProcessOwner: Hashable, Sendable {
    case os
    case user
    case agent(String)
}
