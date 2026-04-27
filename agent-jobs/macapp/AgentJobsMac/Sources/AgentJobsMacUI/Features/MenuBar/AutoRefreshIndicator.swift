import SwiftUI
import AgentJobsCore

/// Three-state auto-refresh indicator. Drives off the view-model
/// (`isRefreshing`, `lastRefreshError`, `lastRefresh`) — no internal
/// timer-driven label since M04's refresh cadence is event-driven.
///
/// States:
///   - error      — `lastRefreshError != nil` → red triangle + "refresh failed"
///   - refreshing — `isRefreshing == true` → accent pulse + "refreshing…"
///   - idle       — fallback → "updated Ns ago" with 1s tick
///
/// AC-V-01..V-03 capture each baseline. Pulse animation gated by
/// `accessibilityReduceMotion` (AC-V-02 captures with reduced motion
/// to keep the baseline phase-stable).
struct AutoRefreshIndicator: View {
    @Environment(ServiceRegistryViewModel.self) private var viewModel
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum IndicatorState {
        case idle, refreshing, error(String)
    }

    private var state: IndicatorState {
        if let err = viewModel.lastRefreshError { return .error(err) }
        if viewModel.isRefreshing { return .refreshing }
        return .idle
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            iconView
            Text(label)
                .font(DesignTokens.Typography.caption.monospacedDigit())
                .foregroundStyle(textColor)
        }
        .onReceive(timer) { now = $0 }
        .help(tooltip)
        .accessibilityLabel("Auto-refresh status: \(label)")
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
                .foregroundStyle(.red)
        case .refreshing:
            Image(systemName: "arrow.clockwise.circle")
                .imageScale(.small)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        case .idle:
            Image(systemName: "arrow.clockwise.circle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        switch state {
        case .error:      return "refresh failed"
        case .refreshing: return "refreshing…"
        case .idle:
            let elapsed = max(0, Int(now.timeIntervalSince(viewModel.lastRefresh)))
            return "updated \(elapsed)s ago"
        }
    }

    private var textColor: Color {
        switch state {
        case .error:      return .red
        case .refreshing: return .primary
        case .idle:       return .secondary
        }
    }

    private var tooltip: String {
        switch state {
        case .error(let msg): return msg
        case .refreshing:     return "Refreshing services…"
        case .idle:           return "Last refresh \(viewModel.lastRefresh.formatted(date: .omitted, time: .standard))"
        }
    }
}
