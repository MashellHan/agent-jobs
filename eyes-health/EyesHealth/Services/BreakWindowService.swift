import AppKit
import SwiftUI

/// Manages the floating NSPanel that shows a 20-second break countdown.
/// The panel is `.floating` level, appears in the top-right corner, and
/// auto-dismisses once the countdown completes.
///
/// Also manages the full-screen overlay window used in aggressive mode.
final class BreakWindowService {
    private var panel: NSPanel?
    private var fullScreenWindow: NSWindow?
    private let appState: AppState
    private weak var monitoringService: MonitoringService?

    init(appState: AppState) {
        self.appState = appState
    }

    func setMonitoringService(_ service: MonitoringService) {
        monitoringService = service
    }

    // MARK: - Show / Dismiss

    func showBreakWindow() {
        guard panel == nil else { return }

        let floatingView = FloatingBreakView(
            onSkip: { [weak self] in
                self?.dismiss()
            },
            onCountdownComplete: { [weak self] in
                self?.handleCountdownComplete()
            }
        )

        let hostingView = NSHostingView(rootView: floatingView)
        hostingView.frame = NSRect(
            x: 0, y: 0,
            width: Constants.floatingWindowWidth,
            height: Constants.floatingWindowHeight
        )

        let newPanel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.contentView = hostingView
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.isMovableByWindowBackground = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        positionTopRight(newPanel)

        newPanel.orderFrontRegardless()
        panel = newPanel
    }

    // MARK: - Full-Screen Break (Aggressive Mode)

    func showFullScreenBreak() {
        guard fullScreenWindow == nil else { return }
        guard let screen = NSScreen.main else { return }

        let breakView = FullScreenBreakView(
            onSkip: { [weak self] in
                self?.dismissFullScreen()
            },
            onComplete: { [weak self] in
                self?.handleFullScreenComplete()
            }
        )

        let hostingView = NSHostingView(rootView: breakView)
        hostingView.frame = screen.frame

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()

        fullScreenWindow = window
    }

    func dismiss() {
        panel?.close()
        panel = nil
        dismissFullScreen()
    }

    // MARK: - Private (Full-Screen)

    private func dismissFullScreen() {
        fullScreenWindow?.close()
        fullScreenWindow = nil
    }

    private func handleFullScreenComplete() {
        monitoringService?.takeBreakNow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.dismissFullScreen()
        }
    }

    // MARK: - Private

    private func handleCountdownComplete() {
        // Auto-record break when countdown finishes
        monitoringService?.takeBreakNow()

        // Brief delay so user sees "Done!" before window closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismiss()
        }
    }

    private func positionTopRight(_ window: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size

        let x = screenFrame.maxX - windowSize.width - 16
        let y = screenFrame.maxY - windowSize.height - 16

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
