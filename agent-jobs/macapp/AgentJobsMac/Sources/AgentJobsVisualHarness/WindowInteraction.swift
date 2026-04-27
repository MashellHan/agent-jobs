import Foundation
import AppKit

/// Drives the Agent Jobs main window for visual-harness scenarios.
///
/// All operations run on `@MainActor` because they touch `NSWindow`. They
/// are best-effort: when the window is not present yet (the app scene
/// hasn't created it), `locateMainWindow()` returns `nil` and the other
/// methods become no-ops rather than throw — visual harness scenarios
/// should call `locateMainWindow()` first and gate on its result.
public enum WindowInteraction {

    public enum Error: Swift.Error, CustomStringConvertible {
        case notFound
        public var description: String {
            switch self {
            case .notFound: return "Main 'Agent Jobs' window not found in NSApp.windows"
            }
        }
    }

    /// Title and identifier the main scene uses (kept in sync with
    /// `AgentJobsAppScene` — the dashboard `Window` declares
    /// `id: "dashboard"` and `title: "Agent Jobs"`).
    public static let mainWindowTitle = "Agent Jobs"
    public static let mainWindowIdentifier = "dashboard"

    @MainActor
    public static func locateMainWindow() -> NSWindow? {
        // NSApp may be nil under raw `swift run` of a non-AppKit binary.
        guard let app = NSApp else { return nil }
        return app.windows.first {
            $0.title == mainWindowTitle
            || $0.identifier?.rawValue == mainWindowIdentifier
        }
    }

    /// Resize the main window to `size`. Pins the window's top-left so
    /// the resize feels intentional, not "jumped". Throws `.notFound` if
    /// the dashboard window doesn't exist yet.
    @MainActor
    public static func resizeMainWindow(to size: CGSize) throws {
        guard let win = locateMainWindow() else { throw Error.notFound }
        let topLeft = NSPoint(x: win.frame.minX, y: win.frame.maxY)
        var newFrame = win.frame
        newFrame.size = size
        newFrame.origin.y = topLeft.y - size.height
        win.setFrame(newFrame, display: true, animate: false)
    }

    /// Synthesize a vertical scroll on the key window's first responder by
    /// posting an NSScrollWheel-equivalent CGEvent. Best-effort.
    @MainActor
    public static func scrollList(by lines: Int) {
        guard let win = locateMainWindow() else { return }
        let center = NSPoint(x: win.frame.midX, y: win.frame.midY)
        let cg = CGEvent(scrollWheelEvent2Source: nil,
                         units: .line,
                         wheelCount: 1,
                         wheel1: Int32(-lines),
                         wheel2: 0, wheel3: 0)
        cg?.location = CGPoint(x: center.x, y: NSScreen.main.map { $0.frame.height - center.y } ?? center.y)
        cg?.post(tap: .cghidEventTap)
    }

    /// Click the row at `index` by computing its rect from the table view's
    /// row count. No-op if the dashboard is not visible. Currently a stub:
    /// row geometry is owned by SwiftUI's List, which doesn't expose a
    /// per-row hitTest — the visual harness uses Snapshot-only scenarios,
    /// so click-by-row is reserved for future critique scenarios.
    @MainActor
    public static func clickRow(at index: Int) {
        // Reserved for a follow-up task that targets specific row views
        // (e.g. MenuBarRichRow) by accessibility identifier.
        _ = index
    }
}
