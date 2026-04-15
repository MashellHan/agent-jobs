# V5: Data Persistence + Daily Eye Health Report

## Iteration Date
2026-04-15

## Summary
Implemented data persistence layer and daily eye health reporting for EyesHealth.
Usage data is saved as JSON files, an eye health score (0-100) is calculated from
five dimensions, and markdown reports are generated with detailed breakdowns.

## New Files

### `EyesHealth/Models/DailyUsageData.swift`
- `DailyUsageData` Codable struct tracking:
  - Total screen time, break records, session counts
  - Longest/shortest/average session durations
  - Break compliance (due, taken, skipped)
  - Hourly screen time distribution (String-keyed for Codable)
  - Night usage (after 22:00)
- Helper methods: `todayDateString()`, `displayDate`, `screenTime(forHour:)`,
  `addScreenTime(_:forHour:)`, `breakCompliancePercent`, `recalculateSessionStats()`

### `EyesHealth/Services/DataPersistenceService.swift`
- Manages `~/Library/Application Support/EyesHealth/data/` and `.../reports/`
- `saveDailyData(_:)` / `loadTodayData()` / `loadData(for:)` — JSON round-trip
- `generateDailyReport(from:score:)` — builds markdown with:
  - Score header with grade
  - Summary table (screen time, breaks, compliance, sessions)
  - Hourly bar chart using block characters
  - Score breakdown by dimension
  - Personalized tips for tomorrow
- `saveDailyReport(_:for:)` — writes `.md` to reports directory

### `EyesHealth/Services/EyeHealthScoreService.swift`
- `EyeHealthScore` value type: totalScore, 5 dimension scores, grade, summary
- `calculateScore(from:)` algorithm:
  - **Break Compliance** (40 pts): `breaksTaken / breaksDue * 40`
  - **Session Quality** (25 pts): avg session <20m=25, <30m=15, <45m=10, else 0
  - **Time Distribution** (15 pts): break coverage across active hours
  - **Total Exposure** (10 pts): <4h=10, <6h=8, <8h=5, >8h=2
  - **Night Penalty** (0 to -10): -2 per hour after 22:00
- Grade mapping: 90+=A+, 80+=A, 70+=B+, 60+=B, 50+=C, 40+=D, <40=F

## Modified Files

### `EyesHealth/Models/AppState.swift`
- Added daily tracking fields:
  - `totalScreenTimeToday`, `sessionsCount`, `longestSessionSeconds`
  - `currentSessionStart`, `hourlyScreenTime`, `breaksDue`, `breaksSkipped`
  - `currentEyeHealthScore`, `currentEyeHealthGrade`
  - `formattedTotalScreenTime` computed property
- Updated `recordBreak()` to track session duration and increment session count
- Updated `incrementContinuousUse(by:)` to also increment total screen time
  and hourly tracking
- Updated `resetDaily()` to reset all V5 fields
- Added `buildDailyUsageData()` to snapshot current state into `DailyUsageData`
- Added `computeSessionDurations()` private helper

### `EyesHealth/Services/MonitoringService.swift`
- Injected `DataPersistenceService` and `EyeHealthScoreService` via init
- Added `autoSaveTimer` — saves data every 5 minutes
- Added `restoreTodayData()` — restores state on app launch from JSON
- Added `updateEyeHealthScore()` — recalculates score after each break
- Updated `pollIdleTime()` to increment `breaksDue` on notification trigger
- Updated `handleSnooze()` to increment `breaksSkipped`
- Added `generateAndSaveDailyReport()` and `generateTodayReport()`
- Exposed `todayReportURL` and `reportsDirectoryURL` for menu actions
- Updated `handleScreenLock()` to save data before lock

### `EyesHealth/Views/MenuBarView.swift`
- Added `onViewReport` and `onOpenReportsFolder` callback properties
- Added **Score Section** showing heart icon with color-coded score and grade
- Added "Today: Xh Ym" total screen time display
- Added "View Today's Report" button — generates markdown and opens in default app
- Added "Open Reports Folder" button — opens reports directory in Finder

### `EyesHealth/App/EyesHealthApp.swift`
- Added `import AppKit` for `NSWorkspace`
- Wired `DataPersistenceService` and `EyeHealthScoreService` into `MonitoringService`
- Added `applicationWillTerminate(_:)` to save data and generate report on quit
- Updated midnight reset to generate yesterday's report before resetting
- Passed `onViewReport` and `onOpenReportsFolder` closures to `MenuBarView`

### `EyesHealth/Utils/Constants.swift`
- Added `autoSaveInterval: TimeInterval = 5 * 60`

## Data Storage

- **Data files**: `~/Library/Application Support/EyesHealth/data/2026-04-15.json`
- **Reports**: `~/Library/Application Support/EyesHealth/reports/2026-04-15-eye-health-report.md`
- Auto-save every 5 minutes
- State restored on app launch
- Report generated at midnight and on app quit

## Git Commits
1. `955c6fc feat: add data persistence and DailyUsageData model`
2. `47fa5cc feat: implement eye health score algorithm`
3. `d3b35a4 feat: generate daily markdown reports and show score in menu`

## Build Status
- `swift build`: **PASS**
- `.app` bundle: **PASS**
- Data directory created: **PASS** (`~/Library/Application Support/EyesHealth/`)
- JSON data saved: **PASS** (`data/2026-04-15.json`)

## Architecture
```
AppDelegate
  ├── AppState (+ V5 daily tracking fields)
  ├── MonitoringService
  │     ├── DataPersistenceService (JSON read/write + report generation)
  │     └── EyeHealthScoreService (0-100 score calculation)
  ├── NotificationService
  ├── BreakWindowService
  └── MascotWindowService

Data Flow:
  poll tick → incrementContinuousUse → hourlyScreenTime + totalScreenTime
  shouldNotify → breaksDue++
  recordBreak → session tracking, score recalc
  autoSave (5m) → DataPersistenceService.saveDailyData
  midnight/quit → generateAndSaveDailyReport → .md file
  app launch → restoreTodayData from JSON
```
