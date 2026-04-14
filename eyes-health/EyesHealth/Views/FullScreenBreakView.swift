import SwiftUI

struct FullScreenBreakView: View {
    let onSkip: () -> Void
    let onComplete: () -> Void

    @State private var remainingSeconds: Int = Constants.fullScreenCountdownSeconds
    @State private var showSkipButton: Bool = false
    @State private var isComplete: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var completionScale: CGFloat = 0.3
    @State private var completionOpacity: Double = 0.0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Progress goes from 1.0 (full) to 0.0 (empty) as countdown runs.
    private var progress: Double {
        Double(remainingSeconds) / Double(Constants.fullScreenCountdownSeconds)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            VStack(spacing: 30) {
                if isComplete {
                    completionView
                } else {
                    countdownView
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in tick() }
        .onAppear {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Constants.skipButtonDelaySeconds
            ) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSkipButton = true
                }
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "eye")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(pulseScale)

            Text("Rest Your Eyes")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            progressRing

            Text("Look at something 20 feet (~6m) away")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            skipButtonView
                .padding(.bottom, 60)
        }
    }

    private var progressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 8)
                .frame(width: 160, height: 160)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            // Countdown number
            Text("\(remainingSeconds)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.green)
        }
    }

    private var skipButtonView: some View {
        Button(action: onSkip) {
            Text("Skip Break")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(showSkipButton ? 1 : 0)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .scaleEffect(completionScale)

            Text("Great job! \u{1F440}")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .opacity(completionOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                completionScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3)) {
                completionOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onComplete()
            }
        }
    }

    // MARK: - Timer Logic

    private func tick() {
        guard !isComplete else { return }
        guard remainingSeconds > 0 else { return }

        remainingSeconds -= 1

        if remainingSeconds == 0 {
            withAnimation(.easeInOut(duration: 0.4)) {
                isComplete = true
            }
        }
    }
}
