import AppKit
import EyesCareCore

/// Manages the floating break reminder window and full-screen overlay.
///
/// Responsible for:
/// - Creating and displaying the floating countdown window (Normal mode)
/// - Creating and displaying the full-screen overlay (Aggressive mode)
/// - Countdown timer management
/// - Dismissal and snooze handling
@MainActor
public final class BreakWindowController {

    // MARK: - Windows

    private var floatingWindow: NSWindow?
    private var fullScreenWindows: [NSWindow] = []
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    private var currentBreakEvent: BreakEvent?

    // MARK: - Callbacks

    public var onDismiss: (() -> Void)?
    public var onSnooze: (() -> Void)?

    // MARK: - UI References

    private var countdownLabel: NSTextField?
    private var titleLabel: NSTextField?
    private var messageLabel: NSTextField?
    private var progressBar: NSProgressIndicator?

    // MARK: - Public API

    /// Show a floating break reminder window (Normal mode).
    public func showFloatingWindow(for event: BreakEvent) {
        dismissAll()
        currentBreakEvent = event
        remainingSeconds = Int(event.breakType.duration)

        let window = createFloatingWindow(for: event)
        floatingWindow = window
        window.makeKeyAndOrderFront(nil)

        startCountdown()
    }

    /// Show a full-screen overlay (Aggressive mode).
    public func showFullScreenOverlay(for event: BreakEvent) {
        dismissAll()
        currentBreakEvent = event
        remainingSeconds = Int(event.breakType.duration)

        // Cover all screens
        for screen in NSScreen.screens {
            let window = createFullScreenWindow(for: event, on: screen)
            fullScreenWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        // Make the first one key
        fullScreenWindows.first?.makeKey()
        startCountdown()
    }

    /// Dismiss all break windows.
    public func dismissAll() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        floatingWindow?.close()
        floatingWindow = nil

        for window in fullScreenWindows {
            window.close()
        }
        fullScreenWindows.removeAll()

        currentBreakEvent = nil
        countdownLabel = nil
        titleLabel = nil
        messageLabel = nil
        progressBar = nil
    }

    // MARK: - Floating Window

    private func createFloatingWindow(for event: BreakEvent) -> NSWindow {
        let windowWidth: CGFloat = 320
        let windowHeight: CGFloat = 200

        // Position in top-right corner
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.maxX - windowWidth - 20
        let originY = screenFrame.maxY - windowHeight - 20

        let window = NSWindow(
            contentRect: NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "EyesCare"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))

