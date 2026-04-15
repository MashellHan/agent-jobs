import SwiftUI

/// A small speech bubble with a downward-pointing triangle, shown above the mascot.
struct SpeechBubbleView: View {
    let text: String
    var isVisible: Bool = true

    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                )

            // Triangle pointer
            TrianglePointer()
                .fill(.white)
                .frame(width: 12, height: 6)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .opacity(opacity)
        .onChange(of: isVisible, initial: true) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = newValue ? 1 : 0
            }
        }
    }
}

// MARK: - Triangle Shape

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
