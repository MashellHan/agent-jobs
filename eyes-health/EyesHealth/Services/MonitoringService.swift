import AppKit
import CoreGraphics
import Foundation

final class MonitoringService: NSObject {
    private let appState: AppState
    private let mascotState: MascotState?
    private var notificationService: NotificationService?
    private var breakWindowService: BreakWindowService?
    private var pollingTimer: Timer?
    private var isScreenLocked: Bool = false

    init(appState: AppState, mascotState: MascotState? = nil) {
        self.appState = appState
        self.mascotState = mascotState
        super.init()
        registerScreenLockObservers()
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
    }

    func stopMonitoring() {
        appState.isMonitoring = false
        pollingTimer?.invalidate()
        pollingTimer = nil
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
            return
        }

        if idleSeconds < Constants.idleThreshold {
            // User is actively using the screen
            appState.incrementContinuousUse(by: Constants.pollingInterval)
        }
        // If idle between 30s and 2m, we neither increment nor reset — just wait

        if appState.shouldNotify {
            appState.hasNotifiedThisSession = true
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
        // Treat screen lock as start of a natural break
    }

    @objc private func handleScreenUnlock() {
        isScreenLocked = false
        // Check if screen was locked long enough for a natural break
        // The idle time from CGEventSource covers the locked period too,
        // so the next poll cycle will detect it automatically
    }

    deinit {
        pollingTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
