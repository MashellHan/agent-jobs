import SwiftUI
import AppKit
import AgentJobsCore

/// The menubar popover. Aggregates the discovery view model into a 480pt
/// layout: header → summary strip → optional error banner →
/// scrollable status-grouped list → footer.
///
/// M06 / T-002: width raised 360 → 480 (own its own .frame so the harness
/// and production stay in sync); rows are now `MenuBarRichRow` (status
/// pill + title + summary + conditional trailing slot); list is grouped
/// by status via `PopoverGrouping`.
/// M06 / T-016: failed rows expose `RetryAffordance` (calls
/// `registry.refresh()` — global refresh is the M06 retry semantic per
/// architecture §3.6).
struct MenuBarPopoverView: View {
    @Environment(ServiceRegistryViewModel.self) private var registry
    @Environment(\.openWindow) private var openWindow

    /// AC-F-04: ≥ 480. Owned here so the popover width is the same in
    /// production (`MenuBarExtra` content) and the visual harness.
    static let popoverWidth: CGFloat = 480

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
                    if registry.phase == .loading && registry.services.isEmpty {
                        loadingSkeleton
                    } else if registry.services.isEmpty {
                        EmptyHintView(message: "No services discovered yet.")
                            .padding(.horizontal, DesignTokens.Spacing.m)
                    } else {
                        ForEach(groupedServices, id: \.group.id) { entry in
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                PopoverGroupHeader(group: entry.group, count: entry.services.count)
                                ForEach(entry.services) { svc in
                                    MenuBarRichRow(
                                        service: svc,
                                        onRetry: retryClosure(for: svc)
                                    )
                                    .padding(.horizontal, DesignTokens.Spacing.s)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.s)
            }
            Divider()
            footer
        }
        .frame(width: Self.popoverWidth)
        // design-003 Top-3 #1 (D-popover-material): blends popover with the
        // desktop wallpaper instead of rendering against the OS default flat
        // background — matches Raycast / Things and adapts to dark mode for
        // free.
        .background(.regularMaterial)
        .task {
            // M04 AC-F-07: tells AppKitVisibilityProvider the popover
            // is on-screen. Cleared in .onDisappear.
            registry.popoverOpen = true
        }
        .onDisappear { registry.popoverOpen = false }
    }

    /// AC-F-12 / T-016: only `.failed` rows surface a Retry closure. M06
    /// retry semantic is "trigger a global refresh" (per architecture §3.6
    /// — per-service retry is out of scope).
    private func retryClosure(for svc: Service) -> ((Service) -> Void)? {
        guard svc.status == .failed else { return nil }
        return { _ in Task { await registry.refresh() } }
    }

    private var groupedServices: [(group: PopoverGrouping.StatusGroup, services: [Service])] {
        // Cap each group to 8 to keep the popover scrollable but bounded —
        // matches the M05 prefix(8) ceiling on the prior section view.
        PopoverGrouping.groupByStatus(registry.services).map { entry in
            (entry.group, Array(entry.services.prefix(8)))
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonRow().padding(.horizontal, DesignTokens.Spacing.s)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.tint)
            Text("Agent Jobs")
                .font(DesignTokens.Typography.heading)
            Spacer()
            AutoRefreshIndicator()
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
                // AC-F-10: with setActivationPolicy(.accessory) the new
                // Window scene won't auto-focus. Force activation so the
                // dashboard becomes key + visible immediately.
                NSApp.activate(ignoringOtherApps: true)
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
