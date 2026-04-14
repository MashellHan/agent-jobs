import SwiftUI

// MARK: - Reminder Mode

enum ReminderMode: String, CaseIterable, Codable {
    case gentle     // Notification only
    case normal     // Notification + floating mini window with countdown
    case aggressive // Full-screen overlay with countdown (V3)

    var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .normal: return "Normal"
        case .aggressive: return "Aggressive"
        }
    }

    var description: String {
        switch self {
        case .gentle: return "Notification only"
        case .normal: return "Notification + floating window"
        case .aggressive: return "Full-screen overlay (coming soon)"
        }
    }

    /// Whether this mode is available in the current version.
    var isAvailable: Bool {
        self != .aggressive
    }
}

// MARK: - Constants

enum Constants {
    static let pollingInterval: TimeInterval = 5
    static let breakIntervalSeconds: TimeInterval = 20 * 60 // 20 min
    static let naturalBreakThreshold: TimeInterval = 2 * 60 // 2 min idle = break
    static let snoozeInterval: TimeInterval = 5 * 60 // 5 min snooze
    static let idleThreshold: TimeInterval = 30 // 30s = considered idle

    static let yellowThreshold: TimeInterval = 10 * 60 // 10 min
    static let redThreshold: TimeInterval = 20 * 60 // 20 min

    static let notificationTitle = "Time for an Eye Break! 👀"
    static let notificationBody = "You've been looking at the screen for 20 minutes.\nLook at something 20 feet (~6m) away for 20 seconds."
    static let notificationCategoryID = "BREAK_REMINDER"
    static let snoozeActionID = "SNOOZE_5"
    static let takeBreakActionID = "TAKE_BREAK"

    // Floating break window
    static let floatingWindowWidth: CGFloat = 200
    static let floatingWindowHeight: CGFloat = 120
    static let breakCountdownSeconds: Int = 20

    // UserDefaults keys
    static let reminderModeKey = "reminderMode"
}

enum StatusColor {
    case green, yellow, red

    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var systemName: String {
        switch self {
        case .green, .yellow: return "eye.fill"
        case .red: return "eye"
        }
    }

    var message: String {
        switch self {
        case .green: return "Eyes are resting well"
        case .yellow: return "Consider taking a break soon"
        case .red: return "Break overdue — rest your eyes!"
        }
    }
}
