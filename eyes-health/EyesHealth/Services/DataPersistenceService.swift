import Foundation

final class DataPersistenceService {
    private let dataDirectory: URL
    private let reportsDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        dataDirectory = appSupport
            .appendingPathComponent("EyesHealth")
            .appendingPathComponent("data")
        reportsDirectory = appSupport
            .appendingPathComponent("EyesHealth")
            .appendingPathComponent("reports")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()

        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Setup

    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        for dir in [dataDirectory, reportsDirectory] {
            if !fm.fileExists(atPath: dir.path) {
                do {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    print("[DataPersistence] Failed to create directory \(dir.path): \(error)")
                }
            }
        }
    }

    // MARK: - Data File Paths

    private func dataFileURL(for dateString: String) -> URL {
        dataDirectory.appendingPathComponent("\(dateString).json")
    }

    private func reportFileURL(for dateString: String) -> URL {
        reportsDirectory.appendingPathComponent("\(dateString)-eye-health-report.md")
    }

    // MARK: - Save / Load Daily Data

    func saveDailyData(_ data: DailyUsageData) {
        let url = dataFileURL(for: data.date)
        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: url, options: .atomic)
        } catch {
            print("[DataPersistence] Failed to save daily data: \(error)")
        }
    }

    func loadTodayData() -> DailyUsageData? {
        let today = DailyUsageData.todayDateString()
        return loadData(for: today)
    }

    func loadData(for dateString: String) -> DailyUsageData? {
        let url = dataFileURL(for: dateString)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let jsonData = try Data(contentsOf: url)
            return try decoder.decode(DailyUsageData.self, from: jsonData)
        } catch {
            print("[DataPersistence] Failed to load data for \(dateString): \(error)")
            return nil
        }
    }

    func loadData(for date: Date) -> DailyUsageData? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return loadData(for: formatter.string(from: date))
    }

    // MARK: - Report Generation

    func generateDailyReport(from data: DailyUsageData, score: EyeHealthScore) -> String {
        var lines: [String] = []

        lines.append("# Eye Health Report \u{2014} \(data.displayDate)")
        lines.append("")
        lines.append("## Score: \(score.totalScore)/100 (\(score.grade))")
        lines.append(score.summary)
        lines.append("")

        // Summary table
        lines.append("## Summary")
        lines.append("| Metric | Value |")
        lines.append("|--------|-------|")
        lines.append("| Total Screen Time | \(formatDuration(data.totalScreenTimeSeconds)) |")
        lines.append("| Breaks Taken | \(data.breaksTaken) |")
        lines.append("| Breaks Recommended | \(data.breaksDue) |")
        lines.append("| Break Compliance | \(data.breakCompliancePercent)% |")
        lines.append("| Sessions | \(data.sessionsCount) |")
        lines.append("| Longest Session | \(formatDuration(data.longestSessionSeconds)) |")

        let avgSession = data.averageSessionSeconds.isFinite ? data.averageSessionSeconds : 0
        lines.append("| Average Session | \(formatDuration(avgSession)) |")
        lines.append("")

        // Hourly screen time bar chart
        lines.append("## Hourly Screen Time")
        lines.append("```")
        for hour in 0...23 {
            let seconds = data.screenTime(forHour: hour)
            guard seconds > 0 else { continue }

            let minutes = Int(seconds / 60)
            let barLength = max(1, minutes / 5) // each block = ~5 minutes
            let bar = String(repeating: "\u{2588}", count: min(barLength, 30))
            let hourLabel = String(format: "%02d", hour)

            var suffix = "\(minutes)m"
            if hour == 12, minutes < 30 {
                suffix += " (lunch break!)"
            }

            lines.append("\(hourLabel): \(bar) \(suffix)")
        }
        lines.append("```")
        lines.append("")

        // Score breakdown
        lines.append("## Score Breakdown")
        lines.append("- Break Compliance: \(score.breakCompliance)/40")
        lines.append("- Session Quality: \(score.sessionQuality)/25")
        lines.append("- Time Distribution: \(score.timeDistribution)/15")
        lines.append("- Total Exposure: \(score.totalExposure)/10")
        if score.nightPenalty < 0 {
            lines.append("- Night Penalty: \(score.nightPenalty)")
        }
        lines.append("- **Total: \(score.totalScore)/100**")
        lines.append("")

        // Tips
        lines.append("## Tips for Tomorrow")
        lines.append(generateTips(from: data, score: score))
        lines.append("")

        lines.append("---")
        lines.append("*Generated by EyesHealth v5.0*")

        return lines.joined(separator: "\n")
    }

    func saveDailyReport(_ report: String, for dateString: String) {
        let url = reportFileURL(for: dateString)
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            print("[DataPersistence] Report saved: \(url.path)")
        } catch {
            print("[DataPersistence] Failed to save report: \(error)")
        }
    }

    /// Returns the file URL for today's report (to open in default app).
    func todayReportURL() -> URL {
        let today = DailyUsageData.todayDateString()
        return reportFileURL(for: today)
    }

    /// Returns the reports directory URL (to open in Finder).
    var reportsDirectoryURL: URL {
        reportsDirectory
    }

    // MARK: - Private Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func generateTips(from data: DailyUsageData, score: EyeHealthScore) -> String {
        var tips: [String] = []

        if data.averageSessionSeconds > 20 * 60 {
            tips.append("- Try to keep sessions under 20 minutes")
        }

        if data.breakCompliancePercent < 80 {
            tips.append("- Take more regular breaks \u{2014} your compliance was \(data.breakCompliancePercent)%")
        }

        // Find gaps in breaks (hours with high usage but no breaks nearby)
        let highUsageHours = (0...23).filter { data.screenTime(forHour: $0) > 50 * 60 }
        if let peakHour = highUsageHours.first {
            let nextHour = (peakHour + 1) % 24
            tips.append("- Consider taking a break between \(peakHour):00-\(nextHour):00")
        }

        if data.nightUsageSeconds < 30 * 60 {
            tips.append("- Great job avoiding late-night screen time!")
        } else {
            let nightMinutes = Int(data.nightUsageSeconds / 60)
            tips.append("- Try to reduce evening screen time (\(nightMinutes)m after 10 PM)")
        }

        if score.totalScore >= 80 {
            tips.append("- Keep up the excellent eye care habits!")
        }

        if tips.isEmpty {
            tips.append("- You're doing great! Keep maintaining good eye health habits.")
        }

        return tips.joined(separator: "\n")
    }
}
