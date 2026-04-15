import AppKit
import SwiftUI

/// Manages a floating NSPanel that hosts the cute eye mascot character.
///
/// The panel is non-activating (doesn't steal focus), draggable, transparent,
/// and positioned in the bottom-right of the primary screen by default.
/// It lives at `.floating` level so it stays on top without being intrusive.
final class MascotWindowService {
    private var panel: NSPanel?
    private let mascotState: MascotState
    private let appState: AppState

    init(appState: AppState, mascotState: MascotState) {
        self.appState = appState
        self.mascotState = mascotState
    }

    // MARK: - Show / Hide

    func show() {
        guard panel == nil else {
            panel?.orderFrontRegardless()
            return
        }

        let mascotView = MascotView(
            expression: mascotState.expression,
            speechText: mascotState.speechText
        )

        // Wrap in an observable container so the panel updates reactively
        let observingView = MascotContainerView(
            mascotState: mascotState
        )

        let hostingView = NSHostingView(rootView: observingView)
        hostingView.frame = NSRect(
            x: 0, y: 0,
            width: Constants.mascotWindowWidth,
            height: Constants.mascotWindowHeight
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
        newPanel.hasShadow = false
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.isMovableByWindowBackground = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.hidesOnDeactivate = false

        positionBottomRight(newPanel)
        newPanel.orderFrontRegardless()
        panel = newPanel

        // Suppress the unused variable warning
        _ = mascotView
    }

    func hide() {
        panel?.close()
        panel = nil
    }

    var isShowing: Bool {
        panel != nil
    }

    // MARK: - Positioning

    private func positionBottomRight(_ window: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size

        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.minY + 20

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Container View

/// A SwiftUI view that observes MascotState and passes current values to MascotView.
/// This enables the NSHostingView to react to state changes.
private struct MascotContainerView: View {
    let mascotState: MascotState

    var body: some View {
        MascotView(
            expression: mascotState.expression,
            speechText: mascotState.speechText
        )
        .frame(
            width: Constants.mascotWindowWidth,
            height: Constants.mascotWindowHeight
        )
    }
}
