import Foundation

/// Display-only formatted view of a `Service`. Pure value type. The
/// underlying `Service.id` is unchanged — formatter operates on display
/// copies only (M05 AC-F-08).
public struct FormattedService: Sendable, Hashable {
    /// Primary text (≤ 60 chars). e.g. "iMessage" not "application.com.apple.MobileSMS.115xxx".
    public let title: String
    /// 1-line secondary text (≤ 80 chars, no newlines). Schedule, pid, etc.
    public let summary: String

    public init(title: String, summary: String) {
        self.title = title
        self.summary = summary
    }
}

/// Pure-Foundation formatter that derives a friendly title + 1-line
/// summary from `Service.source` + `Service.name` + `Service.command`.
/// Closes T-005. No SwiftUI / AppKit dependency. Stateless — fast hot path.
public enum ServiceFormatter {

    public static let titleLimit = 60
    public static let summaryLimit = 80

    public static func format(_ s: Service) -> FormattedService {
        FormattedService(title: friendlyTitle(s), summary: summary(s))
    }

    public static func friendlyTitle(_ s: Service) -> String {
        let raw = rawTitle(s)
        return truncate(raw, max: titleLimit)
    }

    public static func summary(_ s: Service) -> String {
        let raw = rawSummary(s).replacingOccurrences(of: "\n", with: " ")
        return truncate(raw, max: summaryLimit)
    }

    // MARK: - Title rules

    private static func rawTitle(_ s: Service) -> String {
        if s.name.isEmpty || isAllDigits(s.name) {
            return fallbackTitle(s)
        }
        switch s.source {
        case .agentJobsJson, .claudeScheduledTask, .claudeLoop:
            return s.name
        case .launchdUser:
            return launchdLabelToFriendly(s.name)
        case .process:
            return processTitle(name: s.name, command: s.command)
        case .cron, .at, .brewServices, .loginItem:
            return s.name
        }
    }

    private static func launchdLabelToFriendly(_ label: String) -> String {
        if let mapped = bundleIdMap[label] { return mapped }
        // Try removing any numeric tail like ".115xxx".
        var trimmed = label
        if let r = trimmed.range(of: #"\.\d+$"#, options: .regularExpression) {
            trimmed.removeSubrange(r)
            if let mapped2 = bundleIdMap[trimmed] { return mapped2 }
        }
        // Strip vendor prefix and take last segment.
        let parts = trimmed.split(separator: ".").map(String.init)
        let tail = parts.last ?? trimmed
        return camelSplit(tail)
    }

    private static func processTitle(name: String, command: String) -> String {
        let firstToken = command.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first.map(String.init) ?? ""
        let basename = (firstToken as NSString).lastPathComponent
        if !basename.isEmpty && basename.count > name.count {
            return basename
        }
        if !name.isEmpty { return name }
        return basename.isEmpty ? "process" : basename
    }

    private static func fallbackTitle(_ s: Service) -> String {
        let bucket = s.source.bucket.displayName
        let suffix = String(s.id.suffix(6))
        return "\(bucket) (\(suffix))"
    }

    // MARK: - Summary rules

    private static func rawSummary(_ s: Service) -> String {
        switch s.source {
        case .launchdUser:
            let tail = lastPathComponent(of: firstToken(s.command))
            if !tail.isEmpty { return tail }
            return s.schedule.humanDescription
        case .process:
            var bits: [String] = []
            if let pid = s.pid { bits.append("pid \(pid)") }
            if let m = s.metrics {
                bits.append(formatBytes(m.memoryRSS))
            }
            return bits.isEmpty ? s.schedule.humanDescription : bits.joined(separator: " · ")
        case .claudeLoop(let sessionId):
            return "\(s.schedule.humanDescription) · session \(sessionId.prefix(8))"
        case .claudeScheduledTask, .agentJobsJson, .cron, .at, .brewServices, .loginItem:
            return s.schedule.humanDescription
        }
    }

    // MARK: - Helpers

    private static func camelSplit(_ s: String) -> String {
        var out = ""
        for (i, ch) in s.enumerated() {
            if i > 0, ch.isUppercase, let prev = out.last, prev.isLowercase {
                out.append(" ")
            }
            out.append(ch)
        }
        return out
    }

    private static func truncate(_ s: String, max limit: Int) -> String {
        if s.count <= limit { return s }
        let cutIndex = s.index(s.startIndex, offsetBy: limit - 1)
        return String(s[..<cutIndex]) + "…"
    }

    private static func isAllDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isNumber }
    }

    private static func firstToken(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
    }

    private static func lastPathComponent(of s: String) -> String {
        (s as NSString).lastPathComponent
    }

    private static func formatBytes(_ b: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .memory)
    }

    /// Known launchd-label → human friendly name. Curated; ≤ 30 entries
    /// to keep the formatter cheap. Add the long-tail of common labels
    /// users see in the app rather than every Apple bundle id.
    static let bundleIdMap: [String: String] = [
        "com.apple.MobileSMS": "iMessage",
        "com.apple.Mail": "Mail",
        "com.apple.Safari": "Safari",
        "com.apple.finder": "Finder",
        "com.apple.dock": "Dock",
        "com.apple.notificationcenterui": "Notification Center",
        "com.apple.spotlight": "Spotlight",
        "com.apple.cloudd": "iCloud",
        "com.apple.bird": "iCloud Drive",
        "com.apple.WindowServer": "Window Server",
        "com.apple.coreaudiod": "Core Audio",
        "com.apple.bluetoothd": "Bluetooth",
        "com.apple.locationd": "Location Services",
        "com.apple.WiFiAgent": "Wi-Fi Agent",
        "com.apple.controlcenter": "Control Center",
        "com.microsoft.VSCode": "VS Code",
        "com.microsoft.teams": "Microsoft Teams",
        "com.google.Chrome": "Chrome",
        "com.google.drivefs": "Google Drive",
        "com.spotify.client": "Spotify",
        "com.docker.docker": "Docker",
        "org.mozilla.firefox": "Firefox",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.figma.Desktop": "Figma",
        "com.brave.Browser": "Brave",
    ]
}
