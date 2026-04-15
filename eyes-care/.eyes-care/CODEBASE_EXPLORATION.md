# EyesCare Project Exploration — Complete Codebase Analysis

**Date:** 2026-04-15
**Project:** EyesCare macOS Eye Care Application
**Version:** v1 (Skeleton + Menu Bar + Basic Monitoring)
**Status:** PM specs complete → Awaiting lead implementation

---

## 📋 Executive Summary

EyesCare is a native macOS menu bar application designed to protect users' eye health through medically-backed break schedules. The project is founded on three evidence-based standards:

1. **AAO 20-20-20 Rule** — Every 20 minutes, look 20 feet away for 20 seconds
2. **OSHA Recommendations** — Every 60 minutes, rest for 5 minutes
3. **EU Directive 90/270/EEC** — Every 120 minutes, mandatory 15-minute break

**v1 Goal:** Build the application skeleton with:
- Native macOS menu bar integration
- Idle-time monitoring via `CGEventSource`
- Basic UI (no notifications yet)
- Proof of architecture, menu bar integration, and idle detection

---

## 📁 Full Directory Structure

```
eyes-care/
├── .build/                          # Swift build artifacts (generated)
├── .eyes-care/                      # AI project workspace
│   ├── architecture/                # Technical documentation
│   ├── handoffs/
│   │   └── pm-to-lead-v1.md        # Implementation handoff document
│   ├── logs/
│   │   ├── orchestrator.log
│   │   ├── lead-v1.log
│   │   ├── pm-v1.log
│   │   └── orchestrator-stdout.log
│   ├── prompts/                     # Agent system prompts
│   │   ├── dev-prompt.md
│   │   ├── lead-prompt.md
│   │   ├── pm-prompt.md
│   │   └── tester-prompt.md
│   ├── reviews/                     # Code review documents
│   ├── specs/
│   │   ├── competitive-analysis.md  # Market research (Time Out, Stretchly, etc.)
│   │   ├── v1-prd.md               # Product Requirements Document
│   │   └── v1-ux-design.md         # UX/UI Specification
│   ├── testing/                     # Test strategy documents
│   └── status.md                    # Current project status & roadmap
├── Sources/
│   ├── EyesCareApp/                # Application layer (executable target)
│   │   ├── EyesCareApp.swift       # @main entry point (13 lines)
│   │   └── AppDelegate.swift       # Menu bar setup (26 lines)
│   └── EyesCareCore/               # Business logic (library target)
│       ├── Models/
│       │   ├── BreakType.swift     # Medical break definitions (49 lines)
│       │   └── ReminderMode.swift  # Reminder mode enum (30 lines)
│       ├── Protocols/              # (empty — ready for services)
│       ├── Services/               # (empty — IdleMonitor needed)
│       ├── Utils/
│       │   └── Constants.swift     # Configuration constants (27 lines)
│       └── Views/                  # (empty — no UI in Core lib)
├── Tests/
│   └── EyesCareTests/              # Test directory (empty — .gitkeep only)
├── .gitignore
├── Package.swift                    # Swift Package Manager config
└── orchestrator.sh                  # CI/CD orchestration script

---

## 📄 All Swift Source Files (5 files currently)

### 1. `Sources/EyesCareApp/EyesCareApp.swift` (13 lines)

**Purpose:** Main SwiftUI app entry point with NSApplicationDelegateAdaptor

```swift
import SwiftUI
import EyesCareCore

@main
struct EyesCareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

**Key Notes:**
- Uses `@main` for SwiftUI entry point
- Injects `AppDelegate` for menu bar setup
- Empty `Settings` scene to avoid main window
- Clean macOS menu bar app pattern

---

### 2. `Sources/EyesCareApp/AppDelegate.swift` (26 lines)

**Purpose:** Menu bar icon setup and basic quit functionality

```swift
import AppKit
import SwiftUI
import EyesCareCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyesCare")
            button.title = " EyesCare"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "EyesCare v0.1", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
}
```

