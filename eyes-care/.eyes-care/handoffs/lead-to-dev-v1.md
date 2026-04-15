# Lead-to-Dev Handoff: EyesCare v1

**Date:** 2026-04-15
**From:** Lead Engineer Agent
**To:** Dev Agent
**Version:** v1 — Skeleton + Menu Bar + Basic Monitoring

---

## 1. Overview

This document breaks v1 implementation into **8 tasks**, each designed to be **one commit**. Follow the order strictly — each task builds on the previous one.

**Architecture docs to read first:**
- `.eyes-care/architecture/v1-architecture.md` — system design, data flow, type details
- `.eyes-care/architecture/v1-tech-decisions.md` — why each decision was made

**Key constraints:**
- Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — NOT XCTest
- All shared types must be `Sendable`
- `MonitoringSession` must be `@MainActor`
- Use `let` by default, `var` only when necessary
- No `print()` statements — use `os.Logger` if logging is needed
- No third-party dependencies
- Target: >= 80% test coverage on EyesCareCore

---

## 2. Task Breakdown

### Task 1: Add test target to Package.swift

**Files to modify:**
- `Package.swift`

**Changes:**
Add a `testTarget` for `EyesCareTests`:

```swift
.testTarget(
    name: "EyesCareTests",
    dependencies: ["EyesCareCore"],
    path: "Tests/EyesCareTests"
)
```

Also enable strict concurrency checking for all targets by adding `swiftSettings`:

```swift
swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency")
]
```

Apply this to all three targets (EyesCareCore, EyesCareApp, EyesCareTests).

**Delete:** `Tests/EyesCareTests/.gitkeep` (will be replaced by real test files)

**Acceptance criteria:**
- [ ] `swift build` succeeds with zero errors, zero warnings
- [ ] `swift test` runs (even if no tests exist yet)
- [ ] Strict concurrency is enabled

**Commit message:** `chore: add test target and enable strict concurrency`

---

### Task 2: Create ActivityState model

**Files to create:**
- `Sources/EyesCareCore/Models/ActivityState.swift`

**Implementation:**

```swift
import Foundation

/// User activity state derived from idle time.
///
/// State transitions:
/// - `active`: idle seconds < `idleThreshold` (default 30s)
/// - `idle`: idle seconds >= `idleThreshold` and < `naturalBreakThreshold`
/// - `away`: idle seconds >= `naturalBreakThreshold` (default 120s) — treated as natural break
public enum ActivityState: String, Sendable, Equatable, Codable, CaseIterable {
    case active
    case idle
    case away

    /// Derive activity state from the number of seconds since last user input.
    ///
    /// - Parameters:
    ///   - idleSeconds: Seconds since the user's last keyboard/mouse event.
    ///   - idleThreshold: Seconds before the user is considered idle.
    ///   - naturalBreakThreshold: Seconds before idle is promoted to a natural break.
    /// - Returns: The derived `ActivityState`.
    public static func from(
        idleSeconds: TimeInterval,
        idleThreshold: TimeInterval = Constants.idleThreshold,
        naturalBreakThreshold: TimeInterval = Constants.naturalBreakThreshold
    ) -> ActivityState {
        if idleSeconds >= naturalBreakThreshold { return .away }
        if idleSeconds >= idleThreshold { return .idle }
        return .active
    }
}
```

**Acceptance criteria:**
- [ ] `ActivityState` has exactly 3 cases: `.active`, `.idle`, `.away`
- [ ] `from(idleSeconds:)` returns correct state for all threshold boundaries
- [ ] Conforms to `Sendable`, `Equatable`, `Codable`, `CaseIterable`
- [ ] Uses `Constants.idleThreshold` and `Constants.naturalBreakThreshold` as defaults
- [ ] `swift build` succeeds

**Commit message:** `feat: add ActivityState model with threshold-based state derivation`

---

### Task 3: Create IdleDetecting protocol and CGEventSourceIdleDetector

**Files to create:**
- `Sources/EyesCareCore/Protocols/IdleDetecting.swift`
- `Sources/EyesCareCore/Services/CGEventSourceIdleDetector.swift`

