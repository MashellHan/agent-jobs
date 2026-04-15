import Foundation

/// Delegate protocol for receiving monitoring state updates.
///
/// All callbacks are dispatched on the main actor.
@MainActor
public protocol MonitoringSessionDelegate: AnyObject {
    /// Called every poll interval with the latest monitoring status.
    func monitoringSessionDidUpdate(_ status: MonitoringStatus)
}
