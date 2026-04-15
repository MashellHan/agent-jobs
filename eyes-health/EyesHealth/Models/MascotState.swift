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

    /// Timer for cycling eye care tips during idle.
    private var tipCycleTimer: Timer?

    /// Whether a non-tip speech (alert, celebration) is currently showing.
    private var isShowingPrioritySpeech: Bool = false

    private let tipsService: TipsService

    init(tipsService: TipsService = .shared) {
        self.tipsService = tipsService
    }

    /// Start cycling tips every 10 minutes during idle.
    func startTipCycling() {
        tipCycleTimer?.invalidate()
        let timer = Timer.scheduledTimer(
            withTimeInterval: 600, // 10 minutes
            repeats: true
        ) { [weak self] _ in
            self?.showRandomTip()
        }
        RunLoop.current.add(timer, forMode: .common)
        tipCycleTimer = timer
    }

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
        isShowingPrioritySpeech = true
        showSpeech("Great job! \u{1F60A}")

        let timer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.expression = .normal
            self.isShowingPrioritySpeech = false
            self.dismissSpeech()
        }
        RunLoop.current.add(timer, forMode: .common)
        happyTimer = timer
    }

    /// Trigger attention-getting state with speech bubble.
    func alertBreakDue() {
        expression = .worried
        isShowingPrioritySpeech = true
        showSpeech("Time for a break! \u{1F440}")

        // Auto-clear priority flag after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.isShowingPrioritySpeech = false
        }
    }

    /// Show a random eye care tip in the speech bubble for 8 seconds.
    private func showRandomTip() {
        guard !isShowingPrioritySpeech else { return }

        let hour = Calendar.current.component(.hour, from: .now)
        let tip = tipsService.contextualTip(hour: hour, score: 75)
        showSpeech("\u{1F4A1} \(tip.title)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, !self.isShowingPrioritySpeech else { return }
            self.dismissSpeech()
        }
    }

    func showSpeech(_ text: String) {
        speechText = text
    }

    func dismissSpeech() {
        speechText = nil
    }

    deinit {
        happyTimer?.invalidate()
        tipCycleTimer?.invalidate()
    }
}
