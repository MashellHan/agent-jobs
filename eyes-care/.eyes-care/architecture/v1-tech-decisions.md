# EyesCare v1 Technical Decisions

**Version:** 1.0
**Date:** 2026-04-15
**Author:** Lead Engineer Agent
**Status:** Final

---

## Decision Log

### TD-01: Idle Detection via CGEventSource (multiple event types)

**Status:** DECIDED
**Context:** We need to detect when the user stops interacting with the Mac. The PM specified `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType:)`.

**Decision:** Query **four** event types and take the **minimum**:
- `.keyDown` (keyboard)
- `.mouseMoved` (mouse/trackpad movement)
- `.leftMouseDown` (clicks)
- `.scrollWheel` (scrolling)

**Rationale:**
- Using a single `.any` event type is undocumented and may not exist as a valid `CGEventType`
- Checking multiple types ensures we catch all user activity
- `min()` of all idle times gives us "time since the last of any interaction"
- No Accessibility permission needed — `CGEventSource` reads from the HID system

**Alternatives rejected:**
- `CGEventTap` — requires Accessibility permission
- `IOHIDManager` — lower level, more complex, same result
- `NSEvent.addGlobalMonitorForEvents` — requires Accessibility for some event types

---

### TD-02: @MainActor for MonitoringSession (not Actor)

**Status:** DECIDED
**Context:** `MonitoringSession` owns a `Timer` and updates state that drives `NSMenu` items.

**Decision:** Mark `MonitoringSession` as `@MainActor` instead of using a custom actor.

**Rationale:**
- `Timer.scheduledTimer` must be created and fired on the main RunLoop
- `NSMenuItem.title` can only be set from the main thread
- The delegate pattern (`MonitoringSessionDelegate`) is `@MainActor`
- Using a custom actor would require `await` everywhere and `MainActor.run {}` for UI updates — unnecessary complexity for v1

**Trade-off:** Cannot do background work in `MonitoringSession`. This is fine for v1 — `CGEventSource` calls are fast (< 1ms).

---

### TD-03: Delegate pattern (not Combine, not AsyncStream)

**Status:** DECIDED
**Context:** `AppDelegate` needs to react to `MonitoringSession` state changes.

**Decision:** Use a `MonitoringSessionDelegate` protocol with a single callback.

**Rationale:**
- `AppDelegate` is already `@MainActor` — delegate calls are synchronous on the main thread
- No Combine import needed (keeps the dependency footprint minimal)
- `AsyncStream` would require an async context in `AppDelegate`, which is awkward with AppKit
- Delegate is the simplest pattern that works and is familiar to all Swift developers

**Future:** v2+ may add `AsyncStream<MonitoringStatus>` alongside the delegate for SwiftUI views.

---

### TD-04: Date-based time tracking (not accumulated intervals)

**Status:** DECIDED
**Context:** Active time and since-last-break must be accurate over long sessions (8+ hours).

**Decision:** Track wall-clock timestamps, compute intervals on demand.

**Implementation:**
```
accumulatedActiveTime += pollingInterval  // only when state == .active
sinceLastBreak = now - lastBreakEndDate   // computed on demand
```

**Rationale:**
- Timer.scheduledTimer can drift: if the system is under load, a 5-second timer may fire at 5.3s, 5.1s, etc.
- Over 8 hours (5760 polls), accumulated drift could reach 30+ seconds
- Date-based: `sinceLastBreak` is always accurate regardless of timer jitter
- `accumulatedActiveTime` still uses increment-per-poll, but this is intentional — we want to count only observed-active polls

**Trade-off:** `accumulatedActiveTime` may be up to `pollingInterval` inaccurate (acceptable per PRD ±5s target).

---

### TD-05: MonitoringStatus as immutable snapshot

**Status:** DECIDED
**Context:** AppDelegate needs to read monitoring state to update menu items.

**Decision:** Create a `MonitoringStatus` struct that captures a point-in-time snapshot.

