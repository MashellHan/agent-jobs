import SwiftUI
import AgentJobsCore

/// Trailing memorychip badge showing aggregate RSS across discovered services.
/// Always-visible (even at 0B) so its position in the strip is stable.
struct MemoryBadge: View {
    let bytes: UInt64
    var body: some View {
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "memorychip").imageScale(.small).foregroundStyle(.secondary)
            Text(formatted).font(DesignTokens.Typography.caption.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total memory: \(formatted)")
    }
}