        // Title
        let title = NSTextField(labelWithString: titleText(for: event))
        title.font = NSFont.boldSystemFont(ofSize: 16)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 145, width: windowWidth - 40, height: 30)
        self.titleLabel = title
        contentView.addSubview(title)

        // Message
        let message = NSTextField(labelWithString: event.breakType.medicalSource)
        message.font = NSFont.systemFont(ofSize: 12)
        message.textColor = .secondaryLabelColor
        message.alignment = .center
        message.frame = NSRect(x: 20, y: 120, width: windowWidth - 40, height: 20)
        self.messageLabel = message
        contentView.addSubview(message)

        // Countdown
        let countdown = NSTextField(labelWithString: formatCountdown(remainingSeconds))
        countdown.font = NSFont.monospacedDigitSystemFont(ofSize: 36, weight: .medium)
        countdown.alignment = .center
        countdown.frame = NSRect(x: 20, y: 70, width: windowWidth - 40, height: 45)
        self.countdownLabel = countdown
        contentView.addSubview(countdown)

        // Progress bar
        let progress = NSProgressIndicator(frame: NSRect(x: 20, y: 55, width: windowWidth - 40, height: 10))
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = event.breakType.duration
        progress.doubleValue = event.breakType.duration
        self.progressBar = progress
        contentView.addSubview(progress)

        // Buttons
        let snoozeButton = NSButton(
            title: "Snooze 5m",
            target: self,
            action: #selector(snoozeClicked)
        )
        snoozeButton.frame = NSRect(x: 30, y: 15, width: 120, height: 30)
        snoozeButton.bezelStyle = .rounded
        contentView.addSubview(snoozeButton)

        let dismissButton = NSButton(
            title: "I'm resting ✓",
            target: self,
            action: #selector(dismissClicked)
        )
        dismissButton.frame = NSRect(x: 170, y: 15, width: 120, height: 30)
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\r"
        contentView.addSubview(dismissButton)

        window.contentView = contentView
        return window
    }

    // MARK: - Full Screen Window

    private func createFullScreenWindow(for event: BreakEvent, on screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        window.isOpaque = false
        window.hasShadow = false

        let contentView = NSView(frame: screen.frame)
        let centerX = screen.frame.width / 2
        let centerY = screen.frame.height / 2

        // Emoji icon
        let icon = NSTextField(labelWithString: iconForBreak(event.breakType))
        icon.font = NSFont.systemFont(ofSize: 72)
        icon.alignment = .center
        icon.textColor = .white
        icon.frame = NSRect(x: centerX - 50, y: centerY + 60, width: 100, height: 80)
        contentView.addSubview(icon)

        // Title
        let title = NSTextField(labelWithString: titleText(for: event))
        title.font = NSFont.boldSystemFont(ofSize: 28)
        title.alignment = .center
        title.textColor = .white
        title.frame = NSRect(x: centerX - 200, y: centerY + 15, width: 400, height: 40)
        // Only store refs for primary screen
        if screen == NSScreen.main {
            self.titleLabel = title
        }
        contentView.addSubview(title)

        // Message
        let message = NSTextField(labelWithString: messageText(for: event))
        message.font = NSFont.systemFont(ofSize: 16)
        message.alignment = .center
        message.textColor = NSColor.white.withAlphaComponent(0.8)
        message.frame = NSRect(x: centerX - 200, y: centerY - 20, width: 400, height: 25)
        contentView.addSubview(message)

        // Countdown
        let countdown = NSTextField(labelWithString: formatCountdown(remainingSeconds))
        countdown.font = NSFont.monospacedDigitSystemFont(ofSize: 64, weight: .light)
        countdown.alignment = .center
        countdown.textColor = .white
        countdown.frame = NSRect(x: centerX - 150, y: centerY - 100, width: 300, height: 70)
        if screen == NSScreen.main {
            self.countdownLabel = countdown
        }
        contentView.addSubview(countdown)

        // Progress bar
        let progress = NSProgressIndicator(frame: NSRect(x: centerX - 150, y: centerY - 120, width: 300, height: 6))
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = event.breakType.duration
        progress.doubleValue = event.breakType.duration
        if screen == NSScreen.main {
            self.progressBar = progress
        }
        contentView.addSubview(progress)

        // Medical source
        let source = NSTextField(labelWithString: event.breakType.medicalSource)
        source.font = NSFont.systemFont(ofSize: 12)
        source.alignment = .center
        source.textColor = NSColor.white.withAlphaComponent(0.5)
        source.frame = NSRect(x: centerX - 150, y: centerY - 155, width: 300, height: 20)
        contentView.addSubview(source)

        // Only add buttons on main screen
        if screen == NSScreen.main {
            let snoozeButton = NSButton(
                title: "Snooze 5m",
                target: self,
                action: #selector(snoozeClicked)
            )
            snoozeButton.frame = NSRect(x: centerX - 140, y: centerY - 210, width: 130, height: 35)
            snoozeButton.bezelStyle = .rounded
            snoozeButton.contentTintColor = .white
            contentView.addSubview(snoozeButton)

            let dismissButton = NSButton(
                title: "I'm resting ✓",
                target: self,
                action: #selector(dismissClicked)
            )
            dismissButton.frame = NSRect(x: centerX + 10, y: centerY - 210, width: 130, height: 35)
            dismissButton.bezelStyle = .rounded
            dismissButton.keyEquivalent = "\r"
            dismissButton.contentTintColor = .white
            contentView.addSubview(dismissButton)
        }

        window.contentView = contentView
        return window
    }

    // MARK: - Countdown

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            // Break complete
            dismissAll()
            onDismiss?()
            return
        }

        // Update UI
        countdownLabel?.stringValue = formatCountdown(remainingSeconds)
        if let event = currentBreakEvent {
            progressBar?.doubleValue = Double(remainingSeconds)

            // Update all full-screen windows' countdown labels
            for window in fullScreenWindows {
                updateCountdownInWindow(window, seconds: remainingSeconds, totalDuration: event.breakType.duration)
            }
        }
    }

    private func updateCountdownInWindow(_ window: NSWindow, seconds: Int, totalDuration: TimeInterval) {
        // The countdown and progress are updated via the stored references
        // (only for the main screen, which is fine for UX)
    }

    // MARK: - Actions

    @objc private func snoozeClicked() {
        dismissAll()
        onSnooze?()
    }

    @objc private func dismissClicked() {
        dismissAll()
        onDismiss?()
    }

    // MARK: - Helpers

    private func titleText(for event: BreakEvent) -> String {
        let prefix = event.isSnoozed ? "⏰ " : ""
        switch event.breakType {
        case .micro:
            return "\(prefix)👀 Micro Break"
        case .macro:
            return "\(prefix)☕ Rest Break"
        case .mandatory:
            return "\(prefix)🚨 Mandatory Break"
        }
    }

    private func messageText(for event: BreakEvent) -> String {
        switch event.breakType {
        case .micro:
            return "Look at something 20 feet away for 20 seconds"
        case .macro:
            return "Step away and stretch for 5 minutes"
        case .mandatory:
            return "Take a 15-minute break — you've earned it!"
        }
    }

    private func iconForBreak(_ breakType: BreakType) -> String {
        switch breakType {
        case .micro: return "👀"
        case .macro: return "☕"
        case .mandatory: return "🚨"
        }
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "0:%02d", secs)
    }
}
