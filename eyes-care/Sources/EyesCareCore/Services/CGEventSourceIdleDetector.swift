import CoreGraphics
import Foundation

/// Production idle detector using macOS `CGEventSource`.
///
/// Checks multiple event types (keyboard, mouse, click, scroll)
/// and returns the minimum idle time — ensuring any user activity is detected.
///
/// No Accessibility permission required.
public struct CGEventSourceIdleDetector: IdleDetecting {
    public init() {}

    public func secondsSinceLastEvent() -> TimeInterval {
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        let clickIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .leftMouseDown
        )
        let scrollIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .scrollWheel
        )
        return min(keyboardIdle, mouseIdle, clickIdle, scrollIdle)
    }
}
