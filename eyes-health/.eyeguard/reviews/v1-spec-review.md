# EyesHealth V1 — Architecture Review

**Reviewer:** Lead Agent (Tech Lead / Architect)
**Date:** 2026-04-14
**Status:** APPROVED with recommendations
**Target:** macOS 13+ | Swift 5.9 | SwiftUI | Swift Package Manager

---

## 1. Architecture Overview

EyesHealth V1 follows a **Service-oriented MVVM** pattern tailored for a lightweight macOS menu bar app. The architecture prioritizes simplicity: no external dependencies, a single-window `MenuBarExtra` surface, and two focused services that encapsulate all non-UI logic.

### Core Architectural Tenets

| Tenet | Rationale |
|-------|-----------|
| Single `@Observable` AppState | One source of truth eliminates state sync bugs across the small UI surface |
| Services as plain classes | No protocol abstraction in V1 — justified by the minimal scope; protocols can be introduced when testing demands it |
| No persistence in V1 | Daily break count resets at midnight; no need for CoreData/SwiftData yet |
| No external dependencies | Reduces attack surface, simplifies SPM graph, avoids version churn |
| Timer-based polling (5s) | Sufficient granularity for break detection; avoids complexity of CGEventTap |

### Layer Diagram

```
┌─────────────────────────────────────────────────┐
│                   macOS System                  │
│  ┌─────────────────┐  ┌──────────────────────┐  │
│  │ CGEventSource   │  │ DistributedNotif.Ctr │  │
│  │ (idle seconds)  │  │ (lock/unlock)        │  │
│  └────────┬────────┘  └──────────┬───────────┘  │
│           │                      │              │
├───────────┼──────────────────────┼──────────────┤
│           ▼                      ▼              │
│  ┌─────────────────────────────────────────┐    │
│  │         MonitoringService               │    │
│  │  • Timer(5s) polls idle time            │    │
│  │  • Tracks continuousUseTime             │    │
│  │  • Detects natural breaks (idle > 2min) │    │
│  │  • Listens screen lock/unlock           │    │
│  └──────────────────┬──────────────────────┘    │
│                     │ writes                    │
│                     ▼                           │
│  ┌─────────────────────────────────────────┐    │
│  │              AppState                   │    │
│  │  @Observable (single source of truth)   │    │
│  │  • continuousUseSeconds: TimeInterval   │    │
│  │  • breaksTakenToday: Int                │    │
│  │  • lastBreakTime: Date?                 │    │
│  │  • isMonitoring: Bool                   │    │
│  │  • statusColor: StatusColor             │    │
│  └──────────┬──────────────┬───────────────┘    │
│             │ reads        │ triggers           │
│             ▼              ▼                    │
│  ┌──────────────────┐ ┌────────────────────┐    │
│  │  MenuBarView     │ │ NotificationService│    │
│  │  (SwiftUI)       │ │ • UNUserNotif.Ctr  │    │
│  │  • Status icon   │ │ • Permission req   │    │
│  │  • Time display  │ │ • 20-20-20 alert   │    │
│  │  • Break count   │ │ • Action handling  │    │
│  │  • Take Break    │ └────────────────────┘    │
│  │  • Quit          │                           │
│  └──────────────────┘                           │
└─────────────────────────────────────────────────┘
```

---

## 2. File Structure

```
eyes-health/
├── Package.swift                          — SPM manifest (macOS 13+, swift-tools-version: 5.9)
└── EyesHealth/
    ├── App/
    │   └── EyesHealthApp.swift            — @main entry, MenuBarExtra, service lifecycle
    │
    ├── Services/
    │   ├── MonitoringService.swift         — Timer-based idle detection, screen lock observer
    │   └── NotificationService.swift       — UNUserNotificationCenter wrapper, permission flow
    │
    ├── Models/
    │   ├── AppState.swift                 — @Observable shared state, computed status color
    │   └── BreakRecord.swift              — Value type for a single break event
    │
    ├── Views/
    │   └── MenuBarView.swift              — Menu bar dropdown: timer, count, actions
    │
    ├── Utils/
    │   └── Constants.swift                — Timing thresholds, string literals, color mappings
    │
    └── Resources/                         — (Reserved for future assets: icons, sounds)
```

