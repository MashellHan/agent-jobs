import Foundation

/// Immutable snapshot of the current monitoring state.
///
/// Produced by `MonitoringSession` on every poll tick.
/// Consumed by `AppDelegate` to update menu items.
public struct MonitoringStatus: Sendable, Equatable {
    /// Whether monitoring is currently active (not paused).
    public let isMonitoring: Bool

    /// Current user activity state.
    public let activityState: ActivityState

    /// Cumulative active time in seconds since monitoring started.
    public let activeTime: TimeInterval

    /// Seconds since the user's last natural break ended.
    public let sinceLastBreak: TimeInterval

    /// Seconds since last micro break (20-20-20).
    public let sinceLastMicroBreak: TimeInterval

    /// Seconds since last macro break (hourly rest).
    public let sinceLastMacroBreak: TimeInterval

    /// Seconds since last mandatory break (2-hour).
    public let sinceLastMandatoryBreak: TimeInterval

    /// The next break type that will trigger, if any.
    public let nextBreakType: BreakType?

    /// Seconds until the next break triggers.
    public let timeUntilNextBreak: TimeInterval

    /// The current reminder mode.
    public let reminderMode: ReminderMode

    public init(
        isMonitoring: Bool,
        activityState: ActivityState,
        activeTime: TimeInterval,
        sinceLastBreak: TimeInterval,
        sinceLastMicroBreak: TimeInterval = 0,
        sinceLastMacroBreak: TimeInterval = 0,
        sinceLastMandatoryBreak: TimeInterval = 0,
        nextBreakType: BreakType? = nil,
        timeUntilNextBreak: TimeInterval = 0,
        reminderMode: ReminderMode = .gentle
    ) {
        self.isMonitoring = isMonitoring
        self.activityState = activityState
        self.activeTime = activeTime
        self.sinceLastBreak = sinceLastBreak
        self.sinceLastMicroBreak = sinceLastMicroBreak
        self.sinceLastMacroBreak = sinceLastMacroBreak
        self.sinceLastMandatoryBreak = sinceLastMandatoryBreak
        self.nextBreakType = nextBreakType
        self.timeUntilNextBreak = timeUntilNextBreak
        self.reminderMode = reminderMode
    }
}
