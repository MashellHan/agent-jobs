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
    /// AC-F-14: per-bucket short error string (registry-collapsed). Empty
    /// dictionary ≡ no errors — chips render without the warning glyph.
    var errorByBucket: [ServiceSource.Bucket: String] = [:]

    var body: some View {
        // T-015: wrap chips in horizontal ScrollView so the harness/narrow
        // widths can't squeeze chips into a vertical stripe. Total label
        // pinned outside the scroll region so it stays one-line readable.
        HStack(spacing: DesignTokens.Spacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(ServiceSource.Bucket.allCases, id: \.self) { bucket in
                        SourceBucketChip(
                            bucket: bucket,
                            count: count(for: bucket),
                            isSelected: selection == bucket,
                            errorMessage: errorByBucket[bucket]
                        ) {
                            selection = (selection == bucket) ? nil : bucket
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.vertical, 1) // Give Capsule shadows room without clipping
            }
            totalLabel
                .fixedSize(horizontal: true, vertical: false)
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
