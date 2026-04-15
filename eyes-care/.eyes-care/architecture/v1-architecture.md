# EyesCare v1 Architecture

**Version:** 1.0
**Date:** 2026-04-15
**Author:** Lead Engineer Agent
**Status:** Final

---

## 1. Architectural Overview

### 1.1 Design Philosophy

EyesCare v1 follows three core principles:

1. **Testability via Protocol-based DI** - All services defined as protocols with production implementations. Tests inject mocks via default parameter initializers.
2. **Value-type-first with Actor isolation** - Models are `Sendable` structs/enums. Shared mutable state lives in an `@MainActor`-annotated class to avoid data races while keeping UI updates on the main thread.
3. **Separation of concerns** - `EyesCareCore` (library) owns business logic and state machines. `EyesCareApp` (executable) owns AppKit/SwiftUI integration.

### 1.2 High-Level Architecture

```
+----------------------------------------------------------+
|                     macOS System                         |
|   CGEventSource  |  NSStatusBar  |  Timer (RunLoop)     |
+--------+---------+------+--------+---------+-------------+
         |                |                  |
+--------v---------+      |                  |
|  EyesCareCore    |      |                  |
|  (Library Target)|      |                  |
|                  |      |                  |
|  +-----------+   |      |                  |
|  | ActivityState |<-----+------------------+
|  | (enum)    |   |      |                  |
|  +-----------+   |      |                  |
|                  |      |                  |
|  +-----------+   |      |                  |
|  | IdleDetector  |      |                  |
|  | (protocol)|   |      |                  |
|  +-----+-----+   |      |                  |
|        |         |      |                  |
|  +-----v--------+|      |                  |
|  | CGEventSource||      |                  |
|  | IdleDetector  ||      |                  |
|  | (concrete)   ||      |                  |
|  +--------------+|      |                  |
|                  |      |                  |
|  +-----------+   |      |                  |
|  | MonitoringSession |  |                  |
|  | (class)   |   |      |                  |
|  +-----------+   |      |                  |
|                  |      |                  |
|  +-----------+   |      |                  |
|  | TimeFormatter |      |                  |
|  | (enum)    |   |      |                  |
|  +-----------+   |      |                  |
+------------------+      |                  |
                          |                  |
+-------------------------v------------------v-+
|                EyesCareApp                   |
|               (Executable Target)            |
|                                              |
|  +------------------+                        |
|  | EyesCareApp.swift | (@main, Scene)        |
|  +------------------+                        |
|                                              |
|  +------------------+                        |
|  | AppDelegate.swift | (NSStatusItem, NSMenu)|
|  +------------------+                        |
+----------------------------------------------+
```

### 1.3 Data Flow

```
CGEventSource ──(secondsSinceLastEvent)──> IdleDetector
                                               │
                                               v
Timer (5s) ──(tick)──> MonitoringSession.poll()
                            │
                            ├── reads IdleDetector.secondsSinceLastEvent()
                            ├── computes ActivityState transition
                            ├── updates activeTime / sinceLastBreak
                            └── calls delegate.monitoringSessionDidUpdate(_:)
                                               │
                                               v
                                     AppDelegate updates NSMenu items
                                     AppDelegate updates NSStatusItem icon
```

---

## 2. Module Design

### 2.1 EyesCareCore (Library Target)

This module contains **zero** UI dependencies. It imports only `Foundation` and `CoreGraphics`.

#### 2.1.1 Models Layer

| File | Type | Purpose |
|------|------|---------|
| `ActivityState.swift` | `enum` | Three-state machine: `.active`, `.idle`, `.away` |
| `BreakType.swift` | `enum` | Medical break definitions (existing) |
| `ReminderMode.swift` | `enum` | Notification modes for future versions (existing) |
| `MonitoringStatus.swift` | `struct` | Snapshot of current monitoring state (time values, state) |

#### 2.1.2 Protocols Layer

| File | Type | Purpose |
|------|------|---------|
| `IdleDetecting.swift` | `protocol` | Abstracts idle-time source for testability |
| `MonitoringSessionDelegate.swift` | `protocol` | Callback interface for state changes |

#### 2.1.3 Services Layer

