import SwiftUI
import AgentJobsCore

/// Capsule-shaped chip for compact summary metrics ("3 running", "2 failed").
/// Color-tinted background ties the chip back to its semantic status.
struct SummaryChip: View {
    let icon: String
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon).foregroundStyle(color).imageScale(.small)
            Text(label).font(DesignTokens.Typography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}
