import Foundation
import UserNotifications

final class NotificationService: NSObject {
    private let appState: AppState
    private let center: UNUserNotificationCenter
    private var monitoringService: MonitoringService?
    private var hasScheduledReminder: Bool = false

    init(appState: AppState) {
        self.appState = appState
        self.center = UNUserNotificationCenter.current()
        super.init()
    }

    func setMonitoringService(_ service: MonitoringService) {
        monitoringService = service
    }

    func scheduleBreakReminder() {
        // Stub — will be implemented in next commit
    }

    func cancelPendingNotifications() {
        // Stub — will be implemented in next commit
    }

    func requestPermission() {
        // Stub — will be implemented in next commit
    }
}