**Current State:**
- ✅ Menu bar icon visible with eye SF Symbol
- ✅ Version display
- ✅ Quit menu item
- ❌ **TODO (v1):** Add monitoring toggle, status items, active time, since-last-break display

**Requirements from PM-to-Lead Handoff:**
```
Extend AppDelegate to add:
- "Status: Monitoring" / "Status: Paused" item
- "Active: Xh Ym" showing elapsed time since monitoring started
- "Since Last Break: Xm" showing continuous usage time
- "Pause Monitoring" / "Resume Monitoring" toggle
- Update icon (eye → eye.slash) when paused
- Update menu display on state changes (Active/Idle/Away)
```

---

### 3. `Sources/EyesCareCore/Models/BreakType.swift` (49 lines)

**Purpose:** Medical break type definitions with intervals and durations

```swift
import Foundation

/// Break types based on medical guidelines
public enum BreakType: String, Codable, Sendable {
    /// 20-20-20 rule: Every 20 minutes, look 20 feet away for 20 seconds
    /// Source: American Academy of Ophthalmology (AAO)
    case micro

    /// Hourly break: Every 60 minutes, rest for 5 minutes
    /// Source: OSHA recommendations
    case macro

    /// Mandatory break: Every 120 minutes, rest for 15 minutes
    /// Source: EU Screen Equipment Directive 90/270/EEC
    case mandatory

    public var interval: TimeInterval {
        switch self {
        case .micro: return 20 * 60       // 20 minutes
        case .macro: return 60 * 60       // 60 minutes
        case .mandatory: return 120 * 60  // 120 minutes
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .micro: return 20            // 20 seconds
        case .macro: return 5 * 60        // 5 minutes
        case .mandatory: return 15 * 60   // 15 minutes
        }
    }

    public var displayName: String {
        switch self {
        case .micro: return "Micro Break (20-20-20)"
        case .macro: return "Rest Break"
        case .mandatory: return "Mandatory Break"
        }
    }

    public var medicalSource: String {
        switch self {
        case .micro: return "AAO 20-20-20 Rule"
        case .macro: return "OSHA Recommendation"
        case .mandatory: return "EU Directive 90/270/EEC"
        }
    }
}
```

**Key Design Principles:**
- ✅ `Sendable` conformance for Swift 6 strict concurrency
- ✅ `Codable` for future JSON persistence
- ✅ Medical citations hardcoded as documentation
- ✅ Calculated properties for intervals and durations (not error-prone)
- ✅ Display names and sources for UI

**Test Validation (From PR):**
```
- micro:     interval = 20 min (1200s),  duration = 20 sec
- macro:     interval = 60 min (3600s),  duration = 5 min (300s)
- mandatory: interval = 120 min (7200s), duration = 15 min (900s)
```

---

### 4. `Sources/EyesCareCore/Models/ReminderMode.swift` (30 lines)

**Purpose:** Notification mode definitions (for future v3 use)

```swift
import Foundation

/// Reminder notification modes
public enum ReminderMode: String, Codable, Sendable, CaseIterable {
    /// System notification banner only
    case gentle

    /// Notification + floating countdown window
    case normal

    /// Full-screen overlay with countdown
    case aggressive

    public var displayName: String {
        switch self {
        case .gentle: return "Gentle"
        case .normal: return "Normal"
        case .aggressive: return "Aggressive"
        }
    }

    public var description: String {
        switch self {
        case .gentle: return "Notification banner only"
        case .normal: return "Notification + floating window"
        case .aggressive: return "Full-screen overlay"
        }
    }
}
```

**Current Usage:**
- ✅ Enum defined for v1 data models
- ⏸️ Not used until v3 (Notification Upgrade)
- ✅ `CaseIterable` for UI picker support

---

### 5. `Sources/EyesCareCore/Utils/Constants.swift` (27 lines)

**Purpose:** Configuration constants for monitoring behavior

