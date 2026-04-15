import Foundation

/// Abstracts idle-time detection for testability.
///
/// Production code uses `CGEventSourceIdleDetector`.
/// Tests inject `MockIdleDetector` with controllable values.
public protocol IdleDetecting: Sendable {
    /// Returns the number of seconds since the user's last input event.
    func secondsSinceLastEvent() -> TimeInterval
}