**Create Protocols directory if it doesn't exist.**

**IdleDetecting.swift:**

```swift
import Foundation

/// Abstracts idle-time detection for testability.
///
/// Production code uses `CGEventSourceIdleDetector`.
/// Tests inject `MockIdleDetector` with controllable values.
public protocol IdleDetecting: Sendable {
    /// Returns the number of seconds since the user's last input event.
    func secondsSinceLastEvent() -> TimeInterval
}
```

**CGEventSourceIdleDetector.swift:**

```swift
import CoreGraphics

/// Production idle detector using macOS `CGEventSource`.
///
/// Checks multiple event types (keyboard, mouse, click, scroll)
/// and returns the minimum idle time — ensuring any user activity is detected.
///
/// No Accessibility permission required.
public struct CGEventSourceIdleDetector: IdleDetecting {
    public init() {}

    public func secondsSinceLastEvent() -> TimeInterval {
        let keyboardIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        let clickIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .leftMouseDown
        )
        let scrollIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .scrollWheel
        )
        return min(keyboardIdle, mouseIdle, clickIdle, scrollIdle)
    }
}
```

**Acceptance criteria:**
- [ ] `IdleDetecting` protocol has one method: `secondsSinceLastEvent() -> TimeInterval`
- [ ] `IdleDetecting` conforms to `Sendable`
- [ ] `CGEventSourceIdleDetector` is a `struct` implementing `IdleDetecting`
- [ ] Checks 4 event types and returns the minimum
- [ ] `swift build` succeeds

**Commit message:** `feat: add IdleDetecting protocol and CGEventSource implementation`

---

### Task 4: Create MonitoringStatus and MonitoringSessionDelegate

**Files to create:**
- `Sources/EyesCareCore/Models/MonitoringStatus.swift`
- `Sources/EyesCareCore/Protocols/MonitoringSessionDelegate.swift`

**MonitoringStatus.swift:**

```swift
import Foundation

/// Immutable snapshot of the current monitoring state.
///
/// Produced by `MonitoringSession` on every poll tick.
/// Consumed by `AppDelegate` to update menu items.
public struct MonitoringStatus: Sendable, Equatable {
    /// Whether monitoring is currently active (not paused).
    public let isMonitoring: Bool

    /// Current user activity state.
    public let activityState: ActivityState

    /// Cumulative active time in seconds since monitoring started.
    public let activeTime: TimeInterval

    /// Seconds since the user's last natural break ended.
    public let sinceLastBreak: TimeInterval

    public init(
        isMonitoring: Bool,
        activityState: ActivityState,
        activeTime: TimeInterval,
        sinceLastBreak: TimeInterval
    ) {
        self.isMonitoring = isMonitoring
        self.activityState = activityState
        self.activeTime = activeTime
        self.sinceLastBreak = sinceLastBreak
    }
}
```

**MonitoringSessionDelegate.swift:**

```swift
import Foundation

/// Delegate protocol for receiving monitoring state updates.
///
/// All callbacks are dispatched on the main actor.
@MainActor
public protocol MonitoringSessionDelegate: AnyObject {
    /// Called every poll interval with the latest monitoring status.
    func monitoringSessionDidUpdate(_ status: MonitoringStatus)
}
```

**Acceptance criteria:**
- [ ] `MonitoringStatus` is a `Sendable`, `Equatable` struct with 4 stored properties
- [ ] `MonitoringSessionDelegate` is `@MainActor` and `AnyObject`
- [ ] Delegate has one method: `monitoringSessionDidUpdate(_:)`
- [ ] `swift build` succeeds

**Commit message:** `feat: add MonitoringStatus snapshot and MonitoringSessionDelegate protocol`

---

### Task 5: Create TimeFormatter utility

**Files to create:**
- `Sources/EyesCareCore/Utils/TimeFormatter.swift`

**Implementation:**