### File Responsibility Matrix

| File | Lines (est.) | Responsibility | Dependencies |
|------|-------------|----------------|--------------|
| `EyesHealthApp.swift` | 40–60 | App lifecycle, `MenuBarExtra` setup, service init, midnight reset scheduling | AppState, MonitoringService, NotificationService |
| `MonitoringService.swift` | 120–180 | 5s timer, idle time polling, lock/unlock observation, break detection, continuous use tracking | AppState, Constants |
| `NotificationService.swift` | 80–120 | Permission request, notification scheduling, action handling (snooze/dismiss) | AppState, Constants |
| `AppState.swift` | 60–90 | `@Observable` state container, computed `statusColor`, `recordBreak()`, `resetDaily()` | BreakRecord |
| `BreakRecord.swift` | 15–25 | Immutable struct: `id`, `timestamp`, `duration` | None |
| `MenuBarView.swift` | 80–120 | SwiftUI view: dynamic icon, formatted time, break count, action buttons | AppState, MonitoringService |
| `Constants.swift` | 30–50 | `breakIntervalSeconds`, `naturalBreakThreshold`, `pollingInterval`, localized strings | None |

**Total estimated:** 425–645 lines — well within the <800 lines/file guideline.

---

## 3. Class Diagrams (ASCII)

### 3.1 Core Types

```
┌─────────────────────────────────────────────────────┐
│                    AppState                         │
│               «@Observable class»                   │
├─────────────────────────────────────────────────────┤
│ - continuousUseSeconds: TimeInterval                │
│ - breaksTakenToday: Int                             │
│ - lastBreakTime: Date?                              │
│ - isMonitoring: Bool                                │
│ - todayBreakRecords: [BreakRecord]                  │
├─────────────────────────────────────────────────────┤
│ + statusColor: StatusColor          «computed»      │
│ + formattedContinuousUse: String    «computed»      │
│ + recordBreak(duration:) -> Void                    │
│ + resetContinuousUse() -> Void                      │
│ + resetDaily() -> Void                              │
│ + incrementContinuousUse(by:) -> Void               │
└─────────────────────────────────────────────────────┘
           ▲ owns many
           │
┌──────────┴──────────────────────────────────────────┐
│                  BreakRecord                        │
│                  «struct»                           │
├─────────────────────────────────────────────────────┤
│ + id: UUID                                          │
│ + timestamp: Date                                   │
│ + durationSeconds: TimeInterval                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                 StatusColor                         │
│                  «enum»                             │
├─────────────────────────────────────────────────────┤
│ case green    // 0–14 min continuous use             │
│ case yellow   // 15–19 min continuous use            │
│ case red      // 20+ min continuous use              │
├─────────────────────────────────────────────────────┤
│ + systemName: String   «SF Symbol name»             │
│ + color: Color         «SwiftUI Color»              │
└─────────────────────────────────────────────────────┘
```

### 3.2 Services

```
┌─────────────────────────────────────────────────────┐
│               MonitoringService                     │
│                  «class»                            │
├─────────────────────────────────────────────────────┤
│ - appState: AppState                                │
│ - pollingTimer: Timer?                              │
│ - isScreenLocked: Bool                              │
├─────────────────────────────────────────────────────┤
│ + start() -> Void                                   │
│ + stop() -> Void                                    │
│ + triggerManualBreak() -> Void                      │
│ - pollIdleTime() -> Void                            │
│ - observeScreenLock() -> Void                       │
│ - handleScreenLock() -> Void                        │
│ - handleScreenUnlock() -> Void                      │
│ - getIdleSeconds() -> TimeInterval                  │
│ - checkForNaturalBreak(idle:) -> Bool               │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              NotificationService                    │
│                  «class»                            │
├─────────────────────────────────────────────────────┤
│ - center: UNUserNotificationCenter                  │
│ - appState: AppState                                │
│ - delegate: NotificationDelegate                    │
├─────────────────────────────────────────────────────┤
│ + requestPermission() async -> Bool                 │
│ + scheduleBreakReminder() -> Void                   │
│ + cancelPendingNotifications() -> Void              │
│ - configureCategories() -> Void                     │
│ - handleNotificationAction(_:) -> Void              │
└─────────────────────────────────────────────────────┘
```

