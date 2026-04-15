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

    public init(
        isMonitoring: Bool,
        activityState: ActivityState,
        activeTime: TimeInterval,
        sinceLastBreak: TimeInterval
    ) {
        self.isMonitoring = isMonitoring
        self.activityState = activityState
        self.activeTime = activeTime
        self.sinceLastBreak = sinceLastBreak
    }
}
