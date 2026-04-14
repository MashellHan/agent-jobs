import SwiftUI
import Observation

@Observable
final class AppState {
    var continuousUseSeconds: TimeInterval = 0
    var breaksTakenToday: Int = 0
    var lastBreakTime: Date? = nil
    var isMonitoring: Bool = false
    var notificationPermissionGranted: Bool = false

    /// Prevents repeated notifications for the same continuous-use session.
    /// Set to true when a notification fires; reset to false when a break is recorded.
    var hasNotifiedThisSession: Bool = false

    /// When set, notifications are suppressed until this date passes.
    /// The continuous-use counter keeps incrementing so total screen time is accurate.
    var snoozedUntil: Date? = nil

    /// Current reminder intensity level, persisted to UserDefaults.
    var reminderMode: ReminderMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Constants.reminderModeKey),
                  let mode = ReminderMode(rawValue: raw) else {
                return .gentle
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.reminderModeKey)
        }
    }

    private(set) var todayBreakRecords: [BreakRecord] = []

    var statusColor: StatusColor {
        switch continuousUseSeconds {
        case 0..<Constants.yellowThreshold: return .green
        case Constants.yellowThreshold..<Constants.redThreshold: return .yellow
        default: return .red
        }
    }

    var formattedTimeSinceBreak: String {
        let totalSeconds = Int(continuousUseSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var shouldNotify: Bool {
        guard continuousUseSeconds >= Constants.breakIntervalSeconds else { return false }
        guard !hasNotifiedThisSession else { return false }

        // Suppress during active snooze
        if let snoozedUntil, snoozedUntil > .now {
            return false
        }

        return true
    }

    func recordBreak(duration: TimeInterval = 0) {
        let record = BreakRecord(timestamp: .now, durationSeconds: duration)
        todayBreakRecords.append(record)
        breaksTakenToday = todayBreakRecords.count
        lastBreakTime = .now
        continuousUseSeconds = 0
        hasNotifiedThisSession = false
        snoozedUntil = nil
    }

    func incrementContinuousUse(by interval: TimeInterval) {
        continuousUseSeconds += interval
    }

    func resetContinuousUse() {
        continuousUseSeconds = 0
    }

    func resetDaily() {
        todayBreakRecords = []
        breaksTakenToday = 0
        continuousUseSeconds = 0
        lastBreakTime = nil
        hasNotifiedThisSession = false
        snoozedUntil = nil
    }
}
