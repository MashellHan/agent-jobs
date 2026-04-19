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
            if case .error(let msg) = registry.phase {
                Divider()
                ErrorBanner(message: msg) { Task { await registry.refresh() } }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.l) {
                    section(title: "Active Now", services: activeServices,
                            emptyMessage: "No services running right now.")
                    section(title: "Scheduled Soon", services: upcomingServices,
                            emptyMessage: "Nothing scheduled in the next hour.")
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
            AutoRefreshIndicator(lastRefresh: registry.lastRefresh,
                                 intervalSeconds: registry.refreshIntervalSeconds)
            HoverableIconButton(systemImage: "arrow.clockwise", help: "Refresh now") {
                Task { await registry.refresh() }
            }
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
        registry.services.filter { $0.status == .running }.prefix(8).map { $0 }
    }

    private var upcomingServices: [Service] {
        registry.services
            .filter { $0.nextRun != nil && $0.status != .running }
            .sorted { ($0.nextRun ?? .distantFuture) < ($1.nextRun ?? .distantFuture) }
            .prefix(8).map { $0 }
    }

    @ViewBuilder
    private func section(title: String, services: [Service], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignTokens.Spacing.m)
            if registry.phase == .loading && services.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRow().padding(.horizontal, DesignTokens.Spacing.s)
                }
            } else if services.isEmpty {
                EmptyHintView(message: emptyMessage)
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
                openWindow(id: "dashboard")
            }
            .keyboardShortcut("d", modifiers: .command)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(DesignTokens.Spacing.m)
        .font(DesignTokens.Typography.caption)
    }
    @Environment(\.openWindow) private var openWindow
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total memory: \(formatted)")
    }
}

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

/// Compact error strip rendered between the summary and the service list when
/// the registry's `LoadPhase == .error`. Offers a one-tap retry so refresh
/// failures are recoverable instead of silent.
struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.StatusColor.failed)
            VStack(alignment: .leading, spacing: 1) {
                Text("Refresh failed")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry", action: retry)
                .buttonStyle(.borderless)
                .font(DesignTokens.Typography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.vertical, DesignTokens.Spacing.s)
        .background(DesignTokens.StatusColor.failed.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Refresh failed: \(message)")
    }
}

struct ServiceRowCompact: View {
    let service: Service
    @State private var isHovered = false
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
        .background(
            isHovered ? Color.primary.opacity(0.06) : .clear,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.s)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(service.name), \(service.status.rawValue), \(service.schedule.humanDescription)")
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

/// Loading-state placeholder. Pulses subtly via `.redacted(reason: .placeholder)`.
/// Honors Reduce Motion: pulse opacity animation is gated.
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
