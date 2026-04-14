import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    var monitoringService: MonitoringService?
    var notificationService: NotificationService?
    var breakWindowService: BreakWindowService?
    private var midnightTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notifService = NotificationService(appState: appState)
        let monService = MonitoringService(appState: appState)
        let breakService = BreakWindowService(appState: appState)

        monService.setNotificationService(notifService)
        monService.setBreakWindowService(breakService)
        notifService.setMonitoringService(monService)
        breakService.setMonitoringService(monService)

        monitoringService = monService
        notificationService = notifService
        breakWindowService = breakService

        notifService.requestPermission()
        monService.startMonitoring()

        scheduleMidnightReset()
    }

    private func scheduleMidnightReset() {
        midnightTimer?.invalidate()

        guard let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let interval = nextMidnight.timeIntervalSinceNow

        let timer = Timer.scheduledTimer(
            withTimeInterval: max(interval, 1),
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.appState.resetDaily()
            self.scheduleMidnightReset()
        }

        RunLoop.current.add(timer, forMode: .common)
        midnightTimer = timer
    }
}

@main
struct EyesHealthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                appState: appDelegate.appState,
                onTakeBreak: { [weak appDelegate] in
                    appDelegate?.monitoringService?.takeBreakNow()
                }
            )
        } label: {
            let color = appDelegate.appState.statusColor
            Label("EyesHealth", systemImage: color.systemName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(color.color)
        }
        .menuBarExtraStyle(.window)
    }
}
