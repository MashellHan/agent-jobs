import SwiftUI
import AgentJobsCore

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
    }
}

struct MenuBarPopoverView: View {
    @Environment(ServiceRegistryViewModel.self) private var registry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            summaryStrip
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.l) {
                    section(title: "Active Now", services: activeServices)
                    section(title: "Scheduled Soon", services: upcomingServices)
                }
                .padding(.vertical, DesignTokens.Spacing.s)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.tint)
            Text("Agent Jobs")
                .font(DesignTokens.Typography.heading)
            Spacer()
            Button { } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain)
                .help("Refresh now")
        }
        .padding(DesignTokens.Spacing.m)
    }

    private var summaryStrip: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            SummaryChip(icon: "flame.fill", label: "\(registry.summary.running) running",
                        color: DesignTokens.StatusColor.running)
            SummaryChip(icon: "clock.fill", label: "\(registry.summary.scheduled) scheduled",
                        color: DesignTokens.StatusColor.scheduled)
            if registry.summary.failed > 0 {
                SummaryChip(icon: "xmark.circle.fill", label: "\(registry.summary.failed) failed",
                            color: DesignTokens.StatusColor.failed)
            }
            Spacer()
            MemoryBadge(bytes: registry.summary.totalMemoryBytes)
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.vertical, DesignTokens.Spacing.s)
    }

    private var activeServices: [Service] {
        registry.services.filter { $0.status == .running }
    }

    private var upcomingServices: [Service] {
        registry.services
            .filter { $0.nextRun != nil && $0.status != .running }
            .sorted { ($0.nextRun ?? .distantFuture) < ($1.nextRun ?? .distantFuture) }
            .prefix(5).map { $0 }
    }

    @ViewBuilder
    private func section(title: String, services: [Service]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.m)
            if services.isEmpty {
                EmptyHintView(message: "Nothing here yet")
                    .padding(.horizontal, DesignTokens.Spacing.m)
            } else {
                ForEach(services) { svc in
                    ServiceRowCompact(service: svc)
                        .padding(.horizontal, DesignTokens.Spacing.s)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open Dashboard") {
                NSWorkspace.shared.open(URL(string: "agentjobsmac://dashboard")!)
            }
            .keyboardShortcut("d", modifiers: .command)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(DesignTokens.Spacing.m)
        .font(DesignTokens.Typography.caption)
    }
}

// MARK: - Reusable bits

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
    }
}

struct MemoryBadge: View {
    let bytes: UInt64
    var body: some View {
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "memorychip").imageScale(.small).foregroundStyle(.secondary)
            Text(formatted).font(DesignTokens.Typography.caption.monospacedDigit())
        }
    }
}

struct ServiceRowCompact: View {
    let service: Service
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            statusDot
            VStack(alignment: .leading, spacing: 1) {
                Text(service.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Text(service.schedule.humanDescription)
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
        .background(.thinMaterial.opacity(0), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.s))
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

struct EmptyHintView: View {
    let message: String
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "tray").foregroundStyle(.tertiary)
            Text(message).font(DesignTokens.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}
