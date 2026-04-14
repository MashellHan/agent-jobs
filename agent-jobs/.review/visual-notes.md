# Agent Jobs — Visual Review Notes

## 2026-04-15 00:05 — Initial Visual Baseline

### Screenshot Analysis
- TUI is running in a terminal panel (iTerm2 / VS Code integrated terminal)
- Dashboard header shows: "Agent Job Dashboard" with refresh timestamp
- Tab bar visible: ALL / Registered / Live / Active / Error with counts
- Job table visible with multiple rows
- Detail panel appears to be expanded for a selected job
- Footer shortcuts visible at bottom

### Observations
- The TUI renders correctly without stacking issues (clearScreen fix working)
- Multiple cron tasks from session JSONL scanner are now visible
- Column widths appear appropriate for the terminal width
- Tab counts are updating correctly

### Issues Noticed
- [ ] Need to verify session cron tasks show lifecycle (session-only/durable) in detail panel
- [ ] Need to verify sessionId is displayed in detail panel
- [ ] Terminal width seems adequate but should test narrow terminal behavior

### Next Steps
- Take another screenshot in 30 minutes to compare
- Check if auto-refresh (10s) causes visible flicker
- Test detail panel expansion with new cron fields
- Consider adding a "Sessions" tab filter for cron-session tasks

## 2026-04-15 00:10 — Post Source Column Fix

### Changes Applied
- [x] Fixed SOURCE column: now shows short labels (hook/live/cron/launchd) instead of raw codes
- [x] Added `sourceToShort()` for compact table display, keeping `sourceToHuman()` for detail panel
- [x] Snapshots and tests updated — 309 tests passing

### Screenshot Observations
- TUI hot-reloaded successfully (tsx --watch detected file changes)
- SOURCE column now displays readable labels
- Other columns unchanged and stable
- No visual stacking or flicker issues observed

### Feature Ideas from Visual Review
- [ ] Add lifecycle indicator in table (e.g. "⏱" for session-only, "💾" for durable) 
- [ ] Consider showing session ID in a new column for cron tab
- [ ] Add "Cron" tab filter to show only cron tasks
- [ ] Next-run calculation for cron schedule display
