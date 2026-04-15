# EyesHealth V1 — Design Specification

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-14
**Author:** PM Agent

---

## Table of Contents

1. [Overview](#1-overview)
2. [User Stories](#2-user-stories)
3. [Features](#3-features)
4. [UX Wireframes](#4-ux-wireframes)
5. [Technical Requirements](#5-technical-requirements)
6. [Acceptance Criteria](#6-acceptance-criteria)
7. [Medical References](#7-medical-references)

---

## 1. Overview

### 1.1 Product Summary

EyesHealth is a lightweight macOS menu bar application that monitors continuous screen usage and reminds users to take eye breaks following the medically-endorsed **20-20-20 Rule**. The app runs unobtrusively in the status bar, tracks active screen time, and delivers timely notifications to help prevent digital eye strain (computer vision syndrome).

### 1.2 Problem Statement

Prolonged screen use causes digital eye strain affecting 50-90% of computer workers. Symptoms include dry eyes, blurred vision, headaches, and neck pain. The American Academy of Ophthalmology recommends the 20-20-20 rule, but users rarely remember to follow it without automated reminders.

### 1.3 V1 Goals

- Deliver a zero-configuration, install-and-forget experience
- Accurately detect active screen usage vs. natural breaks
- Remind users at medically-recommended intervals
- Require no accessibility permissions or special entitlements
- Run efficiently with minimal CPU/memory footprint

### 1.4 Target User

Knowledge workers who spend 4+ hours daily on a Mac — developers, designers, writers, analysts — who want to protect their eye health without complex setup.

### 1.5 Success Metrics (V1)

| Metric | Target |
|--------|--------|
| Daily active usage (app running) | > 6 hours/day |
| Notification-to-break conversion | > 40% |
| CPU usage (idle polling) | < 0.5% |
| Memory footprint | < 30 MB |
| Crash-free sessions | > 99.5% |

### 1.6 Out of Scope for V1

- Eye health scoring / analytics dashboard
- Customizable break intervals
- Guided exercises during breaks
- iCloud sync
- iOS companion app
- Preferences window
- Auto-launch at login (manual setup via System Settings)
- Sparkle / auto-update

---

## 2. User Stories

### 2.1 Core User Stories

| ID | Story | Priority |
|----|-------|----------|
| US-01 | As a user, I want the app to appear in my menu bar so I can see my screen time at a glance without opening a window. | P0 |
| US-02 | As a user, I want the app to automatically detect when I'm actively using my computer so I don't have to manually start/stop timers. | P0 |
| US-03 | As a user, I want to receive a notification after 20 minutes of continuous screen use reminding me to look away. | P0 |
| US-04 | As a user, I want the notification to explain the 20-20-20 rule so I know what to do during the break. | P0 |
| US-05 | As a user, I want to snooze a reminder for 5 minutes if I'm in the middle of something. | P1 |
| US-06 | As a user, I want to see how many breaks I've taken today so I feel motivated to keep going. | P1 |
| US-07 | As a user, I want the menu bar icon to change color based on how long since my last break so I have a passive visual indicator. | P1 |
| US-08 | As a user, I want the app to recognize when I lock my screen or step away and treat that as a natural break. | P0 |
| US-09 | As a user, I want to manually trigger a break from the menu. | P2 |
| US-10 | As a user, I want the break counter to reset at midnight so each day starts fresh. | P1 |

### 2.2 Anti-Stories (Explicitly NOT in V1)

| ID | Anti-Story |
|----|------------|
| AS-01 | As a user, I do NOT need to customize the break interval in V1. |
| AS-02 | As a user, I do NOT need historical data or weekly reports in V1. |
| AS-03 | As a user, I do NOT need guided exercises during breaks in V1. |
| AS-04 | As a user, I do NOT need the app to sync data across devices in V1. |

---

## 3. Features

### 3.1 Menu Bar Presence

**Description:** The app runs exclusively as a macOS menu bar (status bar) item with no Dock icon and no main window.

**Behavior:**
- Uses `MenuBarExtra` (macOS 13+) with a window-style menu
- Displays an SF Symbol eye icon (`eye` / `eye.fill`)
- Optionally shows elapsed time next to the icon (e.g., `eye.fill 12m`)
- Icon color reflects urgency tier (see 3.6)
- App has `LSUIElement = true` (no Dock icon)

### 3.2 Idle Time Detection

**Description:** Polls system-wide input events to determine whether the user is actively using the computer.

**Behavior:**
- Uses `CGEventSourceSecondsSinceLastEventType(.combinedSessionState, .any)` — **no permissions required**
- Polls every **5 seconds** via a `Timer`
- State machine with two states:
  - **Active**: idle time < 30 seconds → screen time counter increments
  - **Idle**: idle time ≥ 30 seconds → screen time counter pauses
- If idle duration exceeds **2 minutes** continuously, treat as a **natural break**:
  - Reset the continuous screen time counter to 0
  - Increment today's break count
  - Transition icon color to green

**State Diagram:**

```
                    idle < 30s
              ┌──────────────────┐
              │                  │
              ▼                  │
         ┌─────────┐       ┌────┴────┐
  start──▶  ACTIVE  │──────▶│  IDLE   │
         └────┬────┘ idle   └────┬────┘
              │      ≥30s        │
              │                  │ idle ≥ 2 min
              │                  ▼
              │            ┌──────────┐
              │            │ BREAK    │
              │            │ (natural)│
              │            └────┬─────┘
              │                 │ activity resumes
              │◄────────────────┘
              │   reset timer, increment break count
```

### 3.3 Screen Lock Detection

**Description:** Pauses monitoring when the screen is locked and resumes when unlocked.

**Behavior:**
- Listens to `DistributedNotificationCenter` for:
  - `com.apple.screenIsLocked` → pause monitoring, mark time
  - `com.apple.screenIsUnlocked` → resume monitoring
- If lock duration ≥ 2 minutes → treat as natural break (same as idle break)
- If lock duration < 2 minutes → resume continuous timer where it left off

### 3.4 20-20-20 Rule Reminder

**Description:** After 20 minutes of continuous active screen use, deliver a macOS notification.

**Behavior:**
- Threshold: **1200 seconds** (20 minutes) of accumulated active time
- Uses `UNUserNotificationCenter` for local notifications
- Notification content:
  - **Title:** "Time for an Eye Break! 👀"
  - **Body:** "You've been looking at the screen for 20 minutes. Look at something 20 feet (~6 meters) away for 20 seconds."
  - **Sound:** default system sound
- Notification actions:
  - **Default (tap):** Dismiss, count as break taken, reset timer
  - **"Snooze 5 min":** Postpone reminder by 5 minutes, do NOT count as break
  - **"Dismiss":** Dismiss without counting as break, reset timer
- After notification is delivered:
  - If user interacts (tap or Dismiss): reset continuous timer, increment break count
  - If user snoozes: set a 5-minute delayed re-notification
  - If user ignores: re-notify after 5 minutes (max 2 re-notifications, then stop until next active period)
- Request notification permission on first launch

### 3.5 Break Tracking

**Description:** Track the number of eye breaks taken during the current calendar day.

**Behavior:**
- Counter stored in memory (no persistence in V1)
- Break is counted when:
  - User acknowledges notification (tap or Dismiss action)
  - Natural break detected (idle ≥ 2 minutes)
  - User taps "Take a Break Now" in menu
- Counter resets to 0 at midnight local time
- Midnight reset via a scheduled `Timer` that fires at `Calendar.startOfDay(for: tomorrow)`

### 3.6 Menu Bar Icon Color States

**Description:** The icon color changes to passively communicate urgency.

| State | Condition | Icon | Color |
|-------|-----------|------|-------|
| Fresh | 0–10 min since last break | `eye.fill` | Green (`.green`) |
| Warning | 10–20 min since last break | `eye.fill` | Yellow (`.yellow`) |
| Overdue | 20+ min (break overdue) | `eye` (outline) | Red (`.red`) |

**Implementation:** Use `Image(systemName:).symbolRenderingMode(.palette)` with `foregroundStyle` to set icon tint. Update color on each poll tick.

### 3.7 Menu Content

**Description:** Clicking the menu bar icon reveals a compact SwiftUI view.

**Layout:**

```
┌──────────────────────────────────┐
│  🟢 Eyes are resting well        │
│                                  │
│  ⏱  Time since last break: 8m   │
│  ✅ Breaks today: 12             │
│                                  │
│  ┌────────────────────────────┐  │
│  │   👁 Take a Break Now      │  │
│  └────────────────────────────┘  │
│                                  │
│  ──────────────────────────────  │
│  Quit EyesHealth                 │
│                                  │
└──────────────────────────────────┘
```

**Elements:**
1. **Status label** — contextual message:
   - Green: "Eyes are resting well"
   - Yellow: "Consider taking a break soon"
   - Red: "Break overdue — rest your eyes!"
2. **Time since last break** — formatted as `Xm` or `Xh Ym`
3. **Breaks today** — integer count
4. **"Take a Break Now" button** — resets timer, increments break count, shows confirmation
5. **Divider**
6. **"Quit EyesHealth"** — terminates the app

---

## 4. UX Wireframes

### 4.1 Menu Bar States

```
┌─────────────────────────────────────────────────────────────────────┐
│  Menu Bar (macOS)                                                   │
│  ┌──────┐  ┌──────┐  ┌──────┐                                      │
│  │🟢 8m │  │🟡 14m│  │🔴 22m│                                      │
│  └──────┘  └──────┘  └──────┘                                      │
│   Fresh     Warning    Overdue                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Menu — Fresh State

```
╔══════════════════════════════════╗
║  🟢 Eyes are resting well        ║
║                                  ║
║  ⏱  Time since last break   8m  ║
║  ✅ Breaks today             12  ║
║                                  ║
║  ┌────────────────────────────┐  ║
║  │     👁  Take a Break Now   │  ║
║  └────────────────────────────┘  ║
║                                  ║
║  ────────────────────────────── ║
║  Quit EyesHealth                 ║
╚══════════════════════════════════╝
```

### 4.3 Menu — Overdue State

```
╔══════════════════════════════════╗
║  🔴 Break overdue — rest your   ║
║     eyes!                        ║
║                                  ║
║  ⏱  Time since last break  22m  ║
║  ✅ Breaks today              3  ║
║                                  ║
║  ┌────────────────────────────┐  ║
║  │     👁  Take a Break Now   │  ║
║  └────────────────────────────┘  ║
║                                  ║
║  ──────────────────────────────  ║
║  Quit EyesHealth                 ║
╚══════════════════════════════════╝
```

### 4.4 Notification

```
┌──────────────────────────────────────────────────────┐
│ ╔════════════════════════════════════════════════╗    │
│ ║ 👁 EyesHealth                              now ║    │
│ ║                                                ║    │
│ ║ Time for an Eye Break! 👀                      ║    │
│ ║                                                ║    │
│ ║ You've been looking at the screen for 20       ║    │
│ ║ minutes. Look at something 20 feet (~6 meters) ║    │
│ ║ away for 20 seconds.                           ║    │
│ ║                                                ║    │
│ ║        ┌──────────┐  ┌─────────────┐           ║    │
│ ║        │ Dismiss  │  │ Snooze 5min │           ║    │
│ ║        └──────────┘  └─────────────┘           ║    │
│ ╚════════════════════════════════════════════════╝    │
└──────────────────────────────────────────────────────┘
```

### 4.5 First Launch — Permission Request

```
┌──────────────────────────────────────────────────────┐
│ ╔════════════════════════════════════════════════╗    │
│ ║  "EyesHealth" Would Like to Send You           ║    │
│ ║  Notifications                                 ║    │
│ ║                                                ║    │
│ ║  Notifications may include alerts, sounds,     ║    │
│ ║  and icon badges. These can be configured in   ║    │
│ ║  Settings.                                     ║    │
│ ║                                                ║    │
│ ║        ┌───────────┐  ┌──────────┐             ║    │
│ ║        │Don't Allow│  │  Allow   │             ║    │
│ ║        └───────────┘  └──────────┘             ║    │
│ ╚════════════════════════════════════════════════╝    │
└──────────────────────────────────────────────────────┘
```

### 4.6 User Flow Diagram

```
                      ┌─────────────┐
                      │  App Launch  │
                      └──────┬──────┘
                             │
                    ┌────────▼────────┐
                    │ Request notif.  │
                    │ permission      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Start idle      │
                    │ polling (5s)    │
                    └────────┬────────┘
                             │
                 ┌───────────▼───────────┐
                 │ User actively using?  │
                 └───┬───────────────┬───┘
                     │ YES           │ NO
              ┌──────▼──────┐  ┌────▼─────────┐
              │ Increment   │  │ Idle ≥ 2min?  │
              │ screen time │  └──┬─────────┬──┘
              └──────┬──────┘     │ NO      │ YES
                     │            │    ┌────▼──────┐
              ┌──────▼──────┐     │    │ Count as  │
              │ ≥ 20 min?   │     │    │ break,    │
              └──┬───────┬──┘     │    │ reset     │
                 │ NO    │ YES    │    └───────────┘
                 │  ┌────▼─────┐  │
                 │  │ Send     │  │
                 │  │ notif.   │  │
                 │  └────┬─────┘  │
                 │       │        │
                 │  ┌────▼───────────────┐
                 │  │ User response?     │
                 │  └──┬──────┬──────┬───┘
                 │     │      │      │
                 │  Dismiss Snooze  Tap
                 │     │      │      │
                 │  ┌──▼──┐ ┌▼────┐ ┌▼────┐
                 │  │Reset│ │Wait │ │Reset│
                 │  │timer│ │5min │ │timer│
                 │  │+brk │ │     │ │+brk │
                 │  └─────┘ └─────┘ └─────┘
                 │
                 └──── continue polling ────▶ (loop)
```

---

## 5. Technical Requirements

### 5.1 Project Structure

```
EyesHealth/
├── Package.swift                    # SPM manifest
├── Sources/
│   └── EyesHealth/
│       ├── App/
│       │   └── EyesHealthApp.swift  # @main, MenuBarExtra
│       ├── Models/
│       │   ├── ScreenTimeState.swift    # Activity state enum
│       │   └── BreakTracker.swift       # Break counting logic
│       ├── Services/
│       │   ├── IdleDetector.swift        # CGEventSource polling
│       │   ├── ScreenLockMonitor.swift   # DistributedNotificationCenter
│       │   ├── BreakReminderService.swift # 20-20-20 timer logic
│       │   └── NotificationService.swift  # UNUserNotificationCenter
│       ├── ViewModels/
│       │   └── MenuViewModel.swift       # @Observable, drives UI
│       └── Views/
│           └── MenuContentView.swift     # Menu bar popup UI
├── Tests/
│   └── EyesHealthTests/
│       ├── IdleDetectorTests.swift
│       ├── BreakTrackerTests.swift
│       └── BreakReminderServiceTests.swift
└── README.md
```

### 5.2 Platform & Dependencies

| Item | Requirement |
|------|-------------|
| Platform | macOS 13.0+ (Ventura) |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Build System | Swift Package Manager |
| IDE | Xcode 15+ (for development, NOT Xcode project format) |
| Dependencies | None (all Apple frameworks) |

### 5.3 Key Frameworks & APIs

| Framework | Usage |
|-----------|-------|
| `SwiftUI` | MenuBarExtra, menu content view |
| `AppKit` | NSApplication (LSUIElement) |
| `CoreGraphics` | `CGEventSourceSecondsSinceLastEventType` for idle detection |
| `UserNotifications` | `UNUserNotificationCenter` for break reminders |
| `Foundation` | `DistributedNotificationCenter`, `Timer`, `Calendar` |

### 5.4 Idle Detection Implementation

```swift
// No permissions required — reads aggregate HID event age
import CoreGraphics

func secondsSinceLastInput() -> TimeInterval {
    CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: CGEventType(rawValue: ~0)!  // kCGAnyInputEventType
    )
}
```

**Polling strategy:**
- `Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true)`
- On each tick:
  1. Read `secondsSinceLastInput()`
  2. If < 30s → user is active → increment `continuousActiveTime += 5`
  3. If ≥ 30s → user is idle → pause counter, start tracking idle duration
  4. If idle ≥ 120s → natural break → reset `continuousActiveTime = 0`, increment `breaksToday`
  5. If `continuousActiveTime ≥ 1200` (20 min) → fire notification

### 5.5 Screen Lock Detection Implementation

```swift
import Foundation

DistributedNotificationCenter.default().addObserver(
    self,
    selector: #selector(screenDidLock),
    name: NSNotification.Name("com.apple.screenIsLocked"),
    object: nil
)

DistributedNotificationCenter.default().addObserver(
    self,
    selector: #selector(screenDidUnlock),
    name: NSNotification.Name("com.apple.screenIsUnlocked"),
    object: nil
)
```

**Behavior on lock/unlock:**
- `screenDidLock`: record `lockStartTime`, pause idle polling timer
- `screenDidUnlock`: calculate `lockDuration = now - lockStartTime`
  - If `lockDuration ≥ 120s`: treat as break, reset continuous timer
  - If `lockDuration < 120s`: resume continuous timer where it left off
  - Resume polling timer

### 5.6 Notification Implementation

```swift
import UserNotifications

// Category with actions
let snoozeAction = UNNotificationAction(
    identifier: "SNOOZE_ACTION",
    title: "Snooze 5 min",
    options: []
)
let dismissAction = UNNotificationAction(
    identifier: "DISMISS_ACTION",
    title: "Dismiss",
    options: []
)
let breakCategory = UNNotificationCategory(
    identifier: "BREAK_REMINDER",
    actions: [dismissAction, snoozeAction],
    intentIdentifiers: [],
    options: []
)

// Notification content
let content = UNMutableNotificationContent()
content.title = "Time for an Eye Break! 👀"
content.body = "You've been looking at the screen for 20 minutes. Look at something 20 feet (~6 meters) away for 20 seconds."
content.sound = .default
content.categoryIdentifier = "BREAK_REMINDER"
```

### 5.7 Data Model

```swift
// ScreenTimeState.swift
enum ActivityState {
    case active          // User interacting, timer counting
    case idle            // No input for 30s+, timer paused
    case onBreak         // Natural break detected (idle 2min+)
    case screenLocked    // Screen locked, timer paused
}

// BreakTracker.swift
@Observable
final class BreakTracker {
    var continuousActiveSeconds: Int = 0
    var breaksToday: Int = 0
    var lastBreakTime: Date = .now
    var currentState: ActivityState = .active
    var snoozedUntil: Date? = nil
}
```

### 5.8 Menu Bar Icon Color

```swift
// Computed from continuousActiveSeconds
var iconColor: Color {
    let minutesSinceBreak = continuousActiveSeconds / 60
    switch minutesSinceBreak {
    case 0..<10:  return .green
    case 10..<20: return .yellow
    default:      return .red
    }
}

var iconName: String {
    continuousActiveSeconds / 60 >= 20 ? "eye" : "eye.fill"
}
```

### 5.9 Performance Requirements

| Metric | Requirement | Rationale |
|--------|-------------|-----------|
| CPU (polling) | < 0.5% | 5s timer with trivial CGEventSource call |
| Memory | < 30 MB | No image assets, no persistent data |
| Battery impact | Negligible | No continuous rendering, no network |
| Launch time | < 1 second | No heavy initialization |
| Polling interval | 5 seconds | Balance between accuracy and efficiency |

### 5.10 Package.swift Structure

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyesHealth",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "EyesHealth",
            path: "Sources/EyesHealth"
        ),
        .testTarget(
            name: "EyesHealthTests",
            dependencies: ["EyesHealth"],
            path: "Tests/EyesHealthTests"
        )
    ]
)
```

### 5.11 Info.plist Keys

```xml
<!-- Embedded in executable or set via build settings -->
<key>LSUIElement</key>
<true/>   <!-- Hide Dock icon -->

<key>CFBundleName</key>
<string>EyesHealth</string>

<key>CFBundleIdentifier</key>
<string>com.eyeshealth.app</string>

<key>CFBundleVersion</key>
<string>1.0.0</string>

<key>LSMinimumSystemVersion</key>
<string>13.0</string>
```

### 5.12 Error Handling

| Scenario | Handling |
|----------|----------|
| Notification permission denied | App functions normally without notifications; menu bar icon still changes color; log warning |
| CGEventSource returns unexpected value | Treat as active (fail safe — remind more, not less) |
| Timer drift | Use `Date` comparison, not accumulated intervals, for 20-min threshold |
| Midnight reset fails | Reschedule timer on next tick if past midnight and counter not reset |

---

## 6. Acceptance Criteria

### 6.1 Feature: Menu Bar Presence

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-1.1 | App appears in macOS menu bar with an eye icon on launch | Manual: launch app, verify icon visible in menu bar |
| AC-1.2 | App does NOT appear in the Dock | Manual: verify no Dock icon after launch |
| AC-1.3 | Clicking the icon opens a SwiftUI popover/menu | Manual: click icon, verify menu appears |
| AC-1.4 | Menu displays time since last break | Manual: verify time label updates |
| AC-1.5 | Menu displays breaks taken today | Manual: verify counter shows correct value |
| AC-1.6 | "Take a Break Now" button resets timer and increments counter | Manual: click button, verify timer resets to 0, counter increments by 1 |
| AC-1.7 | "Quit EyesHealth" terminates the app | Manual: click Quit, verify app process exits |

### 6.2 Feature: Idle Detection

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-2.1 | Timer increments while user is actively using the computer | Test: simulate activity, verify `continuousActiveSeconds` increases |
| AC-2.2 | Timer pauses when user is idle for > 30 seconds | Test: stop input for 30s, verify counter stops incrementing |
| AC-2.3 | Timer resets after 2+ minutes of inactivity | Test: stop input for 2min, verify counter resets to 0 |
| AC-2.4 | Natural break (2+ min idle) increments break counter | Test: idle for 2min, verify `breaksToday` increments |
| AC-2.5 | Polling interval is 5 seconds | Test: verify timer fires every 5s ± 0.5s |

### 6.3 Feature: Screen Lock Detection

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-3.1 | Timer pauses when screen is locked | Manual: lock screen, unlock after 30s, verify timer did not advance during lock |
| AC-3.2 | Lock duration ≥ 2 min counts as break | Manual: lock screen for 2+ min, unlock, verify break counted and timer reset |
| AC-3.3 | Lock duration < 2 min resumes timer | Manual: lock for 1 min, unlock, verify timer continues from where it paused |

### 6.4 Feature: 20-20-20 Reminder

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-4.1 | Notification fires after 20 minutes of continuous active use | Test: simulate 20min active use, verify notification delivered |
| AC-4.2 | Notification contains correct title and body text | Manual: read notification content |
| AC-4.3 | Tapping notification resets timer and counts break | Manual: tap notification, verify timer resets and counter increments |
| AC-4.4 | "Snooze 5 min" delays re-notification by 5 minutes | Manual: snooze, verify re-notification after 5min |
| AC-4.5 | "Dismiss" resets timer and counts break | Manual: dismiss, verify reset and increment |
| AC-4.6 | App requests notification permission on first launch | Manual: fresh install, verify permission dialog appears |
| AC-4.7 | App works without notification permission (icon still changes color) | Manual: deny permission, verify icon color changes at 10/20 min |

### 6.5 Feature: Break Tracking

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-5.1 | Break counter starts at 0 on app launch | Test: launch app, verify `breaksToday == 0` |
| AC-5.2 | Counter increments on notification acknowledgment | Test: acknowledge notification, verify increment |
| AC-5.3 | Counter increments on natural break (2min idle) | Test: idle 2min, verify increment |
| AC-5.4 | Counter increments on "Take a Break Now" | Manual: click button, verify increment |
| AC-5.5 | Counter resets to 0 at midnight | Test: simulate midnight crossing, verify counter resets |

### 6.6 Feature: Icon Color States

| # | Criterion | Verification |
|---|-----------|--------------|
| AC-6.1 | Icon is green when 0–10 min since last break | Manual: take break, verify green icon |
| AC-6.2 | Icon turns yellow at 10 minutes | Manual: wait 10min, verify yellow |
| AC-6.3 | Icon turns red at 20 minutes | Manual: wait 20min, verify red |
| AC-6.4 | Icon resets to green after break is taken | Manual: take break after red state, verify green |

---

## 7. Medical References

### 7.1 The 20-20-20 Rule

**Source:** American Academy of Ophthalmology (AAO)

**Rule:** Every **20 minutes**, look at something **20 feet** (~6 meters) away for at least **20 seconds**.

**Evidence:**
- Blinking rate drops from ~15/min to ~5/min during screen use, causing dry eyes
- Near-focus sustained for >20 minutes increases ciliary muscle strain
- 20-second distance viewing allows ciliary muscle relaxation
- Multiple studies show reduced symptoms of Computer Vision Syndrome (CVS) when following this rule

**References:**
- American Academy of Ophthalmology. "Computers, Digital Devices and Eye Strain." [aao.org](https://www.aao.org/eye-health/tips-prevention/computer-usage)
- Sheppard AL, Wolffsohn JS. "Digital eye strain: prevalence, measurement and amelioration." *BMJ Open Ophthalmology*. 2018;3(1):e000146. doi:10.1136/bmjophth-2018-000146
- Anshel J. "Visual Ergonomics Handbook." CRC Press, 2005.

### 7.2 Digital Eye Strain / Computer Vision Syndrome

**Prevalence:** Affects 50–90% of computer workers (AOA)

**Symptoms:**
- Eye strain and fatigue
- Dry eyes and irritation
- Blurred vision
- Headaches
- Neck and shoulder pain

**Risk factors:**
- Continuous screen use > 2 hours
- Poor lighting conditions
- Incorrect viewing distance (< 20 inches)
- Uncorrected refractive errors
- Low humidity environments

**References:**
- American Optometric Association. "Computer Vision Syndrome." [aoa.org](https://www.aoa.org/healthy-eyes/eye-and-vision-conditions/computer-vision-syndrome)
- Rosenfield M. "Computer vision syndrome: a review of ocular causes and potential treatments." *Ophthalmic Physiol Opt*. 2011;31(5):502-515.

### 7.3 V1 Parameter Justification

| Parameter | Value | Medical Basis |
|-----------|-------|---------------|
| Active threshold | 20 minutes | AAO 20-20-20 rule |
| Break duration | 20 seconds | AAO 20-20-20 rule (implied in notification text) |
| Idle = inactive | 30 seconds | Conservative; brief pauses (typing → reading) should not reset |
| Natural break | 2 minutes | Clinical guidance suggests >1 min distance viewing relieves strain; 2 min provides margin |
| Snooze duration | 5 minutes | Balance between flexibility and not exceeding 25 min continuous use |

### 7.4 Future Medical Features (Post-V1)

- **Eye Health Score:** Weighted metric based on break frequency, average session length, time-of-day patterns
- **Blink reminders:** Triggered by webcam blink detection (with permission)
- **Blue light exposure tracking:** Integration with Night Shift / True Tone status
- **Weekly reports:** Trend analysis with medical context
- **Exercise library:** Guided eye exercises (palming, figure-8, near-far focus)

---

## Appendix A: Competitive Analysis

| Feature | EyesHealth V1 | Time Out | Stretchly |
|---------|---------------|----------|-----------|
| Platform | macOS | macOS | Cross-platform |
| Price | Free | $6.99 | Free (OSS) |
| Medical basis | 20-20-20 (AAO) | None specific | General wellness |
| Idle detection | Yes (CGEventSource) | Yes | Yes |
| Screen lock detection | Yes | Partial | No |
| Customizable intervals | No (V1) | Yes | Yes |
| Guided exercises | No (V1) | No | Yes |
| Eye health score | No (V1) | No | No |
| Menu bar presence | Yes | Yes | Yes (tray) |
| Permissions needed | None (notif. only) | Accessibility | Varies |
| Data/analytics | No (V1) | No | Basic |

**V1 Differentiator:** Zero-permission, medically-grounded, zero-configuration. Install and it works.

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **20-20-20 Rule** | Medical guideline: every 20 min, look 20 ft away for 20 sec |
| **CVS** | Computer Vision Syndrome — eye strain from prolonged screen use |
| **Idle time** | Seconds since last keyboard/mouse/trackpad input |
| **Natural break** | Idle period ≥ 2 minutes, indicating user stepped away |
| **Continuous active time** | Accumulated seconds of active use without a qualifying break |
| **MenuBarExtra** | SwiftUI API (macOS 13+) for creating menu bar items |
| **LSUIElement** | Info.plist key that hides the app from the Dock |
| **CGEventSource** | CoreGraphics API to query system-wide input event timing |

---

*End of V1 Specification*
