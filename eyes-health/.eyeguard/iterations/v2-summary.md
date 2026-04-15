# V2 Iteration Summary

**Date:** 2026-04-14
**Scope:** Bug fixes from V1 review + new features (reminder modes, floating break window)

---

## Bug Fixes

### BUG-1: Notification spam (CRITICAL)

**Problem:** `shouldNotify` stayed true after the first notification because `continuousUseSeconds` keeps incrementing past the 20-minute threshold. Every 5-second poll cycle called `scheduleBreakReminder()` again. While `NotificationService.hasScheduledReminder` partially guarded against duplicate scheduling, it was fragile and didn't address the root cause.

**Fix:** Added `hasNotifiedThisSession: Bool` to `AppState`. Set to `true` in `MonitoringService.pollIdleTime` immediately before scheduling the notification. `shouldNotify` now gates on `!hasNotifiedThisSession`. Reset to `false` only when a break is recorded (`recordBreak()`) or the snooze period expires.

**Files changed:** `AppState.swift`, `MonitoringService.swift`

### BUG-2: Snooze doesn't properly reset notification state

**Problem:** `handleSnooze()` called `resetContinuousUse()` which zeroed the counter, but the next poll immediately started counting again. After 5 minutes of continued use, the snooze re-notify fired, but the continuous time showed only 5 min (not the true 25 min total). The `DispatchQueue.asyncAfter` approach was also unreliable.

**Fix:** Replaced `resetContinuousUse()` + `asyncAfter` with a `snoozedUntil: Date?` property on `AppState`. When snoozing, `snoozedUntil` is set to `now + 5 minutes`. The continuous-use counter keeps incrementing (accurate total time), but `shouldNotify` returns `false` while the snooze period is active. When `snoozedUntil` expires, `shouldNotify` becomes eligible again if the threshold is still exceeded.

**Files changed:** `AppState.swift`, `MonitoringService.swift`

### BUG-3: shouldNotify returns true forever

**Problem:** Once `continuousUseSeconds >= 20 min`, `shouldNotify` was perpetually `true`. No mechanism existed to gate it after the first notification.

**Fix:** This was fixed together with BUG-1 via the `hasNotifiedThisSession` flag. The `shouldNotify` computed property now checks three conditions:
1. `continuousUseSeconds >= breakIntervalSeconds`
2. `!hasNotifiedThisSession`
3. `snoozedUntil` is nil or in the past

**Files changed:** `AppState.swift`

---

## New Features

### Feature 1: ReminderMode Enum

Added `ReminderMode` enum with three cases:
- **gentle** -- Notification only (existing V1 behavior)
- **normal** -- Notification + floating mini window with 20s countdown
- **aggressive** -- Full-screen overlay (marked unavailable, planned for V3)

Each case provides `displayName`, `description`, and `isAvailable` properties.

**Files:** `Constants.swift`

### Feature 2: Floating Break Window (Normal Mode)

Two new files:

- **FloatingBreakView.swift** -- SwiftUI view with:
  - 20-second countdown ("20s" -> "19s" -> ... -> "Done!")
  - Bold rounded monospaced digits
  - "Look away from screen" / "Break complete!" status text
  - "Skip" button to dismiss early
  - `.ultraThinMaterial` background

- **BreakWindowService.swift** -- Manages an `NSPanel` that:
  - Uses `.floating` window level (stays above other windows)
  - Positions in top-right corner of the screen with 16px margin
  - Is non-activating (doesn't steal focus)
  - Joins all spaces and works in full-screen
  - Auto-records a break when the countdown completes
  - Dismisses 1.5 seconds after "Done!" for visual feedback

Integration: `MonitoringService.pollIdleTime` now checks `appState.reminderMode`. In `.normal` mode, both the notification and floating window are triggered.

**Files:** `FloatingBreakView.swift`, `BreakWindowService.swift`, `MonitoringService.swift`, `EyesHealthApp.swift`

### Feature 3: Mode Selection in Menu

Added to `MenuBarView`:
- Segmented `Picker` for Gentle / Normal / Aggressive modes
- "REMINDER MODE" label and description text for the active mode
- Aggressive auto-resets to Normal if selected (unavailable guard)
- Mode persisted via `UserDefaults` through `AppState.reminderMode`

**Files:** `MenuBarView.swift`, `AppState.swift`

### Feature 4: Last Break Time Display

Added "Last break: X ago" row to the stats section using `RelativeDateTimeFormatter` with `.abbreviated` units style. Shows "none yet" when no break has been recorded.

**Files:** `MenuBarView.swift`

---

## Commits

| # | Hash | Message |
|---|------|---------|
| 1 | `13d4f29` | `fix: prevent notification spam and fix snooze behavior` |
| 2 | `5362b89` | `feat: add ReminderMode enum and mode selection` |
| 3 | `bb9598e` | `feat: implement floating break window for normal mode` |
| 4 | `1a84217` | `feat: add mode picker and last break time to menu` |

## Files Changed (V2)

| File | Status |
|------|--------|
| `EyesHealth/Models/AppState.swift` | Modified |
| `EyesHealth/Services/MonitoringService.swift` | Modified |
| `EyesHealth/Utils/Constants.swift` | Modified |
| `EyesHealth/Views/MenuBarView.swift` | Modified |
| `EyesHealth/App/EyesHealthApp.swift` | Modified |
| `EyesHealth/Views/FloatingBreakView.swift` | **New** |
| `EyesHealth/Services/BreakWindowService.swift` | **New** |

## V3 Backlog

- Implement aggressive mode (full-screen overlay with countdown)
- Add break duration tracking (how long the user actually rested)
- Statistics view with daily/weekly break history
- Customizable break interval (instead of fixed 20 min)
- Sound options for break reminders
