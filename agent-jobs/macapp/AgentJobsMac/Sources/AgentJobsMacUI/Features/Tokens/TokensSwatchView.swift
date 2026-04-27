import SwiftUI
import AgentJobsCore

/// M07 / Task-4 / scenario 14 — visual specimen of the design-token
/// substrate. Three sections stacked vertically:
///
///   1. **Color swatches** — 9-cell grid (4 status + 5 source) so the
///      ui-critic can eyeball saturation, luma, and ΔE separation.
///   2. **Type-scale** — 5 rows (display / title / body / caption / mono)
///      using the canonical pangram so glyph metrics are visible.
///   3. **Spacing ruler** — 5 horizontal bars (4 / 8 / 12 / 16 / 24)
///      so the rhythm is readable at a glance.
///
/// Rendered at 800×600 by default. The view is `internal` — only the
/// `HarnessScenes.tokensSwatch()` factory exposes it to `capture-all`.
struct TokensSwatchView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            colorSection
            typeSection
            spacingSection
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sections

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Colors")
                .font(DesignTokens.Typography.title)
            HStack(spacing: DesignTokens.Spacing.sm) {
                swatch("running",   DesignTokens.SemanticColor.statusRunning)
                swatch("scheduled", DesignTokens.SemanticColor.statusScheduled)
                swatch("failed",    DesignTokens.SemanticColor.statusFailed)
                swatch("idle",      DesignTokens.SemanticColor.statusIdle)
            }
            HStack(spacing: DesignTokens.Spacing.sm) {
                swatch("registered",   DesignTokens.SourceColor.registered)
                swatch("claudeSched",  DesignTokens.SourceColor.claudeSched)
                swatch("claudeLoop",   DesignTokens.SourceColor.claudeLoop)
                swatch("launchd",      DesignTokens.SourceColor.launchd)
                swatch("liveProc",     DesignTokens.SourceColor.liveProc)
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Typography")
                .font(DesignTokens.Typography.title)
            Text("display — The quick brown fox").font(DesignTokens.Typography.display)
            Text("title — The quick brown fox").font(DesignTokens.Typography.title)
            Text("body — The quick brown fox").font(DesignTokens.Typography.body)
            Text("caption — The quick brown fox").font(DesignTokens.Typography.caption)
            Text("mono — The quick brown fox").font(DesignTokens.Typography.mono)
        }
    }

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Spacing")
                .font(DesignTokens.Typography.title)
            ruler("xs (4)",  DesignTokens.Spacing.xs)
            ruler("sm (8)",  DesignTokens.Spacing.sm)
            ruler("md (12)", DesignTokens.Spacing.md)
            ruler("lg (16)", DesignTokens.Spacing.lg)
            ruler("xl (24)", DesignTokens.Spacing.xl)
        }
    }

    // MARK: - Cells

    private func swatch(_ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 72, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func ruler(_ label: String, _ width: CGFloat) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(DesignTokens.Typography.caption)
                .frame(width: 80, alignment: .leading)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: max(width, 2), height: 12)
        }
    }
}