```swift
import Foundation

/// Formats time intervals for menu bar display.
///
/// Follows the UX spec formatting rules:
/// - < 60s → "< 1m"
/// - 1-59 min → "Xm"
/// - 60+ min → "Xh Ym"
/// - 24+ hours → "Xd Yh"
public enum TimeFormatter {

    /// Format active time for display.
    ///
    /// - Parameter interval: Cumulative active seconds.
    /// - Returns: Human-readable string like "1h 23m" or "< 1m".
    public static func formatActiveTime(_ interval: TimeInterval) -> String {
        guard interval >= 0 else { return "—" }

        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days >= 1 {
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        }
        if hours >= 1 {
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        if minutes >= 1 {
            return "\(minutes)m"
        }
        return "< 1m"
    }

    /// Format "since last break" for display.
    ///
    /// - Parameters:
    ///   - interval: Seconds since the last natural break ended.
    ///   - isIdle: Whether the user is currently idle (shows "(resting)" suffix).
    /// - Returns: Human-readable string like "18m" or "0m (resting)".
    public static func formatSinceLastBreak(
        _ interval: TimeInterval,
        isIdle: Bool
    ) -> String {
        if isIdle {
            return "0m (resting)"
        }
        return formatActiveTime(interval)
    }

    /// Placeholder string for paused state.
    public static let pausedPlaceholder = "—"
}
```

**Acceptance criteria:**
- [ ] `formatActiveTime` handles: < 1m, minutes, hours+minutes, days+hours
- [ ] `formatSinceLastBreak` shows "0m (resting)" when idle
- [ ] `formatSinceLastBreak` delegates to `formatActiveTime` when not idle
- [ ] `pausedPlaceholder` returns "—"
- [ ] `swift build` succeeds

**Commit message:** `feat: add TimeFormatter utility for human-readable time display`

---

### Task 6: Create MonitoringSession service

**Files to create:**
- `Sources/EyesCareCore/Services/MonitoringSession.swift`

**This is the most complex file. Read `.eyes-care/architecture/v1-architecture.md` section 3.6 and section 4 carefully.**

**Implementation outline:**

```swift
import Foundation

/// Orchestrates idle monitoring, state transitions, and time tracking.
///
/// `MonitoringSession` is the core engine of EyesCare. It:
/// 1. Polls an `IdleDetecting` source every `Constants.pollingInterval` seconds
/// 2. Derives `ActivityState` from the idle time
/// 3. Tracks cumulative active time and time since last break
/// 4. Notifies its `delegate` with a `MonitoringStatus` snapshot on every tick
///
/// ## Usage
/// ```swift
/// let session = MonitoringSession()
/// session.delegate = self
/// session.start()
/// ```
///
/// ## Threading
/// This class is `@MainActor` because it owns a `Timer` and updates UI-bound state.
@MainActor
public final class MonitoringSession {
    // MARK: - Dependencies

    private let idleDetector: any IdleDetecting

    // MARK: - State

    private(set) var isMonitoring = false
    private var activityState: ActivityState = .active
    private var accumulatedActiveTime: TimeInterval = 0
    private var lastBreakEndDate: Date = Date()
    private var previousState: ActivityState = .active

    // MARK: - Timer

    private var pollTimer: Timer?

    // MARK: - Delegate

    public weak var delegate: (any MonitoringSessionDelegate)?

    // MARK: - Init

    public init(idleDetector: any IdleDetecting = CGEventSourceIdleDetector()) {
        self.idleDetector = idleDetector
    }

    // MARK: - Public API

