import SwiftUI
import AgentJobsCore

struct DashboardView: View {
    @Environment(ServiceRegistryViewModel.self) private var registry
    @State private var selection: Service.ID?
    @State private var categoryFilter: ServiceSource.Category? = nil
    @State private var bucketFilter: ServiceSource.Bucket? = nil
    @State private var showHidden: Bool = false
    @State private var pendingStop: Service? = nil

    /// Optional initial selection — used by visual baseline tests
    /// (AC-V-05) to deterministically pick a row before screenshot capture.
    init(initialSelection: Service.ID? = nil) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            VStack(spacing: 0) {
                SourceBucketStrip(
                    services: registry.services,
                    selection: $bucketFilter,
                    errorByBucket: registry.errorByBucket
                )
                Divider()
                serviceTable
            }
            .toolbar { dashboardToolbar }
        } detail: {
            if let id = selection,
               let svc = registry.services.first(where: { $0.id == id }) {
                ServiceInspector(
                    service: svc,
                    isHidden: registry.hiddenIds.contains(svc.id),
                    errorMessage: registry.errorByServiceId[svc.id],
                    onStop: { pendingStop = $0 },
                    onHide: { svc in Task { await registry.hide(svc.id) } },
                    onUnhide: { svc in Task { await registry.unhide(svc.id) } }
                )
            } else {
                ContentUnavailableView("Select a service",
                                       systemImage: "sidebar.right",
                                       description: Text("Pick something from the list to inspect."))
            }
        }
        .stopConfirmation(pending: $pendingStop) { svc in
            Task { await registry.stop(svc) }
        }
    }

    @ToolbarContentBuilder
    private var dashboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // AC-V-05: indicator visible in BOTH popover AND dashboard
            // toolbar — so visibility doesn't depend on which surface
            // the user has open. Placed LEFT of the Refresh button.
            AutoRefreshIndicator()
            Toggle(isOn: $showHidden) {
                Label("Show hidden", systemImage: "eye")
            }
            .toggleStyle(.button)
            .help("Show services you have hidden")
            Button {
                Task { await registry.refreshNow() }
            } label: {
                if registry.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(registry.isRefreshing)
            .help("Refresh discovery")
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
        DashboardView.filter(
            registry.services,
            category: categoryFilter,
            bucket: bucketFilter,
            hiddenIds: registry.hiddenIds,
            showHidden: showHidden
        )
    }

    /// Pure filter function — both filters AND-ed; nil disables that
    /// constraint. Extracted as `static` so unit tests can exercise the
    /// matrix without spinning up SwiftUI / NavigationSplitView.
    /// 3-arg overload preserves M02 callers.
    static func filter(_ services: [Service],
                       category: ServiceSource.Category?,
                       bucket: ServiceSource.Bucket?) -> [Service] {
        filter(services, category: category, bucket: bucket, hiddenIds: [], showHidden: true)
    }

    static func filter(_ services: [Service],
                       category: ServiceSource.Category?,
                       bucket: ServiceSource.Bucket?,
                       hiddenIds: Set<String>,
                       showHidden: Bool) -> [Service] {
        services.filter { svc in
            let categoryOK = category == nil || svc.source.category == category
            let bucketOK   = bucket == nil   || svc.source.bucket   == bucket
            let hiddenOK   = showHidden || !hiddenIds.contains(svc.id)
            return categoryOK && bucketOK && hiddenOK
        }
    }

    private var emptyTitle: String {
        if registry.services.isEmpty { return "No services discovered yet" }
        if !registry.hiddenIds.isEmpty && !showHidden && allVisibleHidden {
            return "All services hidden"
        }
        if let cat = categoryFilter, let bkt = bucketFilter {
            return "No \(cat.displayName) services in \(bkt.displayName)"
        }
        if let cat = categoryFilter { return "No \(cat.displayName) services" }
        if let bkt = bucketFilter   { return "No \(bkt.displayName) services" }
        return "No services discovered yet"
    }

    private var allVisibleHidden: Bool {
        !registry.services.isEmpty
            && registry.services.allSatisfy { registry.hiddenIds.contains($0.id) }
    }

    private var emptySymbol: String {
        if !registry.hiddenIds.isEmpty && !showHidden && allVisibleHidden {
            return "eye.slash"
        }
        return bucketFilter?.sfSymbol ?? categoryFilter?.sfSymbol ?? "tray"
    }

    private var emptyMessage: String {
        if registry.services.isEmpty {
            return "Providers will populate this view as they discover work."
        }
        if !registry.hiddenIds.isEmpty && !showHidden && allVisibleHidden {
            return "Toggle Show hidden to see them."
        }
        return "Try clearing a filter, or run something in this source."
    }

    private var serviceTable: some View {
        Group {
            if filteredServices.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySymbol,
                    description: Text(emptyMessage)
                )
            } else {
                Table(filteredServices, selection: $selection) {
                    TableColumn("Name") { svc in
                        ServiceRowNameCell(
                            service: svc,
                            isSelected: selection == svc.id,
                            isHidden: registry.hiddenIds.contains(svc.id),
                            onStop: { pendingStop = $0 },
                            onHide: { svc in Task { await registry.hide(svc.id) } },
                            onUnhide: { svc in Task { await registry.unhide(svc.id) } }
                        )
                    }
                    TableColumn("Status") { svc in StatusBadge(status: svc.status) }
                        .width(min: 70, ideal: 90)
                    TableColumn("Schedule") { svc in
                        Text(svc.schedule.humanDescription)
                            .font(DesignTokens.Typography.monoSmall)
                    }
                    TableColumn("Created") { svc in
                        if let created = svc.createdAt {
                            Text(created.formatted(.relative(presentation: .named)))
                                .foregroundStyle(.secondary)
                                .help(created.formatted(date: .abbreviated, time: .standard))
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
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
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

struct ServiceInspector: View {
    let service: Service
    var isHidden: Bool = false
    var errorMessage: String? = nil
    var onStop: (Service) -> Void = { _ in }
    var onHide: (Service) -> Void = { _ in }
    var onUnhide: (Service) -> Void = { _ in }
    @State private var tab: Tab = .overview

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", logs = "Logs", config = "Config", metrics = "Metrics"
        var id: String { rawValue }
        var sfSymbol: String {
            switch self {
            case .overview: return "square.text.square"
            case .logs:     return "text.alignleft"
            case .config:   return "doc.text"
            case .metrics:  return "chart.bar.xaxis"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            actionBar
            if let msg = errorMessage {
                ErrorBanner(message: msg, retry: {})
                    .padding(.horizontal, DesignTokens.Spacing.l)
                    .padding(.bottom, DesignTokens.Spacing.s)
            }
            TabChipRow(selection: $tab)
                .padding(.horizontal, DesignTokens.Spacing.l)
                .padding(.bottom, DesignTokens.Spacing.s)
            Divider()
            ScrollView { content.padding(DesignTokens.Spacing.l) }
        }
    }

    private var actionBar: some View {
        HStack {
            Spacer()
            RowActionStack(
                service: service,
                isHidden: isHidden,
                style: .withLabels,
                onStop: { onStop(service) },
                onHide: { onHide(service) },
                onUnhide: { onUnhide(service) }
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.l)
        .padding(.bottom, DesignTokens.Spacing.s)
    }

    private var header: some View {
        let formatted = ServiceFormatter.format(service)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: service.source.category.sfSymbol)
                Text(formatted.title).font(DesignTokens.Typography.title)
                Spacer()
                StatusBadge(status: service.status)
            }
            Text(formatted.summary)
                .font(DesignTokens.Typography.monoSmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            // design-003 Top-3 #2 / D-M3: quiet provenance subtitle so users
            // immediately see WHERE the service comes from and which project
            // owns it. Both fields are already in the Service model — just
            // unsurfaced.
            Text("\(service.source.category.displayName) · \(service.project ?? "—")")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
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
            // AC-F-08: PID + Owner tiles ONLY when pid is set. When nil we
            // omit the row entirely (NOT render "0") — the model field is
            // genuinely absent for non-process-backed services.
            if let pid = service.pid {
                GridRow {
                    MetricTile(title: "PID", value: "\(pid)", mono: true)
                    MetricTile(title: "Owner", value: ownerLabel)
                }
            }
            // AC-F-07: Provenance group — surfaces createdAt + the service's
            // origin (which agent / sessionId registered it) + log path or
            // task identifier. Spec §"data flow" requires these fields to
            // populate for every row regardless of source. Missing fields
            // render "—" per spec ("render '—'", do NOT extend the model).
            GridRow {
                MetricTile(title: "Created",
                           value: service.createdAt.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "—")
                MetricTile(title: "Origin", value: originLabel, mono: true)
            }
            GridRow {
                MetricTile(title: "Session", value: sessionLabel, mono: true)
                MetricTile(title: "Source path", value: sourcePathLabel, mono: true)
            }
        }
    }

    /// Origin agent + tool surface (e.g. "Claude · scheduledTask"). "—" when
    /// the discovery provider didn't attach an origin.
    private var originLabel: String {
        guard let o = service.origin else { return "—" }
        if let tool = o.toolName { return "\(o.agent.displayName) · \(tool)" }
        return o.agent.displayName
    }

    private var sessionLabel: String {
        service.origin?.sessionId ?? "—"
    }

    /// File path / scheduled-task id surface. The Service model doesn't have
    /// a dedicated "scheduled task id" field (spec: don't extend the model);
    /// we use `logsPath` when set, else "—".
    private var sourcePathLabel: String {
        service.logsPath ?? "—"
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

/// Chip-style tab row replacing `pickerStyle(.segmented)` for the inspector.
/// Linear/Things-flavored: capsule background on the active tab, transparent
/// for the rest. Each tab is a real `Button` so VoiceOver and keyboard nav
/// work without bespoke `accessibilityElement` plumbing.
struct TabChipRow: View {
    @Binding var selection: ServiceInspector.Tab
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(ServiceInspector.Tab.allCases) { t in
                TabChip(tab: t, isSelected: selection == t) { selection = t }
            }
            Spacer()
        }
    }
}

private struct TabChip: View {
    let tab: ServiceInspector.Tab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: tab.sfSymbol).imageScale(.small)
                Text(tab.rawValue).font(DesignTokens.Typography.caption)
            }
            .padding(.horizontal, DesignTokens.Spacing.s)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(background, in: Capsule())
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    private var background: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        if isHovered  { return Color.primary.opacity(0.06) }
        return .clear
    }
}
