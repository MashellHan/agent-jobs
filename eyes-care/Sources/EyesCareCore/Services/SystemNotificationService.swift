import Foundation
import UserNotifications

/// Sends break reminders via macOS system notifications (UNUserNotificationCenter).
///
/// This is the production implementation of `NotificationSending`.
/// It handles:
/// - Requesting notification permissions
/// - Building notification content based on `BreakType`
/// - Delivering notifications with snooze action support
///
/// Note: UNUserNotificationCenter requires a proper app bundle with Info.plist.
/// When running as a bare executable (swift build), notifications will be skipped gracefully.
@MainActor
public final class SystemNotificationService: NSObject, NotificationSending {

    private var center: UNUserNotificationCenter?
    private var permissionGranted = false
    private var isAvailable = false

    // MARK: - Notification Category & Action IDs

    private static let breakCategoryID = "EYESCARE_BREAK"
    private static let snoozeActionID = "SNOOZE_ACTION"
    private static let dismissActionID = "DISMISS_ACTION"

    public override init() {
        super.init()
        setupCenter()
    }

    private func setupCenter() {
        // UNUserNotificationCenter.current() crashes without a bundle.
        // Guard against that by checking Bundle.main.bundleIdentifier.
        guard Bundle.main.bundleIdentifier != nil else {
            isAvailable = false
            return
        }

        do {
            center = UNUserNotificationCenter.current()
            isAvailable = true
            registerCategories()
        }
    }

    // MARK: - NotificationSending

    public func requestPermissions() async {
        guard isAvailable, let center else { return }
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    public func sendBreakReminder(
        for breakEvent: BreakEvent,
        mode: ReminderMode
    ) {
        guard isAvailable, let center else { return }
        let content = buildContent(for: breakEvent)

        let request = UNNotificationRequest(
            identifier: "eyescare-\(breakEvent.breakType.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { _ in }
    }

    // MARK: - Private

    private func registerCategories() {
        guard let center else { return }
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 5 min",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: Self.dismissActionID,
            title: "OK, taking a break",
            options: .destructive
        )

        let breakCategory = UNNotificationCategory(
            identifier: Self.breakCategoryID,
            actions: [dismissAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([breakCategory])
    }

    private func buildContent(
        for breakEvent: BreakEvent
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Self.breakCategoryID
        content.sound = .default

        switch breakEvent.breakType {
        case .micro:
            content.title = "👀 Time for a Micro Break!"
            content.body = "Look at something 20 feet away for 20 seconds. (AAO 20-20-20 Rule)"

        case .macro:
            content.title = "☕ Time for a Rest Break!"
            content.body = "Step away from the screen for 5 minutes. Stretch and move around. (OSHA)"

        case .mandatory:
            content.title = "🚨 Mandatory Break Time!"
            content.body = "You've been working for 2 hours. Take a 15-minute break. (EU Directive)"
        }

        if breakEvent.isSnoozed {
            content.title = "⏰ Reminder: \(content.title)"
        }

        return content
    }
}