    /// Start monitoring. Creates a repeating timer.
    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        activityState = .active
        previousState = .active
        accumulatedActiveTime = 0
        lastBreakEndDate = Date()
        startTimer()
        notifyDelegate()
    }

    /// Pause monitoring. Invalidates the timer.
    public func pause() {
        guard isMonitoring else { return }
        isMonitoring = false
        stopTimer()
        notifyDelegate()
    }

    /// Returns the current monitoring status snapshot.
    public func currentStatus() -> MonitoringStatus {
        let sinceLastBreak: TimeInterval
        if isMonitoring {
            sinceLastBreak = Date().timeIntervalSince(lastBreakEndDate)
        } else {
            sinceLastBreak = 0
        }

        return MonitoringStatus(
            isMonitoring: isMonitoring,
            activityState: isMonitoring ? activityState : .active,
            activeTime: accumulatedActiveTime,
            sinceLastBreak: sinceLastBreak
        )
    }

    // MARK: - Polling (internal for testing)

    /// Called every `Constants.pollingInterval` seconds by the timer.
    /// Also callable directly in tests with a mock `IdleDetecting`.
    func poll() {
        guard isMonitoring else { return }

        let idleSeconds = idleDetector.secondsSinceLastEvent()
        let newState = ActivityState.from(idleSeconds: idleSeconds)

        // State transition: away -> active = break ended, reset counters
        if previousState == .away && newState == .active {
            lastBreakEndDate = Date()
            // Don't accumulate active time for this tick — it's the first tick back
        }

        // Accumulate active time only when the user is active
        if newState == .active && previousState != .away {
            accumulatedActiveTime += Constants.pollingInterval
        }

        previousState = activityState
        activityState = newState

        notifyDelegate()
    }

    // MARK: - Private

    private func startTimer() {
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.pollingInterval,
            repeats: true
        ) { [weak self] _ in
            // Timer callback is on main thread (main RunLoop)
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func notifyDelegate() {
        delegate?.monitoringSessionDidUpdate(currentStatus())
    }
}
```

**Critical details:**
- `previousState` tracks the last state to detect transitions (especially `away` -> `active`)
- `accumulatedActiveTime` only increments during `active` polls where previous wasn't `away`
- `sinceLastBreak` is computed from `lastBreakEndDate` — no drift over time
- `poll()` is `internal` so tests can call it directly

**Acceptance criteria:**
- [ ] `MonitoringSession` is `@MainActor` and `final class`
- [ ] `init` accepts `any IdleDetecting` with default `CGEventSourceIdleDetector()`
- [ ] `start()` creates timer, `pause()` invalidates timer
- [ ] `start()` is idempotent (calling twice doesn't create two timers)
- [ ] `pause()` is idempotent
- [ ] `poll()` correctly transitions state based on idle seconds
- [ ] `away -> active` transition resets `lastBreakEndDate`
- [ ] Active time only accumulates during `.active` state
- [ ] Delegate is notified on every `poll()`, `start()`, and `pause()`
- [ ] `swift build` succeeds

**Commit message:** `feat: add MonitoringSession with state machine and time tracking`

---

### Task 7: Extend AppDelegate with full menu bar integration

**Files to modify:**
- `Sources/EyesCareApp/AppDelegate.swift`

**This is a full rewrite of AppDelegate.** The existing 25-line version is replaced with ~180 lines.

**Implementation outline:**

```swift
import AppKit
import EyesCareCore

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "eye",
                accessibilityDescription: "EyesCare"
            )
        }

        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "EyesCare v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Status
        let statusItem = NSMenuItem(title: "● Monitoring", action: nil, keyEquivalent: "")
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
            let isIdle = status.activityState == .idle || status.activityState == .away
            let formatted = TimeFormatter.formatSinceLastBreak(
                status.sinceLastBreak,
                isIdle: isIdle
            )
            sinceLastBreakMenuItem?.title = "Since Last Break: \(formatted)"
        } else {
            sinceLastBreakMenuItem?.title = "Since Last Break: \(TimeFormatter.pausedPlaceholder)"
        }

        // Toggle button label
        toggleMenuItem?.title = status.isMonitoring ? "Pause Monitoring" : "Resume Monitoring"
    }
}

// MARK: - MonitoringSessionDelegate

