# PM-to-Lead Handoff: EyesCare v1

**Date:** 2026-04-15
**From:** PM Agent
**To:** Tech Lead Agent
**Version:** v1 — Skeleton + Menu Bar + Basic Monitoring

---

## 1. Deliverable Summary

The PM has completed the following v1 deliverables:

| Document | Path | Status |
|----------|------|--------|
| Competitive Analysis | `.eyes-care/specs/competitive-analysis.md` | Complete |
| Product Requirements (PRD) | `.eyes-care/specs/v1-prd.md` | Complete |
| UX Design Specification | `.eyes-care/specs/v1-ux-design.md` | Complete |
| This Handoff | `.eyes-care/handoffs/pm-to-lead-v1.md` | Complete |

---

## 2. What to Build

### v1 Goal
Build a macOS menu bar application skeleton with idle-time monitoring. No break notifications yet — v1 proves the architecture, menu bar integration, and idle detection accuracy.

### Existing Skeleton (Already Implemented)
The following code already exists and should be **extended**, not rewritten:

| File | What Exists | What's Needed |
|------|-------------|---------------|
| `Package.swift` | SPM config with EyesCareCore + EyesCareApp targets | No changes needed |
| `EyesCareApp.swift` | `@main` entry point with `NSApplicationDelegateAdaptor` | No changes needed |
| `AppDelegate.swift` | Basic `NSStatusItem` with icon and quit menu | **Extend**: add monitoring toggle, status display, active time, since-last-break |
| `BreakType.swift` | 3-tier break enum with intervals/durations | No changes needed |
| `ReminderMode.swift` | 3-mode reminder enum | No changes needed |
| `Constants.swift` | Polling/idle/snooze constants | No changes needed |

### New Files Needed

| File | Purpose | Priority |
|------|---------|----------|
| `Sources/EyesCareCore/Models/ActivityState.swift` | Active/Idle/Away state machine | P0 |
| `Sources/EyesCareCore/Services/IdleMonitor.swift` | CGEventSource polling service | P0 |
| `Tests/EyesCareCoreTests/BreakTypeTests.swift` | Break interval/duration tests | P0 |
| `Tests/EyesCareCoreTests/ActivityStateTests.swift` | State machine tests | P0 |
| `Tests/EyesCareCoreTests/IdleMonitorTests.swift` | Idle detection tests | P0 |

---

## 3. Key Technical Decisions

### 3.1 Idle Detection: `CGEventSource` (DECIDED)
- Use `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)` 
- No Accessibility permission required
- Poll every 5 seconds (`Constants.pollingInterval`)
- Idle threshold: 30 seconds (`Constants.idleThreshold`)
- Natural break threshold: 120 seconds (`Constants.naturalBreakThreshold`)

### 3.2 Architecture: Protocol-Oriented (DECIDED)
- Define `IdleMonitor` as a protocol for testability
- Concrete `CGEventSourceIdleMonitor` for production
- Mock implementation for unit tests
- Use `@MainActor` for UI-bound state

### 3.3 State Machine: 3 States (DECIDED)
```
ACTIVE ──(idle > 30s)──► IDLE ──(idle > 120s)──► AWAY/NATURAL_BREAK
   ▲                        │                         │
   └────(input detected)────┘                         │
   ▲                                                  │
   └──────────(input detected, reset counters)────────┘
```

### 3.4 Menu Bar: NSMenu with Info Items (DECIDED)
- Use standard `NSMenu` (no SwiftUI popover in v1)
- Info items are disabled `NSMenuItem` with value display
- Toggle item changes title based on monitoring state
- No keyboard shortcuts except ⌘Q for Quit

---

## 4. Acceptance Criteria (PM Will Verify)

The PM will test against these criteria before marking v1 as ACCEPTED:

- [ ] `swift build` completes with zero errors and zero warnings
- [ ] App launches and shows menu bar icon (`eye` SF Symbol)
- [ ] No Dock icon appears (menu bar only)
- [ ] Menu shows: version, status, active time, since-last-break, pause/resume, quit
- [ ] Pause/Resume toggle works correctly
- [ ] Idle detection identifies active vs. idle correctly
- [ ] Natural break (120s idle) resets the "since last break" counter
- [ ] Memory < 20 MB in idle state
- [ ] Test coverage >= 80% on EyesCareCore
- [ ] All BreakType medical values match: micro=20m/20s, macro=60m/5m, mandatory=120m/15m

---

## 5. Priorities

| Priority | Items |
|----------|-------|
| **P0 (Must)** | Menu bar icon, status display, monitoring toggle, idle detection, natural break detection, active time tracking, tests |
| **P1 (Should)** | Icon state change (eye → eye.slash on pause), idle state shown in menu |
| **P2 (Nice)** | Elapsed time formatting with d/h/m units, "(resting)" annotation during idle |

---

## 6. Risks the Lead Should Know

| Risk | Mitigation |
|------|------------|
| `CGEventSource` may behave differently on macOS 15+ | Test on latest macOS; document any quirks |
| SwiftUI `Settings` empty scene might cause issues | Current approach works; if issues arise, remove Settings scene entirely |
| Timer drift over long sessions (days) | Use `Date`-based elapsed time, not accumulated intervals |
| Menu bar space on small screens | Icon-only (no title text) to minimize footprint |

---

## 7. What NOT to Build in v1

Resist the temptation to add these — they're explicitly out of scope:

- Break notifications or reminders (v2)
- Notification modes / overlays (v3)
- UserDefaults persistence (v4)
- Any settings/preferences UI (v7)
- Launch-at-login (v10)
- Dock icon or main window
- Any third-party dependencies

---

## 8. Communication Protocol

After implementation, the Lead should:
1. Update `.eyes-care/status.md` with v1 status
2. Place any technical notes in `.eyes-care/architecture/`
3. Commit all code
4. Signal readiness for PM acceptance review

The PM will then:
1. Read the status update
2. Run acceptance tests
3. Write acceptance result to `.eyes-care/handoffs/pm-acceptance-v1.md`
4. If accepted, begin planning v2 PRD

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | PM Agent | Initial handoff for v1 |
