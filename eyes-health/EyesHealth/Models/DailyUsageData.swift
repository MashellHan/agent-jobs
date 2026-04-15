import Foundation

struct DailyUsageData: Codable {
    let date: String  // "2026-04-15"
    var totalScreenTimeSeconds: TimeInterval
    var breakRecords: [BreakRecord]
    var sessionsCount: Int
    var longestSessionSeconds: TimeInterval
    var shortestSessionSeconds: TimeInterval
    var averageSessionSeconds: TimeInterval

    // Break compliance
    var breaksDue: Int
    var breaksTaken: Int
    var breaksSkipped: Int

    // Time distribution
    var hourlyScreenTime: [String: TimeInterval]  // "0"-"23" -> seconds (String keys for Codable)
    var nightUsageSeconds: TimeInterval  // usage after 22:00

    init(date: String) {
        self.date = date
        self.totalScreenTimeSeconds = 0
        self.breakRecords = []
        self.sessionsCount = 0
        self.longestSessionSeconds = 0
        self.shortestSessionSeconds = .infinity
        self.averageSessionSeconds = 0
        self.breaksDue = 0
        self.breaksTaken = 0
        self.breaksSkipped = 0
        self.hourlyScreenTime = [:]
        self.nightUsageSeconds = 0
    }

    // MARK: - Convenience

    /// Date string for today in "yyyy-MM-dd" format.
    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Human-readable date from the stored date string.
    var displayDate: String {
        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let parsed = inFormatter.date(from: date) else { return date }

        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "MMMM d, yyyy"
        return outFormatter.string(from: parsed)
    }

    /// Hourly screen time keyed by integer hour (0-23).
    func screenTime(forHour hour: Int) -> TimeInterval {
        hourlyScreenTime[String(hour)] ?? 0
    }

    mutating func addScreenTime(_ seconds: TimeInterval, forHour hour: Int) {
        let key = String(hour)
        let existing = hourlyScreenTime[key] ?? 0
        hourlyScreenTime[key] = existing + seconds
    }

    /// Break compliance percentage (0-100).
    var breakCompliancePercent: Int {
        guard breaksDue > 0 else { return 100 }
        return min(100, (breaksTaken * 100) / breaksDue)
    }

    /// Recalculate derived session stats from break records.
    mutating func recalculateSessionStats() {
        guard !breakRecords.isEmpty else { return }

        let durations = breakRecords.compactMap { record -> TimeInterval? in
            record.durationSeconds > 0 ? record.durationSeconds : nil
        }

        // Sessions count is one more than breaks taken (first session + one per break)
        sessionsCount = breakRecords.count + 1

        if let longest = durations.max() {
            longestSessionSeconds = longest
        }
        if let shortest = durations.min() {
            shortestSessionSeconds = shortest
        }
        if !durations.isEmpty {
            averageSessionSeconds = durations.reduce(0, +) / Double(durations.count)
        }
    }
}