### 3.3 View

```
┌─────────────────────────────────────────────────────┐
│                 MenuBarView                         │
│                «SwiftUI View»                       │
├─────────────────────────────────────────────────────┤
│ @Environment appState: AppState                     │
│ var monitoringService: MonitoringService             │
├─────────────────────────────────────────────────────┤
│ + body: some View                                   │
│   ├─ Header: "EyesHealth" + status dot              │
│   ├─ Divider                                        │
│   ├─ Row: "Continuous Use: {time}"                  │
│   ├─ Row: "Breaks Today: {count}"                   │
│   ├─ Row: "Last Break: {relative time}"             │
│   ├─ Divider                                        │
│   ├─ Button: "Take a Break Now"                     │
│   └─ Button: "Quit"                                 │
└─────────────────────────────────────────────────────┘
```

### 3.4 App Entry Point

```
┌─────────────────────────────────────────────────────┐
│               EyesHealthApp                         │
│              «@main struct»                         │
├─────────────────────────────────────────────────────┤
│ @State appState: AppState                           │
│ @State monitoringService: MonitoringService          │
│ @State notificationService: NotificationService      │
├─────────────────────────────────────────────────────┤
│ + body: some Scene                                  │
│   └─ MenuBarExtra("EyesHealth", systemImage:)       │
│       └─ MenuBarView(monitoringService:)            │
│          .environment(appState)                      │
├─────────────────────────────────────────────────────┤
│ + init()                                            │
│   ├─ Create AppState                                │
│   ├─ Create MonitoringService(appState:)            │
│   ├─ Create NotificationService(appState:)          │
│   └─ Schedule midnight reset timer                  │
└─────────────────────────────────────────────────────┘
```

---

## 4. Key Interfaces

### 4.1 AppState — The Observable Core

```swift
@Observable
final class AppState {
    // MARK: - Published State
    var continuousUseSeconds: TimeInterval = 0
    var breaksTakenToday: Int = 0
    var lastBreakTime: Date? = nil
    var isMonitoring: Bool = false

    // MARK: - Internal
    private(set) var todayBreakRecords: [BreakRecord] = []

    // MARK: - Computed
    var statusColor: StatusColor {
        switch continuousUseSeconds {
        case 0..<(15 * 60):   return .green
        case (15 * 60)..<(20 * 60): return .yellow
        default:              return .red
        }
    }

    var formattedContinuousUse: String {
        let minutes = Int(continuousUseSeconds) / 60
        let seconds = Int(continuousUseSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Mutations
    func recordBreak(duration: TimeInterval = 0) {
        let record = BreakRecord(timestamp: .now, durationSeconds: duration)
        todayBreakRecords.append(record)
        breaksTakenToday = todayBreakRecords.count
        lastBreakTime = .now
        continuousUseSeconds = 0
    }

    func resetDaily() {
        todayBreakRecords = []
        breaksTakenToday = 0
        continuousUseSeconds = 0
        lastBreakTime = nil
    }

    func incrementContinuousUse(by interval: TimeInterval) {
        continuousUseSeconds += interval
    }

    func resetContinuousUse() {
        continuousUseSeconds = 0
    }
}
```

**Design note:** `AppState` is a `class` (not struct) because `@Observable` requires reference semantics. Mutation methods are explicit — no raw property writes from outside. This is the best compromise for SwiftUI + observability.

### 4.2 MonitoringService — Core Detection Logic

