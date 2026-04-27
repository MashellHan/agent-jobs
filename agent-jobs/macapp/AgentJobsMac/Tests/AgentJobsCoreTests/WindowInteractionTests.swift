import Testing
import Foundation
import AppKit
@testable import AgentJobsVisualHarness

/// AC-F-04: WindowInteraction resize observable to ±1pt; locate is
/// resilient to "no window yet".
@Suite("WindowInteraction (M05 T06)", .serialized)
struct WindowInteractionTests {

    @MainActor
    @Test("locateMainWindow returns nil when no matching NSWindow is open")
    func locateNilWhenAbsent() {
        // The test process is `swift test` — no SwiftUI scene is mounted,
        // so we expect either nil (NSApp nil) or a non-matching window list.
        let win = WindowInteraction.locateMainWindow()
        #expect(win == nil)
    }

    @MainActor
    @Test("AC-F-04: resizeMainWindow throws .notFound when the dashboard isn't up")
    func resizeThrowsWhenAbsent() {
        do {
            try WindowInteraction.resizeMainWindow(to: CGSize(width: 1000, height: 700))
            Issue.record("expected .notFound")
        } catch WindowInteraction.Error.notFound {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @MainActor
    @Test("AC-F-04 positive: resize against an injected NSWindow updates frame within ±1pt",
          .enabled(if: ProcessInfo.processInfo.environment["AGENTJOBS_GUI_TESTS"] == "1"))
    func resizeAgainstInjectedWindow() throws {
        // Gated on AGENTJOBS_GUI_TESTS=1 because creating an NSWindow inside
        // `swift test` racing other suites' notification dispatches can SIGSEGV
        // on macOS 14 (NSApp not fully bootstrapped). The capture-all CLI
        // exercises the same code path against a real scene.
        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = WindowInteraction.mainWindowTitle
        win.identifier = NSUserInterfaceItemIdentifier(WindowInteraction.mainWindowIdentifier)
        defer { win.close() }

        let target = CGSize(width: 1024, height: 720)
        try WindowInteraction.resizeMainWindow(to: target)
        #expect(abs(win.frame.size.width - target.width) <= 1)
        #expect(abs(win.frame.size.height - target.height) <= 1)
    }

    @MainActor
    @Test("scrollList + clickRow are no-ops when window absent (don't crash)")
    func scrollAndClickAreSafe() {
        WindowInteraction.scrollList(by: 5)
        WindowInteraction.clickRow(at: 0)
        // No assertion — the test passes by not crashing.
    }
}