**Rationale:**
- Immutable value type prevents race conditions (even though we're single-threaded)
- `Equatable` conformance allows AppDelegate to skip redundant menu updates
- Clean API boundary: `MonitoringSession` produces status, `AppDelegate` consumes it
- Follows the project's immutability-first principle

---

### TD-06: Protocol name `IdleDetecting` (not `IdleMonitor`)

**Status:** DECIDED
**Context:** The PM's handoff document uses "IdleMonitor" as both the protocol and concept name.

**Decision:** Name the protocol `IdleDetecting` and the concrete implementation `CGEventSourceIdleDetector`.

**Rationale:**
- Avoids confusion with `MonitoringSession` (which is the "monitor" in the system)
- Swift API naming: protocols describe capabilities (`-ing`, `-able`) — e.g., `Equatable`, `Codable`, `Identifiable`
- `IdleDetecting` clearly communicates what the conforming type does
- `CGEventSourceIdleDetector` is a noun that implements the capability

---

### TD-07: Swift Testing framework (not XCTest)

**Status:** DECIDED
**Context:** Project rules mandate Swift Testing (`import Testing`) for new tests.

**Decision:** Use `@Test` and `#expect` exclusively. No XCTest.

**Rationale:**
- Swift Testing is the modern standard (Swift 5.9+)
- `@Test` with `arguments:` enables parameterized tests (used for TimeFormatter)
- Better error messages than `XCTAssertEqual`
- Aligned with project's Swift coding standards

**Constraint:** Swift Testing requires Xcode 16+ or `swift-testing` package. Since we're on Swift 5.9+ with macOS 14+, this is available.

---

### TD-08: Test target name `EyesCareTests` (existing directory)

**Status:** DECIDED
**Context:** The Tests directory has `Tests/EyesCareTests/` with a `.gitkeep` file.

**Decision:** Use the existing `EyesCareTests` directory and add it as a `testTarget` in Package.swift.

**Rationale:**
- Directory already exists
- Name is clear and follows SPM conventions
- Tests only depend on `EyesCareCore` — they don't import `EyesCareApp`

**Package.swift change:**
```swift
.testTarget(
    name: "EyesCareTests",
    dependencies: ["EyesCareCore"],
    path: "Tests/EyesCareTests"
)
```

---

### TD-09: Menu item property references (not tag-based lookup)

**Status:** DECIDED
**Context:** AppDelegate needs to update specific menu items (status, active time, etc.) every 5 seconds.

**Decision:** Store `NSMenuItem` references as private properties.

**Rationale:**
- Direct property access is O(1) — no menu traversal needed
- Type-safe — no `menu.item(withTag: 42)` magic numbers
- Rebuild-free — just update `.title` on existing items
- Properties are set once in `setupMenuBar()` and reused for the app lifetime

**Alternative rejected:** Rebuilding the entire NSMenu on every poll — wasteful, causes visual flickering.

---

### TD-10: No Dock icon via empty Settings scene

**Status:** DECIDED (existing)
**Context:** Menu-bar-only app should not appear in the Dock.

**Decision:** Keep the current approach: `Settings { EmptyView() }` as the only Scene.

**Rationale:**
- SwiftUI `@main` with no `WindowGroup` and only `Settings` scene → no Dock icon
- `NSApplicationDelegateAdaptor` handles all AppKit setup
- `LSUIElement` is not needed when there are no windows — the behavior is implicit

**Risk:** If this breaks on future macOS, add `Info.plist` with `LSUIElement = true`.

---

### TD-11: Separate MonitoringSessionDelegate protocol file

**Status:** DECIDED
**Context:** The delegate protocol for MonitoringSession — where should it live?

**Decision:** Dedicated file at `Protocols/MonitoringSessionDelegate.swift`.

**Rationale:**
- Follows single-responsibility file organization
- The protocol is consumed by `EyesCareApp` (AppDelegate), so it needs to be `public`
- Keeping it separate from `MonitoringSession.swift` keeps both files focused and small

---

### TD-12: poll() is internal, not private

**Status:** DECIDED
**Context:** `MonitoringSession.poll()` is the core method that reads idle time and transitions state.

**Decision:** Mark `poll()` as `internal` (default access level, omit keyword).

**Rationale:**
- Tests need to call `poll()` directly to simulate timer ticks
- Tests can't (and shouldn't) create real `Timer` instances
- `internal` is visible within the `EyesCareCore` module and its test target
- From `EyesCareApp`'s perspective, `poll()` is not visible (different module)

---

## Summary

| # | Decision | Impact |
|---|----------|--------|
| TD-01 | Multiple CGEventSource event types | Accurate idle detection |
| TD-02 | @MainActor for MonitoringSession | Simple threading model |
| TD-03 | Delegate pattern | Clean callback interface |
| TD-04 | Date-based time tracking | Drift-free over long sessions |
| TD-05 | Immutable MonitoringStatus snapshot | Safe data transfer |
| TD-06 | `IdleDetecting` protocol naming | Clear Swift API design |
| TD-07 | Swift Testing framework | Modern test infrastructure |
| TD-08 | EyesCareTests target | Matches existing directory |
| TD-09 | Menu item property references | Efficient UI updates |
| TD-10 | No Dock icon via empty Settings | Existing approach works |
| TD-11 | Separate delegate protocol file | Single responsibility |
| TD-12 | Internal poll() method | Testable without real timers |

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | Lead Engineer Agent | Initial tech decisions for v1 |
