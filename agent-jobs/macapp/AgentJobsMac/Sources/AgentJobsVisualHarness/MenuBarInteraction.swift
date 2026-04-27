import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

/// Drives the Agent Jobs `MenuBarExtra` for visual-harness scenarios.
///
/// Two coordinated paths:
///
/// 1. **In-process** (the only path the visual-harness CLI uses): post
///    `Notification.Name("AgentJobs.HarnessTogglePopover")` and let the
///    running app react. The app installs an observer in
///    `AgentJobsAppScene.body.task` that flips a popover state and posts
///    `AgentJobs.HarnessPopoverDidOpen` back. Synchronous + entitlement-free
///    + works under SwiftPM `swift run`.
/// 2. **Out-of-process AX** (`clickMenuExtraViaAX()` / `locate…`): walks the
///    system-wide accessibility tree to find the menu-bar item belonging to
///    the bundle, then synthesizes a CGEvent click. Requires
///    `AXIsProcessTrusted()`; raises `.accessibilityDenied` otherwise so
///    callers surface a clear "grant Accessibility" message instead of a
///    silent no-op.
public enum MenuBarInteraction {

    public enum Error: Swift.Error, CustomStringConvertible {
        case accessibilityDenied
        case notFound
        case eventPostFailed
        case timeout
        public var description: String {
            switch self {
            case .accessibilityDenied:
                return "Accessibility permission required — open System Settings ▸ Privacy & Security ▸ Accessibility and add the Agent Jobs binary."
            case .notFound:           return "Agent Jobs menu extra not found in the system AX tree"
            case .eventPostFailed:    return "CGEventPost failed (HID tap denied?)"
            case .timeout:            return "Popover did not open within timeout"
            }
        }
    }

    /// Notification names — kept on this type so app + harness agree.
    public static let togglePopoverNotification = Notification.Name("AgentJobs.HarnessTogglePopover")
    public static let popoverDidOpenNotification = Notification.Name("AgentJobs.HarnessPopoverDidOpen")
    public static let dismissPopoverNotification = Notification.Name("AgentJobs.HarnessDismissPopover")

    /// `true` when the harness must request Accessibility permission before
    /// using the AX-based out-of-process path. The in-process path does NOT
    /// need accessibility — it only flips a SwiftUI state via Notification.
    public static func requiresAccessibility() -> Bool {
        !AXIsProcessTrusted()
    }

    // MARK: - In-process (primary path used by capture-all)

    /// Open the popover by posting a Notification the app observes.
    /// Returns once the app has acknowledged via `popoverDidOpenNotification`,
    /// or after `timeout` seconds. Safe to call from any thread.
    @MainActor
    public static func clickMenuExtra(timeout: TimeInterval = 1.0) async throws {
        let center = NotificationCenter.default
        // Subscribe BEFORE posting so we don't miss a synchronous reply.
        let waiter = await waitForAck(timeout: timeout) {
            center.post(name: togglePopoverNotification, object: nil)
        }
        if !waiter { throw Error.timeout }
    }

    @MainActor
    private static func waitForAck(
        timeout: TimeInterval,
        afterSubscribe trigger: @MainActor () -> Void
    ) async -> Bool {
        let center = NotificationCenter.default
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let box = AckBox()
            box.token = center.addObserver(
                forName: popoverDidOpenNotification,
                object: nil, queue: .main
            ) { _ in
                guard !box.fired else { return }
                box.fired = true
                if let t = box.token { center.removeObserver(t) }
                cont.resume(returning: true)
            }
            trigger()
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                guard !box.fired else { return }
                box.fired = true
                if let t = box.token { center.removeObserver(t) }
                cont.resume(returning: false)
            }
        }
    }

    /// Mutable single-shot ack guard. `@MainActor`-isolated so the
    /// observer + timer callbacks (both delivered on the main queue)
    /// can safely poke at `fired` without crossing a Sendable boundary.
    @MainActor
    private final class AckBox {
        var fired = false
        var token: NSObjectProtocol?
    }

    /// Dismiss the popover by posting the dismiss notification. Best-effort,
    /// no acknowledgement required.
    @MainActor
    public static func dismissPopover() {
        NotificationCenter.default.post(name: dismissPopoverNotification, object: nil)
    }

    // MARK: - Out-of-process AX path

    /// Locate the bundle's menu-bar item rect via the system-wide AX tree.
    /// Returns `CGRect.null` if found-but-no-position; throws on missing
    /// permission or missing app.
    public static func locateAgentJobsMenuExtra(bundleHint: String = "Agent Jobs") throws -> CGRect {
        if !AXIsProcessTrusted() { throw Error.accessibilityDenied }
        // Find the running app whose name matches the hint (substring).
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(bundleHint)
        }) else {
            throw Error.notFound
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        // Read the extras menu bar attribute (kAXExtrasMenuBarAttribute on
        // newer SDKs; fall back to children walk).
        var ref: CFTypeRef?
        let attr = "AXExtrasMenuBar" as CFString
        let err = AXUIElementCopyAttributeValue(axApp, attr, &ref)
        if err != .success {
            throw Error.notFound
        }
        // The extras menu bar element exposes a position + size.
        let extrasElem = unsafeBitCast(ref, to: AXUIElement.self)
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(extrasElem, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(extrasElem, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            throw Error.notFound
        }
        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: pos, size: size)
    }

    /// Synthesize a left-click at the bundle's menu-extra rect via CGEvent.
    /// Out-of-process path — for visual-harness scenarios that drive a
    /// separately-launched app binary. The in-process scenarios should call
    /// `clickMenuExtra(timeout:)` instead.
    public static func clickMenuExtraViaAX(bundleHint: String = "Agent Jobs") throws {
        let rect = try locateAgentJobsMenuExtra(bundleHint: bundleHint)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard
            let down = CGEvent(mouseEventSource: nil,
                               mouseType: .leftMouseDown,
                               mouseCursorPosition: center,
                               mouseButton: .left),
            let up = CGEvent(mouseEventSource: nil,
                             mouseType: .leftMouseUp,
                             mouseCursorPosition: center,
                             mouseButton: .left)
        else {
            throw Error.eventPostFailed
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
