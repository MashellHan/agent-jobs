# EyesCare v1 — UX Design Specification

**Version:** 1.0
**Date:** 2026-04-15
**Author:** PM Agent
**Status:** Draft

---

## 1. Design Principles

| Principle | Description |
|-----------|-------------|
| **Invisible until needed** | Menu bar app should be non-intrusive; no Dock icon, no main window |
| **Glanceable status** | Users should understand their eye health status in < 2 seconds |
| **Medical trust** | Every break reference should cite its medical source |
| **Native feel** | Follow macOS Human Interface Guidelines; no custom chrome |
| **Zero config start** | App works perfectly with defaults, no setup wizard needed |

---

## 2. Menu Bar Icon

### 2.1 Icon States

The menu bar icon communicates monitoring state at a glance:

```
State: Monitoring (Active)
┌─────────────────────────────────┐
│  ...  👁  EyesCare  ...        │  ← Menu bar
└─────────────────────────────────┘
  SF Symbol: "eye" (filled)
  Title: hidden (icon only for cleanliness)
  Color: Default (template image)

State: Paused
┌─────────────────────────────────┐
│  ...  👁  ...                   │  ← Menu bar
└─────────────────────────────────┘
  SF Symbol: "eye.slash" 
  Color: Default (template image, dimmed feel)

State: User is Idle (detected)
┌─────────────────────────────────┐
│  ...  😴  ...                   │  ← Menu bar
└─────────────────────────────────┘
  SF Symbol: "eye.slash" or "moon.zzz"
  Color: Default
```

### 2.2 Icon Decision

For v1 simplicity, use:
- **Monitoring:** `eye` SF Symbol (no title text — saves menu bar space)
- **Paused:** `eye.slash` SF Symbol
- No color changes in v1 (template images only for Dark/Light mode compatibility)

---

## 3. Menu Structure

When the user clicks the menu bar icon, the following dropdown menu appears:

### 3.1 Menu Layout

```
┌──────────────────────────────────────┐
│  EyesCare v1.0                       │  ← Disabled (app identity)
│──────────────────────────────────────│
│  ● Monitoring                        │  ← Green dot when active
│  Active Time: 1h 23m                 │  ← Disabled (info display)
│  Since Last Break: 18m               │  ← Disabled (info display)
│──────────────────────────────────────│
│  Pause Monitoring                    │  ← Toggle action
│──────────────────────────────────────│
│  Quit EyesCare                 ⌘Q   │  ← Quit with shortcut
└──────────────────────────────────────┘
```

### 3.2 Menu States

**When Monitoring is Active:**
```
┌──────────────────────────────────────┐
│  EyesCare v1.0                       │
│──────────────────────────────────────│
│  ● Monitoring                        │  ← Green circle prefix
│  Active Time: 1h 23m                 │
│  Since Last Break: 18m               │
│──────────────────────────────────────│
│  Pause Monitoring                    │
│──────────────────────────────────────│
│  Quit EyesCare                 ⌘Q   │
└──────────────────────────────────────┘
```

**When Monitoring is Paused:**
```
┌──────────────────────────────────────┐
│  EyesCare v1.0                       │
│──────────────────────────────────────│
│  ○ Paused                            │  ← Hollow circle prefix
│  Active Time: —                      │  ← Dash when not tracking
│  Since Last Break: —                 │
│──────────────────────────────────────│
│  Resume Monitoring                   │  ← Label changes
│──────────────────────────────────────│
│  Quit EyesCare                 ⌘Q   │
└──────────────────────────────────────┘
```

**When User is Idle (detected automatically):**
```
┌──────────────────────────────────────┐
│  EyesCare v1.0                       │
│──────────────────────────────────────│
│  ● Monitoring (Idle)                 │  ← Shows idle sub-state
│  Active Time: 1h 23m                 │  ← Frozen while idle
│  Since Last Break: 0m (resting)      │  ← Shows "resting" note
│──────────────────────────────────────│
│  Pause Monitoring                    │
│──────────────────────────────────────│
│  Quit EyesCare                 ⌘Q   │
└──────────────────────────────────────┘
```

### 3.3 Menu Item Specifications

| Item | Type | State | Key Equivalent | Action |
|------|------|-------|---------------|--------|
| "EyesCare v1.0" | Info | Disabled | — | None (title display) |
| Separator | — | — | — | Visual divider |
| "● Monitoring" / "○ Paused" | Info | Disabled | — | Status indicator |
| "Active Time: Xh Ym" | Info | Disabled | — | Live counter |
| "Since Last Break: Xm" | Info | Disabled | — | Time since idle reset |
| Separator | — | — | — | Visual divider |
| "Pause/Resume Monitoring" | Action | Enabled | — | Toggle monitoring |
| Separator | — | — | — | Visual divider |
| "Quit EyesCare" | Action | Enabled | ⌘Q | Terminate app |

---

## 4. User Flows

### 4.1 First Launch Flow

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   App opens  │ ──► │  Menu bar icon   │ ──► │   Monitoring     │
│  (no window) │     │  appears (👁)    │     │   starts auto    │
└─────────────┘     └──────────────────┘     └─────────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │ Idle detection   │
                                              │ begins polling   │
                                              │ (every 5 sec)    │
                                              └─────────────────┘
