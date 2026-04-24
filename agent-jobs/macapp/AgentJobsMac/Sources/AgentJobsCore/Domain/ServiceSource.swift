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

    /// User-facing data-source bucket. ORTHOGONAL to `Category`.
    /// `Category` groups by *kind of scheduler* (Claude/launchd/cron/...).
    /// `Bucket` groups by *which discovery provider produced this row* — what
    /// the M02 summary strip displays. Five cases align 1-1 with the five
    /// providers wired into `defaultRegistry()`.
    ///
    /// Cases not produced by any wired provider in M02 fall back to the
    /// closest bucket; they will not appear in the strip's counts unless a
    /// future provider emits them.
    public var bucket: Bucket {
        switch self {
        case .agentJobsJson:        return .registered
        case .claudeScheduledTask:  return .claudeScheduled
        case .claudeLoop:           return .claudeSession
        case .launchdUser:          return .launchd
        case .process:              return .liveProcess
        case .cron, .at:            return .launchd       // placeholder
        case .brewServices:         return .liveProcess   // placeholder
        case .loginItem:            return .registered    // placeholder
        }
    }

    /// AC-F-05 chip ordering: registered → claudeScheduled → claudeSession →
    /// launchd → liveProcess. `Bucket.allCases` IS the authoritative order.
    public enum Bucket: String, CaseIterable, Sendable, Hashable {
        case registered
        case claudeScheduled
        case claudeSession
        case launchd
        case liveProcess

        public var displayName: String {
            switch self {
            case .registered:      return "registered"
            case .claudeScheduled: return "claude-sched"
            case .claudeSession:   return "claude-loop"
            case .launchd:         return "launchd"
            case .liveProcess:     return "live-proc"
            }
        }

        public var sfSymbol: String {
            switch self {
            case .registered:      return "doc.badge.gearshape"
            case .claudeScheduled: return "brain.head.profile"
            case .claudeSession:   return "terminal"
            case .launchd:         return "desktopcomputer"
            case .liveProcess:     return "bolt.horizontal"
            }
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
        case .calendar(let comps):  return Self.humanizeCalendar(comps)
        case .onDemand:             return "on demand"
        case .unknown:              return "—"
        }
    }

    /// Render a `[DateComponents]` (one entry per launchd CalendarInterval
    /// dict) into a single user-facing line. Common cases get nice names
    /// ("daily at 09:00", "weekly Mon at 03:00"); anything more exotic falls
    /// back to a count ("3 calendar triggers"). Per `feedback_schedule_display`
    /// — show the actual frequency, not "always-on".
    static func humanizeCalendar(_ comps: [DateComponents]) -> String {
        guard let first = comps.first else { return "calendar trigger" }
        if comps.count == 1 {
            return describe(first)
        }
        // If every entry shares the same time-of-day, surface that.
        let timeStrings = Set(comps.map { timeOfDay($0) })
        if timeStrings.count == 1, let t = timeStrings.first {
            return "\(comps.count)× \(t)"
        }
        return "\(comps.count) calendar triggers"
    }

    private static func describe(_ c: DateComponents) -> String {
        let time = timeOfDay(c)
        // weekday-only (with optional time)
        if let wd = c.weekday {
            let name = weekdayShort(cocoaWeekday: wd)
            return "weekly \(name)\(time.isEmpty ? "" : " at \(time)")"
        }
        // monthly: day-of-month set
        if let day = c.day {
            return "monthly on day \(day)\(time.isEmpty ? "" : " at \(time)")"
        }
        // hour set, no day/weekday → daily at HH:MM
        if c.hour != nil {
            return "daily at \(time)"
        }
        // only minute → every hour at MM
        if let m = c.minute {
            return "hourly at :\(String(format: "%02d", m))"
        }
        return "calendar trigger"
    }

    private static func timeOfDay(_ c: DateComponents) -> String {
        guard let h = c.hour else { return "" }
        let m = c.minute ?? 0
        return String(format: "%02d:%02d", h, m)
    }

    private static func weekdayShort(cocoaWeekday: Int) -> String {
        // Cocoa: 1=Sun … 7=Sat
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let idx = max(1, min(7, cocoaWeekday)) - 1
        return names[idx]
    }

    private func formatSeconds(_ s: Int) -> String {
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s/60)m" }
        if s < 86400 { return "\(s/3600)h" }
        return "\(s/86400)d"
    }
}
