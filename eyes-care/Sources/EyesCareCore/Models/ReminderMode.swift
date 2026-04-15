import Foundation

/// Reminder notification modes
public enum ReminderMode: String, Codable, Sendable, CaseIterable {
    /// System notification banner only
    case gentle

    /// Notification + floating countdown window
    case normal

    /// Full-screen overlay with countdown
    case aggressive

    public var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .normal: return "Normal"
        case .aggressive: return "Aggressive"
        }
    }

    public var description: String {
        switch self {
        case .gentle: return "Notification banner only"
        case .normal: return "Notification + floating window"
        case .aggressive: return "Full-screen overlay"
        }
    }
}
