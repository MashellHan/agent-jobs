import SwiftUI
import AgentJobsCore

/// Compact error strip rendered between the summary and the service list when
/// the registry's `LoadPhase == .error`. Offers a one-tap retry so refresh
/// failures are recoverable instead of silent.
struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.StatusColor.failed)
            VStack(alignment: .leading, spacing: 1) {
                Text("Refresh failed")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry", action: retry)
                .buttonStyle(.borderless)
                .font(DesignTokens.Typography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.m)
        .padding(.vertical, DesignTokens.Spacing.s)
        .background(DesignTokens.StatusColor.failed.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Refresh failed: \(message)")
    }
}
