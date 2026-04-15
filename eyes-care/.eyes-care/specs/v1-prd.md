# EyesCare v1 — Product Requirements Document

**Version:** 1.0
**Date:** 2026-04-15
**Author:** PM Agent
**Status:** Draft
**Theme:** Skeleton + Menu Bar + Basic Monitoring

---

## 1. Overview

### 1.1 Product Vision
EyesCare is a macOS menu bar application that protects users' eye health by enforcing medically-backed break schedules. Unlike competing apps that use arbitrary intervals, EyesCare is built on three evidence-based standards: the AAO 20-20-20 Rule, OSHA rest recommendations, and EU Directive 90/270/EEC.

### 1.2 Version Goal
v1 establishes the application skeleton: a native macOS menu bar app with basic idle-time monitoring via `CGEventSource`. No break notifications yet — this version proves the architecture works, the menu bar integration is solid, and idle detection is accurate.

### 1.3 Target Users
- Knowledge workers spending 6+ hours daily at a Mac
- Developers, designers, writers, researchers
- Users who have experienced eye strain, headaches, or dry eyes
- Health-conscious professionals who want medical-backed guidance

### 1.4 Success Metrics
| Metric | Target |
|--------|--------|
| App launches without crash | 100% |
| Menu bar icon appears correctly | 100% |
| Idle time detection accuracy | ±5 seconds |
| Memory footprint (idle) | < 20 MB |
| CPU usage (monitoring) | < 1% |
| `swift build` passes | Zero errors, zero warnings |

---

## 2. Medical Foundation

These standards MUST be hardcoded as the default break schedule and cited throughout the app:

| Rule | Source | Interval | Duration | Priority |
|------|--------|----------|----------|----------|
| 20-20-20 Micro Break | AAO (American Academy of Ophthalmology) | 20 min | 20 sec | P0 |
| Rest Break | OSHA Recommendations | 60 min | 5 min | P0 |
| Mandatory Break | EU Directive 90/270/EEC | 120 min | 15 min | P0 |

**Note:** v1 defines these as data models only. Active enforcement begins in v2.

---

## 3. Functional Requirements

### 3.1 Application Lifecycle (P0)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| F-1.1 | App runs as a macOS menu bar application (no Dock icon) | `LSUIElement = true` behavior; no Dock icon visible |
| F-1.2 | App uses `@main` SwiftUI entry point with `NSApplicationDelegateAdaptor` | Clean startup via `EyesCareApp.swift` |
| F-1.3 | App creates an `NSStatusItem` in the system menu bar | Eye icon (SF Symbol `eye`) visible in menu bar |
| F-1.4 | App does not show a main window on launch | No window appears; only menu bar icon |

### 3.2 Menu Bar UI (P0)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| F-2.1 | Display app name and version in menu | "EyesCare v1.0" shown as disabled menu item |
| F-2.2 | Show monitoring status | "Status: Monitoring" or "Status: Paused" menu item |
| F-2.3 | Toggle monitoring on/off | "Start Monitoring" / "Pause Monitoring" menu item toggles state |
| F-2.4 | Show elapsed active time | "Active: Xh Ym" showing time since monitoring started |
| F-2.5 | Show time since last break | "Since Last Break: Xm" showing continuous usage time |
| F-2.6 | Quit action | "Quit EyesCare" with Cmd+Q shortcut |
| F-2.7 | Separator lines between sections | Visual grouping of related menu items |

### 3.3 Idle Detection (P0)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| F-3.1 | Use `CGEventSource.secondsSinceLastEventType` for idle detection | Direct CoreGraphics API usage, no Accessibility permissions needed |
| F-3.2 | Poll at configurable interval (default: 5 seconds) | Timer fires every `Constants.pollingInterval` seconds |
| F-3.3 | Detect user idle state after threshold (default: 30 seconds) | Idle state changes when no input for `Constants.idleThreshold` |
| F-3.4 | Detect natural breaks (default: 120 seconds idle) | Long idle period recognized as natural break |
| F-3.5 | Track cumulative active time | Accurate to ±5 seconds |
| F-3.6 | Reset active time counter after natural break | Counter resets when user returns from extended idle |
| F-3.7 | Update menu bar display on state changes | Menu items reflect current monitoring state |

### 3.4 Data Models (P0)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| F-4.1 | `BreakType` enum with micro/macro/mandatory cases | Medical intervals and durations hardcoded per spec |
| F-4.2 | `ReminderMode` enum with gentle/normal/aggressive cases | Modes defined for future v3 use |
| F-4.3 | Activity state model (active/idle/away) | Clean state machine for monitoring |

### 3.5 Architecture (P0)

