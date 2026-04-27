import SwiftUI
import AgentJobsCore

/// Per-row name cell with hover state. Owns its own `@State isHovered`
/// (extracted from the column closure so each row has isolated hover) and
/// reveals `RowActionStack` on hover OR when the row is selected (so
/// keyboard-only users still discover the affordances).
struct ServiceRowNameCell: View {
    let service: Service
    let isSelected: Bool
    let isHidden: Bool
    let onStop: (Service) -> Void
    let onHide: (Service) -> Void
    let onUnhide: (Service) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: service.source.category.sfSymbol)
                .foregroundStyle(.secondary)
            Text(service.name)
            Spacer(minLength: DesignTokens.Spacing.s)
            if showActions {
                RowActionStack(
                    service: service,
                    isHidden: isHidden,
                    style: .iconOnly,
                    onStop: { onStop(service) },
                    onHide: { onHide(service) },
                    onUnhide: { onUnhide(service) }
                )
                .transition(.opacity)
            }
        }
        .opacity(isHidden ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }

    private var showActions: Bool { isHovered || isSelected }
}
