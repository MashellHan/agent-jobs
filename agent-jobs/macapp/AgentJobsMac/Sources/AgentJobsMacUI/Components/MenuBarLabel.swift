import SwiftUI
import AgentJobsCore

/// Compact menubar status icon: dot showing running state, count badge,
/// and a triangle when failures are present. Sits inside `MenuBarExtra`'s
/// `label:` slot so the user sees system status at a glance.
struct MenuBarLabel: View {
    let state: MenuBarSummary

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: state.running > 0 ? "circle.fill" : "circle")
                .foregroundStyle(state.running > 0 ? DesignTokens.StatusColor.running : .secondary)
                .imageScale(.small)
            if state.running > 0 {
                Text("\(state.running)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            if state.failed > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.StatusColor.failed)
                    .imageScale(.small)
            }
        }
        // M05 T06: lets MenuBarInteraction find the bundle's status item
        // via the Accessibility tree (`AXExtrasMenuBar` walk).
        .accessibilityIdentifier("agent-jobs.menubar")
        .accessibilityLabel("Agent Jobs menu bar status")
    }
}
