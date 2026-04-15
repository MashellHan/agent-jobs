import Foundation
import Observation

// MARK: - Expression

enum MascotExpression: Equatable {
    case happy      // After a break — squinty happy eyes, bounces
    case normal     // Standard look, periodic blinking
    case concerned  // Warning state — slightly worried look
    case worried    // Overdue — wide eyes, shakes
    case sleeping   // Night mode (future) — eyes nearly closed, zzz
}

// MARK: - State

@Observable
final class MascotState {
    var expression: MascotExpression = .normal
    var speechText: String? = nil
    var isVisible: Bool = true

    /// Whether the speech bubble should auto-dismiss after a delay.
    var speechAutoDismiss: Bool = true

    /// Temporary override duration for happy expression (seconds).
    private var happyTimer: Timer?

    /// Update mascot expression based on current app state.
    func updateFromAppState(_ appState: AppState) {
        let status = appState.statusColor
        let newExpression: MascotExpression = switch status {
        case .green: .normal
        case .yellow: .concerned
        case .red: .worried
        }

        // Don't override happy expression mid-celebration
        guard expression != .happy else { return }
        expression = newExpression
    }

    /// Show the happy expression for a duration, then revert.
    func celebrateBreak(duration: TimeInterval = 10) {
        happyTimer?.invalidate()
        expression = .happy
        showSpeech("Great job! \u{1F60A}")

        let timer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.expression = .normal
            self.dismissSpeech()
        }
        RunLoop.current.add(timer, forMode: .common)
        happyTimer = timer
    }

    /// Trigger attention-getting state with speech bubble.
    func alertBreakDue() {
        expression = .worried
        showSpeech("Time for a break! \u{1F440}")
    }

    func showSpeech(_ text: String) {
        speechText = text
    }

    func dismissSpeech() {
        speechText = nil
    }

    deinit {
        happyTimer?.invalidate()
    }
}