| File | Type | Purpose |
|------|------|---------|
| `CGEventSourceIdleDetector.swift` | `struct` | Production idle detector using CGEventSource |
| `MonitoringSession.swift` | `class` | State machine + time tracking orchestrator |

#### 2.1.4 Utils Layer

| File | Type | Purpose |
|------|------|---------|
| `Constants.swift` | `enum` | Configuration constants (existing) |
| `TimeFormatter.swift` | `enum` | Human-readable time display formatting |

### 2.2 EyesCareApp (Executable Target)

This module depends on `EyesCareCore` and imports `AppKit`, `SwiftUI`.

| File | Type | Purpose |
|------|------|---------|
| `EyesCareApp.swift` | `struct` | @main entry point (existing) |
| `AppDelegate.swift` | `class` | NSStatusItem, NSMenu, Timer, MonitoringSession coordinator |

---

## 3. Key Types — Detailed Design

### 3.1 ActivityState

```swift
// Sources/EyesCareCore/Models/ActivityState.swift

public enum ActivityState: String, Sendable, Equatable, Codable {
    case active  // User has interacted within idleThreshold
    case idle    // No input for idleThreshold...naturalBreakThreshold
    case away    // No input for >= naturalBreakThreshold (natural break)
    
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

**Design decisions:**
- Pure function `from(idleSeconds:)` makes state derivation testable without timers
- Thresholds are parameters with defaults — tests can override
- `Sendable`, `Equatable`, `Codable` for concurrency safety and future persistence

### 3.2 IdleDetecting Protocol

```swift
// Sources/EyesCareCore/Protocols/IdleDetecting.swift

public protocol IdleDetecting: Sendable {
    func secondsSinceLastEvent() -> TimeInterval
}
```

**Why a protocol?**
- `CGEventSource` is not available in test targets (no display server in CI)
- Protocol allows mock injection: `MockIdleDetector` returns controlled values
- Future: could swap to IOKit fallback without touching business logic

### 3.3 CGEventSourceIdleDetector

```swift
// Sources/EyesCareCore/Services/CGEventSourceIdleDetector.swift

import CoreGraphics

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

**Design decisions:**
- Checks **multiple** event types (keyboard, mouse move, click, scroll) and takes the minimum — ensures any user activity is detected
- `struct` — no mutable state, `Sendable` for free
- No Accessibility permission required

### 3.4 MonitoringStatus

```swift
// Sources/EyesCareCore/Models/MonitoringStatus.swift

public struct MonitoringStatus: Sendable, Equatable {
    public let isMonitoring: Bool
    public let activityState: ActivityState
    public let activeTime: TimeInterval       // cumulative active seconds
    public let sinceLastBreak: TimeInterval   // seconds since last natural break
    public let lastStateChange: Date
    
    public init(
        isMonitoring: Bool,
        activityState: ActivityState,
        activeTime: TimeInterval,
        sinceLastBreak: TimeInterval,
        lastStateChange: Date
    ) { ... }
}
```

**Why a separate snapshot struct?**
- Immutable data transfer object — AppDelegate reads it to update menu
- `Equatable` enables change detection — only update menu when values change
- Clean separation: `MonitoringSession` produces it, `AppDelegate` consumes it

### 3.5 MonitoringSessionDelegate

```swift
// Sources/EyesCareCore/Protocols/MonitoringSessionDelegate.swift

@MainActor
public protocol MonitoringSessionDelegate: AnyObject {
    func monitoringSessionDidUpdate(_ status: MonitoringStatus)
}
```

**Why delegate pattern (not Combine/async)?**
- AppDelegate is already `@MainActor` — delegate callbacks are natural
- No Combine dependency needed for v1
- Simple, explicit, easy to test with a mock delegate
- Future versions can add `AsyncStream`-based API alongside if needed

### 3.6 MonitoringSession

