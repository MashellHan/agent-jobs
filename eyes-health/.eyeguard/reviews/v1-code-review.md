# EyesHealth V1 — Code Review

**Reviewer:** Lead Agent (Tech Lead)
**Date:** 2026-04-14
**Scope:** All 7 Swift source files in `EyesHealth/`
**Reviewed Against:** V1 Spec (`v1-spec.md`) and Approved Architecture (`v1-spec-review.md`)

---

## Overall Verdict: PASS_WITH_ISSUES

## Summary

The V1 implementation is a clean, focused codebase (393 total lines across 7 files) that delivers the core 20-20-20 reminder functionality. The architecture aligns well with the approved spec review — single `@Observable` AppState, service-oriented design, proper `NSObject` inheritance for `@objc` selectors. However, there are **two critical bugs** (notification flooding and snooze timer inaccuracy), several high-priority gaps (no tests, missing `Dismiss` action from spec, no idle-to-active state transition logic), and a few medium issues that should be addressed before shipping.

---

## Critical Issues

### C-1: Notification Flooding — `scheduleBreakReminder()` fires every 5 seconds after 20 minutes

**File:** `MonitoringService.swift:87-89`, `NotificationService.swift:62-63`

Once `continuousUseSeconds >= 1200` (20 min), `appState.shouldNotify` returns `true` on every subsequent poll tick (every 5 seconds). Each tick calls `scheduleBreakReminder()`. Although `NotificationService` has a `hasScheduledReminder` guard, this flag is only reset when the user interacts with the notification OR `cancelPendingNotifications()` is called. But if the user **ignores** the notification entirely, `hasScheduledReminder` stays `true` and new notifications are blocked — which is correct for not flooding. However, the real problem is more subtle: **the continuous use counter keeps incrementing past 20 min**. There is no mechanism to:

1. Stop incrementing `continuousUseSeconds` after the notification fires (the counter grows to 25m, 30m, etc. forever)
2. Implement the spec's **re-notification after 5 minutes** (max 2 re-notifications)

The spec (Section 3.4) requires: "If user ignores: re-notify after 5 minutes (max 2 re-notifications, then stop until next active period)." This logic is entirely missing.

**Impact:** The user sees exactly one notification and if they ignore it, they never get reminded again until a natural break resets the counter. This defeats the core purpose of the app.

### C-2: Snooze uses `DispatchQueue.main.asyncAfter` — unreliable for 5-minute delays

