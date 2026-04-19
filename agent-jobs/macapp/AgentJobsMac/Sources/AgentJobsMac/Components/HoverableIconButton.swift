import SwiftUI
import AgentJobsCore

/// Borderless icon button with a hover-revealed background. Replaces ad-hoc
/// `.buttonStyle(.plain)` icon buttons that lacked discoverability.
struct HoverableIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .padding(DesignTokens.Spacing.xs)
                .background(
                    isHovered ? Color.primary.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.s)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
