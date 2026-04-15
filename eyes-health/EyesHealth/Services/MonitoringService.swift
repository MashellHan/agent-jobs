import AppKit
import CoreGraphics
import Foundation

final class MonitoringService: NSObject {
    private let appState: AppState
    private let mascotState: MascotState?
    private var notificationService: NotificationService?
    private var breakWindowService: BreakWindowService?
    private var pollingTimer: Timer?
    private var autoSaveTimer: Timer?
    private var isScreenLocked: Bool = false

    private let persistenceService: DataPersistenceService
    private let scoreService: EyeHealthScoreService

    init(
        appState: AppState,
        mascotState: MascotState? = nil,
        persistenceService: DataPersistenceService = DataPersistenceService(),
        scoreService: EyeHealthScoreService = EyeHealthScoreService()
    ) {
        self.appState = appState
        self.mascotState = mascotState
        self.persistenceService = persistenceService
        self.scoreService = scoreService
        super.init()
        registerScreenLockObservers()
        restoreTodayData()
    }

    func setNotificationService(_ service: NotificationService) {
        notificationService = service
    }

    func setBreakWindowService(_ service: BreakWindowService) {
        breakWindowService = service
    }

    // MARK: - Start / Stop

    func startMonitoring() {
        guard !appState.isMonitoring else { return }
        appState.isMonitoring = true
        startPollingTimer()
        startAutoSaveTimer()
    }

    func stopMonitoring() {
        appState.isMonitoring = false
        pollingTimer?.invalidate()
        pollingTimer = nil
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        saveCurrentData()
    }

    // MARK: - Manual Break

    func takeBreakNow() {
        appState.recordBreak()
        notificationService?.cancelPendingNotifications()
        breakWindowService?.dismiss()
        mascotState?.celebrateBreak()
    }

    // MARK: - Snooze

    func handleSnooze() {
        // Don't reset continuous use — keep tracking total screen time.
        // Instead, suppress notifications until snooze period expires.
        appState.snoozedUntil = Date.now.addingTimeInterval(Constants.snoozeInterval)
        appState.hasNotifiedThisSession = false
        appState.breaksSkipped += 1
    }

    // MARK: - Polling Timer

    private func startPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(
            timeInterval: Constants.pollingInterval,
            target: self,
            selector: #selector(pollIdleTime),
            userInfo: nil,
            repeats: true
        )
        RunLoop.current.add(pollingTimer!, forMode: .common)
    }

    @objc private func pollIdleTime() {
        guard appState.isMonitoring, !isScreenLocked else { return }

        let idleSeconds = currentIdleTime()

        if idleSeconds >= Constants.naturalBreakThreshold {
            // Natural break detected — user was idle for 2+ minutes
            appState.recordBreak(duration: idleSeconds)
            notificationService?.cancelPendingNotifications()
            updateEyeHealthScore()
            return
        }

        if idleSeconds < Constants.idleThreshold {
            // User is actively using the screen
            appState.incrementContinuousUse(by: Constants.pollingInterval)
        }
        // If idle between 30s and 2m, we neither increment nor reset — just wait

        if appState.shouldNotify {
            appState.hasNotifiedThisSession = true
            appState.breaksDue += 1
            mascotState?.alertBreakDue()

            switch appState.reminderMode {
            case .gentle:
                notificationService?.scheduleBreakReminder()
            case .normal:
                notificationService?.scheduleBreakReminder()
                breakWindowService?.showBreakWindow()
            case .aggressive:
                breakWindowService?.showFullScreenBreak()
            }
        }
    }

    // MARK: - Idle Time Detection

    private func currentIdleTime() -> TimeInterval {
        // Use CGEventSource to get seconds since last user input event
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        return idleTime
    }

    // MARK: - Screen Lock / Unlock

    private func registerScreenLockObservers() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        dnc.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func handleScreenLock() {
        isScreenLocked = true
        saveCurrentData()
    }

    @objc private func handleScreenUnlock() {
        isScreenLocked = false
    }

    // MARK: - Auto-Save (every 5 minutes)

    private func startAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        let timer = Timer.scheduledTimer(
            withTimeInterval: Constants.autoSaveInterval,
            repeats: true
        ) { [weak self] _ in
            self?.saveCurrentData()
            self?.updateEyeHealthScore()
        }
        RunLoop.current.add(timer, forMode: .common)
        autoSaveTimer = timer
    }

    // MARK: - Persistence

    func saveCurrentData() {
        let data = appState.buildDailyUsageData()
        persistenceService.saveDailyData(data)
    }

    private func restoreTodayData() {
        guard let saved = persistenceService.loadTodayData() else { return }

        appState.totalScreenTimeToday = saved.totalScreenTimeSeconds
        appState.sessionsCount = max(1, saved.sessionsCount)
        appState.longestSessionSeconds = saved.longestSessionSeconds
        appState.breaksDue = saved.breaksDue
        appState.breaksSkipped = saved.breaksSkipped

        // Restore hourly screen time
        for (key, value) in saved.hourlyScreenTime {
            if let hour = Int(key) {
                appState.hourlyScreenTime[hour] = value
            }
        }

        // Restore break records
        for record in saved.breakRecords {
            appState.recordBreak(duration: record.durationSeconds)
        }

        updateEyeHealthScore()
        print("[MonitoringService] Restored today's data: \(saved.totalScreenTimeSeconds)s screen time, \(saved.breaksTaken) breaks")
    }

    // MARK: - Eye Health Score

    private func updateEyeHealthScore() {
        let data = appState.buildDailyUsageData()
        let score = scoreService.calculateScore(from: data)
        appState.currentEyeHealthScore = score.totalScore
        appState.currentEyeHealthGrade = score.grade
    }

    // MARK: - Daily Report Generation

    /// Generate yesterday's report and save, then reset for today.
    func generateAndSaveDailyReport() {
        let data = appState.buildDailyUsageData()
        let score = scoreService.calculateScore(from: data)
        let report = persistenceService.generateDailyReport(from: data, score: score)
        persistenceService.saveDailyReport(report, for: data.date)
        persistenceService.saveDailyData(data)
    }

    /// Generate and save the current day's report (for "View Today's Report").
    func generateTodayReport() {
        let data = appState.buildDailyUsageData()
        let score = scoreService.calculateScore(from: data)
        let report = persistenceService.generateDailyReport(from: data, score: score)
        persistenceService.saveDailyReport(report, for: data.date)
    }

    /// URL for today's report file.
    var todayReportURL: URL {
        persistenceService.todayReportURL()
    }

    /// URL for the reports directory.
    var reportsDirectoryURL: URL {
        persistenceService.reportsDirectoryURL
    }

    deinit {
        pollingTimer?.invalidate()
        autoSaveTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
