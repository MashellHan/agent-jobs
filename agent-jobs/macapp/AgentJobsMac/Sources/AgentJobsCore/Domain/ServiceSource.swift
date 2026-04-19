import Foundation

public enum ServiceSource: Hashable, Sendable {
    case agentJobsJson
    case claudeScheduledTask(durable: Bool)
    case claudeLoop(sessionId: String)
    case launchdUser
    case cron
    case brewServices
    case at
    case loginItem
    case process(matched: String)

    public var category: Category {
        switch self {
        case .claudeScheduledTask, .claudeLoop:
            return .claude
        case .launchdUser:
            return .launchd
        case .cron, .at:
            return .cron
        case .brewServices:
            return .brew
        case .loginItem:
            return .login
        case .agentJobsJson:
            return .agentJobs
        case .process:
            return .process
        }
    }

    public enum Category: String, CaseIterable, Sendable, Hashable {
        case claude
        case launchd
        case cron
        case brew
        case login
        case agentJobs
        case process

        public var displayName: String {
            switch self {
            case .claude:    return "Claude"
            case .launchd:   return "LaunchAgents"
            case .cron:      return "Cron / At"
            case .brew:      return "Homebrew Services"
            case .login:     return "Login Items"
            case .agentJobs: return "Agent Jobs (local)"
            case .process:   return "Processes"
            }
        }

        public var sfSymbol: String {
            switch self {
            case .claude:    return "brain.head.profile"
            case .launchd:   return "desktopcomputer"
            case .cron:      return "clock.arrow.circlepath"
            case .brew:      return "mug"
            case .login:     return "door.left.hand.open"
            case .agentJobs: return "doc.badge.gearshape"
            case .process:   return "bolt.horizontal"
            }
        }
    }
}

public enum Schedule: Hashable, Sendable {
    case cron(String)
    case interval(seconds: Int)
    case eventTrigger(String)
    case calendar(components: [DateComponents])
    case onDemand
    case unknown

    /// Human-readable rendering ("every 30s", "daily at 09:00", "0 9 * * *").
    public var humanDescription: String {
        switch self {
        case .cron(let expr):       return CronHumanizer.humanize(expr)
        case .interval(let s):      return "every \(formatSeconds(s))"
        case .eventTrigger(let t):  return "on \(t)"
        case .calendar:             return "calendar trigger"
        case .onDemand:             return "on demand"
        case .unknown:              return "—"
        }
    }

    private func formatSeconds(_ s: Int) -> String {
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s/60)m" }
        if s < 86400 { return "\(s/3600)h" }
        return "\(s/86400)d"
    }
}
