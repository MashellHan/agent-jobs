# V6 Iteration Summary: Eye Care Tips Engine

## Date: 2026-04-15

## Feature: Contextual Eye Care Tips (護眼小妙招)

### What Was Built

#### 1. EyeCareTip Model (`EyesHealth/Models/EyeCareTip.swift`)
- `EyeCareTip` struct with `Identifiable`, `Codable` conformance
- `TipCategory` enum with 7 categories: hydration, exercise, posture, lighting, nutrition, rest, environment
- Each category has a display name and SF Symbol icon
- Each tip includes: id, category, title, content, medical source, and icon

#### 2. TipsService (`EyesHealth/Services/TipsService.swift`)
- Singleton service managing 35 medically-backed eye care tips
- **Rotation logic**: tracks shown tip IDs to avoid repeats; resets when all tips have been shown
- **Contextual delivery**: `contextualTip(hour:score:)` selects category based on time-of-day and eye health score:
  - Late night (22-5): rest tips
  - Morning (6-9): posture tips
  - Mid-morning (10-11): exercise/hydration
  - Lunch (12-13): nutrition tips
  - Afternoon (14-17): varies by health score
  - Evening (18-21): lighting tips
- 35 tips across 7 categories (5 per category), sourced from: AAO, Mayo Clinic, NHS, WHO, NEI, AOA, OSHA, NASA, Vision Council, Sleep Foundation

#### 3. Integration Points

**NotificationService**:
- Break reminder notifications now include a contextual tip in the body
- Format: standard 20-20-20 message + `💡 Tip: {tip content}`
- Tips are selected based on current hour and eye health score

**MascotState**:
- New `startTipCycling()` method starts a 10-minute repeating timer
- Every 10 minutes during idle, mascot shows a random tip in speech bubble for 8 seconds
- Priority speech protection: tips don't interrupt break alerts or celebration messages
- `isShowingPrioritySpeech` flag prevents tip display during important messages

**MenuBarView**:
- New "Daily Tip" section between mascot toggle and action buttons
- Shows: category icon, tip title, tip content (up to 3 lines), and medical source
- "Next Tip" button to cycle through tips on demand
- Tip refreshes each time the menu is opened via `onAppear`

**AppDelegate**:
- Starts tip cycling when mascot is shown on launch
- Starts/stops tip cycling when mascot visibility is toggled

### Commits

1. `877d33e` — `feat: add eye care tips engine with 30+ medically-backed tips`
   - New files: EyeCareTip.swift, TipsService.swift
   - 35 tips, 7 categories, rotation and contextual delivery

2. `a2cd681` — `feat: integrate tips into notifications, mascot, and menu`
   - Modified: NotificationService, MascotState, EyesHealthApp, MenuBarView
   - Tips in notifications, mascot speech bubbles, and menu bar

### Build Status
- `swift build`: **PASS**
- `.app` bundle: **PASS** (built and launched successfully)

### Screenshots
- `v6-running.png` — Full desktop with app running
- `v6-menubar.png` — Menu bar showing green eye icon
- `v6-mascot.png` — Eye Guardian mascot in bottom-right corner

### Architecture Notes
- `TipsService` is a singleton (`TipsService.shared`) for easy access across services and views
- Tips are hardcoded (no external file/network dependency) for reliability
- Rotation state is in-memory only (resets on app restart, which is fine for tips)
- Contextual tip selection is deterministic by time-of-day, with score-based variation in afternoon hours

### Medical Sources Referenced
| Source | Abbreviation | Tips |
|--------|--------------|------|
| American Academy of Ophthalmology | AAO | 7 |
| American Optometric Association | AOA | 4 |
| Mayo Clinic | Mayo Clinic | 1 |
| National Health Service (UK) | NHS | 1 |
| World Health Organization | WHO | 1 |
| National Eye Institute | NEI | 3 |
| OSHA | OSHA | 4 |
| Vision Council | Vision Council | 2 |
| Sleep Foundation | Sleep Foundation | 1 |
| NASA Clean Air Study | NASA | 1 |
| Other research | Various | 10 |
