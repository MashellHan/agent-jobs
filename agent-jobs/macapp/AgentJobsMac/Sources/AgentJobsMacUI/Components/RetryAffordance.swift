import SwiftUI

/// Trailing-slot retry button for a `MenuBarRichRow` whose service is
/// `.failed`. Square 22pt button (matches popover row icon size) with the
/// `arrow.clockwise` SF symbol. Reachable via keyboard tab traversal
/// because it's a real `Button`. AC-F-12 / T-016.
struct RetryAffordance: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .imageScale(.small)
                .frame(width: 22, height: 22)
                .background(
                    isHovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.04),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Retry")
        .accessibilityLabel("Retry")
    }
}
