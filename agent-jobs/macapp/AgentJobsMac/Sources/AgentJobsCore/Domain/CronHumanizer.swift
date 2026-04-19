import Foundation

/// Translates a cron expression into a human-readable schedule string.
///
/// Handles common patterns; falls back to the raw expression with a `cron:` prefix
/// when nothing matches. Resolves strict-review H-001 (`feedback_schedule_display`).
public enum CronHumanizer {

    /// Returns a phrase like "weekdays 9:00am" or "every 5 minutes" for known patterns,
    /// otherwise `"cron: <expr>"`.
    public static func humanize(_ expr: String) -> String {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 5 else { return "cron: \(trimmed)" }
        let (minute, hour, dom, month, dow) = (parts[0], parts[1], parts[2], parts[3], parts[4])

        // Every-N minute patterns: "*/N * * * *"
        if minute.hasPrefix("*/"), hour == "*", dom == "*", month == "*", dow == "*",
           let n = Int(minute.dropFirst(2)), n > 0 {
            return "every \(n) minute\(n == 1 ? "" : "s")"
        }

        // Hourly at minute M: "M * * * *"
        if let m = Int(minute), hour == "*", dom == "*", month == "*", dow == "*" {
            return m == 0 ? "every hour" : "hourly at :\(String(format: "%02d", m))"
        }

        // Every N hours: "0 */N * * *"
        if minute == "0", hour.hasPrefix("*/"), dom == "*", month == "*", dow == "*",
           let n = Int(hour.dropFirst(2)), n > 0 {
            return "every \(n) hour\(n == 1 ? "" : "s")"
        }

        // Daily at H:M: "M H * * *"
        if let m = Int(minute), let h = Int(hour), dom == "*", month == "*", dow == "*" {
            return "daily at \(formatTime(h: h, m: m))"
        }

        // Weekdays at H:M: "M H * * 1-5"
        if let m = Int(minute), let h = Int(hour), dom == "*", month == "*", dow == "1-5" {
            return "weekdays at \(formatTime(h: h, m: m))"
        }

        // Weekly on day-of-week at H:M: "M H * * D"
        if let m = Int(minute), let h = Int(hour), dom == "*", month == "*",
           let d = Int(dow), (0...7).contains(d) {
            return "every \(dayName(d)) at \(formatTime(h: h, m: m))"
        }

        // Monthly on day D at H:M: "M H D * *"
        if let m = Int(minute), let h = Int(hour), let d = Int(dom), month == "*", dow == "*" {
            return "monthly on the \(ordinal(d)) at \(formatTime(h: h, m: m))"
        }

        return "cron: \(trimmed)"
    }

    private static func formatTime(h: Int, m: Int) -> String {
        let suffix = h < 12 ? "am" : "pm"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if m == 0 { return "\(hour12)\(suffix)" }
        return "\(hour12):\(String(format: "%02d", m))\(suffix)"
    }

    private static func dayName(_ d: Int) -> String {
        // Cron day-of-week: 0 and 7 both mean Sunday (BSD/Vixie cron).
        // Array has 8 entries so indexing by either 0 or 7 yields "Sunday"
        // without a branch — the trailing "Sunday" is intentional, not off-by-one.
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names[d]
    }

    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