```swift
// Sources/EyesCareCore/Services/MonitoringSession.swift

@MainActor
public final class MonitoringSession {
    // Dependencies (protocol-based DI)
    private let idleDetector: any IdleDetecting
    
    // State
    private(set) var isMonitoring: Bool = false
    private var activityState: ActivityState = .active
    private var monitoringStartDate: Date?
    private var lastBreakEndDate: Date?
    private var accumulatedActiveTime: TimeInterval = 0
    private var lastActiveDate: Date?
    
    // Timer
    private var pollTimer: Timer?
    
    // Delegate
    weak var delegate: (any MonitoringSessionDelegate)?
    
    // DI with defaults
    public init(idleDetector: any IdleDetecting = CGEventSourceIdleDetector()) {
        self.idleDetector = idleDetector
    }
    
    // Public API
    public func start() { ... }
    public func pause() { ... }
    public func currentStatus() -> MonitoringStatus { ... }
    
    // Internal
    func poll() { ... }  // Called by Timer every Constants.pollingInterval
}
```

**Design decisions:**
- `@MainActor` because it owns a `Timer` (RunLoop-based) and UI state
- `final class` — needs reference semantics for Timer lifecycle and delegate
- Tracks time with `Date` objects, not accumulated intervals (prevents drift)
- `poll()` is `internal` (not private) so tests can call it directly without real timers

### 3.7 TimeFormatter

```swift
// Sources/EyesCareCore/Utils/TimeFormatter.swift

public enum TimeFormatter {
    public static func formatActiveTime(_ interval: TimeInterval) -> String { ... }
    public static func formatSinceLastBreak(_ interval: TimeInterval, isIdle: Bool) -> String { ... }
}
```

**Formatting rules (from UX spec):**

| Duration | Active Time | Since Last Break |
|----------|-------------|-----------------|
| < 60s | "< 1m" | "< 1m" |
| 1-59 min | "Xm" | "Xm" |
| 60+ min | "Xh Ym" | "Xh Ym" |
| 24+ hours | "Xd Yh" | N/A |
| During idle | — | "0m (resting)" |
| Paused | "—" | "—" |

---

## 4. State Machine

### 4.1 State Transitions

```
                    ┌─────────────────────────────────────────┐
                    │                                         │
                    │         idleSeconds < idleThreshold      │
                    │              (input detected)            │
                    │                                         │
                    ▼                                         │
              ┌──────────┐     idleSeconds >= idleThreshold   │
              │  ACTIVE  │ ─────────────────────────────► ┌──────┐
              │          │                                │ IDLE │
              └──────────┘                                └──┬───┘
                    ▲                                        │
                    │     idleSeconds < idleThreshold         │  idleSeconds >= naturalBreakThreshold
                    │          (input detected)               │
                    │    *** RESET active time ***             ▼
                    │                                    ┌──────────┐
                    └────────────────────────────────────│  AWAY    │
                                                        │(natural  │
                                                        │ break)   │
                                                        └──────────┘
```

### 4.2 State Behavior

| Transition | Time Tracking Effect |
|------------|---------------------|
| `active` stays `active` | Accumulate active time; increment sinceLastBreak |
| `active` -> `idle` | Freeze active time; sinceLastBreak continues (will become break if >= 120s) |
| `idle` -> `active` | Resume active time accumulation; sinceLastBreak continues |
| `idle` -> `away` | Natural break detected; prepare to reset sinceLastBreak |
| `away` -> `active` | **Reset sinceLastBreak to 0**; start fresh active session |

### 4.3 Time Tracking Strategy

**Problem:** Timer-accumulated intervals drift over long sessions (hours/days).

**Solution:** Date-based tracking:
- `monitoringStartDate: Date` — when monitoring was started
- `lastBreakEndDate: Date` — when the last natural break ended (user returned)
- `lastActiveDate: Date` — when we last observed active state
- `accumulatedActiveTime: TimeInterval` — only incremented during `.active` polls

On each `poll()`:
1. Read `idleDetector.secondsSinceLastEvent()`
2. Derive new `ActivityState.from(idleSeconds:)`
3. If previous was `.active` and still `.active`: add `Constants.pollingInterval` to `accumulatedActiveTime`
4. If transitioning to `.away`: no time changes
5. If transitioning from `.away` to `.active`: reset `lastBreakEndDate = Date()`, reset sinceLastBreak
6. Compute `sinceLastBreak = Date().timeIntervalSince(lastBreakEndDate)`
7. Build `MonitoringStatus` snapshot and notify delegate

