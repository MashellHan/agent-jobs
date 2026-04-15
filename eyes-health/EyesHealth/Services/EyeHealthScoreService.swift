import Foundation

struct EyeHealthScore {
    let totalScore: Int       // 0-100
    let breakCompliance: Int  // 0-40 points
    let sessionQuality: Int   // 0-25 points
    let timeDistribution: Int // 0-15 points
    let totalExposure: Int    // 0-10 points
    let nightPenalty: Int     // 0 to -10 points
    let grade: String         // A+, A, B+, B, C, D, F
    let summary: String       // "Excellent eye care today!"
}

final class EyeHealthScoreService {

    func calculateScore(from data: DailyUsageData) -> EyeHealthScore {
        let breakCompliance = calculateBreakCompliance(data)
        let sessionQuality = calculateSessionQuality(data)
        let timeDistribution = calculateTimeDistribution(data)
        let totalExposure = calculateTotalExposure(data)
        let nightPenalty = calculateNightPenalty(data)

        let rawScore = breakCompliance + sessionQuality + timeDistribution + totalExposure + nightPenalty
        let totalScore = max(0, min(100, rawScore))
        let grade = gradeFor(score: totalScore)
        let summary = summaryFor(score: totalScore, grade: grade)

        return EyeHealthScore(
            totalScore: totalScore,
            breakCompliance: breakCompliance,
            sessionQuality: sessionQuality,
            timeDistribution: timeDistribution,
            totalExposure: totalExposure,
            nightPenalty: nightPenalty,
            grade: grade,
            summary: summary
        )
    }

    // MARK: - Break Compliance (40 pts)

    /// breaksTaken / breaksDue * 40
    /// If no breaks were due (very short usage), give full points.
    private func calculateBreakCompliance(_ data: DailyUsageData) -> Int {
        guard data.breaksDue > 0 else { return 40 }
        let ratio = Double(data.breaksTaken) / Double(data.breaksDue)
        return Int(min(1.0, ratio) * 40.0)
    }

    // MARK: - Session Quality (25 pts)

    /// avg session < 20min = 25, < 30min = 15, < 45min = 10, else 0
    private func calculateSessionQuality(_ data: DailyUsageData) -> Int {
        // If no meaningful screen time, give full points
        guard data.totalScreenTimeSeconds > 60 else { return 25 }
        guard data.sessionsCount > 0 else { return 25 }

        let avgSessionMinutes = (data.totalScreenTimeSeconds / Double(data.sessionsCount)) / 60.0

        switch avgSessionMinutes {
        case ..<20: return 25
        case 20..<30: return 15
        case 30..<45: return 10
        default: return 0
        }
    }

    // MARK: - Time Distribution (15 pts)

    /// Measures how evenly breaks are spread across active hours.
    /// More spread out = higher score.
    private func calculateTimeDistribution(_ data: DailyUsageData) -> Int {
        // Count hours with meaningful screen time (> 5 minutes)
        let activeHours = (0...23).filter { data.screenTime(forHour: $0) > 5 * 60 }
        guard activeHours.count >= 2 else { return 15 }  // Short usage = full points

        // Count hours with breaks
        let breakHours = Set(data.breakRecords.map {
            Calendar.current.component(.hour, from: $0.timestamp)
        })

        let activeWithBreaks = activeHours.filter { breakHours.contains($0) }.count
        let coverage = Double(activeWithBreaks) / Double(activeHours.count)

        return Int(coverage * 15.0)
    }

    // MARK: - Total Exposure (10 pts)

    /// < 4h = 10, < 6h = 8, < 8h = 5, > 8h = 2
    private func calculateTotalExposure(_ data: DailyUsageData) -> Int {
        let hours = data.totalScreenTimeSeconds / 3600.0

        switch hours {
        case ..<4: return 10
        case 4..<6: return 8
        case 6..<8: return 5
        default: return 2
        }
    }

    // MARK: - Night Penalty (0 to -10)

    /// -2 per hour of usage after 22:00
    private func calculateNightPenalty(_ data: DailyUsageData) -> Int {
        let nightHours = data.nightUsageSeconds / 3600.0
        let penalty = Int(nightHours * -2.0)
        return max(-10, penalty)
    }

    // MARK: - Grade

    private func gradeFor(score: Int) -> String {
        switch score {
        case 90...: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B+"
        case 60..<70: return "B"
        case 50..<60: return "C"
        case 40..<50: return "D"
        default: return "F"
        }
    }

    // MARK: - Summary

    private func summaryFor(score: Int, grade: String) -> String {
        switch score {
        case 90...:
            return "Excellent eye care today! Your eyes are well-rested."
        case 80..<90:
            return "Great job today! You took most of your recommended breaks."
        case 70..<80:
            return "Good effort! A few more breaks would improve your score."
        case 60..<70:
            return "Fair performance. Try to take more regular breaks tomorrow."
        case 50..<60:
            return "Your eyes need more rest. Consider shorter sessions."
        case 40..<50:
            return "Below average. Please prioritize eye breaks tomorrow."
        default:
            return "Your eyes are strained. Please take frequent breaks!"
        }
    }
}
