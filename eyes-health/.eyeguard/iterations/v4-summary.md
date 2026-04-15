# V4 Iteration Summary — Eye Guardian Mascot (护眼精灵)

## Date
2026-04-14

## Feature
Cute floating mascot character — a kawaii-style eye that lives on screen and reacts to eye health status.

## What Was Built

### New Files (4)

| File | Lines | Purpose |
|------|-------|---------|
| `Models/MascotState.swift` | 78 | Observable state: expression enum, speech text, celebration/alert methods |
| `Views/MascotView.swift` | 310 | Pure SwiftUI eye character with all animations |
| `Views/SpeechBubbleView.swift` | 48 | Rounded speech bubble with triangle pointer |
| `Services/MascotWindowService.swift` | 111 | Floating NSPanel management |

### Modified Files (4)

| File | Changes |
|------|---------|
| `Utils/Constants.swift` | Added mascot window dimensions, UserDefaults key |
| `App/EyesHealthApp.swift` | AppDelegate creates MascotWindowService, syncs state, passes toggle binding |
| `Services/MonitoringService.swift` | Triggers mascot alert on break due, celebration on break taken |
| `Views/MenuBarView.swift` | Added "Show Eye Guardian" toggle with persistence |

## Mascot Design

The Eye Guardian is a ~60×60pt round eye character drawn entirely with SwiftUI shapes:

- **Body**: White eyeball with subtle blue tint, gray stroke outline
- **Iris**: Colored circle that changes with health status:
  - 🟢 Green (0–10 min) — healthy
  - 🟡 Amber (10–20 min) — concerned
  - 🔴 Red (20+ min) — worried/overdue
- **Pupil**: Black circle that follows the mouse cursor (±3px)
- **Sparkle**: Small white highlight dot for cute effect
- **Eyelids**: Animated paths for blinking and expressions
- **Cheeks**: Subtle pink circles for kawaii appeal

## Animations

| Animation | Trigger | Details |
|-----------|---------|---------|
| Periodic blink | Every 3–6s (random) | Eyelids close for ~120ms |
| Gentle bobbing | Always | 2px vertical sine wave, 2s period |
| Mouse tracking | Always | Pupil follows cursor direction, 100ms polling |
| Bounce | Happy expression | Spring scale to 1.15x then back |
| Shake | Worried expression | 5-step horizontal shake sequence |
| Iris color | Status change | Smooth color transition |

## Expressions

| Expression | When | Visual |
|------------|------|--------|
| `.normal` | Healthy (green status) | Wide-open eyes, regular blinking |
| `.concerned` | Warning (yellow status) | Slightly narrowed eyelids |
| `.worried` | Overdue (red status) | Wide eyes + larger pupil + shake |
| `.happy` | After break taken | Squinty happy eyelids + bounce + "Great job! 😊" |
| `.sleeping` | (Future) night mode | Nearly closed eyelids |

## Speech Bubbles

- White rounded rectangle with downward-pointing triangle
- Subtle shadow for depth
- Fade in/out with 0.3s animation
- Triggered messages:
  - Break due: "Time for a break! 👀"
  - Break taken: "Great job! 😊" (auto-dismisses after 10s)

## Window Behavior

- **Type**: NSPanel with `.nonactivatingPanel` + `.fullSizeContentView`
- **Level**: `.floating` (above normal windows, below screen saver)
- **Position**: Bottom-right of screen, 20pt from edges
- **Draggable**: Via `isMovableByWindowBackground`
- **Persistence**: Joins all spaces, works in full-screen auxiliary
- **Toggle**: "Show Eye Guardian" in menu bar, persisted to UserDefaults
- **Focus**: Non-activating — never steals keyboard focus

## Integration Points

1. **AppDelegate** → creates MascotWindowService on launch, starts 2s state-sync timer
2. **MonitoringService.pollIdleTime()** → calls `mascotState.alertBreakDue()` when `shouldNotify`
3. **MonitoringService.takeBreakNow()** → calls `mascotState.celebrateBreak()` for 10s happy mode
4. **MenuBarView** → `Toggle("Show Eye Guardian")` binding controls show/hide

## Commits

1. `311759e` — `feat: add MascotView with cute eye character and animations`
2. `948b5ec` — `feat: add MascotWindowService for floating mascot window`
3. `78eccb8` — `feat: wire mascot to app state and add toggle in menu`

## Screenshots

- `screenshots/v4-mascot.png` — Full desktop with mascot visible in bottom-right
- `screenshots/v4-mascot-closeup.png` — Close-up of the eye mascot character

## Known Limitations / Future Work

- **Pupil tracking uses approximate screen position**: The mouse-tracking math estimates the mascot's screen position from the default bottom-right placement. If the user drags the mascot elsewhere, tracking direction will be slightly off. A future version could read the panel's actual frame.
- **Sleep expression**: Defined but not triggered — intended for a future night-mode feature.
- **Speech bubble auto-dismiss**: Currently relies on `MascotState.celebrateBreak()` timer. A generic auto-dismiss timer in the view layer would be more robust.
- **No sound effects**: The mascot is purely visual. Subtle sound effects on expression change could enhance delight.