---

## 5. Menu Bar Integration

### 5.1 AppDelegate Responsibilities

```
AppDelegate
├── Setup
│   ├── Create NSStatusItem with "eye" SF Symbol
│   ├── Build NSMenu with info items + actions
│   ├── Create MonitoringSession (inject IdleDetector)
│   └── Set self as MonitoringSession.delegate
│
├── Monitoring Lifecycle
│   ├── Start monitoring on applicationDidFinishLaunching
│   ├── Pause/Resume via menu toggle item
│   └── Stop monitoring on applicationWillTerminate
│
├── Menu Update (on MonitoringSessionDelegate callback)
│   ├── Update status item: "● Monitoring" / "● Monitoring (Idle)" / "○ Paused"
│   ├── Update active time: "Active Time: Xh Ym"
│   ├── Update since last break: "Since Last Break: Xm"
│   └── Update icon: "eye" (monitoring) / "eye.slash" (paused)
│
└── Menu Items (stored as properties for dynamic updates)
    ├── titleItem (disabled) — "EyesCare v1.0"
    ├── statusItem (disabled) — "● Monitoring"
    ├── activeTimeItem (disabled) — "Active Time: ..."
    ├── sinceLastBreakItem (disabled) — "Since Last Break: ..."
    └── toggleItem (enabled) — "Pause Monitoring" / "Resume Monitoring"
```

### 5.2 Menu Item References

AppDelegate stores `NSMenuItem` references as properties to update them dynamically:

```swift
private var statusMenuItem: NSMenuItem?
private var activeTimeMenuItem: NSMenuItem?
private var sinceLastBreakMenuItem: NSMenuItem?
private var toggleMenuItem: NSMenuItem?
```

This avoids rebuilding the entire menu on every poll (5 seconds).

---

## 6. File Map

### 6.1 New Files (v1)

```
Sources/EyesCareCore/
├── Models/
│   ├── ActivityState.swift        (NEW — ~40 lines)
│   └── MonitoringStatus.swift     (NEW — ~35 lines)
├── Protocols/
│   ├── IdleDetecting.swift        (NEW — ~12 lines)
│   └── MonitoringSessionDelegate.swift  (NEW — ~10 lines)
├── Services/
│   ├── CGEventSourceIdleDetector.swift  (NEW — ~30 lines)
│   └── MonitoringSession.swift    (NEW — ~150 lines)
└── Utils/
    └── TimeFormatter.swift        (NEW — ~55 lines)

Tests/EyesCareTests/
├── Mocks/
│   ├── MockIdleDetector.swift     (NEW — ~20 lines)
│   └── MockMonitoringSessionDelegate.swift  (NEW — ~25 lines)
├── BreakTypeTests.swift           (NEW — ~50 lines)
├── ActivityStateTests.swift       (NEW — ~60 lines)
├── MonitoringStatusTests.swift    (NEW — ~30 lines)
├── TimeFormatterTests.swift       (NEW — ~70 lines)
└── MonitoringSessionTests.swift   (NEW — ~120 lines)
```

### 6.2 Modified Files (v1)

```
Sources/EyesCareApp/
└── AppDelegate.swift              (MODIFY — expand from ~25 to ~180 lines)

Package.swift                      (MODIFY — add test target)
```

### 6.3 Unchanged Files (v1)

```
Sources/EyesCareApp/EyesCareApp.swift
Sources/EyesCareCore/Models/BreakType.swift
Sources/EyesCareCore/Models/ReminderMode.swift
Sources/EyesCareCore/Utils/Constants.swift
```

---

## 7. Dependency Graph

```
Package.swift
    │
    ├── EyesCareCore (library)
    │       imports: Foundation, CoreGraphics
    │       no external dependencies
    │
    ├── EyesCareApp (executable)
    │       depends on: EyesCareCore
    │       imports: AppKit, SwiftUI, EyesCareCore
    │
    └── EyesCareTests (test)
            depends on: EyesCareCore
            imports: Testing, EyesCareCore
            (does NOT import EyesCareApp — tests Core logic only)
```

### 7.1 Internal Dependency Order

