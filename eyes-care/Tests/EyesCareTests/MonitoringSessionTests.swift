import Testing
@testable import EyesCareCore

@Suite("MonitoringSession Tests")
struct MonitoringSessionTests {

    // MARK: - Start / Pause lifecycle

    @Test("start sets isMonitoring to true and notifies delegate")
    @MainActor
    func startSetsMonitoring() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()

        #expect(session.isMonitoring == true)
        #expect(delegate.updateCount == 1)
        #expect(delegate.lastStatus?.isMonitoring == true)

        session.pause()
    }

    @Test("pause sets isMonitoring to false and notifies delegate")
    @MainActor
    func pauseSetsMonitoring() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.pause()

        #expect(session.isMonitoring == false)
        #expect(delegate.updateCount == 2) // start + pause
        #expect(delegate.lastStatus?.isMonitoring == false)
    }

    @Test("start is idempotent — calling twice does not break")
    @MainActor
    func startIdempotent() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.start() // second call should be no-op

        #expect(delegate.updateCount == 1) // only one notification
        #expect(session.isMonitoring == true)

        session.pause()
    }

    @Test("pause is idempotent — calling twice does not break")
    @MainActor
    func pauseIdempotent() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.pause()
        session.pause() // second call should be no-op

        #expect(delegate.updateCount == 2) // start + one pause
        #expect(session.isMonitoring == false)
    }

    // MARK: - State detection via poll

    @Test("poll with active user sets active state")
    @MainActor
    func pollActiveState() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 0
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.poll()

        #expect(delegate.lastStatus?.activityState == .active)

        session.pause()
    }

    @Test("poll with idle user sets idle state")
    @MainActor
    func pollIdleState() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 35
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.poll()

        #expect(delegate.lastStatus?.activityState == .idle)

        session.pause()
    }

    @Test("poll with away user sets away state")
    @MainActor
    func pollAwayState() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 130
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.poll()

        #expect(delegate.lastStatus?.activityState == .away)

        session.pause()
    }

    // MARK: - Active time accumulation

    @Test("active time accumulates over multiple polls")
    @MainActor
    func activeTimeAccumulation() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 0
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.poll() // 1st poll: active
        session.poll() // 2nd poll: active
        session.poll() // 3rd poll: active

        let expectedTime = 3.0 * Constants.pollingInterval
        #expect(delegate.lastStatus?.activeTime == expectedTime)

        session.pause()
    }

    // MARK: - Away resets break timer

    @Test("away to active transition resets sinceLastBreak")
    @MainActor
    func awayResetsBreakTimer() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()

        // Simulate active for a bit
        mock.idleSeconds = 0
        session.poll()
        session.poll()

        // User goes away
        mock.idleSeconds = 130
        session.poll()
        #expect(delegate.lastStatus?.activityState == .away)

        // User comes back
        mock.idleSeconds = 0
        session.poll()
        #expect(delegate.lastStatus?.activityState == .active)

        // sinceLastBreak should be very small (just reset)
        if let sinceLastBreak = delegate.lastStatus?.sinceLastBreak {
            #expect(sinceLastBreak < 2.0)
        }

        session.pause()
    }

    // MARK: - Paused state

    @Test("poll does nothing when paused")
    @MainActor
    func pollWhilePaused() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 0
        let session = MonitoringSession(idleDetector: mock)
        let delegate = MockMonitoringSessionDelegate()
        session.delegate = delegate

        session.start()
        session.pause()
        let countAfterPause = delegate.updateCount

        session.poll() // should be no-op

        #expect(delegate.updateCount == countAfterPause)
    }

    // MARK: - currentStatus

    @Test("currentStatus returns correct snapshot")
    @MainActor
    func currentStatusSnapshot() {
        let mock = MockIdleDetector()
        mock.idleSeconds = 0
        let session = MonitoringSession(idleDetector: mock)

        session.start()
        session.poll()

        let status = session.currentStatus()
        #expect(status.isMonitoring == true)
        #expect(status.activityState == .active)
        #expect(status.activeTime == Constants.pollingInterval)

        session.pause()
    }

    @Test("currentStatus when paused shows zero sinceLastBreak")
    @MainActor
    func currentStatusWhenPaused() {
        let mock = MockIdleDetector()
        let session = MonitoringSession(idleDetector: mock)

        session.start()
        session.pause()

        let status = session.currentStatus()
        #expect(status.isMonitoring == false)
        #expect(status.sinceLastBreak == 0)
    }
}
