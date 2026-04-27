import SwiftUI
import AgentJobsCore

/// Capsule status pill with SF Symbol prefix + accessibilityLabel.
/// Used by both dashboard table and inspector header.
///
/// The SF Symbol prefix carries the WCAG 1.4.1 "use of color" guarantee —
/// status is never communicated by hue alone.
struct StatusBadge: View {
    let status: ServiceStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .imageScale(.small)
            Text(status.rawValue.capitalized)
                .font(DesignTokens.Typography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, 2)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.rawValue)")
    }
    private var symbol: String {
        switch status {
        case .running:   return "circle.fill"
        case .scheduled: return "clock.fill"
        case .failed:    return "xmark.octagon.fill"
        case .paused:    return "pause.circle.fill"
        case .done:      return "checkmark.circle.fill"
        case .idle:      return "moon.zzz.fill"
        case .orphaned:  return "questionmark.circle.fill"
        case .unknown:   return "questionmark.circle"
        }
    }
    private var color: Color {
        switch status {
        case .running:   return DesignTokens.SemanticColor.statusRunning
        case .scheduled: return DesignTokens.SemanticColor.statusScheduled
        case .failed:    return DesignTokens.SemanticColor.statusFailed
        case .paused:    return DesignTokens.StatusColor.paused
        case .done:      return DesignTokens.StatusColor.done
        case .idle:      return DesignTokens.SemanticColor.statusIdle
        default:         return DesignTokens.StatusColor.unknown
        }
    }
}
