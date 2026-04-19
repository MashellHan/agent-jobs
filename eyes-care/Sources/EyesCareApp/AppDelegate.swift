import AppKit
import EyesCareCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Menu Bar

    private var statusItem: NSStatusItem?

    // Menu item references for dynamic updates
    private var statusMenuItem: NSMenuItem?
    private var activeTimeMenuItem: NSMenuItem?
    private var sinceLastBreakMenuItem: NSMenuItem?
    private var nextBreakMenuItem: NSMenuItem?
    private var toggleMenuItem: NSMenuItem?

    // Mode menu items
    private var gentleMenuItem: NSMenuItem?
    private var normalMenuItem: NSMenuItem?
    private var aggressiveMenuItem: NSMenuItem?

    // MARK: - Monitoring

    private var monitoringSession: MonitoringSession?
    private var notificationService: SystemNotificationService?
    private let breakWindowController = BreakWindowController()

    // MARK: - Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMonitoring()
        setupMenuBar()
        monitoringSession?.start()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        monitoringSession?.pause()
    }

    // MARK: - Setup

    private func setupMonitoring() {
        let session = MonitoringSession()
        session.delegate = self

        // Set up system notifications
        let notifService = SystemNotificationService()
        session.setupNotifications(notifService)
        self.notificationService = notifService

        // Set up break window callbacks
        breakWindowController.onDismiss = { [weak self] in
            self?.monitoringSession?.recordBreak(.micro)
        }
        breakWindowController.onSnooze = { [weak self] in
            // Re-trigger after snooze duration
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(Constants.snoozeDuration))
                guard let session = self.monitoringSession,
                      session.isMonitoring else { return }
                let event = BreakEvent(breakType: .micro, isSnoozed: true)
                self.showBreakUI(for: event, mode: session.reminderMode)
            }
        }

        monitoringSession = session
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "eye",
                accessibilityDescription: "EyesCare"
            )
        }

        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(
            title: "EyesCare v3.0",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        let statusItem = NSMenuItem(
            title: "● Monitoring",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        self.statusMenuItem = statusItem
        menu.addItem(statusItem)

        // Active time
        let activeTimeItem = NSMenuItem(
            title: "Active Time: < 1m",
            action: nil,
            keyEquivalent: ""
        )
        activeTimeItem.isEnabled = false
        self.activeTimeMenuItem = activeTimeItem
        menu.addItem(activeTimeItem)

        // Since last break
        let sinceLastBreakItem = NSMenuItem(
            title: "Since Last Break: < 1m",
            action: nil,
            keyEquivalent: ""
        )
        sinceLastBreakItem.isEnabled = false
        self.sinceLastBreakMenuItem = sinceLastBreakItem
        menu.addItem(sinceLastBreakItem)

        // Next break
        let nextBreakItem = NSMenuItem(
            title: "Next Break: Micro in 20m",
            action: nil,
            keyEquivalent: ""
        )
        nextBreakItem.isEnabled = false
        self.nextBreakMenuItem = nextBreakItem
        menu.addItem(nextBreakItem)

        menu.addItem(NSMenuItem.separator())

        // Reminder Mode submenu
        let modeSubmenu = NSMenu()

        let gentleItem = NSMenuItem(
            title: "Gentle — Banner only",
            action: #selector(selectGentleMode),
            keyEquivalent: ""
        )
        gentleItem.target = self
        gentleItem.state = .on
        self.gentleMenuItem = gentleItem
        modeSubmenu.addItem(gentleItem)

        let normalItem = NSMenuItem(
            title: "Normal — Banner + Window",
            action: #selector(selectNormalMode),
            keyEquivalent: ""
        )
        normalItem.target = self
        self.normalMenuItem = normalItem
        modeSubmenu.addItem(normalItem)

        let aggressiveItem = NSMenuItem(
            title: "Aggressive — Full Screen",
            action: #selector(selectAggressiveMode),
            keyEquivalent: ""
        )
        aggressiveItem.target = self
        self.aggressiveMenuItem = aggressiveItem
        modeSubmenu.addItem(aggressiveItem)

        let modeItem = NSMenuItem(
            title: "Reminder Mode",
            action: nil,
            keyEquivalent: ""
        )
        modeItem.submenu = modeSubmenu
        menu.addItem(modeItem)

        menu.addItem(NSMenuItem.separator())

        // Take break now
        let takeBreakItem = NSMenuItem(
            title: "Take a Break Now",
            action: #selector(takeBreakNow),
            keyEquivalent: "b"
        )
        takeBreakItem.target = self
        menu.addItem(takeBreakItem)

        // Toggle
        let toggleItem = NSMenuItem(
            title: "Pause Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        toggleItem.target = self
        self.toggleMenuItem = toggleItem
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit EyesCare",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleMonitoring() {
        guard let session = monitoringSession else { return }

        if session.isMonitoring {
            session.pause()
        } else {
            session.start()
        }
    }

    @objc private func takeBreakNow() {
        monitoringSession?.recordBreak(.micro)
    }

    @objc private func selectGentleMode() {
        setReminderMode(.gentle)
    }

    @objc private func selectNormalMode() {
        setReminderMode(.normal)
    }

    @objc private func selectAggressiveMode() {
        setReminderMode(.aggressive)
    }

    private func setReminderMode(_ mode: ReminderMode) {
        monitoringSession?.reminderMode = mode
        updateModeMenuItems(mode)
    }

    private func updateModeMenuItems(_ mode: ReminderMode) {
        gentleMenuItem?.state = mode == .gentle ? .on : .off
        normalMenuItem?.state = mode == .normal ? .on : .off
        aggressiveMenuItem?.state = mode == .aggressive ? .on : .off
    }

    // MARK: - Menu Updates

    private func updateMenu(with status: MonitoringStatus) {
        // Icon
        let iconName = status.isMonitoring ? "eye" : "eye.slash"
        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "EyesCare"
        )

        // Status text
        if status.isMonitoring {
            let stateText: String
            switch status.activityState {
            case .active:
                stateText = "● Monitoring"
            case .idle:
                stateText = "● Monitoring (Idle)"
            case .away:
                stateText = "● Monitoring (Idle)"
            }
            statusMenuItem?.title = stateText
        } else {
            statusMenuItem?.title = "○ Paused"
        }

        // Active time
        if status.isMonitoring {
            let formatted = TimeFormatter.formatActiveTime(status.activeTime)
            activeTimeMenuItem?.title = "Active Time: \(formatted)"
        } else {
            activeTimeMenuItem?.title = "Active Time: \(TimeFormatter.pausedPlaceholder)"
        }

        // Since last break
        if status.isMonitoring {
            let isIdle = status.activityState == .idle
                || status.activityState == .away
            let formatted = TimeFormatter.formatSinceLastBreak(
                status.sinceLastBreak,
                isIdle: isIdle
            )
            sinceLastBreakMenuItem?.title = "Since Last Break: \(formatted)"
        } else {
            sinceLastBreakMenuItem?.title = "Since Last Break: \(TimeFormatter.pausedPlaceholder)"
        }

        // Next break
        if status.isMonitoring, let nextType = status.nextBreakType {
            let remaining = TimeFormatter.formatActiveTime(status.timeUntilNextBreak)
            if status.timeUntilNextBreak <= 0 {
                nextBreakMenuItem?.title = "⚠️ \(nextType.displayName) OVERDUE"
            } else {
                nextBreakMenuItem?.title = "Next: \(nextType.displayName) in \(remaining)"
            }
        } else if !status.isMonitoring {
            nextBreakMenuItem?.title = "Next Break: \(TimeFormatter.pausedPlaceholder)"
        }

        // Toggle button label
        toggleMenuItem?.title = status.isMonitoring
            ? "Pause Monitoring"
            : "Resume Monitoring"

        // Mode checkmarks
        updateModeMenuItems(status.reminderMode)
    }
}

// MARK: - MonitoringSessionDelegate

extension AppDelegate: MonitoringSessionDelegate {
    public func monitoringSessionDidUpdate(_ status: MonitoringStatus) {
        updateMenu(with: status)
    }

    public func monitoringSessionDidTriggerBreak(_ event: BreakEvent) {
        guard let session = monitoringSession else { return }
        showBreakUI(for: event, mode: session.reminderMode)
    }

    // MARK: - Break UI

    private func showBreakUI(for event: BreakEvent, mode: ReminderMode) {
        switch mode {
        case .gentle:
            // System notification only — already handled by MonitoringSession + SystemNotificationService
            break
        case .normal:
            // System notification + floating window
            breakWindowController.showFloatingWindow(for: event)
        case .aggressive:
            // System notification + full-screen overlay
            breakWindowController.showFullScreenOverlay(for: event)
        }
    }
}
