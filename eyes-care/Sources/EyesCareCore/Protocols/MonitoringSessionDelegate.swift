import Foundation

/// Delegate protocol for receiving monitoring state updates.
///
/// All callbacks are dispatched on the main actor.
@MainActor
public protocol MonitoringSessionDelegate: AnyObject {
    /// Called every poll interval with the latest monitoring status.
    func monitoringSessionDidUpdate(_ status: MonitoringStatus)

    /// Called when a break reminder is triggered.
    /// Default implementation does nothing.
    func monitoringSessionDidTriggerBreak(_ event: BreakEvent)
}

/// Default implementation makes `monitoringSessionDidTriggerBreak` optional.
public extension MonitoringSessionDelegate {
    func monitoringSessionDidTriggerBreak(_ event: BreakEvent) {}
}
