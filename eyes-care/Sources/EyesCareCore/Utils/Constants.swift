import Foundation

/// Application constants
public enum Constants {
    /// Polling interval for idle detection (seconds)
    public static let pollingInterval: TimeInterval = 5.0

    /// Idle threshold - user considered idle after this many seconds
    public static let idleThreshold: TimeInterval = 30.0

    /// Natural break threshold - idle this long counts as a break
    public static let naturalBreakThreshold: TimeInterval = 120.0

    /// Default snooze duration
    public static let snoozeDuration: TimeInterval = 5 * 60  // 5 minutes

    /// UserDefaults keys
    public static let reminderModeKey = "eyesCare.reminderMode"
    public static let isMonitoringKey = "eyesCare.isMonitoring"

    /// Data directory name
    public static let dataDirectoryName = "EyesCare"

    /// Report file prefix
    public static let reportPrefix = "eyescare-report"
}
