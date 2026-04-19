import SwiftUI
import AgentJobsCore

struct DashboardView: View {
    @Environment(ServiceRegistryViewModel.self) private var registry
    @State private var selection: Service.ID?
    @State private var categoryFilter: ServiceSource.Category? = nil

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            serviceTable
        } detail: {
            if let id = selection,
               let svc = registry.services.first(where: { $0.id == id }) {
                ServiceInspector(service: svc)
            } else {
                ContentUnavailableView("Select a service",
                                       systemImage: "sidebar.right",
                                       description: Text("Pick something from the list to inspect."))
            }
        }
    }

    private var sidebar: some View {
        List(selection: $categoryFilter) {
            Section("Filters") {
                HStack {
                    Label("All", systemImage: "tray.full")
                    Spacer()
                    Text("\(registry.services.count)")
                        .font(DesignTokens.Typography.monoSmall)
                        .foregroundStyle(.secondary)
                }
                .tag(Optional<ServiceSource.Category>.none)
            }
            Section("Categories") {
                ForEach(ServiceSource.Category.allCases, id: \.self) { cat in
                    HStack {
                        Label(cat.displayName, systemImage: cat.sfSymbol)
                        Spacer()
                        Text("\(count(for: cat))")
                            .font(DesignTokens.Typography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(cat))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Agent Jobs")
    }

    private func count(for cat: ServiceSource.Category) -> Int {
        registry.services.lazy.filter { $0.source.category == cat }.count
    }

    private var filteredServices: [Service] {
        guard let cat = categoryFilter else { return registry.services }
        return registry.services.filter { $0.source.category == cat }
    }

    private var serviceTable: some View {
        Table(filteredServices, selection: $selection) {
            TableColumn("Name") { svc in
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: svc.source.category.sfSymbol)
                        .foregroundStyle(.secondary)
                    Text(svc.name)
                }
            }
            TableColumn("Status") { svc in StatusBadge(status: svc.status) }
                .width(min: 70, ideal: 90)
            TableColumn("Schedule") { svc in
                Text(svc.schedule.humanDescription)
                    .font(DesignTokens.Typography.monoSmall)
            }
            TableColumn("Created") { svc in
                Text(svc.createdAt.formatted(.relative(presentation: .named)))
                    .foregroundStyle(.secondary)
                    .help(svc.createdAt.formatted(date: .abbreviated, time: .standard))
            }
            TableColumn("CPU") { svc in
                if let m = svc.metrics {
                    Text(m.cpuPercentClampedFormatted)
                        .foregroundStyle(DesignTokens.ResourceColor.cpu(m.cpuPercent))
                        .font(.body.monospacedDigit())
                } else { Text("—").foregroundStyle(.tertiary) }
            }.width(min: 60, ideal: 70)
            TableColumn("Memory") { svc in
                if let m = svc.metrics {
                    Text(m.memoryRSSFormatted)
                        .foregroundStyle(DesignTokens.ResourceColor.memory(m.memoryRSS))
                        .font(.body.monospacedDigit())
                } else { Text("—").foregroundStyle(.tertiary) }
            }.width(min: 80, ideal: 90)
            TableColumn("Last Run") { svc in
                Text(svc.lastRun.map { $0.formatted(.relative(presentation: .named)) } ?? "—")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ServiceStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .imageScale(.small)
            Text(status.rawValue.capitalized)
                .font(DesignTokens.Typography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, 2)
        .background(color.opacity(0.18), in: Capsule())
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.rawValue)")
    }
    private var symbol: String {
        switch status {
        case .running:   return "circle.fill"
        case .scheduled: return "clock.fill"
        case .failed:    return "xmark.octagon.fill"
        case .paused:    return "pause.circle.fill"
        case .done:      return "checkmark.circle.fill"
        case .idle:      return "moon.zzz.fill"
        case .orphaned:  return "questionmark.circle.fill"
        case .unknown:   return "questionmark.circle"
        }
    }
    private var color: Color {
        switch status {
        case .running:   return DesignTokens.StatusColor.running
        case .scheduled: return DesignTokens.StatusColor.scheduled
        case .failed:    return DesignTokens.StatusColor.failed
        case .paused:    return DesignTokens.StatusColor.paused
        case .done:      return DesignTokens.StatusColor.done
        case .idle:      return DesignTokens.StatusColor.idle
        default:         return DesignTokens.StatusColor.unknown
        }
    }
}

struct ServiceInspector: View {
    let service: Service
    @State private var tab: Tab = .overview

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", logs = "Logs", config = "Config", metrics = "Metrics"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.Spacing.l)
            .padding(.bottom, DesignTokens.Spacing.s)
            Divider()
            ScrollView { content.padding(DesignTokens.Spacing.l) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: service.source.category.sfSymbol)
                Text(service.name).font(DesignTokens.Typography.title)
                Spacer()
                StatusBadge(status: service.status)
            }
            if !service.command.isEmpty {
                Text(service.command).font(DesignTokens.Typography.monoSmall).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(DesignTokens.Spacing.l)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview: overviewContent
        case .logs:
            ContentUnavailableView("Logs streaming",
                                   systemImage: "text.alignleft",
                                   description: Text("Live log tail lands in M1.2."))
        case .config:
            ContentUnavailableView("Raw configuration",
                                   systemImage: "doc.text.below.ecg",
                                   description: Text("plist / cron / json source view lands in M1.3."))
        case .metrics:  metricsContent
        }
    }

    private var overviewContent: some View {
        Grid(alignment: .leading, horizontalSpacing: DesignTokens.Spacing.l,
             verticalSpacing: DesignTokens.Spacing.m) {
            GridRow {
                MetricTile(title: "Schedule", value: service.schedule.humanDescription, mono: true)
                MetricTile(title: "Project", value: service.project ?? "—")
            }
            GridRow {
                MetricTile(title: "Last Run",
                           value: service.lastRun.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "—")
                MetricTile(title: "Next Run",
                           value: service.nextRun.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "—")
            }
            if let pid = service.pid {
                GridRow {
                    MetricTile(title: "PID", value: "\(pid)", mono: true)
                    MetricTile(title: "Owner", value: ownerLabel)
                }
            }
        }
    }

    private var metricsContent: some View {
        Group {
            if let m = service.metrics {
                Grid(horizontalSpacing: DesignTokens.Spacing.l, verticalSpacing: DesignTokens.Spacing.m) {
                    GridRow {
                        MetricTile(title: "CPU", value: m.cpuPercentClampedFormatted)
                        MetricTile(title: "Memory (RSS)", value: m.memoryRSSFormatted)
                    }
                    GridRow {
                        MetricTile(title: "Threads", value: "\(m.threadCount)")
                        MetricTile(title: "FDs", value: "\(m.fileDescriptors)")
                    }
                }
            } else {
                Text("No process metrics — not running, or PID unknown.").foregroundStyle(.secondary)
            }
        }
    }

    private var ownerLabel: String {
        switch service.owner {
        case .os: return "system"
        case .user: return "user"
        case .agent(let n): return n.displayName
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var mono: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title.uppercased())
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value).font(mono ? DesignTokens.Typography.mono : DesignTokens.Typography.metric)
        }
        .padding(DesignTokens.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.m))
    }
}