**File:** `MonitoringService.swift:47`

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + Constants.snoozeInterval)
```

Using `asyncAfter` with a 5-minute (300 second) delay is unreliable. macOS can defer GCD blocks during App Nap or system sleep. If the system sleeps during the snooze period, the snooze notification may fire immediately upon wake or not at all. The spec explicitly calls out timer drift as a concern (Section 5.12).

Additionally, `handleSnooze()` calls `appState.resetContinuousUse()` which sets the counter to 0. When the user resumes activity during the snooze period, `pollIdleTime()` starts incrementing again from 0. After 5 minutes the snooze fires `scheduleBreakReminder()`, but by then `continuousUseSeconds` could be anywhere. If the user was active for the full 5 min snooze period, they'd be at 300s (5 min) — well below the 1200s threshold. The snooze correctly re-schedules via `scheduleBreakReminder()` directly, but the `shouldNotify` computed property would return `false`, creating a confusing state mismatch.

**Impact:** Snooze timing is unreliable and state management during snooze is inconsistent.

---

## High Issues

### H-1: No unit tests exist

**Files:** No `Tests/` directory at all

The approved architecture spec (Section 7.3) mandates tests for `AppState` and `MonitoringService` with >= 80% coverage. The `Package.swift` has no test target defined. Zero tests shipped.

**Impact:** No confidence in correctness of state transitions, break counting, or midnight reset logic. Regressions will be invisible.

### H-2: Missing `Dismiss` notification action from spec

**File:** `NotificationService.swift:37-57`

The spec (Section 3.4) defines three notification actions:
1. **Default (tap):** Dismiss, count as break, reset timer
2. **"Snooze 5 min":** Postpone reminder
3. **"Dismiss":** Dismiss without counting as break, reset timer

The implementation only registers two actions: `TAKE_BREAK` and `SNOOZE_5`. The spec's explicit "Dismiss" action (which resets timer and counts as break) is missing. The `UNNotificationDismissActionIdentifier` (system dismiss via swipe) is not handled either.

Additionally, there's a spec ambiguity: the spec says "Dismiss" should "Dismiss without counting as break, reset timer" but also says "If user interacts (tap or Dismiss): reset continuous timer, increment break count". The implementation treats the default tap action as `takeBreakNow()` (counts break + resets), which follows the latter interpretation. But the explicit "Dismiss" button is still absent.

### H-3: `AppState` mutated from background threads without synchronization

**File:** `NotificationService.swift:25-26`, `MonitoringService.swift:47-52`

```swift
// NotificationService.swift
center.requestAuthorization(options: ...) { [weak self] granted, error in
    DispatchQueue.main.async {
        self?.appState.notificationPermissionGranted = granted  // OK: dispatched to main
    }
}
```

The permission callback correctly dispatches to main. However, `UNUserNotificationCenterDelegate` methods (`willPresent`, `didReceive`) are called on an arbitrary thread by the system. Inside `didReceive`, the code calls `monitoringService?.takeBreakNow()` which calls `appState.recordBreak()` — mutating `@Observable` state from a non-main thread. `@Observable` does not guarantee thread safety; SwiftUI expects all state mutations on `@MainActor`.

**Impact:** Potential data race on `AppState` properties. Could cause UI inconsistencies or crashes in rare timing conditions.

### H-4: Screen lock detection doesn't properly handle lock duration

**File:** `MonitoringService.swift:123-133`

The spec (Section 3.3) requires:
- If lock duration >= 2 minutes: treat as natural break
- If lock duration < 2 minutes: resume continuous timer where it left off

The implementation does neither — it just sets `isScreenLocked = true/false` and relies on `CGEventSource` to detect the idle time on the next poll. While this may work in practice (since `CGEventSource` does track time during lock), it's **not guaranteed**. The screen lock notification pauses the polling guard (`guard ... !isScreenLocked`), so no poll fires while locked. On unlock, the very next poll will see the idle time and handle it. But there's a gap: if the user unlocks and immediately interacts (mouse/keyboard within < 1 second), the CGEventSource idle time could reset to near-zero before the next 5-second poll fires. This would cause the lock period to be missed entirely, as if the user never locked the screen.

The architecture spec (Section 4.2, `handleScreenLock`/`handleScreenUnlock`) explicitly records `lockStartTime` and calculates lock duration on unlock. This implementation omits that logic.

**Impact:** Short screen locks (30s-2min) followed by immediate activity could silently lose the lock period, making the continuous use timer inaccurate.

### H-5: Timer uses target-action pattern creating a strong reference cycle risk

**File:** `MonitoringService.swift:59-64`

```swift
pollingTimer = Timer.scheduledTimer(
    timeInterval: Constants.pollingInterval,
    target: self,
    selector: #selector(pollIdleTime),
    userInfo: nil,
    repeats: true
)
```

The `target:selector:` Timer API retains `self` strongly. Since `MonitoringService` holds `pollingTimer` and `pollingTimer` retains `MonitoringService`, this is a **retain cycle**. The `deinit` that calls `pollingTimer?.invalidate()` will never fire because the timer keeps `self` alive.

The architecture spec (Section 4.2) used the closure-based `Timer.scheduledTimer(withTimeInterval:repeats:)` with `[weak self]` specifically to avoid this.

**Impact:** `MonitoringService` and its timer will never be deallocated. For a long-running menu bar app, this is less of a leak concern (it lives for the app's lifetime) but is still a correctness issue and would prevent clean shutdown/restart of monitoring.

---

## Medium Issues

### M-1: `MenuBarView` doesn't use `@Environment` or `@Bindable` for `AppState`

**File:** `MenuBarView.swift:4`

```swift
let appState: AppState
```

`AppState` is passed as a plain `let` property. For `@Observable` to trigger SwiftUI view updates, the view needs to access the `@Observable` object's properties within `body`. While this technically works (SwiftUI's observation tracking detects property access regardless of how the object is injected), the approved architecture (Section 3.3) recommends `@Environment appState: AppState` for proper SwiftUI idiom. Using `@Environment` ensures the state is available to child views without prop drilling.

### M-2: Circular dependency between `MonitoringService` and `NotificationService`

**File:** `EyesHealthApp.swift:13-14`

```swift
monService.setNotificationService(notifService)
notifService.setMonitoringService(monService)
```

Both services hold optional references to each other, set via setter injection after init. While both use it for coordination, this creates a potential retain cycle (both are strong references) and violates single-responsibility. The architecture spec didn't design for bidirectional service coupling — it shows `MonitoringService` writing to `AppState` and `NotificationService` reading from `AppState`, with `AppState` mediating.

A cleaner pattern would be: `MonitoringService` publishes events (via callback or delegate), `NotificationService` subscribes. Or use `AppState` as the mediator and have the app coordinate between services.

### M-3: `formattedTimeSinceBreak` shows 0m on fresh start

**File:** `AppState.swift:22-30`

When the app starts, `continuousUseSeconds` is 0, so the formatted time shows "0m". But the label in the menu says "Screen time: 0m" which is accurate. However, the **spec (Section 3.7)** labels this as "Time since last break: Xm" — the implementation shows "Screen time" which is subtly different. "Time since last break" should show time elapsed since `lastBreakTime`, not `continuousUseSeconds` (which pauses during idle).

### M-4: No `LSUIElement` configuration in `Package.swift` or via `Info.plist`

The spec (Section 5.11) requires `LSUIElement = true` to hide the Dock icon. SPM executable targets don't automatically embed an `Info.plist`. Without this, the app will show a Dock icon, which contradicts the spec requirement for a menu-bar-only app.

### M-5: `print()` used for error logging

**Files:** `NotificationService.swift:30, 83`

```swift
print("[NotificationService] Permission error: \(error.localizedDescription)")
print("[NotificationService] Schedule error: \(error.localizedDescription)")
```

Production code should use `os.Logger` (or `OSLog`) instead of `print()`. `print()` output goes to stdout and is not captured by macOS Console.app, making debugging deployed apps impossible.

### M-6: `StatusColor` thresholds differ from spec

**File:** `Constants.swift:10`

```swift
static let yellowThreshold: TimeInterval = 10 * 60 // 10 min
```

Both the spec (Section 3.6) and the implementation agree on 0-10 min = green, 10-20 min = yellow. But the architecture spec (Section 3.1) defines green as 0-14 min and yellow as 15-19 min. The implementation follows the V1 spec (correct), but this inconsistency between the two specs should be noted. **The implementation is correct per the V1 spec.**

---

## Low Issues

### L-1: `BreakRecord` has `Codable` conformance but is never persisted

**File:** `BreakRecord.swift:3`

Adding `Codable` now is a good V2 preparation (as the architecture spec recommends), but it's dead code in V1. This is a non-issue but worth noting.

### L-2: `Constants` imports `SwiftUI` only for `StatusColor`'s `Color` type

**File:** `Constants.swift:1`

The `Constants` enum itself doesn't need SwiftUI. `StatusColor` uses `Color`, which requires the import. Splitting `StatusColor` into its own file would keep `Constants` framework-agnostic, but this is minor for a small codebase.

### L-3: `MenuBarView` `onTakeBreak` closure uses `[weak appDelegate]`

**File:** `EyesHealthApp.swift:58-60`

```swift
onTakeBreak: { [weak appDelegate] in
    appDelegate?.monitoringService?.takeBreakNow()
}
```

`appDelegate` is retained by the app's `@NSApplicationDelegateAdaptor`, so it will live for the entire app lifecycle. The `[weak]` capture is harmless but unnecessary.

### L-4: No accessibility labels on menu bar view elements

**File:** `MenuBarView.swift`

The status circle, stats, and buttons have no explicit `accessibilityLabel` modifiers. macOS VoiceOver users may have a degraded experience.

---

## Positive Highlights

1. **Clean file organization** — 7 files, all under 140 lines, following the approved directory structure exactly. Total codebase is ~393 lines, well within quality bounds.

2. **Proper `NSObject` inheritance** — `MonitoringService` correctly inherits from `NSObject` for `@objc` selector support with `DistributedNotificationCenter`, as the architecture spec recommended.

3. **Good `deinit` cleanup** — `MonitoringService.deinit` invalidates the timer and removes observers. This shows awareness of resource management.

4. **Correct platform target** — `Package.swift` targets `.macOS(.v14)` as the architecture spec mandated (resolving RISK-5 re: `@Observable` availability).

5. **`BreakRecord` is a proper value type** — Immutable struct with `Identifiable`, `Codable`, `Equatable`. Clean, minimal, V2-ready.

6. **`hasScheduledReminder` dedup guard** — `NotificationService` prevents duplicate notification scheduling within the same break cycle. Simple and effective.

7. **Well-structured `MenuBarView`** — Clean separation into `statusSection`, `statsSection`, `actionSection` computed properties. Readable and under 80 lines.

8. **`StatusColor` enum is well-designed** — Encapsulates icon name, color, and message in one place. Easy to extend for new states.

9. **Midnight reset scheduling** — Uses `Calendar.nextDate(after:matching:)` which is DST-safe and correctly reschedules recursively.

10. **Notification delegate properly handles foreground display** — `willPresent` returns `[.banner, .sound]` so notifications show even though menu bar apps are technically always "foreground".

---

## Action Items for Dev

### Must Fix (Blocking V1 Ship)

1. **Fix notification re-notification logic** (C-1): After the initial notification fires, implement the spec's re-notify behavior — if user ignores, re-notify after 5 minutes (max 2 re-notifications). Track `notificationAttempts` count and only reset on break or natural idle. Stop incrementing `continuousUseSeconds` past the threshold, or use a separate `notificationSentAt` timestamp to drive re-notification timing.

2. **Fix snooze timer reliability** (C-2): Replace `DispatchQueue.main.asyncAfter` with a `Timer.scheduledTimer` on the main RunLoop (forMode: `.common`). Track snooze state in `AppState` (e.g., `snoozedUntil: Date?` as the spec's data model suggests) and check it during each poll tick rather than relying on a delayed dispatch.

### Should Fix (Before V1 Ship)

3. **Add unit tests** (H-1): At minimum, add tests for `AppState` (state transitions, computed properties, `resetDaily`, `recordBreak`) and `MonitoringService` (extract `IdleTimeProvider` protocol for testability, as the architecture spec recommends). Add a test target to `Package.swift`.

4. **Add `Dismiss` notification action** (H-2): Add a third `UNNotificationAction` with identifier `DISMISS_ACTION` and handle `UNNotificationDismissActionIdentifier` in `didReceive`. Decide whether dismiss counts as a break or not (spec is ambiguous) and document the decision.

5. **Ensure `@MainActor` safety** (H-3): Either mark `AppState` as `@MainActor`, or dispatch all `appState` mutations to `DispatchQueue.main.async` in the notification delegate methods. The most correct Swift approach is to annotate `AppState` with `@MainActor` and use `MainActor.assumeIsolated` or `@MainActor` closures in the services.

6. **Record screen lock timestamps** (H-4): In `handleScreenLock()`, store `lockStartTime = Date.now`. In `handleScreenUnlock()`, calculate `lockDuration = Date.now.timeIntervalSince(lockStartTime)` and if >= 2 minutes, call `appState.recordBreak()`. Don't rely solely on CGEventSource for lock detection.

7. **Fix Timer retain cycle** (H-5): Switch to the closure-based `Timer.scheduledTimer(withTimeInterval:repeats:)` with `[weak self]` capture, matching the architecture spec's implementation.

### Nice to Fix

8. **Add `LSUIElement` Info.plist** (M-4): Create an `Info.plist` file or add `swiftSettings` to the SPM target to embed the `LSUIElement = true` key. Without this, the app will show in the Dock.

9. **Break circular service dependency** (M-2): Refactor the bidirectional `MonitoringService <-> NotificationService` coupling. Consider using `AppState` as the mediator, or introduce a callback/delegate pattern.

10. **Use `@Environment` for `AppState` injection** (M-1): Change `MenuBarView` to receive `AppState` via `@Environment(AppState.self)` rather than a plain `let` property, matching the approved architecture and SwiftUI idioms.

11. **Replace `print()` with `os.Logger`** (M-5): Create a `Logger` instance and use structured logging for error conditions.

12. **Fix label to match spec** (M-3): Change "Screen time" label in `MenuBarView` to "Time since last break" to match the spec's wireframe text.

13. **Add accessibility labels** (L-4): Add `.accessibilityLabel()` modifiers to the status dot, stats rows, and action buttons for VoiceOver support.

---

## Architecture Compliance Summary

| Architecture Requirement | Status | Notes |
|--------------------------|--------|-------|
| Single `@Observable` AppState | PASS | Clean implementation |
| Service-oriented (MonitoringService + NotificationService) | PASS | Both present and functional |
| `MenuBarExtra` with window style | PASS | Correctly configured |
| macOS 14+ deployment target | PASS | `Package.swift` targets `.macOS(.v14)` |
| `NSObject` for `@objc` selectors | PASS | Both services extend `NSObject` |
| `BreakRecord` as value type with `Codable` | PASS | Immutable struct, ready for V2 |
| `Constants` enum for thresholds | PASS | All magic numbers centralized |
| `IdleTimeProvider` protocol for testability | FAIL | Not implemented; `currentIdleTime()` is hardcoded |
| Test target in `Package.swift` | FAIL | No test target, no tests |
| `LSUIElement = true` for Dock hiding | FAIL | No Info.plist configured |
| Midnight reset scheduling | PASS | DST-safe implementation |
| Screen lock detection via DistributedNotificationCenter | PARTIAL | Observers registered but lock duration logic missing |
| Re-notification on ignore (max 2) | FAIL | Not implemented |
| Snooze with `snoozedUntil` state tracking | PARTIAL | Snooze exists but uses unreliable dispatch, no state tracking |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Notification flood (C-1) | Prevented by `hasScheduledReminder` | LOW | But re-notification logic still missing |
| Data race on AppState (H-3) | MEDIUM | Crash/UI corruption | Add `@MainActor` annotation |
| Timer retain cycle (H-5) | HIGH (certain) | Memory never freed | Switch to closure-based Timer |
| CGEventSource permission (from arch RISK-1) | LOW on macOS 14+ | App doesn't detect idle | Not addressed in code — needs runtime check |

---

*Review generated by Lead Agent — EyesHealth V1 Code Review*
