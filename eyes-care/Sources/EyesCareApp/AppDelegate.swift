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
    private var toggleMenuItem: NSMenuItem?

    // MARK: - Monitoring

    private var monitoringSession: MonitoringSession?

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
            title: "EyesCare v1.0",
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

        menu.addItem(NSMenuItem.separator())

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

        // Toggle button label
        toggleMenuItem?.title = status.isMonitoring
            ? "Pause Monitoring"
            : "Resume Monitoring"
    }
}

// MARK: - MonitoringSessionDelegate

extension AppDelegate: MonitoringSessionDelegate {
    public func monitoringSessionDidUpdate(_ status: MonitoringStatus) {
        updateMenu(with: status)
    }
}