```swift
import Foundation

/// Application constants
public enum Constants {
    /// Polling interval for idle detection (seconds)
    public static let pollingInterval: TimeInterval = 5.0

    /// Idle threshold - user considered idle after this many seconds
    public static let idleThreshold: TimeInterval = 30.0

    /// Natural break threshold - idle this long counts as a break
    public static let naturalBreakThreshold: TimeInterval = 120.0

    /// Default snooze duration
    public static let snoozeDuration: TimeInterval = 5 * 60  // 5 minutes

    /// UserDefaults keys
    public static let reminderModeKey = "eyesCare.reminderMode"
    public static let isMonitoringKey = "eyesCare.isMonitoring"

    /// Data directory name
    public static let dataDirectoryName = "EyesCare"

    /// Report file prefix
    public static let reportPrefix = "eyescare-report"
}
```

**Key Values:**
- Polling: 5 seconds (conservative, battery-aware)
- Idle threshold: 30 seconds
- Natural break threshold: 120 seconds (2 minutes)
- Snooze: 5 minutes (for future v2 reminders)

---

## 🏗️ Package.swift Configuration

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EyesCare",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EyesCare", targets: ["EyesCareApp"])
    ],
    targets: [
        .target(
            name: "EyesCareCore",
            path: "Sources/EyesCareCore"
        ),
        .executableTarget(
            name: "EyesCareApp",
            dependencies: ["EyesCareCore"],
            path: "Sources/EyesCareApp"
        )
    ]
)
```

**Architecture:**
- ✅ Two-tier design: Core library + App executable
- ✅ macOS 14+ (Sonoma) deployment target
- ✅ Swift 5.9+ (supports Sendable, async/await)
- ✅ No third-party dependencies (pure Apple frameworks)
- ✅ SPM only (no Xcode project file)

---

## 📚 Project Documentation (AI Workspace)

### `.eyes-care/specs/v1-prd.md` (238 lines)

**Product Requirements Document v1.0**

**Version Theme:** Skeleton + Menu Bar + Basic Monitoring

**Key Sections:**

1. **Overview**
   - Product Vision: Medical-backed break schedules
   - Success Metrics: 100% app launch, <20MB memory, <1% CPU, ±5s idle accuracy
   - Target Users: Knowledge workers spending 6+ hours at Mac

2. **Medical Foundation** (Hardcoded)
   | Rule | Source | Interval | Duration | Priority |
   |------|--------|----------|----------|----------|
   | 20-20-20 | AAO | 20 min | 20 sec | P0 |
   | Rest Break | OSHA | 60 min | 5 min | P0 |
   | Mandatory Break | EU 90/270/EEC | 120 min | 15 min | P0 |

3. **Functional Requirements (P0 — Must Have)**
   - F-1: Application Lifecycle (menu bar only, no Dock icon)
   - F-2: Menu Bar UI (version, status, active time, since-last-break, toggle, quit)
   - F-3: Idle Detection (CGEventSource polling, 5s interval, 30s threshold, 120s natural break)
   - F-4: Data Models (BreakType, ReminderMode, ActivityState)
   - F-5: Architecture (Core + App targets, macOS 14+, Swift 5.9 strict concurrency)

4. **Non-Functional Requirements**
   - Performance: <20MB memory, <1% CPU, <2s startup
   - Reliability: 100% crash-free, graceful error handling
   - Compatibility: macOS 14+, Universal (Apple Silicon + Intel), Swift 5.9+
   - Code Quality: ≥80% test coverage, zero warnings, SwiftLint compliance

5. **Out of Scope for v1**
   - Break notifications (v2)
   - Notification modes (v3)
   - Data persistence (v4)
   - Health scoring (v5)
   - Daily reports (v6)
   - Settings panel (v7)
   - Eye exercises (v8)
   - Web dashboard (v9)
   - Packaging & polish (v10)

6. **Acceptance Criteria (10 items)**
   - [ ] `swift build` zero errors/warnings
   - [ ] Menu bar icon with eye symbol
   - [ ] No Dock icon
   - [ ] Menu shows version, status, times, toggle, quit
   - [ ] Pause/Resume works correctly
   - [ ] Idle detection accurate
   - [ ] Natural break resets counter
   - [ ] Memory <20MB
   - [ ] ≥80% test coverage
   - [ ] BreakType medical values correct

7. **Risks & Mitigations**
   - `CGEventSource` behavior on macOS 15+
   - SwiftUI Settings scene compatibility
   - Timer drift over long sessions
   - Menu bar space constraints

---

### `.eyes-care/specs/v1-ux-design.md` (345 lines)

**UX Design Specification v1.0**

**Design Principles:**
- Invisible until needed (menu bar app, no Dock)
- Glanceable status (<2 seconds comprehension)
- Medical trust (cite sources)
- Native feel (macOS HIG)
- Zero config (works perfectly with defaults)

**Menu Bar Icon:**
```
Monitoring:  👁 (eye SF Symbol)
Paused:      👁⃠ (eye.slash SF Symbol)
Idle:        😴 (moon.zzz or eye.slash)
```

**Menu Structure (When Monitoring Active):**
```
EyesCare v1.0
─────────────────────────
● Monitoring
Active Time: 1h 23m
Since Last Break: 18m
─────────────────────────
Pause Monitoring
─────────────────────────
Quit EyesCare           ⌘Q
```

**Menu Structure (When Paused):**
```
EyesCare v1.0
─────────────────────────
○ Paused
Active Time: —
Since Last Break: —
─────────────────────────
Resume Monitoring
─────────────────────────
Quit EyesCare           ⌘Q
```

**Menu Structure (When Idle):**
```
EyesCare v1.0
─────────────────────────
● Monitoring (Idle)
Active Time: 1h 23m
Since Last Break: 0m (resting)
─────────────────────────
Pause Monitoring
─────────────────────────
Quit EyesCare           ⌘Q
```

**Time Display Formatting:**
| Duration | Display |
|----------|---------|
| <1m | "Active Time: < 1m" |
| 1-59m | "Active Time: Xm" |
| 1-23h | "Active Time: Xh Ym" |
| 24+h | "Active Time: Xd Yh" |

**User Flows:**
1. First Launch: App opens → Menu bar icon → Monitoring auto-starts
2. Monitoring Toggle: User clicks icon → Menu appears → Pause/Resume
3. Idle Detection: Timer fires → Check CGEventSource → Active/Idle/Away
4. Natural Break: 30s idle → Idle state; 120s idle → Natural break (counter resets)

**Accessibility:**
- VoiceOver descriptions for all menu items
- Template images for Dark/Light mode auto-adaptation
- High contrast support
- No animations in v1

**Future UX (Not v1):**
- v2: Break notification banners, countdown in menu bar title
- v3: Floating countdown window, full-screen break overlay
- v7: Preferences window
- v8: Eye exercise animations

---

### `.eyes-care/specs/competitive-analysis.md` (251 lines)

**Competitive Analysis: macOS Eye Care & Break Reminder Apps**

**Market Players Analyzed:**

1. **Time Out (Dejal)** — Native macOS veteran
   - Pricing: Free + Supporter tiers ($3.99-$14.99)
   - Tech: Native Objective-C/Swift
   - Breaks: Normal (~10m/60m), Micro (~15s/15m), Custom
   - Strengths: Mature, deep customization, activity tracking, screen dimming
   - Weaknesses: No medical foundation, aging UI, no health scoring

2. **Stretchly** — Cross-platform open-source
   - Pricing: Free & open source
   - Tech: Electron (~100-200MB RAM)
   - Breaks: Mini (20s/10m), Long (5m/30m)
   - Strengths: Cross-platform, open source, strict mode, rich customization
   - Weaknesses: Electron overhead, non-native, no health tracking

3. **BreakTimer** — Minimalist open-source
   - Pricing: Free & open source (GPLv3)
   - Tech: Electron
   - Breaks: Single configurable type
   - Strengths: Simplest UX, working hours concept
   - Weaknesses: Only 1 break type, no idle detection, minimal features

4. **Pandan** (Sindre Sorhus) — Ultra-lightweight native
   - Pricing: Free
   - Tech: Native Swift/SwiftUI
   - Breaks: Awareness-based (no structure), Shortcuts integration
   - Strengths: Ultra-lightweight, beautiful native design, infinite extensibility
   - Weaknesses: Awareness-only (not enforcement), no structured breaks, no health scoring

**EyesCare Differentiation:**

| Feature | Time Out | Stretchly | BreakTimer | Pandan | **EyesCare** |
|---------|----------|-----------|------------|--------|---|
| Native macOS | ✅ | ❌ Electron | ❌ Electron | ✅ | **✅** |
| Medical foundation | ❌ | ❌ | ❌ | ❌ | **✅ AAO/OSHA/EU** |
| 20-20-20 rule | Manual | Close | ❌ | ❌ | **✅ Built-in** |
| 3-tier breaks | ❌ 2+custom | ❌ 2 | ❌ 1 | ❌ | **✅ 3** |
| Idle detection | ✅ | ✅ | ❌ | ✅ | **✅** |
| Health scoring | ❌ | ❌ | ❌ | ❌ | **✅ (v5+)** |
| Daily reports | ❌ | ❌ | ❌ | ❌ | **✅ (v6+)** |

**Market Gaps (EyesCare Opportunities):**

1. **Medical Credibility Gap** — No competitor cites medical sources
2. **Native macOS Gap** — Only Time Out & Pandan are native; EyesCare adds more structure
3. **Health Intelligence Gap** — Zero competitors offer health scoring/trends
4. **Holistic Eye Care Gap** — No app combines breaks + exercises + scoring + reports
5. **Modern macOS Design Gap** — Time Out aging, Stretchly/BreakTimer non-native, Pandan passive

**EyesCare Positioning:** "The doctor-recommended eye care app for macOS power users"

---

### `.eyes-care/handoffs/pm-to-lead-v1.md` (157 lines)

**PM-to-Lead Handoff: v1 Implementation Blueprint**

**Deliverable Summary:**
- ✅ Competitive Analysis
- ✅ v1 PRD
- ✅ v1 UX Design
- ✅ PM-to-Lead Handoff (this doc)

**What to Build:**

| File | What Exists | What's Needed |
|------|-------------|---------------|
| `Package.swift` | ✅ SPM config | No changes |
| `EyesCareApp.swift` | ✅ @main entry | No changes |
| `AppDelegate.swift` | ✅ Basic NSStatusItem | **Extend:** add toggle, status items, times |
| `BreakType.swift` | ✅ 3-tier enum | No changes |
| `ReminderMode.swift` | ✅ 3-mode enum | No changes |
| `Constants.swift` | ✅ Polling/idle/snooze | No changes |
| `ActivityState.swift` | ❌ **NEW** | State machine (P0) |
| `IdleMonitor.swift` | ❌ **NEW** | CGEventSource service (P0) |
| Tests | ❌ **NEW** | BreakType, ActivityState, IdleMonitor tests (P0) |

**Key Technical Decisions:**

1. **Idle Detection: `CGEventSource`**
   - API: `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)`
   - No Accessibility permission required
   - Poll every 5 seconds (Constants.pollingInterval)
   - Idle threshold: 30 seconds
   - Natural break threshold: 120 seconds

2. **Architecture: Protocol-Oriented**
   - Define `IdleMonitor` as protocol for testability
   - Concrete `CGEventSourceIdleMonitor` for production
   - Mock implementation for unit tests
   - Use `@MainActor` for UI-bound state

3. **State Machine: 3 States**
   ```
   ACTIVE ──(idle > 30s)──► IDLE ──(idle > 120s)──► AWAY/NATURAL_BREAK
      ▲                        │                         │
      └────(input detected)────┘                         │
      ▲                                                  │
      └──────────(input detected, reset counters)────────┘
   ```

4. **Menu Bar: NSMenu with Info Items**
   - Use standard NSMenu (no SwiftUI popover in v1)
   - Info items are disabled NSMenuItem for value display
   - Toggle item changes title based on monitoring state
   - No keyboard shortcuts except ⌘Q

**Acceptance Criteria (PM Will Verify):**
- [ ] `swift build` zero errors/warnings
- [ ] App launches with menu bar icon
- [ ] No Dock icon
- [ ] Menu shows all required items
- [ ] Pause/Resume toggle works
- [ ] Idle detection accurate
- [ ] Natural break resets counter
- [ ] Memory <20MB
- [ ] Test coverage ≥80%
- [ ] BreakType medical values correct

**Priorities:**
- P0 (Must): Menu bar icon, status, toggle, idle detection, tests
- P1 (Should): Icon state change, idle indication in menu
- P2 (Nice): Time formatting, "(resting)" annotation

**Risks:**
- `CGEventSource` behavior on macOS 15+
- SwiftUI Settings scene compatibility
- Timer drift over long sessions
- Menu bar space on small screens

**What NOT to Build in v1:**
- ❌ Break notifications/reminders (v2)
- ❌ Notification modes/overlays (v3)
- ❌ UserDefaults persistence (v4)
- ❌ Any settings/preferences UI (v7)
- ❌ Launch-at-login (v10)
- ❌ Dock icon or main window
- ❌ Third-party dependencies

---

### `.eyes-care/status.md` (74 lines)

**Current Project Status**

**Phase:** PM Specs Complete → Awaiting Lead Implementation

**Version Roadmap:**
| Version | Theme | Status |
|---------|-------|--------|
| v1 | Skeleton + Menu Bar + Monitoring | **PM specs done** → Lead implementation |
| v2 | Core Reminders (20-20-20, 3-tier, CGEventSource) | Pending |
| v3 | Notification Upgrade (Gentle/Normal/Aggressive) | Pending |
| v4 | Data Persistence (JSON, UserDefaults, history) | Pending |
| v5 | Health Scoring (4-dimensional algorithm) | Pending |
| v6 | Daily Report System | Pending |
| v7 | Settings Panel | Pending |
| v8 | Eye Exercises | Pending |
| v9 | Web Dashboard | Pending |
| v10 | Polish & Release (auto-launch, DMG, docs) | Pending |

**v1 Implementation Status:**
| Component | Status | Notes |
|-----------|--------|-------|
| Package.swift | ✅ Exists | SPM config |
| EyesCareApp.swift | ✅ Exists | @main entry |
| AppDelegate.swift | ⚠️ Partial | Needs monitoring toggle & status items |
| BreakType.swift | ✅ Exists | 3-tier medical definitions |
| ReminderMode.swift | ✅ Exists | Gentle/Normal/Aggressive enum |
| Constants.swift | ✅ Exists | Polling/idle thresholds |
| **ActivityState.swift** | ❌ **NOT YET** | State machine needed |
| **IdleMonitor.swift** | ❌ **NOT YET** | CGEventSource polling needed |
| **Tests** | ❌ **NOT YET** | Coverage needed |

**Acceptance Status:**
- PM Specs: ✅ Complete
- Lead Implementation: ❌ Not Started
- Tester Verification: ❌ Not Started
- PM Acceptance: ❌ Not Started

**Key Decisions:**
1. Idle Detection: CGEventSource (no Accessibility permission)
2. Menu Bar: NSMenu with info items
3. State Machine: 3 states (Active → Idle → Away/Natural Break)
4. No Dock Icon: LSUIElement-style menu bar only
5. Medical Foundation: AAO 20-20-20, OSHA hourly, EU mandatory

**Blockers:** None — ready for Lead to begin v1 implementation.

---

## 🎯 v1 Implementation Roadmap

### Phase 1: ActivityState Model (P0)

**File:** `Sources/EyesCareCore/Models/ActivityState.swift`

```swift
/// Activity state of the user
public enum ActivityState: Sendable, Equatable {
    /// User actively using computer (keyboard/mouse within 30s)
    case active
    
