import SwiftUI
import AgentJobsCore

/// Inspector / overview tile presenting one labeled metric.
/// 1pt strokeBorder gives the tile depth (design-002 D-M8); minHeight keeps
/// adjacent tiles aligned in a `GridRow` (design-002 D-L5).
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
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.m)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }
}
