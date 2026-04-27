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
    /// AC-F-14 / M05 T09: short per-bucket error string surfaced from
    /// `ServiceRegistryViewModel.errorByBucket`. When non-nil, the chip
    /// shows a small warning glyph and prepends the message to its
    /// help-tooltip text. `nil` ≡ "OK".
    var errorMessage: String? = nil
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
                    .fixedSize()
                Text("\(count)")
                    .font(DesignTokens.Typography.monoSmall)
                    .foregroundStyle(.secondary)
                if errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.small)
                        .foregroundStyle(DesignTokens.SemanticColor.statusFailed)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, DesignTokens.Spacing.s)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .opacity(zeroStateOpacity)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .help(helpText)
        .accessibilityLabel("\(bucket.displayName), \(count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// AC-F-11: 0-count chip is dimmed (≤ 0.6) so the user reads
    /// "nothing here" before they read the chip text.
    private var zeroStateOpacity: Double {
        (count == 0 && !isSelected) ? 0.55 : 1.0
    }

    private var helpText: String {
        let base: String
        if count == 0 {
            // T-008: surface the "why is this 0" explanation.
            base = bucket.emptyExplanation
        } else if isSelected {
            base = "Showing only \(bucket.displayName). Click to clear filter."
        } else {
            base = "Filter to \(bucket.displayName) services."
        }
        if let err = errorMessage, !err.isEmpty {
            return "\(err)\n\n\(base)"
        }
        return base
    }

    private var background: Color {
        if isSelected { return bucketTint.opacity(0.20) }
        if isHovered  { return bucketTint.opacity(0.10) }
        return Color.primary.opacity(0.03)
    }

    private var foreground: Color {
        if isSelected { return bucketTint }
        if count == 0 { return .secondary }
        return .primary
    }

    private var iconStyle: Color {
        if isSelected { return bucketTint }
        if count == 0 { return .secondary }
        return .secondary
    }

    /// M07 T-T01: per-bucket source tint pulled from
    /// `DesignTokens.SourceColor` — replaces the M06 accentColor-only
    /// selection styling with a bucket-coded palette.
    private var bucketTint: Color {
        switch bucket {
        case .registered:      return DesignTokens.SourceColor.registered
        case .claudeScheduled: return DesignTokens.SourceColor.claudeSched
        case .claudeSession:   return DesignTokens.SourceColor.claudeLoop
        case .launchd:         return DesignTokens.SourceColor.launchd
        case .liveProcess:     return DesignTokens.SourceColor.liveProc
        }
    }
}

// MARK: - T-008 zero-state explanations

private extension ServiceSource.Bucket {
    /// Tooltip body shown when the chip's count is 0 — explains where the
    /// provider looks so the user knows whether the empty state is
    /// configurable or expected. T-008 / AC-F-11.
    var emptyExplanation: String {
        switch self {
        case .registered:
            return "No registered services in agent-jobs.json."
        case .claudeScheduled:
            return "No claude-loop crons in ~/.claude/projects/."
        case .claudeSession:
            return "No active Claude sessions found."
        case .launchd:
            return "No matching launchd user agents."
        case .liveProcess:
            return "No live processes match the discovery filter."
        }
    }
}
