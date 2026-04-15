import SwiftUI
import AppKit

/// A cute Q-style (kawaii) eye mascot drawn entirely with SwiftUI shapes.
///
/// The character is a round eyeball (~60×60) with an iris that changes color
/// based on eye-health status, a pupil that follows the mouse, periodic
/// blinking, gentle bobbing, and expression-driven eyelid animations.
struct MascotView: View {
    let expression: MascotExpression
    let speechText: String?

    // MARK: - Animation State

    @State private var isBlinking = false
    @State private var bobOffset: CGFloat = 0
    @State private var pupilOffset: CGSize = .zero
    @State private var shakeOffset: CGFloat = 0
    @State private var bounceScale: CGFloat = 1.0
    @State private var blinkTimer: Timer?
    @State private var mouseTrackingTimer: Timer?
    @State private var speechOpacity: Double = 0

    private let mascotSize = Constants.mascotSize

    var body: some View {
        VStack(spacing: 4) {
            speechBubble
            eyeCharacter
        }
        .onAppear { startIdleAnimations() }
        .onDisappear { stopTimers() }
        .onChange(of: expression) { _, newValue in
            handleExpressionChange(newValue)
        }
        .onChange(of: speechText) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                speechOpacity = newValue != nil ? 1 : 0
            }
        }
    }

    // MARK: - Speech Bubble

    @ViewBuilder
    private var speechBubble: some View {
        if let text = speechText {
            SpeechBubbleView(text: text)
                .opacity(speechOpacity)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Eye Character

    private var eyeCharacter: some View {
        ZStack {
            // Eyeball body — white with faint blue tint
            eyeballBody

            // Iris — color depends on expression
            irisView

            // Pupil — follows mouse
            pupilView

            // Sparkle highlight
            sparkleView

            // Eyelids — animate per expression
            topEyelid
            bottomEyelid

            // Cute cheeks
            cheeksView
        }
        .frame(width: mascotSize, height: mascotSize)
        .offset(y: bobOffset)
        .offset(x: shakeOffset)
        .scaleEffect(bounceScale)
    }

    // MARK: - Eyeball

    private var eyeballBody: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(white: 1.0),
                        Color(red: 0.94, green: 0.96, blue: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: mascotSize / 2
                )
            )
            .frame(width: mascotSize, height: mascotSize * 0.9)
            .overlay(
                Ellipse()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }

    // MARK: - Iris

    private var irisColor: Color {
        switch expression {
        case .happy: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .normal: return Color(red: 0.3, green: 0.75, blue: 0.45)
        case .concerned: return Color(red: 0.9, green: 0.75, blue: 0.2)
        case .worried: return Color(red: 0.9, green: 0.3, blue: 0.25)
        case .sleeping: return Color(red: 0.5, green: 0.7, blue: 0.55)
        }
    }

    private var irisSize: CGFloat { mascotSize * 0.48 }

    private var irisView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        irisColor,
                        irisColor.opacity(0.7)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: irisSize / 2
                )
            )
            .frame(width: irisSize, height: irisSize)
            .offset(pupilOffset * 0.3)
            .animation(.easeOut(duration: 0.15), value: irisColor)
    }

    // MARK: - Pupil

    private var pupilSize: CGFloat {
        switch expression {
        case .worried: return mascotSize * 0.18
        case .sleeping: return mascotSize * 0.12
        default: return mascotSize * 0.16
        }
    }

    private var pupilView: some View {
        Circle()
            .fill(Color.black)
            .frame(width: pupilSize, height: pupilSize)
            .offset(pupilOffset * 0.5)
            .animation(.easeOut(duration: 0.15), value: pupilOffset)
    }

    // MARK: - Sparkle

    private var sparkleView: some View {
        Circle()
            .fill(Color.white.opacity(0.85))
            .frame(width: mascotSize * 0.1, height: mascotSize * 0.1)
            .offset(x: -mascotSize * 0.1, y: -mascotSize * 0.1)
            .offset(pupilOffset * 0.15)
    }

    // MARK: - Eyelids

    private var eyelidOpenness: CGFloat {
        if isBlinking { return 0.05 }
        switch expression {
        case .happy: return 0.35
        case .normal: return 1.0
        case .concerned: return 0.7
        case .worried: return 1.0
        case .sleeping: return 0.2
        }
    }

    private var topEyelid: some View {
        EyelidShape(position: .top, openness: eyelidOpenness)
            .fill(Color(red: 0.96, green: 0.92, blue: 0.88))
            .frame(width: mascotSize, height: mascotSize * 0.9)
            .animation(.easeInOut(duration: isBlinking ? 0.08 : 0.25), value: eyelidOpenness)
    }

    private var bottomEyelid: some View {
        EyelidShape(position: .bottom, openness: eyelidOpenness)
            .fill(Color(red: 0.96, green: 0.92, blue: 0.88))
            .frame(width: mascotSize, height: mascotSize * 0.9)
            .animation(.easeInOut(duration: isBlinking ? 0.08 : 0.25), value: eyelidOpenness)
    }

    // MARK: - Cheeks

    private var cheeksView: some View {
        HStack(spacing: mascotSize * 0.5) {
            Circle()
                .fill(Color.pink.opacity(cheeksOpacity))
                .frame(width: mascotSize * 0.15, height: mascotSize * 0.15)
            Circle()
                .fill(Color.pink.opacity(cheeksOpacity))
                .frame(width: mascotSize * 0.15, height: mascotSize * 0.15)
        }
        .offset(y: mascotSize * 0.2)
    }

    private var cheeksOpacity: Double {
        switch expression {
        case .happy: return 0.5
        case .normal, .concerned: return 0.2
        case .worried: return 0.1
        case .sleeping: return 0.3
        }
    }

    // MARK: - Idle Animations

    private func startIdleAnimations() {
        startBobbing()
        startBlinking()
        startMouseTracking()
    }

    private func startBobbing() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            bobOffset = 2
        }
    }

    private func startBlinking() {
        scheduleNextBlink()
    }

    private func scheduleNextBlink() {
        let interval = Double.random(in: 3...6)
        let timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [self] _ in
            performBlink()
        }
        RunLoop.current.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func performBlink() {
        guard expression != .sleeping else {
            scheduleNextBlink()
            return
        }

        withAnimation(.easeInOut(duration: 0.08)) {
            isBlinking = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.08)) {
                isBlinking = false
            }
            scheduleNextBlink()
        }
    }

    private func startMouseTracking() {
        let timer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { _ in
            updatePupilFromMouse()
        }
        RunLoop.current.add(timer, forMode: .common)
        mouseTrackingTimer = timer
    }

    private func updatePupilFromMouse() {
        let mouseLocation = NSEvent.mouseLocation

        // Get mascot center on screen (approximate — center of primary screen
        // bottom-right area). The exact position depends on MascotWindowService
        // placement, but relative direction is what matters.
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Approximate mascot position (bottom-right)
        let mascotScreenX = screenFrame.maxX - Constants.mascotWindowWidth / 2
        let mascotScreenY = screenFrame.minY + Constants.mascotWindowHeight / 2

        let dx = mouseLocation.x - mascotScreenX
        let dy = mouseLocation.y - mascotScreenY
        let distance = sqrt(dx * dx + dy * dy)

        // Normalize and clamp to ±3 pixels
        let maxOffset: CGFloat = 3
        let normalizedX: CGFloat
        let normalizedY: CGFloat

        if distance > 10 {
            normalizedX = (dx / distance) * maxOffset
            normalizedY = -(dy / distance) * maxOffset // Flip Y for SwiftUI coords
        } else {
            normalizedX = 0
            normalizedY = 0
        }

        DispatchQueue.main.async {
            pupilOffset = CGSize(width: normalizedX, height: normalizedY)
        }
    }

    private func stopTimers() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
    }

    // MARK: - Expression Changes

    private func handleExpressionChange(_ newExpression: MascotExpression) {
        switch newExpression {
        case .happy:
            // Bounce animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                bounceScale = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceScale = 1.0
                }
            }

        case .worried:
            // Shake animation
            shakeAnimation()

        default:
            bounceScale = 1.0
            shakeOffset = 0
        }
    }

    private func shakeAnimation() {
        let shakeSequence: [(CGFloat, Double)] = [
            (3, 0.05), (-3, 0.1), (2, 0.15), (-2, 0.2), (0, 0.25)
        ]
        for (offset, delay) in shakeSequence {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.05)) {
                    shakeOffset = offset
                }
            }
        }
    }
}

// MARK: - Eyelid Shape

private enum EyelidPosition {
    case top, bottom
}

private struct EyelidShape: Shape {
    let position: EyelidPosition
    var openness: CGFloat // 0 = fully closed, 1 = fully open

    var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY

        switch position {
        case .top:
            // Top eyelid slides down from the top
            let closedY = midY + rect.height * 0.1
            let openY = rect.minY - rect.height * 0.05
            let lidY = openY + (closedY - openY) * (1 - openness)

            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: lidY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: lidY),
                control: CGPoint(x: rect.midX, y: lidY + rect.height * 0.15)
            )
            path.closeSubpath()

        case .bottom:
            // Bottom eyelid slides up from the bottom
            let closedY = midY - rect.height * 0.1
            let openY = rect.maxY + rect.height * 0.05
            let lidY = openY + (closedY - openY) * (1 - openness)

            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: lidY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: lidY),
                control: CGPoint(x: rect.midX, y: lidY - rect.height * 0.15)
            )
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - CGSize Multiplication Helper

private extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
