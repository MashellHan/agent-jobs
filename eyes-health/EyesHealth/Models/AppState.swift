import SwiftUI
import Observation

@Observable
final class AppState {
    var continuousUseSeconds: TimeInterval = 0
    var breaksTakenToday: Int = 0
    var lastBreakTime: Date? = nil
    var isMonitoring: Bool = false
    var notificationPermissionGranted: Bool = false

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
        continuousUseSeconds >= Constants.breakIntervalSeconds
    }

    func recordBreak(duration: TimeInterval = 0) {
        let record = BreakRecord(timestamp: .now, durationSeconds: duration)
        todayBreakRecords.append(record)
        breaksTakenToday = todayBreakRecords.count
        lastBreakTime = .now
        continuousUseSeconds = 0
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
    }
}
