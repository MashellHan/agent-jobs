import SwiftUI

struct FloatingBreakView: View {
    let onSkip: () -> Void
    let onCountdownComplete: () -> Void

    @State private var remainingSeconds: Int = Constants.breakCountdownSeconds

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            countdownDisplay
            statusLabel
            skipButton
        }
        .padding(16)
        .frame(
            width: Constants.floatingWindowWidth,
            height: Constants.floatingWindowHeight
        )
        .background(.ultraThinMaterial)
        .onReceive(timer) { _ in
            tick()
        }
    }

    // MARK: - Subviews

    private var countdownDisplay: some View {
        Text(countdownText)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(remainingSeconds > 0 ? Color.primary : Color.green)
    }

    private var statusLabel: some View {
        Text(remainingSeconds > 0 ? "Look away from screen" : "Break complete!")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var skipButton: some View {
        Button(action: onSkip) {
            Text("Skip")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .opacity(remainingSeconds > 0 ? 1 : 0)
    }

    // MARK: - Helpers

    private var countdownText: String {
        if remainingSeconds > 0 {
            return "\(remainingSeconds)s"
        }
        return "Done!"
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            onCountdownComplete()
        }
    }
}
