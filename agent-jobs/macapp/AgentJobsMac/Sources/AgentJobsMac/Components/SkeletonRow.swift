import SwiftUI
import AgentJobsCore

/// Loading-state placeholder. Pulses subtly via opacity animation.
/// Honors Reduce Motion: pulse animation is gated by `accessibilityReduceMotion`.
struct SkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            Circle().fill(.quaternary).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 140, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 80, height: 8)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 48, height: 8)
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .opacity(pulse ? 0.5 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}