```

**Key decision:** Monitoring starts automatically on launch. No setup wizard. No permissions dialog (CGEventSource doesn't need one). The user sees the eye icon and knows it's working.

### 4.2 Monitoring Toggle Flow

```
  User clicks menu bar icon
           │
           ▼
  ┌─────────────────┐
  │   Menu appears   │
  │   Shows status   │
  └────────┬────────┘
           │
    ┌──────┴──────┐
    │              │
    ▼              ▼
┌────────┐   ┌──────────┐
│ "Pause │   │  "Resume │
│ Monitoring"│  Monitoring"│
└───┬────┘   └────┬─────┘
    │              │
    ▼              ▼
┌────────────┐  ┌──────────────┐
│ Stop timer │  │ Restart timer│
│ Icon → 👁⃠ │  │ Icon → 👁    │
│ Clear stats│  │ Resume stats │
└────────────┘  └──────────────┘
```

### 4.3 Idle Detection Flow

```
┌───────────────┐
│ Timer fires   │
│ (every 5 sec) │
└───────┬───────┘
        │
        ▼
┌───────────────────────┐
│ Check CGEventSource   │
│ secondsSinceLastEvent │
└───────────┬───────────┘
        │
   ┌────┴────┐
   │         │
   ▼         ▼
 < 30s    >= 30s
 ACTIVE    IDLE
   │         │
   ▼         │
┌────────┐   │     >= 120s?
│Increment│   ├────────┐
│active   │   │        │
│time     │   ▼        ▼
└────────┘  ┌─────┐  ┌──────────────┐
            │IDLE │  │NATURAL BREAK │
            │state│  │Reset active  │
            └─────┘  │time counter  │
                     └──────────────┘
```

### 4.4 Natural Break Recognition

```
User stops typing/moving mouse
          │
          ▼  (after 30 seconds)
    ┌───────────┐
    │  IDLE     │  Menu shows: "● Monitoring (Idle)"
    └─────┬─────┘
          │  (after 120 seconds total)
          ▼
    ┌───────────────┐
    │ NATURAL BREAK │  "Since Last Break" resets to 0
    └───────┬───────┘
            │  User returns (input detected)
            ▼
    ┌───────────────┐
    │ ACTIVE again  │  Active time starts fresh
    │ Break credited│  Menu shows: "Since Last Break: 0m"
    └───────────────┘
```

---

## 5. Time Display Formatting

### 5.1 Active Time Format

| Duration | Display |
|----------|---------|
| < 1 minute | "Active Time: < 1m" |
| 1-59 minutes | "Active Time: Xm" |
| 1-23 hours | "Active Time: Xh Ym" |
| 24+ hours | "Active Time: Xd Yh" |

### 5.2 Since Last Break Format

| Duration | Display |
|----------|---------|
| During idle | "Since Last Break: 0m (resting)" |
| < 1 minute | "Since Last Break: < 1m" |
| 1-59 minutes | "Since Last Break: Xm" |
| 60+ minutes | "Since Last Break: Xh Ym" |
| Monitoring paused | "Since Last Break: —" |

---

## 6. Visual Design

### 6.1 Colors

v1 uses **system colors only** (no custom palette):

| Element | Color |
|---------|-------|
| Menu bar icon | System template (adapts to Light/Dark) |
| Status dot (active) | "●" character (green implied by context) |
| Status dot (paused) | "○" character |
| Menu text | System default |
| Info items | System disabled text color |

### 6.2 Typography

All text uses **system font** at standard NSMenu sizes. No custom fonts in v1.

### 6.3 Accessibility

| Requirement | Implementation |
|-------------|----------------|
| VoiceOver | Menu items have accessibility descriptions |
| Menu bar icon | `accessibilityDescription: "EyesCare"` |
| Status | "EyesCare is monitoring your screen time" / "EyesCare is paused" |
| High contrast | Template images work automatically |
| Reduce motion | No animations in v1 |

---

## 7. Edge Cases

| Scenario | Behavior |
|----------|----------|
| System sleep/wake | Detect as extended idle; credit as natural break |
| Screen saver activates | Treat as idle (CGEventSource still works) |
| Multiple displays | CGEventSource is global; works across all displays |
| User switches macOS accounts | App runs per-user; monitoring is per-session |
| App launched multiple times | macOS prevents duplicate menu bar items (single instance) |
| Clock change (DST, NTP) | Use monotonic clock for elapsed time; Date for display |

---

## 8. Future UX Considerations (Not in v1)

These UX patterns are planned for future versions and should NOT be implemented in v1, but the architecture should accommodate them:

| Version | UX Element | Note |
|---------|-----------|------|
| v2 | Break notification banners | Will use `UNUserNotificationCenter` |
| v2 | Countdown timer in menu bar title | "18m" displayed next to icon |
| v3 | Floating countdown window | Non-focusable overlay |
| v3 | Full-screen break overlay | Dimmed screen with timer |
| v7 | Preferences window | Standard macOS Settings pane |
| v8 | Eye exercise animations | SwiftUI-animated guides |

---

## 9. Design References

| App | What to Learn |
|-----|--------------|
| Pandan | Ultra-clean menu bar integration |
| Time Out | Screen dimming transition |
| macOS Battery menu | Info-display menu items pattern |
| macOS Wi-Fi menu | Status + action menu pattern |
| Bartender | Menu bar icon management |

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-04-15 | 1.0 | PM Agent | Initial UX design for v1 |