extension AppDelegate: MonitoringSessionDelegate {
    public func monitoringSessionDidUpdate(_ status: MonitoringStatus) {
        updateMenu(with: status)
    }
}
```

**Key implementation details:**
- Remove the old `button.title = " EyesCare"` — icon only (saves menu bar space per UX spec)
- Remove old version string "v0.1" → "v1.0"
- `toggleMonitoring()` is `@objc` for NSMenuItem action target
- `target = self` must be set explicitly (NSMenu doesn't auto-target)
- `applicationWillTerminate` pauses monitoring for clean shutdown

**Acceptance criteria:**
- [ ] Menu bar shows "eye" icon when monitoring, "eye.slash" when paused
- [ ] Menu displays: "EyesCare v1.0", status, active time, since last break, toggle, quit
- [ ] Status shows "● Monitoring" / "● Monitoring (Idle)" / "○ Paused"
- [ ] Toggle button shows "Pause Monitoring" / "Resume Monitoring"
- [ ] Active time and since-last-break update every 5 seconds
- [ ] Paused state shows "—" for time values
- [ ] Quit has ⌘Q shortcut
- [ ] Monitoring starts automatically on launch
- [ ] `swift build` succeeds

**Commit message:** `feat: extend AppDelegate with monitoring toggle, status display, and time tracking`

---

### Task 8: Add unit tests (>= 80% coverage)

**Files to create:**
- `Tests/EyesCareTests/Mocks/MockIdleDetector.swift`
- `Tests/EyesCareTests/Mocks/MockMonitoringSessionDelegate.swift`
- `Tests/EyesCareTests/BreakTypeTests.swift`
- `Tests/EyesCareTests/ActivityStateTests.swift`
- `Tests/EyesCareTests/MonitoringStatusTests.swift`
- `Tests/EyesCareTests/TimeFormatterTests.swift`
- `Tests/EyesCareTests/MonitoringSessionTests.swift`

**Files to delete:**
- `Tests/EyesCareTests/.gitkeep`

**Create Mocks directory:** `Tests/EyesCareTests/Mocks/`

#### MockIdleDetector.swift:

```swift
import EyesCareCore

final class MockIdleDetector: IdleDetecting, @unchecked Sendable {
    var idleSeconds: TimeInterval = 0

    func secondsSinceLastEvent() -> TimeInterval {
        idleSeconds
    }
}
```

#### MockMonitoringSessionDelegate.swift:

```swift
import EyesCareCore

@MainActor
final class MockMonitoringSessionDelegate: MonitoringSessionDelegate {
    private(set) var lastStatus: MonitoringStatus?
    private(set) var updateCount = 0

    func monitoringSessionDidUpdate(_ status: MonitoringStatus) {
        lastStatus = status
        updateCount += 1
    }
}
```

#### BreakTypeTests.swift:

Test all medical values match the spec:
- `micro.interval == 1200` (20 min)
- `micro.duration == 20` (20 sec)
- `macro.interval == 3600` (60 min)
- `macro.duration == 300` (5 min)
- `mandatory.interval == 7200` (120 min)
- `mandatory.duration == 900` (15 min)
- Display names and medical sources are non-empty

#### ActivityStateTests.swift:

Test `ActivityState.from(idleSeconds:)`:
- `idleSeconds: 0` → `.active`
- `idleSeconds: 29` → `.active`
- `idleSeconds: 30` → `.idle` (exactly at threshold)
- `idleSeconds: 60` → `.idle`
- `idleSeconds: 119` → `.idle`
- `idleSeconds: 120` → `.away` (exactly at threshold)
- `idleSeconds: 500` → `.away`
- Custom thresholds: `from(idleSeconds: 10, idleThreshold: 5, naturalBreakThreshold: 15)` → `.idle`

#### MonitoringStatusTests.swift:

- Test `init` stores all values correctly
- Test `Equatable` conformance (two equal, two different)

#### TimeFormatterTests.swift:

Use parameterized `@Test` with `arguments:`:
- `formatActiveTime(0)` → "< 1m"
- `formatActiveTime(59)` → "< 1m"
- `formatActiveTime(60)` → "1m"
- `formatActiveTime(300)` → "5m"
- `formatActiveTime(3660)` → "1h 1m"
- `formatActiveTime(7200)` → "2h 0m"
- `formatActiveTime(90000)` → "1d 1h"
- `formatActiveTime(-1)` → "—"
- `formatSinceLastBreak(300, isIdle: false)` → "5m"
- `formatSinceLastBreak(300, isIdle: true)` → "0m (resting)"
- `pausedPlaceholder` → "—"

#### MonitoringSessionTests.swift:

Test session lifecycle with `MockIdleDetector`:
- **Start/Pause**: verify `isMonitoring` toggles, delegate notified
- **Idempotent start**: calling `start()` twice doesn't break
- **Idempotent pause**: calling `pause()` twice doesn't break
- **Active state**: set mock idle to 0, call `poll()`, verify `.active` state
- **Idle state**: set mock idle to 35, call `poll()`, verify `.idle` state
- **Away state**: set mock idle to 130, call `poll()`, verify `.away` state
- **Active time accumulation**: poll 3 times with idle=0, verify activeTime == 3 * pollingInterval
- **Away resets break timer**: simulate `active -> away -> active`, verify sinceLastBreak resets
- **Paused state**: pause, verify `poll()` does nothing

**Acceptance criteria:**
- [ ] All tests pass with `swift test`
- [ ] `swift test --enable-code-coverage` shows >= 80% on EyesCareCore
- [ ] Uses Swift Testing (`import Testing`, `@Test`, `#expect`)
- [ ] No XCTest imports
- [ ] Mocks are in a dedicated `Mocks/` subdirectory
- [ ] MonitoringSession tests use `@MainActor` (since MonitoringSession is @MainActor)

