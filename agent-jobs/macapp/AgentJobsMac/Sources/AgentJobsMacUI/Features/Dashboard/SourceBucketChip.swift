import SwiftUI
import AgentJobsCore

/// Single chip in the Dashboard's per-source summary strip.
/// Capsule with SF Symbol + display label + count. Three visual states:
///   - selected → accent background, accent foreground
///   - zero count → tertiary foreground (muted)
///   - default → primary foreground on subtle background
///
/// Tap toggles the bound `selection` (set to this bucket if not selected,
/// nil if it already is — second tap clears the filter per AC-F-06).
struct SourceBucketChip: View {
    let bucket: ServiceSource.Bucket
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: bucket.sfSymbol)
                    .imageScale(.small)
                    .foregroundStyle(iconStyle)
                Text(bucket.displayName)
                    .font(DesignTokens.Typography.caption)
                Text("\(count)")
                    .font(DesignTokens.Typography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.s)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(helpText)
        .accessibilityLabel("\(bucket.displayName), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var helpText: String {
        isSelected
            ? "Showing only \(bucket.displayName). Click to clear filter."
            : "Filter to \(bucket.displayName) services."
    }

    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.20) }
        if isHovered  { return Color.primary.opacity(0.06) }
        return Color.primary.opacity(0.03)
    }

    private var foreground: Color {
        if isSelected { return Color.accentColor }
        if count == 0 { return .secondary }
        return .primary
    }

    private var iconStyle: Color {
        if isSelected { return Color.accentColor }
        if count == 0 { return .secondary }
        return .secondary
    }
}