```swift
final class MonitoringService {
    private let appState: AppState
    private var pollingTimer: Timer?
    private var isScreenLocked = false
    private var lastPollTime: Date = .now

    init(appState: AppState) {
        self.appState = appState
        observeScreenLock()
    }

    func start() {
        appState.isMonitoring = true
        lastPollTime = .now
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.pollIdleTime()
        }
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        appState.isMonitoring = false
    }

    func triggerManualBreak() {
        appState.recordBreak()
    }

    private func getIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            .init(rawValue: ~0)!   // all event types
        )
    }

    private func pollIdleTime() {
        guard !isScreenLocked else { return }

        let idle = getIdleSeconds()
        if idle >= Constants.naturalBreakThreshold {
            // User was idle long enough — count as natural break
            if appState.continuousUseSeconds > 0 {
                appState.recordBreak(duration: idle)
            }
        } else {
            // User is active — accumulate continuous use time
            let elapsed = Date.now.timeIntervalSince(lastPollTime)
            appState.incrementContinuousUse(by: elapsed)
        }
        lastPollTime = .now
    }

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self, selector: #selector(handleScreenLock),
            name: .init("com.apple.screenIsLocked"), object: nil
        )
        center.addObserver(
            self, selector: #selector(handleScreenUnlock),
            name: .init("com.apple.screenIsUnlocked"), object: nil
        )
    }

    @objc private func handleScreenLock() {
        isScreenLocked = true
        // Screen lock counts as a break
        if appState.continuousUseSeconds > Constants.minimumUseBeforeBreak {
            appState.recordBreak()
        } else {
            appState.resetContinuousUse()
        }
    }

    @objc private func handleScreenUnlock() {
        isScreenLocked = false
        lastPollTime = .now
    }
}
```

### 4.3 NotificationService — User Alert System

```swift
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let appState: AppState
    private var delegate: NotificationDelegate?

    init(appState: AppState) {
        self.appState = appState
        self.delegate = NotificationDelegate(appState: appState)
        center.delegate = delegate
        configureCategories()
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleBreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = Constants.notificationTitle
        content.body = Constants.notificationBody
        content.sound = .default
        content.categoryIdentifier = Constants.notificationCategoryID

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1, repeats: false
        )
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content, trigger: trigger
        )
        center.add(request)
    }

    func cancelPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    private func configureCategories() {
        let takeBreak = UNNotificationAction(
            identifier: "TAKE_BREAK", title: "Take Break", options: []
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE_5", title: "Snooze 5 min", options: []
        )
        let category = UNNotificationCategory(
            identifier: Constants.notificationCategoryID,
            actions: [takeBreak, snooze],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }
}
```

### 4.4 Constants

```swift
enum Constants {
    // Timing (seconds)
    static let pollingInterval: TimeInterval = 5
    static let breakIntervalSeconds: TimeInterval = 20 * 60   // 20 minutes
    static let naturalBreakThreshold: TimeInterval = 2 * 60   // 2 minutes idle = break
    static let minimumUseBeforeBreak: TimeInterval = 5 * 60   // min 5 min to count as break

    // Status thresholds
    static let yellowThreshold: TimeInterval = 15 * 60        // 15 minutes
    static let redThreshold: TimeInterval = 20 * 60           // 20 minutes

    // Notification
    static let notificationTitle = "Time for an Eye Break! 👀"
    static let notificationBody = "Look at something 20 feet away for 20 seconds."
    static let notificationCategoryID = "BREAK_REMINDER"
}
```

---

## 5. Data Flow

### 5.1 Normal Usage Cycle

```
┌──────────┐  every 5s   ┌───────────────────┐
│  Timer   │────────────▶│  pollIdleTime()   │
└──────────┘             └────────┬──────────┘
                                  │
                     ┌────────────┼────────────┐
                     ▼                         ▼
              idle < 2 min              idle >= 2 min
              (user active)             (natural break)
                     │                         │
                     ▼                         ▼
          appState.increment          appState.recordBreak()
          ContinuousUse(by:)                   │
                     │                         │
                     ▼                         ▼
          ┌──────────────────┐      ┌──────────────────┐
          │ continuousUse    │      │ breaksTakenToday  │
          │ += elapsed       │      │ += 1              │
          │                  │      │ continuousUse = 0 │
          └────────┬─────────┘      └──────────────────┘
                   │
                   ▼
          continuousUse >= 20 min?
                   │
          ┌────────┴────────┐
          │ YES             │ NO
          ▼                 ▼
  scheduleBreakReminder()  (continue)
  → notification shown
```

