import EyesCareCore

@MainActor
final class MockMonitoringSessionDelegate: MonitoringSessionDelegate {
    private(set) var lastStatus: MonitoringStatus?
    private(set) var updateCount = 0

    func monitoringSessionDidUpdate(_ status: MonitoringStatus) {
        lastStatus = status
        updateCount += 1
    }
}
