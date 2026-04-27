import SwiftUI
import AgentJobsCore

/// Inline empty-state hint used inside menubar sections. Lighter than
/// `ContentUnavailableView` — the menubar popover is too dense for a full
/// empty-state, so this is a single tray-icon + caption row.
struct EmptyHintView: View {
    let message: String
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "tray").foregroundStyle(.tertiary)
            Text(message).font(DesignTokens.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}
