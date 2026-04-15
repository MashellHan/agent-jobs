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

    // MARK: - V5: Daily Tracking

    /// Total screen time today (never resets on break, only on daily reset).
    var totalScreenTimeToday: TimeInterval = 0

    /// Number of continuous-use sessions today.
    var sessionsCount: Int = 1

    /// Duration of the longest session today.
    var longestSessionSeconds: TimeInterval = 0

    /// When the current continuous-use session started.
    var currentSessionStart: Date = .now

    /// Screen time per hour (0-23) in seconds.
    var hourlyScreenTime: [Int: TimeInterval] = [:]

    /// How many breaks were recommended (incremented each time shouldNotify triggers).
    var breaksDue: Int = 0

    /// How many breaks were skipped (snoozed or dismissed without break).
    var breaksSkipped: Int = 0

    /// Current eye health score — updated periodically.
    var currentEyeHealthScore: Int = 100

    /// Current eye health grade — updated periodically.
    var currentEyeHealthGrade: String = "A+"

    /// Formatted total screen time today.
    var formattedTotalScreenTime: String {
        let totalSeconds = Int(totalScreenTimeToday)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

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
        // Track session duration before resetting
        let sessionDuration = continuousUseSeconds
        if sessionDuration > longestSessionSeconds {
            longestSessionSeconds = sessionDuration
        }

        let record = BreakRecord(timestamp: .now, durationSeconds: duration)
        todayBreakRecords.append(record)
        breaksTakenToday = todayBreakRecords.count
        lastBreakTime = .now
        continuousUseSeconds = 0
        hasNotifiedThisSession = false
        snoozedUntil = nil

        // Start a new session
        sessionsCount += 1
        currentSessionStart = .now
    }

    func incrementContinuousUse(by interval: TimeInterval) {
        continuousUseSeconds += interval
        totalScreenTimeToday += interval

        // Track hourly screen time
        let hour = Calendar.current.component(.hour, from: .now)
        hourlyScreenTime[hour, default: 0] += interval
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

        // V5: Reset daily tracking
        totalScreenTimeToday = 0
        sessionsCount = 1
        longestSessionSeconds = 0
        currentSessionStart = .now
        hourlyScreenTime = [:]
        breaksDue = 0
        breaksSkipped = 0
        currentEyeHealthScore = 100
        currentEyeHealthGrade = "A+"
    }

    /// Build a DailyUsageData snapshot from the current state.
    func buildDailyUsageData() -> DailyUsageData {
        var data = DailyUsageData(date: DailyUsageData.todayDateString())
        data.totalScreenTimeSeconds = totalScreenTimeToday
        data.breakRecords = todayBreakRecords
        data.sessionsCount = sessionsCount
        data.longestSessionSeconds = longestSessionSeconds

        // Calculate shortest session from break records
        // Each break marks the end of a session; session duration ~= time between breaks
        let sessionDurations = computeSessionDurations()
        data.shortestSessionSeconds = sessionDurations.min() ?? 0
        data.averageSessionSeconds = sessionDurations.isEmpty
            ? 0
            : sessionDurations.reduce(0, +) / Double(sessionDurations.count)

        data.breaksDue = breaksDue
        data.breaksTaken = breaksTakenToday
        data.breaksSkipped = breaksSkipped

        // Convert hourly screen time to String-keyed map for Codable
        for (hour, seconds) in hourlyScreenTime {
            data.hourlyScreenTime[String(hour)] = seconds
        }

        // Calculate night usage (after 22:00)
        let nightHours = [22, 23, 0, 1, 2, 3, 4, 5]
        data.nightUsageSeconds = nightHours.reduce(0.0) { total, hour in
            total + (hourlyScreenTime[hour] ?? 0)
        }

        return data
    }

    /// Compute individual session durations from break timestamps.
    private func computeSessionDurations() -> [TimeInterval] {
        guard !todayBreakRecords.isEmpty else { return [] }

        var durations: [TimeInterval] = []
        var previousTime = Calendar.current.startOfDay(for: .now)

        for record in todayBreakRecords.sorted(by: { $0.timestamp < $1.timestamp }) {
            let sessionDuration = record.timestamp.timeIntervalSince(previousTime)
            if sessionDuration > 0 {
                durations.append(sessionDuration)
            }
            previousTime = record.timestamp
        }

        return durations
    }
}
