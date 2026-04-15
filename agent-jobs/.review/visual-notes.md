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

## 2026-04-15 08:59 — Visual Review (v037)

### Screenshot Analysis
- **Display active** — 7.7MB screenshot captured (retina)
- Foreground app: **Microsoft Teams** — user is in a video meeting
- Screen share shows a **monitoring/observability dashboard** (Grafana-style) with:
  - Left nav: Metrics Dashboard, Security Dashboard, Codeway Dashboard, Monitor Monitoring, Log Search, Documentation
  - Main content: "Failure by Type" time-series charts (stacked area graphs)
  - Multiple metric panels with traffic/error rate data
- Right side: Teams meeting participants with video feeds
- Bottom: Meeting chat with active conversation about Kanban dashboard UX

### Agent-Jobs TUI Status
- TUI is running in background (processes still active)
- Not visible — user is in a full-screen Teams meeting, no terminal visible
- Cannot assess TUI rendering visually this cycle

### Observations from Meeting Context
- The monitoring dashboard on screen shares design patterns relevant to agent-jobs:
  - **Stacked area charts** for failure rates — could inspire a "job health over time" mini-chart
  - **Left sidebar navigation** with collapsible sections — current agent-jobs tab bar is simpler but similar concept
  - **Filter bar at top** with time range, environment, service selectors — agent-jobs could benefit from similar filter controls
  - **"Failure by Type" categorization** — agent-jobs already categorizes by source, could add failure type breakdown
- Meeting discussion about "Kanban dashboard" UX — relates to project grouping brainstorm from v037

### Verification via Tests (in lieu of visual)
- 334/334 tests pass (confirmed this cycle)
- No code changes since v036 — visual state unchanged
- Flicker fix still awaiting visual confirmation (3 consecutive reviews without TUI in viewport)

### Outstanding Visual Items
- [ ] **Verify flicker fix** — now 3 reviews without visual confirmation (v035, v036, v037)
- [ ] Verify session cron tasks show lifecycle in detail panel
- [ ] Test narrow terminal behavior (<100 cols)
- [ ] Isolate agent-jobs TUI in dedicated terminal for better capture
- [ ] Consider `tmux capture-pane -p` as text-based TUI verification fallback

## 2026-04-15 09:28 — Visual Review (v038)

### Screenshot Attempt
- **Display asleep/locked** — 367KB black screen (same as v034 pattern)
- 4 TUI processes running in background (PIDs 68094, 68121, 79094, 94180)
- No tmux sessions available for text-based capture

### Snapshot-Based Visual Verification (NEW APPROACH)
Since screencapture has failed 4 out of 7 attempts (display sleep), switched to analyzing Vitest snapshot output as definitive visual verification. The snapshot captures exactly what Ink renders to the terminal.

**Table Layout (from `job-table.test.tsx.snap`):**
```
   ST SERVICE                AGENT        SOURCE     SCHEDULE       LAST RUN     RESULT  CREATED
────────────────────────────────────────────────────────────────────────────────────────────────────
▶  ●  my-web-server          claude-code  hook       always-on      04-10 18:00  success 7h ago
   ●  node server.js         claude-code  hook       always-on      04-10 19:00  success 6h ago
   ●  pm2 api.js             claude-code  hook       always-on      04-10 20:00  success 5h ago
   ○  my-very-long-contain…  claude-code  hook       always-on      04-10 21:00  error   4h ago
   ●  server.js :4000        manual       live       always-on      04-10 22:00  success 8h ago
   ✗  flask-server           claude-code  hook       always-on      04-10 16:30  error   9h ago
   ●  pew sync               claude-code  hook       always-on      04-11 09:00  success just now
   ●  backup script          claude-code  cron       daily 2am      04-11 10:00  success 1d ago
   ●  openclaw-monitor       openclaw     hook       every 30 min   04-11 00:30  success 11h ago
   ○  pending-task           claude-code  hook       weekdays 9am   -            unknown 2h ago
   ●  pew sync               manual       launchd    every 10 min   04-11 00:50  success 9d ago
   ●  pew update             manual       launchd    daily 9am      04-11 17:00  success 9d ago
   ●  node gateway           openclaw     launchd    always-on      04-11 01:00  success 8d ago
```

