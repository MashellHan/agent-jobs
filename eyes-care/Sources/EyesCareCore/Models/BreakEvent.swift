import Foundation

/// Represents a break that has been triggered or is pending.
///
/// Used to communicate between `BreakScheduler` and notification/UI layers.
public struct BreakEvent: Sendable, Equatable {
    /// The type of break (micro, macro, mandatory).
    public let breakType: BreakType

    /// When the break was triggered.
    public let triggeredAt: Date

    /// Whether this break was snoozed by the user.
    public let isSnoozed: Bool

    public init(
        breakType: BreakType,
        triggeredAt: Date = Date(),
        isSnoozed: Bool = false
    ) {
        self.breakType = breakType
        self.triggeredAt = triggeredAt
        self.isSnoozed = isSnoozed
    }

    /// A snoozed copy of this event.
    public func snoozed() -> BreakEvent {
        BreakEvent(
            breakType: breakType,
            triggeredAt: triggeredAt,
            isSnoozed: true
        )
    }
}
