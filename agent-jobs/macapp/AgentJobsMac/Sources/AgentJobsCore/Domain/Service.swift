import Foundation

/// A normalized representation of any background "service" we discover —
/// OS daemons, cron entries, brew services, login items, Claude scheduled
/// tasks, or live agent loops. Every Provider returns these.
///
/// Field set mirrors the TUI contract (`src/types.ts`) plus strict-review
/// iter-001 §"数据模型" requirements: `createdAt`, `history`, `origin`.
public struct Service: Identifiable, Hashable, Sendable {
    public let id: String
    public let source: ServiceSource
    public let kind: ServiceKind
    public let name: String
    public let project: String?
    /// Always present (empty string if the source has no command surface).
    /// Required for TUI parity and HIG-compliant detail panels.
    public let command: String
    public let schedule: Schedule
    public let status: ServiceStatus
    /// When the service record was first registered/observed. `nil` when the
    /// underlying source doesn't expose a real registration time (e.g. launchd
    /// — `launchctl list` only reports current PID + last-exit, never load
    /// time). The UI shows "—" for nil rather than a synthetic `Date()` that
    /// would lie about provenance (strict-iter-007 M-006).
    public let createdAt: Date?
    public let lastRun: Date?
    public let nextRun: Date?
    public let pid: Int32?
    public let metrics: ResourceMetrics?
    public let logsPath: String?
    public let owner: ProcessOwner
    /// Friendly history (most recent first). Smart-truncated for display
    /// per memory `feedback_tui_history`.
    public let history: [HistoryEvent]
    /// Where this service originated from (the agent / tool / session that
    /// registered it). Used by the "registered" source category.
    public let origin: ServiceOrigin?

    public init(
        id: String,
        source: ServiceSource,
        kind: ServiceKind,
        name: String,
        project: String? = nil,
        command: String = "",
        schedule: Schedule = .onDemand,
        status: ServiceStatus = .unknown,
        createdAt: Date? = nil,
        lastRun: Date? = nil,
        nextRun: Date? = nil,
        pid: Int32? = nil,
        metrics: ResourceMetrics? = nil,
        logsPath: String? = nil,
        owner: ProcessOwner = .user,
        history: [HistoryEvent] = [],
        origin: ServiceOrigin? = nil
    ) {
        self.id = id
        self.source = source
        self.kind = kind
        self.name = name
        self.project = project
        self.command = command
        self.schedule = schedule
        self.status = status
        self.createdAt = createdAt
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.pid = pid
        self.metrics = metrics
        self.logsPath = logsPath
        self.owner = owner
        self.history = history
        self.origin = origin
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
    case agent(AgentKind)
}

/// Typed agent identity (avoids string typos per code-review-001 L3).
public enum AgentKind: Hashable, Sendable {
    case claude
    case codex
    case openclaw
    case custom(String)

    public var displayName: String {
        switch self {
        case .claude:           return "Claude"
        case .codex:            return "Codex"
        case .openclaw:         return "OpenClaw"
        case .custom(let s):    return s
        }
    }
}

/// Single event in a service's history (run started, completed, failed, …).
/// Used by the inspector "Logs"/"Overview" tabs.
public struct HistoryEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case started, completed, failed, paused, resumed, scheduled, edited
    }
    public let at: Date
    public let kind: Kind
    /// One-line summary suitable for display. Long output should live in `logsPath`.
    public let summary: String

    public init(at: Date, kind: Kind, summary: String) {
        self.at = at
        self.kind = kind
        self.summary = summary
    }
}

/// Where a service was originally registered.
public struct ServiceOrigin: Hashable, Sendable {
    public let agent: AgentKind
    public let sessionId: String?
    public let toolName: String?

    public init(agent: AgentKind, sessionId: String? = nil, toolName: String? = nil) {
        self.agent = agent
        self.sessionId = sessionId
        self.toolName = toolName
    }
}

// MARK: - M03 actions

public extension Service {
    /// Pure derived gate. UI uses it to pre-disable the Stop button. The
    /// executor re-checks the same predicates at action time. Implementation
    /// delegates to `RealStopExecutor.refusalReason` so there is exactly one
    /// source of truth for the six predicates.
    var canStop: Bool {
        RealStopExecutor.refusalReason(
            for: self,
            selfPid: ProcessInfo.processInfo.processIdentifier,
            plistURL: LaunchdPlistReader.plistURL(forLabel:)
        ) == nil
    }

    /// Display copy with `metrics` substituted. Used by
    /// `LiveResourceSampler` (M05 T04) to merge sampled CPU%/RSS into a
    /// service after `discoverAllDetailed()` returns. Identity preserved.
    func with(metrics newMetrics: ResourceMetrics?) -> Service {
        Service(
            id: id, source: source, kind: kind, name: name, project: project,
            command: command, schedule: schedule, status: status,
            createdAt: createdAt, lastRun: lastRun, nextRun: nextRun,
            pid: pid, metrics: newMetrics, logsPath: logsPath, owner: owner,
            history: history, origin: origin
        )
    }
}


