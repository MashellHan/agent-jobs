import SwiftUI
import AgentJobsCore

/// Single-row dense representation of a Service used inside the menubar
/// popover sections. Hover-highlights, shows a status dot + friendly title +
/// 1-line summary + (cpu, memory) cluster.
///
/// M05 T09: title + secondary text now flow through `ServiceFormatter` so
/// the user sees "iMessage" / "every 15m" instead of the raw
/// `application.com.apple.MobileSMS.115xxx` label.
struct ServiceRowCompact: View {
    let service: Service
    @State private var isHovered = false
    private var formatted: FormattedService { ServiceFormatter.format(service) }
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            statusDot
            VStack(alignment: .leading, spacing: 1) {
                Text(formatted.title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Text(formatted.summary)
                    .font(DesignTokens.Typography.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            metricsCluster
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

    private var statusDot: some View {
        Circle()
            .fill(color(for: service.status))
            .frame(width: 8, height: 8)
    }

    @ViewBuilder
    private var metricsCluster: some View {
        if let m = service.metrics {
            HStack(spacing: DesignTokens.Spacing.s) {
                Text(m.cpuPercentClampedFormatted)
                    .font(DesignTokens.Typography.monoSmall.monospacedDigit())
                    .foregroundStyle(DesignTokens.ResourceColor.cpu(m.cpuPercent))
                Text(m.memoryRSSFormatted)
                    .font(DesignTokens.Typography.monoSmall.monospacedDigit())
                    .foregroundStyle(DesignTokens.ResourceColor.memory(m.memoryRSS))
            }
        } else {
            Text("—").foregroundStyle(.tertiary).font(DesignTokens.Typography.monoSmall)
        }
    }

    private func color(for status: ServiceStatus) -> Color {
        switch status {
        case .running:   return DesignTokens.StatusColor.running
        case .scheduled: return DesignTokens.StatusColor.scheduled
        case .failed:    return DesignTokens.StatusColor.failed
        case .paused:    return DesignTokens.StatusColor.paused
        case .done:      return DesignTokens.StatusColor.done
        default:         return DesignTokens.StatusColor.unknown
        }
    }
}
