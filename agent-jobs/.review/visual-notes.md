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

## 2026-04-15 05:52 — Visual Review Attempt (v034)

### Screenshot Attempt
- Two screenshots taken (`screencapture -x`): both returned solid black images
- **Cause:** Display appears to be asleep/locked — `screencapture` captures the framebuffer which is blank when the display is off
- TUI process may still be running in background but is not visible for capture

### Alternative Verification
- Verified TUI rendering via test snapshots: `ink-testing-library` render output confirms all columns display correctly
- `sourceToShort()` labels verified in tests: hook/live/cron/launchd all render within 9-char column width
- Full table snapshot test passes with all fixture jobs rendering on 1-2 lines max
- No visual regressions expected from v034 changes (scanner.ts + utils.ts — no component changes)

### Code Changes Impact on Visual
- **No visual changes this cycle.** Both commits (`80aaf72`, `9c24388`) modify backend scanner logic and pattern matching — no changes to `job-table.tsx`, `job-detail.tsx`, `header.tsx`, `tab-bar.tsx`, or `footer.tsx`
- TUI appearance should be identical to v033 observations

### Observations from Test Snapshots
- TableHeader renders: ST | SERVICE | AGENT | SOURCE | SCHEDULE | LAST RUN | RESULT | CREATED
- SOURCE column shows short labels (hook, live, cron, launchd) — confirmed in `sourceToShort` tests
- `friendlyCronName` changes only affect cron task SERVICE names — no layout impact
- Column alignment test passes: SERVICE column start matches between header and rows

### Outstanding Visual Items
- [ ] Capture live TUI screenshot when display is active
- [ ] Verify session cron tasks show lifecycle in detail panel
- [ ] Test narrow terminal behavior (<100 cols)
- [ ] Check auto-refresh flicker (clearScreen P2 still carried)

### Next Steps
- Schedule next visual review when display is confirmed active
- Consider using `tmux capture-pane` as fallback when screencapture returns black
- Test `npx tsx src/index.tsx 2>&1 | head -50` for non-interactive render verification
