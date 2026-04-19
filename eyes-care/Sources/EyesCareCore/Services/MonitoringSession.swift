import Foundation

/// Orchestrates idle monitoring, state transitions, time tracking, and break scheduling.
///
/// `MonitoringSession` is the core engine of EyesCare. It:
/// 1. Polls an `IdleDetecting` source every `Constants.pollingInterval` seconds
/// 2. Derives `ActivityState` from the idle time
/// 3. Tracks cumulative active time and time since last break (per break type)
/// 4. Checks if any break is due via `BreakScheduler`
/// 5. Notifies its `delegate` with a `MonitoringStatus` snapshot on every tick
/// 6. Triggers break reminders via `NotificationSending`
///
/// ## Usage
/// ```swift
/// let session = MonitoringSession()
/// session.delegate = self
/// session.start()
/// ```
///
/// ## Threading
/// This class is `@MainActor` because it owns a `Timer` and updates UI-bound state.
@MainActor
public final class MonitoringSession {
    // MARK: - Dependencies

    private let idleDetector: any IdleDetecting
    private var notificationService: (any NotificationSending)?

    // MARK: - State

    public private(set) var isMonitoring = false
    private var activityState: ActivityState = .active
    private var accumulatedActiveTime: TimeInterval = 0
    private var lastBreakEndDate: Date = Date()
    private var previousState: ActivityState = .active

    // MARK: - Break Tracking

    private var lastMicroBreakDate: Date = Date()
    private var lastMacroBreakDate: Date = Date()
    private var lastMandatoryBreakDate: Date = Date()

    /// Tracks whether we've already notified for the current overdue break
    /// so we don't spam the user every 5 seconds.
    private var lastNotifiedBreakType: BreakType?
    private var lastNotifiedDate: Date?

    /// Minimum seconds between repeated notifications for the same break type.
    private static let renotifyInterval: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Reminder Mode

    public var reminderMode: ReminderMode = .gentle

    // MARK: - Timer

    private var pollTimer: Timer?

    // MARK: - Delegate

    public weak var delegate: (any MonitoringSessionDelegate)?

    // MARK: - Init

    public init(
        idleDetector: any IdleDetecting = CGEventSourceIdleDetector(),
        notificationService: (any NotificationSending)? = nil
    ) {
        self.idleDetector = idleDetector
        self.notificationService = notificationService
    }

    /// Set up the notification service (call after app launch).
    public func setupNotifications(_ service: any NotificationSending) {
        self.notificationService = service
        Task {
            await service.requestPermissions()
        }
    }

    // MARK: - Public API

