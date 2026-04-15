import Foundation

struct EyeCareTip: Identifiable, Codable {
    let id: String
    let category: TipCategory
    let title: String
    let content: String
    let source: String
    let icon: String

    enum TipCategory: String, Codable, CaseIterable {
        case hydration
        case exercise
        case posture
        case lighting
        case nutrition
        case rest
        case environment

        var displayName: String {
            switch self {
            case .hydration: return "Hydration"
            case .exercise: return "Exercise"
            case .posture: return "Posture"
            case .lighting: return "Lighting"
            case .nutrition: return "Nutrition"
            case .rest: return "Rest"
            case .environment: return "Environment"
            }
        }

        var icon: String {
            switch self {
            case .hydration: return "drop.fill"
            case .exercise: return "figure.walk"
            case .posture: return "figure.stand"
            case .lighting: return "sun.max.fill"
            case .nutrition: return "leaf.fill"
            case .rest: return "moon.fill"
            case .environment: return "wind"
            }
        }
    }
}
