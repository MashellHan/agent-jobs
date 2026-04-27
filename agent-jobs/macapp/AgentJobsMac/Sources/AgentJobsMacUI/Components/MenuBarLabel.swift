import SwiftUI
import AgentJobsCore

/// Compact menubar status icon: custom monoline template glyph + count
/// badge + optional failure triangle. Sits inside `MenuBarExtra`'s
/// `label:` slot.
///
/// M07 / T-001: SF Symbol placeholder swapped for the custom
/// `MenuBarIcon` template image (loaded from `Bundle.module` so both
/// the production app AND the headless `capture-all` runner pick it
/// up). Count overlay moved into a dedicated `BadgeOverlay` view so
/// the three contractual branches (0 / 1..9 / "9+") have a single
/// declarative home.
struct MenuBarLabel: View {
    let state: MenuBarSummary

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            IdentityImage.menuBarTemplate()
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
            BadgeOverlay(count: state.running)
                .accessibilityHidden(state.running == 0)
            if state.failed > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.StatusColor.failed)
                    .imageScale(.small)
            }
        }
        // M05 T06: lets MenuBarInteraction find the bundle's status item
        // via the Accessibility tree (`AXExtrasMenuBar` walk).
        .accessibilityIdentifier("agent-jobs.menubar")
        .accessibilityLabel("Agent Jobs menu bar status — \(state.running) running")
    }
}

/// AC-F-07 contract: 0 → no overlay; 1..9 → literal digit; ≥10 → "9+".
/// `BadgeText.text(for:)` exposes the same logic to the test target so
/// the three contractual branches can be asserted without instantiating
/// SwiftUI.
struct BadgeOverlay: View {
    let count: Int
    var body: some View {
        if count == 0 {
            EmptyView()
        } else {
            Text(BadgeText.text(for: count))
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityIdentifier("agent-jobs.menubar.badge")
        }
    }
}

/// Pure helper exposing the badge-string contract for tests.
public enum BadgeText {
    /// `nil` for 0 (no overlay rendered); literal digit for 1..9;
    /// the literal string `"9+"` for ≥10.
    public static func text(for count: Int) -> String {
        if count <= 0 { return "" }
        if count >= 10 { return "9+" }
        return "\(count)"
    }

    /// Convenience: returns whether `BadgeOverlay` will render anything.
    public static func renders(for count: Int) -> Bool { count > 0 }
}