    /// User idle but not yet on a natural break (30s - 120s idle)
    case idle
    
    /// User has taken a natural break (120s+ idle, triggers counter reset)
    case away
}
```

**Requirements:**
- Sendable for Swift 6 strict concurrency
- State transitions: active → idle → away → active
- Track time in each state
- Reset counters on natural break (away → active transition)

---

### Phase 2: IdleMonitor Service (P0)

**File:** `Sources/EyesCareCore/Services/IdleMonitor.swift`

**Protocol Interface:**

```swift
/// Protocol for idle time detection
public protocol IdleMonitor: Sendable {
    /// Get seconds since last user input event
    func secondsSinceLastEvent() -> TimeInterval
    
    /// Get current activity state
    func currentState() -> ActivityState
}

/// Production implementation using CGEventSource
public final class CGEventSourceIdleMonitor: IdleMonitor {
    public func secondsSinceLastEvent() -> TimeInterval {
        // Use CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)
    }
    
    public func currentState() -> ActivityState {
        // Apply Constants.idleThreshold and Constants.naturalBreakThreshold
    }
}
```

**Requirements:**
- Use `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)`
- Apply Constants.idleThreshold (30s) for active→idle transition
- Apply Constants.naturalBreakThreshold (120s) for natural break detection
- No Accessibility permissions required
- Protocol-based for testing (easy to mock)

---

### Phase 3: AppDelegate Enhancement (P0)

**Update:** `Sources/EyesCareApp/AppDelegate.swift`

**Add:**
- Monitoring toggle (pause/resume)
- Status display ("● Monitoring" / "○ Paused")
- Active time display ("Active: Xh Ym")
- Since-last-break display ("Since Last Break: Xm")
- Timer for polling idle state (every 5 seconds)
- Icon state change (eye ↔ eye.slash)
- Menu item updates on state changes

**Pseudocode:**

```swift
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var isMonitoring: Bool = true
    private var activityState: ActivityState = .active
    private var activeStartTime: Date?
    private var idleMonitor: IdleMonitor = CGEventSourceIdleMonitor()
    private var pollTimer: Timer?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startMonitoring()
    }
    
    private func setupMenuBar() {
        // Create status item with eye icon
        // Create menu with items:
        //   - "EyesCare v1.0" (disabled)
        //   - Separator
        //   - "● Monitoring" / "○ Paused" (disabled, info)
        //   - "Active: Xh Ym" (disabled, info)
        //   - "Since Last Break: Xm" (disabled, info)
        //   - Separator
        //   - "Pause/Resume Monitoring" (enabled, action)
        //   - Separator
        //   - "Quit EyesCare" (enabled, action, ⌘Q)
    }
    
    private func startMonitoring() {
        activeStartTime = Date()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Constants.pollingInterval, repeats: true) { [weak self] _ in
            self?.pollIdleState()
        }
    }
    
    private func pollIdleState() {
        if !isMonitoring { return }
        
        let newState = idleMonitor.currentState()
        if newState != activityState {
            handleStateChange(from: activityState, to: newState)
            activityState = newState
        }
        
        updateMenuDisplay()
    }
    
    private func handleStateChange(from: ActivityState, to: ActivityState) {
        // Natural break detection: away → active resets counter
        if from == .away && to == .active {
            activeStartTime = Date() // Reset counter
        }
    }
    
    private func updateMenuDisplay() {
        // Update all info items with current values
    }
    
    @objc private func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            activeStartTime = Date()
        }
        updateMenuDisplay()
    }
}
```

---

### Phase 4: Unit Tests (P0)

**File:** `Tests/EyesCareTests/BreakTypeTests.swift`

```swift
import Testing
@testable import EyesCareCore

