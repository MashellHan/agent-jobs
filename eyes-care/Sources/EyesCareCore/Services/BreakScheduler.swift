import Foundation

/// Determines when breaks should be triggered based on elapsed active time.
///
/// The scheduler tracks time since last break for each `BreakType` independently.
/// When `sinceLastBreak` exceeds a break type's interval, that break is due.
///
/// ## Priority
/// If multiple breaks are due simultaneously, the highest-priority break wins:
/// `mandatory > macro > micro`
public struct BreakScheduler: Sendable {

    /// Check which break (if any) is due given the time since last break.
    ///
    /// - Parameters:
    ///   - sinceLastBreak: Seconds since the user's last natural break or triggered break.
    ///   - lastMicroBreak: Date of last micro break (nil if never taken).
    ///   - lastMacroBreak: Date of last macro break (nil if never taken).
    ///   - lastMandatoryBreak: Date of last mandatory break (nil if never taken).
    ///   - now: Current date (injectable for testing).
    /// - Returns: The highest-priority `BreakType` that is due, or `nil`.
    public static func breakDue(
        sinceLastMicroBreak: TimeInterval,
        sinceLastMacroBreak: TimeInterval,
        sinceLastMandatoryBreak: TimeInterval
    ) -> BreakType? {
        // Check highest priority first
        if sinceLastMandatoryBreak >= BreakType.mandatory.interval {
            return .mandatory
        }
        if sinceLastMacroBreak >= BreakType.macro.interval {
            return .macro
        }
        if sinceLastMicroBreak >= BreakType.micro.interval {
            return .micro
        }
        return nil
    }

    /// Calculate time remaining until the next break of a given type.
    ///
    /// - Parameters:
    ///   - breakType: The type of break to check.
    ///   - sinceLastBreak: Seconds since the last break of this type.
    /// - Returns: Seconds remaining, or 0 if the break is overdue.
    public static func timeUntilBreak(
        _ breakType: BreakType,
        sinceLastBreak: TimeInterval
    ) -> TimeInterval {
        max(0, breakType.interval - sinceLastBreak)
    }
}