### 5.2 Screen Lock/Unlock Flow

```
DistributedNotificationCenter
         │
    ┌────┴────┐
    ▼         ▼
  LOCK      UNLOCK
    │         │
    ▼         ▼
isScreenLocked   isScreenLocked
  = true           = false
    │              lastPollTime = .now
    ▼
continuousUse > 5 min?
    │
  ┌─┴──┐
  Y    N
  │    │
  ▼    ▼
recordBreak()  resetContinuousUse()
```

### 5.3 Midnight Reset Flow

```
EyesHealthApp.init()
       │
       ▼
  Calculate seconds until next midnight
       │
       ▼
  Timer.scheduledTimer(fireAt: midnight)
       │
       ▼ (at midnight)
  appState.resetDaily()
       │
       ▼
  Schedule next midnight timer (recursive)
```

### 5.4 User Interaction Flow

```
User clicks menu bar icon
       │
       ▼
  MenuBarView.body renders
  ├── Shows continuousUseSeconds (formatted MM:SS)
  ├── Shows breaksTakenToday count
  ├── Shows lastBreakTime (relative: "3 min ago")
  │
  User clicks "Take a Break Now"
       │
       ▼
  monitoringService.triggerManualBreak()
       │
       ▼
  appState.recordBreak()
  ├── continuousUseSeconds = 0
  ├── breaksTakenToday += 1
  └── lastBreakTime = .now
       │
       ▼
  @Observable triggers UI update automatically
```

---

## 6. Technical Risks & Mitigations

### RISK-1: `CGEventSource.secondsSinceLastEventType` Permission (MEDIUM)

**Risk:** On macOS 13+, accessing `CGEventSource` may require Accessibility permissions or Input Monitoring. Without it, idle detection silently returns 0.

**Mitigation:**
- Test on a fresh macOS install with no permissions granted.
- Detect when idle time is always 0 and prompt the user to grant Input Monitoring permission in System Settings > Privacy & Security.
- Add an `Info.plist` entry with `NSInputMonitoringUsageDescription` if needed for SPM-based builds.
- **Fallback:** If permission is denied, degrade to time-only reminders (fixed 20-min interval without idle detection).

### RISK-2: Timer Accuracy During Sleep/App Nap (LOW-MEDIUM)

**Risk:** macOS App Nap can throttle timers for background apps. Menu bar apps are generally exempt, but edge cases exist.

**Mitigation:**
- Use `ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason:)` if needed — but avoid for V1 to keep energy impact low.
- Recalculate `continuousUseSeconds` using wall-clock deltas (`Date.now - lastPollTime`) rather than trusting timer regularity. **Already implemented** in the polling design above.
- On system wake from sleep, treat it like a screen unlock — reset `lastPollTime`.

### RISK-3: `DistributedNotificationCenter` Reliability (LOW)

**Risk:** `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` are undocumented private notifications. Apple could remove or rename them.

**Mitigation:**
- These notifications have been stable since macOS 10.6 and are widely used in production apps.
- Add a `TODO` comment linking to the Darwin source where they're defined, so future devs can verify.
- If they stop working, idle detection alone (idle > threshold = break) still covers the core use case.

### RISK-4: No App Sandbox Complications (LOW)

**Risk:** SPM-based executable targets don't automatically get sandboxing, entitlements, or Info.plist. This means no App Store distribution but also no sandbox restrictions.

**Mitigation:**
- V1 is distributed outside the App Store (direct download / Homebrew).
- For future App Store distribution, migrate to Xcode project with proper entitlements.
- Document the distribution model in the project README.

### RISK-5: `@Observable` Requires macOS 14+ in SwiftUI Context (HIGH)

**Risk:** `@Observable` (Observation framework) is only available on macOS 14 (Sonoma)+. The `Package.swift` targets macOS 13 (Ventura). This is a **compile-time error**.