@Test
func breakTypeIntervals() {
    #expect(BreakType.micro.interval == 20 * 60)
    #expect(BreakType.macro.interval == 60 * 60)
    #expect(BreakType.mandatory.interval == 120 * 60)
}

@Test
func breakTypeDurations() {
    #expect(BreakType.micro.duration == 20)
    #expect(BreakType.macro.duration == 5 * 60)
    #expect(BreakType.mandatory.duration == 15 * 60)
}

@Test
func breakTypeDisplayNames() {
    #expect(BreakType.micro.displayName == "Micro Break (20-20-20)")
    #expect(BreakType.macro.displayName == "Rest Break")
    #expect(BreakType.mandatory.displayName == "Mandatory Break")
}

@Test
func medicalSources() {
    #expect(BreakType.micro.medicalSource == "AAO 20-20-20 Rule")
    #expect(BreakType.macro.medicalSource == "OSHA Recommendation")
    #expect(BreakType.mandatory.medicalSource == "EU Directive 90/270/EEC")
}
```

**File:** `Tests/EyesCareTests/ActivityStateTests.swift`

```swift
// Test state transitions, codability, sendability
```

**File:** `Tests/EyesCareTests/IdleMonitorTests.swift`

```swift
// Test with mock IdleMonitor implementation
// Verify state transitions at thresholds
// Test counters reset on natural break
```

---

## 🔑 Key Design Patterns

### 1. Protocol-Oriented Design

```swift
public protocol IdleMonitor: Sendable {
    func secondsSinceLastEvent() -> TimeInterval
    func currentState() -> ActivityState
}

