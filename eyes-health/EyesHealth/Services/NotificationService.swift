import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let appState: AppState
    private let center: UNUserNotificationCenter
    private var monitoringService: MonitoringService?
    private var hasScheduledReminder: Bool = false

    init(appState: AppState) {
        self.appState = appState
        self.center = UNUserNotificationCenter.current()
        super.init()
        center.delegate = self
        configureCategories()
    }

    func setMonitoringService(_ service: MonitoringService) {
        monitoringService = service
    }

    // MARK: - Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.appState.notificationPermissionGranted = granted
            }
            if let error {
                print("[NotificationService] Permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Categories & Actions

    private func configureCategories() {
        let takeBreakAction = UNNotificationAction(
            identifier: Constants.takeBreakActionID,
            title: "Take Break",
            options: .foreground
        )

        let snoozeAction = UNNotificationAction(
            identifier: Constants.snoozeActionID,
            title: "Snooze 5 min",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Constants.notificationCategoryID,
            actions: [takeBreakAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    // MARK: - Schedule / Cancel

    func scheduleBreakReminder() {
        guard !hasScheduledReminder else { return }
        hasScheduledReminder = true

        let content = UNMutableNotificationContent()
        content.title = Constants.notificationTitle
        content.body = Constants.notificationBody
        content.sound = .default
        content.categoryIdentifier = Constants.notificationCategoryID

        // Trigger immediately (1 second delay for UNTimeIntervalNotificationTrigger minimum)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "break-reminder-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationService] Schedule error: \(error.localizedDescription)")
            }
        }
    }

    func cancelPendingNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        hasScheduledReminder = false
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground (menu bar app is always "foreground")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Constants.snoozeActionID:
            // Snooze: don't count as break, wait 5 min then re-notify
            hasScheduledReminder = false
            monitoringService?.handleSnooze()

        case Constants.takeBreakActionID:
            // Take break: count as break, reset timer
            hasScheduledReminder = false
            monitoringService?.takeBreakNow()

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — treat as taking a break
            hasScheduledReminder = false
            monitoringService?.takeBreakNow()

        default:
            hasScheduledReminder = false
        }

        completionHandler()
    }
}
