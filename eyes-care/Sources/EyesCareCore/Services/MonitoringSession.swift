import Foundation

/// Orchestrates idle monitoring, state transitions, and time tracking.
///
/// `MonitoringSession` is the core engine of EyesCare. It:
/// 1. Polls an `IdleDetecting` source every `Constants.pollingInterval` seconds
/// 2. Derives `ActivityState` from the idle time
/// 3. Tracks cumulative active time and time since last break
/// 4. Notifies its `delegate` with a `MonitoringStatus` snapshot on every tick
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

    // MARK: - State

    private(set) var isMonitoring = false
    private var activityState: ActivityState = .active
    private var accumulatedActiveTime: TimeInterval = 0
    private var lastBreakEndDate: Date = Date()
    private var previousState: ActivityState = .active

    // MARK: - Timer

    private var pollTimer: Timer?

    // MARK: - Delegate

    public weak var delegate: (any MonitoringSessionDelegate)?

    // MARK: - Init

    public init(idleDetector: any IdleDetecting = CGEventSourceIdleDetector()) {
        self.idleDetector = idleDetector
    }

    // MARK: - Public API

    /// Start monitoring. Creates a repeating timer.
    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activityState = .active
        previousState = .active
        accumulatedActiveTime = 0
        lastBreakEndDate = Date()
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

    /// Returns the current monitoring status snapshot.
    public func currentStatus() -> MonitoringStatus {
        let sinceLastBreak: TimeInterval
        if isMonitoring {
            sinceLastBreak = Date().timeIntervalSince(lastBreakEndDate)
        } else {
            sinceLastBreak = 0
        }

        return MonitoringStatus(
            isMonitoring: isMonitoring,
            activityState: isMonitoring ? activityState : .active,
            activeTime: accumulatedActiveTime,
            sinceLastBreak: sinceLastBreak
        )
    }

    // MARK: - Polling (internal for testing)

    /// Called every `Constants.pollingInterval` seconds by the timer.
    /// Also callable directly in tests with a mock `IdleDetecting`.
    func poll() {
        guard isMonitoring else { return }

        let idleSeconds = idleDetector.secondsSinceLastEvent()
        let newState = ActivityState.from(idleSeconds: idleSeconds)

        // State transition: away -> active = break ended, reset counters
        if previousState == .away && newState == .active {
            lastBreakEndDate = Date()
            // Don't accumulate active time for this tick — first tick back
        }

        // Accumulate active time only when the user is active
        if newState == .active && previousState != .away {
            accumulatedActiveTime += Constants.pollingInterval
        }

        previousState = activityState
        activityState = newState

        notifyDelegate()
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