**Mitigation options (pick one):**

| Option | macOS Target | Trade-off |
|--------|-------------|-----------|
| A. Raise deployment target to macOS 14 | `.macOS(.v14)` | Drops Ventura support (~15% of users) |
| B. Use `ObservableObject` + `@Published` | `.macOS(.v13)` | More boilerplate, `@StateObject`/`@EnvironmentObject` required |
| C. Use `@Observable` with `@backDeployed` | `.macOS(.v13)` | Only works with Xcode 15+, runtime may have edge cases |

**Recommendation:** **Option A** — Raise to macOS 14. Rationale:
- macOS 13 adoption is declining (April 2026).
- `@Observable` is cleaner, reduces boilerplate, and is the forward direction of SwiftUI.
- Avoids `@StateObject` / `@EnvironmentObject` / `@ObservedObject` confusion.

### RISK-6: Notification Permission Denied (LOW)

**Risk:** User denies notification permission → the 20-20-20 reminder never fires.

**Mitigation:**
- Show a brief "Notifications disabled" indicator in the menu bar dropdown.
- Provide a "Re-enable Notifications" button that opens System Settings deep link.
- The menu bar icon color change (green → yellow → red) still provides a visual reminder even without notifications.

---

## 7. Recommendations for Development

### 7.1 Implementation Order

Execute in this sequence to maintain a buildable project at each step:

| Phase | Files | Deliverable |
|-------|-------|-------------|
| **P1: Skeleton** | `Package.swift`, `EyesHealthApp.swift`, `Constants.swift` | App launches with empty menu bar icon |
| **P2: State** | `AppState.swift`, `BreakRecord.swift`, `StatusColor` enum | Observable state container compiles |
| **P3: View** | `MenuBarView.swift` | Menu bar dropdown shows static data from AppState |
| **P4: Monitoring** | `MonitoringService.swift` | Timer ticks, idle detection works, state updates flow to UI |
| **P5: Notifications** | `NotificationService.swift` | 20-min notification fires, actions handled |
| **P6: Polish** | Dynamic icon color, midnight reset, edge cases | Feature-complete V1 |

### 7.2 Critical Implementation Details

**a. MenuBarExtra Icon Binding**

```swift
// In EyesHealthApp.body:
MenuBarExtra {
    MenuBarView(monitoringService: monitoringService)
        .environment(appState)
} label: {
    Image(systemName: appState.statusColor.systemName)
        .symbolRenderingMode(.palette)
        .foregroundStyle(appState.statusColor.color)
}
```

The icon must be reactive to `appState.statusColor`. Using `@Observable` ensures this updates automatically when `continuousUseSeconds` changes.

**b. Midnight Reset Scheduling**

```swift
private func scheduleMidnightReset() {
    let calendar = Calendar.current
    guard let midnight = calendar.nextDate(
        after: .now,
        matching: DateComponents(hour: 0, minute: 0, second: 0),
        matchingPolicy: .nextTime
    ) else { return }

    let interval = midnight.timeIntervalSinceNow
    Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
        self?.appState.resetDaily()
        self?.scheduleMidnightReset()  // schedule next
    }
}
```

**c. CGEventSource Idle Detection**

```swift
private func getIdleSeconds() -> TimeInterval {
    // ~0 as UInt32 = all event types combined
    CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        CGEventType(rawValue: UInt32.max)!
    )
}
```

> **Warning:** The `rawValue: ~0` pattern to get "all events" is fragile. Test with `CGEventType(rawValue: UInt32.max)` and verify it compiles. Alternatively, check specific event types (keyboard + mouse + scroll) individually and take the minimum.

**d. NSObject Requirement for @objc Selectors**

`MonitoringService` uses `@objc` selectors for `DistributedNotificationCenter`. This requires the class to inherit from `NSObject`:

```swift
final class MonitoringService: NSObject { ... }
```

This is a minor constraint but necessary for the Objective-C bridging used by `DistributedNotificationCenter.addObserver(_:selector:name:object:)`.

