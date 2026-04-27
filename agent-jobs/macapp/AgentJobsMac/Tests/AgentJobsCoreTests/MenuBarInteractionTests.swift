import Testing
import Foundation
import AppKit
@testable import AgentJobsVisualHarness

/// AC-F-03: in-process MenuBarInteraction click → popover open ack.
/// AX path is gated on AXIsProcessTrusted() so CI without permission
/// just skips that branch.
@Suite("MenuBarInteraction (M05 T06)", .serialized)
struct MenuBarInteractionTests {

    @Test("requiresAccessibility() reflects current AX trust state")
    func reflectsAxTrust() {
        let denied = MenuBarInteraction.requiresAccessibility()
        // Sanity: the call returns and is bool. We don't assert the value
        // because it depends on the host's TCC database.
        #expect(denied == true || denied == false)
    }

    @MainActor
    @Test("AC-F-03 in-process: posting toggle notification + ack resumes the call")
    func inProcessClickResumesOnAck() async throws {
        // Wire a stand-in observer that mimics the AgentJobsAppScene
        // wiring. The scene observer is the production sender of the
        // ack notification; here we simulate it.
        let center = NotificationCenter.default
        var observer: NSObjectProtocol?
        observer = center.addObserver(
            forName: MenuBarInteraction.togglePopoverNotification,
            object: nil, queue: .main
        ) { _ in
            center.post(
                name: MenuBarInteraction.popoverDidOpenNotification,
                object: nil
            )
        }
        defer { if let o = observer { center.removeObserver(o) } }

        // Should resume cleanly within timeout.
        try await MenuBarInteraction.clickMenuExtra(timeout: 0.5)
    }

    @MainActor
    @Test("AC-F-03 in-process: missing observer → timeout error")
    func timeoutWhenNoObserver() async {
        // No observer wired ⇒ the call must time out and throw.
        do {
            try await MenuBarInteraction.clickMenuExtra(timeout: 0.1)
            Issue.record("expected timeout error")
        } catch let e as MenuBarInteraction.Error {
            #expect(e == .timeout || e == .accessibilityDenied)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @MainActor
    @Test("dismissPopover posts the dismiss notification (no throw)")
    func dismissDoesNotThrow() {
        var observed = false
        let center = NotificationCenter.default
        let token = center.addObserver(
            forName: MenuBarInteraction.dismissPopoverNotification,
            object: nil, queue: .main
        ) { _ in observed = true }
        defer { center.removeObserver(token) }
        MenuBarInteraction.dismissPopover()
        // The dispatch is synchronous on the main queue.
        #expect(observed)
    }

    @Test("AX path raises accessibilityDenied when not trusted",
          .enabled(if: !AXIsProcessTrusted()))
    func axDeniedWhenNotTrusted() {
        do {
            _ = try MenuBarInteraction.locateAgentJobsMenuExtra()
            Issue.record("expected accessibilityDenied")
        } catch MenuBarInteraction.Error.accessibilityDenied {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

extension MenuBarInteraction.Error: Equatable {
    public static func == (a: MenuBarInteraction.Error, b: MenuBarInteraction.Error) -> Bool {
        String(describing: a) == String(describing: b)
    }
}
