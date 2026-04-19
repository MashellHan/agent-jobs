import SwiftUI
import AgentJobsCore

/// "Last refreshed 4s ago • next in 26s" — addresses strict-review iter-001
/// memory `feedback_tui_design` (visible auto-refresh).
struct AutoRefreshIndicator: View {
    let lastRefresh: Date
    let intervalSeconds: TimeInterval
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "arrow.clockwise.circle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && nextIn <= 3)
            Text(label)
                .font(DesignTokens.Typography.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .onReceive(timer) { now = $0 }
        .accessibilityLabel("Auto-refresh status: \(label)")
    }

    private var elapsed: Int { max(0, Int(now.timeIntervalSince(lastRefresh))) }
    private var nextIn: Int { max(0, Int(intervalSeconds) - elapsed) }

    private var label: String {
        if nextIn == 0 { return "refreshing…" }
        return "updated \(elapsed)s ago • next in \(nextIn)s"
    }
}