### Snapshot Visual Analysis
✅ **Column alignment**: All 8 columns (ST, SERVICE, AGENT, SOURCE, SCHEDULE, LAST RUN, RESULT, CREATED) perfectly aligned
✅ **Status icons**: ● (active/green), ○ (stopped/gray), ✗ (error/red) — correct per status
✅ **SOURCE labels**: hook, live, cron, launchd — all showing short labels (sourceToShort working)
✅ **SCHEDULE display**: always-on, daily 2am, every 30 min, every 10 min, weekdays 9am — all human-readable
✅ **LAST RUN format**: MM-DD HH:MM compact format, dash for never-run jobs
✅ **CREATED column**: Relative time (Xh ago, Xd ago, just now)
✅ **Name truncation**: "my-very-long-contain…" truncated with ellipsis
✅ **Selection indicator**: ▶ on first row (selected, not expanded)
✅ **Multi-source data**: registered (hook), live, cron, launchd all present in one table
✅ **AGENT diversity**: claude-code, manual, openclaw — three agent types visible

**Detail Panel (expanded view):**
```
▼  ●  my-web-server  [expanded]
   ╭─────────────────────────────────────────╮
   │  Command:       node src/server.js ...  │
   │  Status:        active                  │
   │  Agent:         claude-code             │
   │  Source:        Hook-registered          │  ← sourceToHuman (verbose)
   │  Project:       /Users/dev/my-project   │
   │  Port:          3000                    │
   │  ── Schedule ──                         │
   │  Frequency:     always-on               │
   │  ── History ──                          │
   │  Created:       2026-04-10 18:00 (7h)   │
   │  Last Run:      2026-04-10 18:00 (7h)   │
   │  Run Count:     5                       │
   │  Last Result:   success                 │
   │    ... and 4 earlier runs               │
   │  ESC or d to close                      │
   ╰─────────────────────────────────────────╯
```

✅ **Rounded border**: ╭╮╰╯ box drawing characters
✅ **Labeled fields**: Command, Status, Agent, Source, Project, Port — all present
✅ **Source label**: "Hook-registered" (sourceToHuman, verbose for detail panel)
✅ **Run history**: "... and 4 earlier runs" with singular/plural handling
✅ **Close instruction**: "ESC or d to close" at bottom

### Issues Identified from Snapshot
- **None.** The layout is clean, well-aligned, and all data sources are represented.
- The only missing elements from the snapshot are sessionId/lifecycle fields — those fixtures don't have those fields set. Verified by separate JobDetail tests (24/24 pass) that Session and Lifecycle fields render correctly when present.

### Visual Review Reliability Summary
| Review | Method | Result |
|--------|--------|--------|
| v033 00:05 | screencapture | ✅ TUI visible |
| v033 00:10 | screencapture | ✅ TUI visible (post-fix) |
| v034 05:52 | screencapture | ❌ Black screen |
| v035 07:58 | screencapture | ⚠️ Different TUI visible |
| v036 08:34 | screencapture | ⚠️ VS Code, TUI not focused |
| v037 08:59 | screencapture | ⚠️ Teams meeting |
| v038 09:28 | **snapshot analysis** | ✅ **Complete layout verified** |

**Conclusion:** Snapshot-based verification is more reliable than screencapture for this project. It captures the exact Ink render output independent of display state. Recommend using this as the primary visual verification method going forward, with screencapture as supplementary when the display is active.

### Outstanding Visual Items
- [x] Column alignment verified via snapshot ✅
- [x] Source labels verified (hook/live/cron/launchd) ✅
- [x] Multi-source data in one table verified ✅
- [x] Detail panel layout verified ✅
- [x] Session/lifecycle fields verified via JobDetail tests ✅
- [ ] **Verify flicker fix live** — still not observed in real terminal (4 reviews)
- [ ] Test narrow terminal behavior (<100 cols)

## 2026-04-15 10:25 — Visual Review (v040)

### Screenshot
- **macOS lock screen** — 25.5MB retina capture of Lake Tahoe wallpaper with clock "Wed Apr 15 10:25"
- Machine is locked, no application windows accessible
- TUI processes still running in background

### Updated Reliability Summary
| # | Time | Display | Method | TUI Visible |
|---|------|---------|--------|-------------|
| 1 | 00:05 | Active | screencapture | ✅ Yes |
| 2 | 00:10 | Active | screencapture | ✅ Yes |
| 3 | 05:52 | Sleep | screencapture | ❌ Black |
| 4 | 07:58 | Active | screencapture | ⚠️ Other app |
| 5 | 08:34 | Active | screencapture | ⚠️ VS Code |
| 6 | 08:59 | Active | screencapture | ⚠️ Teams |
| 7 | 09:28 | Sleep | snapshot | ✅ Verified |
| 8 | 10:25 | Locked | screencapture | ❌ Lock screen |

**Screencapture TUI hit rate: 2/7 (29%).** Snapshot analysis remains the reliable method.
