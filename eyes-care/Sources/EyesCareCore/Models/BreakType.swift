import Foundation

/// Break types based on medical guidelines
public enum BreakType: String, Codable, Sendable {
    /// 20-20-20 rule: Every 20 minutes, look 20 feet away for 20 seconds
    /// Source: American Academy of Ophthalmology (AAO)
    case micro

    /// Hourly break: Every 60 minutes, rest for 5 minutes
    /// Source: OSHA recommendations
    case macro

    /// Mandatory break: Every 120 minutes, rest for 15 minutes
    /// Source: EU Screen Equipment Directive 90/270/EEC
    case mandatory

    public var interval: TimeInterval {
        switch self {
        case .micro: return 20 * 60       // 20 minutes
        case .macro: return 60 * 60       // 60 minutes
        case .mandatory: return 120 * 60  // 120 minutes
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .micro: return 20            // 20 seconds
        case .macro: return 5 * 60        // 5 minutes
        case .mandatory: return 15 * 60   // 15 minutes
        }
    }

    public var displayName: String {
        switch self {
        case .micro: return "Micro Break (20-20-20)"
        case .macro: return "Rest Break"
        case .mandatory: return "Mandatory Break"
        }
    }

    public var medicalSource: String {
        switch self {
        case .micro: return "AAO 20-20-20 Rule"
        case .macro: return "OSHA Recommendation"
        case .mandatory: return "EU Directive 90/270/EEC"
        }
    }
}
