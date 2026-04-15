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

## 2026-04-15 07:58 — Active Display Screenshot (v035)

### Screenshot Analysis
- **Display is active** — full 6016x3384 retina screenshot captured (4.4MB)
- VS Code workspace visible with multiple terminal panels
- Left sidebar: agent-jobs project file tree visible
- Multiple Claude Code sessions running in integrated terminals
- Claude Session Monitor TUI visible in bottom-right panel

### Workspace Layout
- 4+ terminal panels visible in VS Code integrated terminal
- Build/test output visible in some panels
- The agent-jobs TUI itself is not the focused/visible TUI — the Claude Session Monitor occupies the bottom-right panel
- Session data shows active/stopped indicators with tabular layout

### User-Reported Issue
- **Dashboard flickers every ~10 seconds** — user confirmed this is still happening
- This corresponds to the `clearScreen()` call in the auto-refresh cycle (P2 #5, carried since v031)
- Root cause: `clearScreen()` clears the entire terminal, Ink re-renders, causing visible flash
- The `clearScreen` workaround was added in v031 to fix Ink's `log-update` stacking bug, but introduced flicker

### Flicker Fix Analysis
- Current approach: `clearScreen()` → Ink re-renders from scratch every 10s
- Better approach: Only clear when the number of rendered lines changes (height-sensitive clear)
- Best approach: Use Ink's built-in `rerender()` without `clearScreen()` — investigate if `log-update` stacking is actually fixed in current Ink 5.x
- Alternative: Use `stdout.write(ansiEscapes.clearScreen)` with `ansiEscapes.cursorTo(0,0)` to avoid visible flash

### Outstanding Visual Items
- [x] Capture live TUI screenshot when display is active — DONE
- [ ] Verify session cron tasks show lifecycle in detail panel
- [ ] Test narrow terminal behavior (<100 cols)
- [ ] **FIX: Auto-refresh flicker (clearScreen P2 — user reported)** — PRIORITY
- [ ] Isolate agent-jobs TUI in its own terminal panel for better visual review

## 2026-04-15 08:34 — Visual Review (v036)

### Screenshot Analysis
- **Display active** — 3.4MB screenshot captured
- VS Code workspace is focused on a different project ("RAVEN") — an "Agent Team Full" planning document is open in the main editor
- Right panel shows a Chat/Copilot interface searching for OpenAI Codex documentation
- macOS dock visible at bottom with multiple app icons
- No terminal panels visible — the integrated terminal appears to be collapsed or hidden

### Agent-Jobs TUI Status
- TUI processes confirmed running (PIDs 68094, 68121, 94180) — the dashboard is alive in a background terminal
- The TUI is not visible in the current VS Code viewport — user has switched to a different workspace/project
- Cannot assess TUI rendering, column layout, or flicker fix effectiveness visually

### Changes Since Last Visual Review
- **Flicker fix applied** (`1e44603`): `clearScreen()` removed from auto-refresh callback
- **JobDetail coverage** (`ebfc01c`): 25 new tests covering all conditional branches — verified via test output that all fields render correctly
- **No component changes** — layout/rendering code unchanged since v033

### Verification via Tests (in lieu of visual)
- 334/334 tests pass
- Components coverage: 100% statements, 97.7% branches
- Full table snapshot test confirms layout stability
- JobDetail test confirms: Session, Lifecycle, Port, PID fields render conditionally
- `clearScreen()` only called on height-changing operations now (10 call sites in keyboard handlers)

### Outstanding Visual Items
- [x] Auto-refresh flicker fix applied — **needs visual confirmation when TUI is visible**
- [ ] Verify flicker fix effectiveness (watch dashboard for 30+ seconds)
- [ ] Verify session cron tasks show lifecycle in detail panel (confirmed via tests)
- [ ] Test narrow terminal behavior (<100 cols)
- [ ] Isolate agent-jobs TUI in dedicated terminal for better capture

### Feature Observations from Workspace
- User is working on a multi-agent team planning document ("Agent Team Full")
- Multiple projects active simultaneously — the dashboard would benefit from a **project filter** to show jobs grouped by project
- The Copilot chat panel suggests interest in AI agent tooling — agent-jobs could integrate with more AI assistant platforms beyond Claude Code