```
Constants (standalone)
    ↓
ActivityState (depends on Constants for thresholds)
    ↓
IdleDetecting (protocol, no deps)
    ↓
CGEventSourceIdleDetector (implements IdleDetecting)
    ↓
MonitoringStatus (depends on ActivityState)
    ↓
MonitoringSessionDelegate (depends on MonitoringStatus)
    ↓
TimeFormatter (depends on nothing)
    ↓
MonitoringSession (depends on all above)
```

---

## 8. Concurrency Model

### 8.1 Thread Safety

| Type | Isolation | Rationale |
|------|-----------|-----------|
| `ActivityState` | `Sendable` (enum) | Value type, safe to share |
| `MonitoringStatus` | `Sendable` (struct) | Value type, safe to share |
| `CGEventSourceIdleDetector` | `Sendable` (struct) | Stateless, safe to share |
| `MonitoringSession` | `@MainActor` | Owns Timer + UI state; must be on main thread |
| `AppDelegate` | `@MainActor` (implicit via NSObject) | AppKit requirement |

### 8.2 Timer Strategy

- Use `Timer.scheduledTimer(withTimeInterval:repeats:)` on the main RunLoop
- The Timer fires every `Constants.pollingInterval` (5 seconds)
- Timer is invalidated on `pause()` and `applicationWillTerminate`
- No background threads needed — entire v1 runs on `@MainActor`

---

## 9. Extensibility for Future Versions

### 9.1 v2 Extension Points (Core Reminders)

- `MonitoringSession` will gain break schedule tracking
- New `BreakScheduler` service will observe `MonitoringStatus.sinceLastBreak`
- `MonitoringSessionDelegate` will gain `monitoringSessionShouldBreak(_:type:)` callback

### 9.2 v3 Extension Points (Notification Upgrade)

- New `NotificationPresenter` protocol in Core
- `GentleNotificationPresenter`, `NormalNotificationPresenter`, `AggressiveNotificationPresenter` in App
- `MonitoringSession` calls presenter via delegate

### 9.3 v4 Extension Points (Data Persistence)

- New `PersistenceService` protocol in Core
- `JSONFilePersistenceService` in Core (writes to ~/Library/Application Support/EyesCare/)
- `MonitoringSession` calls persistence on state changes

**Architecture rule:** Each version adds new protocols + concrete implementations. Existing code changes minimally.

---

## 10. Testing Strategy

### 10.1 Test Architecture

```
Tests/EyesCareTests/
├── Mocks/
│   ├── MockIdleDetector.swift           # Returns configurable idle seconds
│   └── MockMonitoringSessionDelegate.swift  # Captures status updates
├── BreakTypeTests.swift                 # Medical values + formatting
├── ActivityStateTests.swift             # State derivation from idle seconds
├── MonitoringStatusTests.swift          # Snapshot equality
├── TimeFormatterTests.swift             # All formatting rules
└── MonitoringSessionTests.swift         # Full session lifecycle
```

### 10.2 Mock Design

```swift
final class MockIdleDetector: IdleDetecting, @unchecked Sendable {
    var idleSeconds: TimeInterval = 0
    func secondsSinceLastEvent() -> TimeInterval { idleSeconds }
}
```

This allows tests to:
1. Set `mockIdleDetector.idleSeconds = 0` → simulate active user
2. Set `mockIdleDetector.idleSeconds = 35` → simulate idle user
3. Set `mockIdleDetector.idleSeconds = 130` → simulate away user
4. Call `session.poll()` directly → test state transitions without real timers

### 10.3 Coverage Targets

| Module | Target | Strategy |
|--------|--------|----------|
| ActivityState | 100% | Pure function, all paths testable |
| MonitoringStatus | 100% | Value type, trivial |
| TimeFormatter | 100% | Pure functions, parameterized tests |
| MonitoringSession | 90%+ | Mock DI, direct poll() calls |
| BreakType | 100% | Value assertions |
| CGEventSourceIdleDetector | 0% | Requires display server; excluded from CI coverage |

**Overall EyesCareCore target: >= 80%** (CGEventSourceIdleDetector excluded by design)

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | Lead Engineer Agent | Initial v1 architecture |