**Commit message:** `test: add comprehensive unit tests for EyesCareCore (>= 80% coverage)`

---

## 3. Implementation Order Summary

| Order | Task | Files | Estimated Lines |
|-------|------|-------|----------------|
| 1 | Package.swift test target | Package.swift | ~10 changed |
| 2 | ActivityState model | 1 new | ~40 |
| 3 | IdleDetecting + CGEventSourceIdleDetector | 2 new | ~42 |
| 4 | MonitoringStatus + Delegate | 2 new | ~45 |
| 5 | TimeFormatter | 1 new | ~55 |
| 6 | MonitoringSession | 1 new | ~150 |
| 7 | AppDelegate rewrite | 1 modified | ~180 |
| 8 | Unit tests | 7 new | ~350 |

**Total new/modified lines:** ~870

---

## 4. Important Notes

### 4.1 Do NOT change these files
- `Sources/EyesCareCore/Models/BreakType.swift` — complete, tested in Task 8
- `Sources/EyesCareCore/Models/ReminderMode.swift` — complete, used in v3
- `Sources/EyesCareCore/Utils/Constants.swift` — complete
- `Sources/EyesCareApp/EyesCareApp.swift` — complete

### 4.2 Strict Concurrency
All types must compile cleanly with strict concurrency enabled:
- `Sendable` enums and structs — free (value types)
- `@unchecked Sendable` on `MockIdleDetector` — mutable var in tests only
- `@MainActor` on `MonitoringSession` and `AppDelegate`

### 4.3 Swift Testing Gotchas
- `@Test` functions can be `@MainActor` — needed for testing `MonitoringSession`
- `#expect(x == y)` not `XCTAssertEqual(x, y)`
- `#expect(throws: SomeError.self) { ... }` for error testing
- No `setUp()`/`tearDown()` — use `init()`/`deinit` on a test struct, or just create fresh instances in each `@Test`

### 4.4 Build Verification
After every task, run:
```bash
swift build 2>&1
```
Ensure zero errors AND zero warnings.

After Task 8:
```bash
swift test 2>&1
swift test --enable-code-coverage 2>&1
```

---

## 5. After Implementation

When all 8 tasks are done:
1. Run `swift build` — zero errors, zero warnings
2. Run `swift test` — all tests pass
3. Run `swift test --enable-code-coverage` — verify >= 80% on EyesCareCore
4. Write handoff to `.eyes-care/handoffs/dev-to-lead-v1.md` with:
   - List of all files created/modified
   - Test results summary
   - Coverage report
   - Any deviations from this plan
5. Update `.eyes-care/status.md`

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | Lead Engineer Agent | Initial task breakdown for v1 |