### 7.3 Testing Strategy

| Layer | Test Approach | Priority |
|-------|---------------|----------|
| `AppState` | Unit tests — verify state transitions, computed properties, reset logic | **HIGH** |
| `BreakRecord` | Unit tests — trivial, but verify `Equatable`/`Identifiable` | LOW |
| `MonitoringService` | Integration test — mock `getIdleSeconds()` return value, verify state changes | **HIGH** |
| `NotificationService` | Manual testing — `UNUserNotificationCenter` is hard to mock in unit tests | MEDIUM |
| `MenuBarView` | Manual / snapshot testing — verify rendering | LOW |
| `Constants` | N/A — static values | N/A |

**Recommended test structure:**

```
EyesHealth/
└── Tests/
    ├── AppStateTests.swift        — state transitions, computed values
    └── MonitoringServiceTests.swift — idle detection logic (injected time source)
```

To make `MonitoringService` testable, extract `getIdleSeconds()` behind a protocol:

```swift
protocol IdleTimeProvider {
    func secondsSinceLastEvent() -> TimeInterval
}

struct SystemIdleTimeProvider: IdleTimeProvider {
    func secondsSinceLastEvent() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, ...)
    }
}
```

This enables injecting a mock in tests without touching system APIs.

### 7.4 Platform Target Decision

**Action required before implementation:** Resolve RISK-5.

```swift
// Package.swift — recommended change:
platforms: [
    .macOS(.v14)  // Required for @Observable
]
```

### 7.5 Future V2 Considerations (Out of Scope for V1)

These are explicitly **not** in V1 but should inform V1 design to avoid refactoring:

| Feature | V1 Preparation |
|---------|---------------|
| Settings window (custom intervals) | Keep thresholds in `Constants.swift` — easy to replace with `@AppStorage` later |
| Break history persistence | `BreakRecord` is already a clean value type — add `Codable` conformance now |
| Menu bar chart / stats | `todayBreakRecords` array already tracks timestamps |
| Launch at login | Requires `SMAppService` (macOS 13+) — add in V2, no V1 prep needed |
| Sounds / haptics | `Resources/` directory reserved |

### 7.6 Energy Impact

Menu bar apps are always running. Keep energy impact minimal:

- 5-second polling timer is acceptable (CPU wake ~200x/day from timer alone is negligible)
- Do **not** use `CADisplayLink` or high-frequency timers
- Avoid unnecessary SwiftUI view invalidation — `@Observable` handles this well
- No continuous animations in the menu bar icon

---

## 8. Approval & Summary

### Architecture Verdict: **APPROVED**

The V1 architecture is well-scoped, minimal, and appropriate for a menu bar utility app. The service-oriented approach with a single observable state container is the right pattern for this complexity level.

### Critical Actions Before Development

| # | Action | Severity |
|---|--------|----------|
| 1 | Raise `Package.swift` target to `.macOS(.v14)` for `@Observable` support | **BLOCKING** |
| 2 | Add `Codable` conformance to `BreakRecord` now (prepares V2 persistence) | Recommended |
| 3 | Inherit `MonitoringService` from `NSObject` for `@objc` selector support | Required |
| 4 | Extract `IdleTimeProvider` protocol for testability | Recommended |
| 5 | Test `CGEventSource` on clean macOS install for permission requirements | Required |

### Quality Gates for V1 Completion

- [ ] Menu bar icon appears and changes color based on continuous use time
- [ ] Idle detection correctly identifies natural breaks (>2 min idle)
- [ ] Screen lock/unlock pauses and resumes monitoring
- [ ] 20-20-20 notification fires after 20 min continuous use
- [ ] "Take a Break" button resets timer and increments count
- [ ] Daily counter resets at midnight
- [ ] App launches without requiring Accessibility permissions (or gracefully degrades)
- [ ] Energy impact rated "Low" in Activity Monitor
- [ ] Unit tests pass for `AppState` and `MonitoringService` with ≥80% coverage on those files

---

*Document generated by Lead Agent — EyesHealth V1 Architecture Review*