| ID | Requirement | Acceptance Criteria |
|----|-------------|---------------------|
| F-5.1 | Separate `EyesCareCore` library target | Business logic isolated from UI |
| F-5.2 | Separate `EyesCareApp` executable target | App layer depends on Core |
| F-5.3 | Swift Package Manager project structure | `Package.swift` with both targets |
| F-5.4 | macOS 14+ deployment target | Modern SwiftUI/AppKit APIs available |
| F-5.5 | Swift 5.9+ with strict concurrency | `Sendable` conformance on all shared types |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NF-1.1 | Memory footprint (idle state) | < 20 MB |
| NF-1.2 | CPU usage during monitoring | < 1% |
| NF-1.3 | App startup time | < 2 seconds |
| NF-1.4 | Timer polling overhead | Negligible (5s interval) |

### 4.2 Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NF-2.1 | Crash-free sessions | 100% |
| NF-2.2 | Graceful handling of permission denial | App runs with degraded functionality |
| NF-2.3 | Clean shutdown on Quit | No orphaned timers or resources |

### 4.3 Compatibility

| ID | Requirement | Target |
|----|-------------|--------|
| NF-3.1 | macOS version | 14.0+ (Sonoma) |
| NF-3.2 | Architecture | Universal (Apple Silicon + Intel) |
| NF-3.3 | Swift version | 5.9+ |

### 4.4 Code Quality

| ID | Requirement | Target |
|----|-------------|--------|
| NF-4.1 | Test coverage | >= 80% on EyesCareCore |
| NF-4.2 | Zero compiler warnings | Clean build |
| NF-4.3 | SwiftLint compliance | Zero violations |
| NF-4.4 | Documentation | Public API fully documented |

---

## 5. Out of Scope for v1

The following features are explicitly **NOT** in v1:

| Feature | Planned Version |
|---------|----------------|
| Break notifications / reminders | v2 |
| Notification modes (gentle/normal/aggressive) | v3 |
| Data persistence (JSON/UserDefaults) | v4 |
| Health scoring algorithm | v5 |
| Daily reports | v6 |
| Settings/Preferences window | v7 |
| Eye exercises | v8 |
| Dashboard (web) | v9 |
| Auto-launch, DMG packaging | v10 |

---

## 6. Technical Constraints

1. **No third-party dependencies** — v1 uses only Apple frameworks (Foundation, AppKit, SwiftUI, CoreGraphics)
2. **No Accessibility permissions** — `CGEventSource` works without Accessibility access
3. **No network calls** — fully offline app
4. **No Dock icon** — menu bar only (`LSUIElement` style)
5. **SPM only** — no Xcode project file, build with `swift build`

---

## 7. File Structure (Expected v1 Output)

```
Sources/
├── EyesCareApp/
│   ├── EyesCareApp.swift          # @main entry point
│   └── AppDelegate.swift          # NSStatusItem, menu, monitoring toggle
├── EyesCareCore/
│   ├── Models/
│   │   ├── BreakType.swift        # 3-tier break definitions
│   │   ├── ReminderMode.swift     # Notification mode enum
│   │   └── ActivityState.swift    # Active/Idle/Away state machine (NEW)
│   ├── Services/
│   │   └── IdleMonitor.swift      # CGEventSource polling service (NEW)
│   └── Utils/
│       └── Constants.swift        # Configuration constants
Tests/
└── EyesCareCoreTests/
    ├── BreakTypeTests.swift        # Break interval/duration tests
    ├── ActivityStateTests.swift    # State machine tests (NEW)
    └── IdleMonitorTests.swift     # Idle detection tests (NEW)
```

---

## 8. Acceptance Criteria Summary

v1 is **ACCEPTED** when all of the following are true:

- [ ] `swift build` completes with zero errors and zero warnings
- [ ] App launches and shows menu bar icon with eye symbol
- [ ] Menu displays: version, monitoring status, active time, since-last-break, quit
- [ ] Start/Pause monitoring toggle works correctly
- [ ] Idle detection correctly identifies active vs. idle state
- [ ] Natural break detection resets the active timer
- [ ] Memory usage < 20 MB in idle state
- [ ] Test coverage >= 80% on EyesCareCore
- [ ] All `BreakType` medical values match the specification table
- [ ] Clean architecture: Core library separated from App target

---

## 9. Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `CGEventSource` requires permissions on newer macOS | Medium | High | Test on macOS 14+; fallback to IOKit if needed |
| SwiftUI `Settings` scene conflicts with menu-bar-only | Low | Medium | Use empty Settings scene with `NSApplicationDelegateAdaptor` |
| Timer drift over long sessions | Low | Low | Use `Date`-based elapsed time, not accumulated intervals |
| Excessive polling drains battery | Low | Medium | 5-second interval is conservative; monitor energy impact |

---

## 10. Dependencies

- **Upstream:** None (v1 is the foundation)
- **Downstream:** v2 (Core Reminders) depends on v1's IdleMonitor and ActivityState
- **External:** None (no third-party packages)

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | PM Agent | Initial PRD for v1 |
