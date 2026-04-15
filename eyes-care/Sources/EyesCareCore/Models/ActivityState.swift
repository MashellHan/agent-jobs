import Foundation

/// User activity state derived from idle time.
///
/// State transitions:
/// - `active`: idle seconds < `idleThreshold` (default 30s)
/// - `idle`: idle seconds >= `idleThreshold` and < `naturalBreakThreshold`
/// - `away`: idle seconds >= `naturalBreakThreshold` (default 120s) — treated as natural break
public enum ActivityState: String, Sendable, Equatable, Codable, CaseIterable {
    case active
    case idle
    case away

    /// Derive activity state from the number of seconds since last user input.
    ///
    /// - Parameters:
    ///   - idleSeconds: Seconds since the user's last keyboard/mouse event.
    ///   - idleThreshold: Seconds before the user is considered idle.
    ///   - naturalBreakThreshold: Seconds before idle is promoted to a natural break.
    /// - Returns: The derived `ActivityState`.
    public static func from(
        idleSeconds: TimeInterval,
        idleThreshold: TimeInterval = Constants.idleThreshold,
        naturalBreakThreshold: TimeInterval = Constants.naturalBreakThreshold
    ) -> ActivityState {
        if idleSeconds >= naturalBreakThreshold { return .away }
        if idleSeconds >= idleThreshold { return .idle }
        return .active
    }
}
