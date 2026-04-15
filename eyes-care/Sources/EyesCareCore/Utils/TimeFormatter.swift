import Foundation

/// Formats time intervals for menu bar display.
///
/// Follows the UX spec formatting rules:
/// - < 60s → "< 1m"
/// - 1-59 min → "Xm"
/// - 60+ min → "Xh Ym"
/// - 24+ hours → "Xd Yh"
public enum TimeFormatter {

    /// Format active time for display.
    ///
    /// - Parameter interval: Cumulative active seconds.
    /// - Returns: Human-readable string like "1h 23m" or "< 1m".
    public static func formatActiveTime(_ interval: TimeInterval) -> String {
        guard interval >= 0 else { return "—" }

        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days >= 1 {
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        if hours >= 1 {
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        if minutes >= 1 {
            return "\(minutes)m"
        }
        return "< 1m"
    }

    /// Format "since last break" for display.
    ///
    /// - Parameters:
    ///   - interval: Seconds since the last natural break ended.
    ///   - isIdle: Whether the user is currently idle (shows "(resting)" suffix).
    /// - Returns: Human-readable string like "18m" or "0m (resting)".
    public static func formatSinceLastBreak(
        _ interval: TimeInterval,
        isIdle: Bool
    ) -> String {
        if isIdle {
            return "0m (resting)"
        }
        return formatActiveTime(interval)
    }

    /// Placeholder string for paused state.
    public static let pausedPlaceholder = "—"
}