// Production
public final class CGEventSourceIdleMonitor: IdleMonitor { }

// Testing (mock)
struct MockIdleMonitor: IdleMonitor {
    var mockIdleTime: TimeInterval = 0
    func secondsSinceLastEvent() -> TimeInterval { mockIdleTime }
}
```

**Benefit:** Easy to test; can swap implementations without changing AppDelegate.

### 2. Value-Based Time Tracking

```swift
// DO: Use Date-based elapsed time
let activeStartTime: Date
var activeSeconds: TimeInterval {
    Date().timeIntervalSince(activeStartTime)
}

// DON'T: Accumulate intervals (prone to drift)
var accumulatedSeconds: TimeInterval = 0
```

**Benefit:** Accurate over long sessions; resilient to timer drift.

### 3. Swift 6 Sendable Conformance

```swift
public enum ActivityState: Sendable { }
public protocol IdleMonitor: Sendable { }

// All types crossing isolation boundaries are Sendable
```

**Benefit:** Enables @MainActor safety; catches threading bugs at compile time.

### 4. Constants Enum

```swift
public enum Constants {
    public static let pollingInterval: TimeInterval = 5.0
    // Single source of truth; easy to adjust without code changes
}
```

---

## 📊 Current Codebase Stats

| Metric | Value |
|--------|-------|
| **Total Swift Files** | 5 |
| **Lines of Code (LOC)** | ~145 lines |
| **Package Targets** | 2 (Core + App) |
| **External Dependencies** | 0 (Apple frameworks only) |
| **Minimum macOS** | 14.0 (Sonoma) |
| **Swift Version** | 5.9+ |
| **Test Coverage** | 0% (no tests yet) |

---

## ✅ Next Steps for Lead

1. **Create ActivityState model** with 3-state enum (Active/Idle/Away)
2. **Create IdleMonitor protocol** with CGEventSourceIdleMonitor implementation
3. **Update AppDelegate** to add monitoring toggle, status items, time tracking
4. **Add Timer polling** (every 5 seconds) to poll idle state
5. **Write unit tests** for BreakType, ActivityState, IdleMonitor
6. **Verify acceptance criteria:**
   - `swift build` succeeds with zero warnings
   - App launches with eye icon
   - Menu displays all required items
   - Idle detection accurate
   - Tests coverage ≥80%
7. **Update `.eyes-care/status.md`** with implementation status
8. **Signal readiness** for PM acceptance review

---

## 🔗 References

- **AAO 20-20-20 Rule:** https://www.aao.org/eye-health/tips-prevention/computer-usage
- **OSHA Computer Workstation Guidelines**
- **EU Directive 90/270/EEC:** Display Screen Equipment
- **CGEventSource Documentation:** Apple Developer Docs
- **Swift Testing Framework:** `import Testing`
- **macOS Human Interface Guidelines**

---

**Document Generated:** 2026-04-15
**Project Status:** Ready for Lead Implementation