    /// Start monitoring. Creates a repeating timer.
    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activityState = .active
        previousState = .active
        accumulatedActiveTime = 0
        let now = Date()
        lastBreakEndDate = now
        lastMicroBreakDate = now
        lastMacroBreakDate = now
        lastMandatoryBreakDate = now
        lastNotifiedBreakType = nil
        lastNotifiedDate = nil
        startTimer()
        notifyDelegate()
    }

    /// Pause monitoring. Invalidates the timer.
    public func pause() {
        guard isMonitoring else { return }
        isMonitoring = false
        stopTimer()
        notifyDelegate()
    }

    /// Manually record that a break was taken.
    /// Resets the timer for the given break type (and all lower-priority types).
    public func recordBreak(_ breakType: BreakType) {
        let now = Date()
        switch breakType {
        case .mandatory:
            lastMandatoryBreakDate = now
            lastMacroBreakDate = now
            lastMicroBreakDate = now
        case .macro:
            lastMacroBreakDate = now
            lastMicroBreakDate = now
        case .micro:
            lastMicroBreakDate = now
        }
        lastBreakEndDate = now
        lastNotifiedBreakType = nil
        lastNotifiedDate = nil
        notifyDelegate()
    }

    /// Returns the current monitoring status snapshot.
    public func currentStatus() -> MonitoringStatus {
        let now = Date()

        let sinceLastBreak: TimeInterval
        let sinceMicro: TimeInterval
        let sinceMacro: TimeInterval
        let sinceMandatory: TimeInterval

        if isMonitoring {
            sinceLastBreak = now.timeIntervalSince(lastBreakEndDate)
            sinceMicro = now.timeIntervalSince(lastMicroBreakDate)
            sinceMacro = now.timeIntervalSince(lastMacroBreakDate)
            sinceMandatory = now.timeIntervalSince(lastMandatoryBreakDate)
        } else {
            sinceLastBreak = 0
            sinceMicro = 0
            sinceMacro = 0
            sinceMandatory = 0
        }

        // Find the next break that will trigger
        let nextBreak = findNextBreak(
            sinceMicro: sinceMicro,
            sinceMacro: sinceMacro,
            sinceMandatory: sinceMandatory
        )

        return MonitoringStatus(
            isMonitoring: isMonitoring,
            activityState: isMonitoring ? activityState : .active,
            activeTime: accumulatedActiveTime,
            sinceLastBreak: sinceLastBreak,
            sinceLastMicroBreak: sinceMicro,
            sinceLastMacroBreak: sinceMacro,
            sinceLastMandatoryBreak: sinceMandatory,
            nextBreakType: nextBreak?.type,
            timeUntilNextBreak: nextBreak?.timeRemaining ?? 0,
            reminderMode: reminderMode
        )
    }

    // MARK: - Polling (internal for testing)

    /// Called every `Constants.pollingInterval` seconds by the timer.
    /// Also callable directly in tests with a mock `IdleDetecting`.
    func poll() {
        guard isMonitoring else { return }

        let idleSeconds = idleDetector.secondsSinceLastEvent()
        let newState = ActivityState.from(idleSeconds: idleSeconds)

        // State transition: away -> active = natural break ended, reset counters
        if previousState == .away && newState == .active {
            recordBreak(.micro) // Natural break counts as at least a micro break
        }

        // Accumulate active time only when the user is active
        if newState == .active && previousState != .away {
            accumulatedActiveTime += Constants.pollingInterval
        }

        previousState = activityState
        activityState = newState

        // Check if any break is due (only when user is active)
        if newState == .active {
            checkBreakSchedule()
        }

        notifyDelegate()
    }

    // MARK: - Break Scheduling

    private func checkBreakSchedule() {
        let now = Date()
        let sinceMicro = now.timeIntervalSince(lastMicroBreakDate)
        let sinceMacro = now.timeIntervalSince(lastMacroBreakDate)
        let sinceMandatory = now.timeIntervalSince(lastMandatoryBreakDate)

        guard let dueBreak = BreakScheduler.breakDue(
            sinceLastMicroBreak: sinceMicro,
            sinceLastMacroBreak: sinceMacro,
            sinceLastMandatoryBreak: sinceMandatory
        ) else {
            return
        }

        // Don't re-notify for the same break type too quickly
        if let lastType = lastNotifiedBreakType,
           let lastDate = lastNotifiedDate,
           lastType == dueBreak,
           now.timeIntervalSince(lastDate) < Self.renotifyInterval {
            return
        }

        // Trigger notification
        let event = BreakEvent(breakType: dueBreak, triggeredAt: now)
        notificationService?.sendBreakReminder(for: event, mode: reminderMode)

        lastNotifiedBreakType = dueBreak
        lastNotifiedDate = now

        // Notify delegate about the break event
        delegate?.monitoringSessionDidTriggerBreak(event)
    }

    private func findNextBreak(
        sinceMicro: TimeInterval,
        sinceMacro: TimeInterval,
        sinceMandatory: TimeInterval
    ) -> (type: BreakType, timeRemaining: TimeInterval)? {
        let microRemaining = BreakScheduler.timeUntilBreak(.micro, sinceLastBreak: sinceMicro)
        let macroRemaining = BreakScheduler.timeUntilBreak(.macro, sinceLastBreak: sinceMacro)
        let mandatoryRemaining = BreakScheduler.timeUntilBreak(.mandatory, sinceLastBreak: sinceMandatory)

        // Find the soonest break
        var soonest: (type: BreakType, timeRemaining: TimeInterval)?

        for (type, remaining) in [
            (BreakType.micro, microRemaining),
            (.macro, macroRemaining),
            (.mandatory, mandatoryRemaining)
        ] {
            if let current = soonest {
                if remaining < current.timeRemaining {
                    soonest = (type, remaining)
                }
            } else {
                soonest = (type, remaining)
            }
        }

        return soonest
    }

    // MARK: - Private

    private func startTimer() {
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.pollingInterval,
            repeats: true
        ) { [weak self] _ in
            // Timer callback is on main thread (main RunLoop)
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func notifyDelegate() {
        delegate?.monitoringSessionDidUpdate(currentStatus())
    }
}
