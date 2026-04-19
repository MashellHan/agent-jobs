import Foundation

/// Protocol for sending break reminder notifications.
///
/// Abstracts the notification delivery mechanism for testability.
/// Production uses `SystemNotificationService` (UNUserNotificationCenter).
/// Tests inject a mock.
@MainActor
public protocol NotificationSending: AnyObject {
    /// Send a break reminder notification.
    ///
    /// - Parameters:
    ///   - breakEvent: The break event that triggered this notification.
    ///   - mode: The reminder mode (gentle/normal/aggressive).
    func sendBreakReminder(
        for breakEvent: BreakEvent,
        mode: ReminderMode
    )

    /// Request notification permissions from the user.
    func requestPermissions() async
}
