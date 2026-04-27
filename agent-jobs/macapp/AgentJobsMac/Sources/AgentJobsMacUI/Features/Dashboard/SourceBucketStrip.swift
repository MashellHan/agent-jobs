import SwiftUI
import AgentJobsCore

/// Horizontal strip of `SourceBucketChip`s — one per `ServiceSource.Bucket`,
/// in the canonical `Bucket.allCases` order (AC-F-05). All five chips ALWAYS
/// render, even when their count is zero (spec: "show all 5 chips always,
/// including 0-count chips, with secondary styling for zero").
///
/// Trailing "total: N" label (not a button — just an aggregate indicator).
struct SourceBucketStrip: View {
    let services: [Service]
    @Binding var selection: ServiceSource.Bucket?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(ServiceSource.Bucket.allCases, id: \.self) { bucket in
                SourceBucketChip(
                    bucket: bucket,
                    count: count(for: bucket),
                    isSelected: selection == bucket
                ) {
                    selection = (selection == bucket) ? nil : bucket
                }
            }
            Spacer(minLength: DesignTokens.Spacing.s)
            totalLabel
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.vertical, DesignTokens.Spacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Source filter strip")
    }

    private var totalLabel: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text("total")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
            Text("\(services.count)")
                .font(DesignTokens.Typography.monoSmall)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.s)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private func count(for bucket: ServiceSource.Bucket) -> Int {
        services.lazy.filter { $0.source.bucket == bucket }.count
    }
}
