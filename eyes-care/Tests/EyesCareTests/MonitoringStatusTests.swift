import Testing
@testable import EyesCareCore

@Suite("MonitoringStatus Tests")
struct MonitoringStatusTests {

    @Test("init stores all values correctly")
    func initStoresValues() {
        let status = MonitoringStatus(
            isMonitoring: true,
            activityState: .active,
            activeTime: 300,
            sinceLastBreak: 120
        )

        #expect(status.isMonitoring == true)
        #expect(status.activityState == .active)
        #expect(status.activeTime == 300)
        #expect(status.sinceLastBreak == 120)
    }

    @Test("two equal statuses are equal")
    func equalStatuses() {
        let status1 = MonitoringStatus(
            isMonitoring: true,
            activityState: .idle,
            activeTime: 60,
            sinceLastBreak: 30
        )
        let status2 = MonitoringStatus(
            isMonitoring: true,
            activityState: .idle,
            activeTime: 60,
            sinceLastBreak: 30
        )

        #expect(status1 == status2)
    }

    @Test("different statuses are not equal")
    func differentStatuses() {
        let status1 = MonitoringStatus(
            isMonitoring: true,
            activityState: .active,
            activeTime: 300,
            sinceLastBreak: 120
        )
        let status2 = MonitoringStatus(
            isMonitoring: false,
            activityState: .idle,
            activeTime: 0,
            sinceLastBreak: 0
        )

        #expect(status1 != status2)
    }

    @Test("paused status has expected defaults")
    func pausedStatus() {
        let status = MonitoringStatus(
            isMonitoring: false,
            activityState: .active,
            activeTime: 0,
            sinceLastBreak: 0
        )

        #expect(status.isMonitoring == false)
        #expect(status.activeTime == 0)
    }
}
