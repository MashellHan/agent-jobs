import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let mascotState = MascotState()
    var monitoringService: MonitoringService?
    var notificationService: NotificationService?
    var breakWindowService: BreakWindowService?
    var mascotWindowService: MascotWindowService?
    private var midnightTimer: Timer?
    private var mascotUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notifService = NotificationService(appState: appState)
        let monService = MonitoringService(appState: appState, mascotState: mascotState)
        let breakService = BreakWindowService(appState: appState)
        let mascotService = MascotWindowService(appState: appState, mascotState: mascotState)

        monService.setNotificationService(notifService)
        monService.setBreakWindowService(breakService)
        notifService.setMonitoringService(monService)
        breakService.setMonitoringService(monService)

        monitoringService = monService
        notificationService = notifService
        breakWindowService = breakService
        mascotWindowService = mascotService

        notifService.requestPermission()
        monService.startMonitoring()

        // Show mascot if enabled (defaults to true)
        let showMascot = UserDefaults.standard.object(forKey: Constants.showMascotKey) as? Bool ?? true
        if showMascot {
            mascotService.show()
        }

        startMascotStateSync()
        scheduleMidnightReset()
    }

    /// Periodically sync mascot expression with app state.
    private func startMascotStateSync() {
        let timer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            self.mascotState.updateFromAppState(self.appState)
        }
        RunLoop.current.add(timer, forMode: .common)
        mascotUpdateTimer = timer
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
                },
                showMascot: Binding(
                    get: {
                        UserDefaults.standard.object(forKey: Constants.showMascotKey) as? Bool ?? true
                    },
                    set: { [weak appDelegate] newValue in
                        UserDefaults.standard.set(newValue, forKey: Constants.showMascotKey)
                        if newValue {
                            appDelegate?.mascotWindowService?.show()
                        } else {
                            appDelegate?.mascotWindowService?.hide()
                        }
                    }
                )
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
