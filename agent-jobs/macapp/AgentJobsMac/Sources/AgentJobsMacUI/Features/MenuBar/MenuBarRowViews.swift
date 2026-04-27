import SwiftUI
import AgentJobsCore

/// Section header used by `MenuBarPopoverView` above each status group.
/// Uppercase caption + count chip — Things 3 / Linear flavor.
/// AC-F-05 / AC-D-02.
struct PopoverGroupHeader: View {
    let group: PopoverGrouping.StatusGroup
    let count: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(group.displayName)
                .font(DesignTokens.Typography.caption.smallCaps())
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Text("\(count)")
                .font(DesignTokens.Typography.monoSmall)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.top, DesignTokens.Spacing.xs)
    }
}

/// Rich popover row — primary surface for an active/scheduled/failed
/// service. Status pill on the left, friendly title + 1-line summary in
/// the middle, conditional trailing slot on the right (Retry button when
/// `.failed`, otherwise the CPU/RSS metrics cluster).
///
/// AC-F-06 (3 fields), AC-F-12 (retry on failed).
struct MenuBarRichRow: View {
    let service: Service
    /// Set by parent to a non-nil closure ONLY on `.failed` rows. The
    /// closure is invoked when the user taps the trailing Retry button.
    var onRetry: ((Service) -> Void)? = nil

    @State private var isHovered = false
    private var formatted: FormattedService { ServiceFormatter.format(service) }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.s) {
            statusPill
            VStack(alignment: .leading, spacing: 1) {
                Text(formatted.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Text(formatted.summary)
                    .font(DesignTokens.Typography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignTokens.Spacing.s)
            trailingSlot
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .background(
            isHovered ? Color.primary.opacity(0.06) : .clear,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.s)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatted.title), \(service.status.rawValue), \(formatted.summary)")
    }

    /// Capsule-shaped colored pill carrying the status text. Uppercase
    /// to match Things-style.
    private var statusPill: some View {
        Text(service.status.rawValue.uppercased())
            .font(DesignTokens.Typography.caption.smallCaps().weight(.semibold))
            .foregroundStyle(pillForeground)
            .padding(.horizontal, DesignTokens.Spacing.s)
            .padding(.vertical, 2)
            .background(pillBackground, in: Capsule())
            .fixedSize()
    }

    private var pillBackground: Color {
        statusColor.opacity(0.18)
    }

    private var pillForeground: Color {
        statusColor
    }

    private var statusColor: Color {
        switch service.status {
        case .running:   return DesignTokens.StatusColor.running
        case .scheduled: return DesignTokens.StatusColor.scheduled
        case .failed:    return DesignTokens.StatusColor.failed
        case .paused:    return DesignTokens.StatusColor.paused
        case .done:      return DesignTokens.StatusColor.done
        default:         return DesignTokens.StatusColor.unknown
        }
    }

    @ViewBuilder
    private var trailingSlot: some View {
        if service.status == .failed, let retry = onRetry {
            RetryAffordance { retry(service) }
        } else if let m = service.metrics {
            HStack(spacing: DesignTokens.Spacing.s) {
                Text(m.cpuPercentClampedFormatted)
                    .font(DesignTokens.Typography.monoSmall.monospacedDigit())
                    .foregroundStyle(DesignTokens.ResourceColor.cpu(m.cpuPercent))
                Text(m.memoryRSSFormatted)
                    .font(DesignTokens.Typography.monoSmall.monospacedDigit())
                    .foregroundStyle(DesignTokens.ResourceColor.memory(m.memoryRSS))
            }
            .fixedSize()
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
                .font(DesignTokens.Typography.monoSmall)
        }
    }
}
