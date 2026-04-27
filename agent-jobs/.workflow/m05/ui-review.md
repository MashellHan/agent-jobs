# M05 UI Review (ui-critic)

**Captured:** 2026-04-24T18:35:00Z (re-captured fresh via `swift run capture-all` — 1.72s, 10/10 scenarios)
**App commit:** 69cd464 (per sidecar metadata)
**Scenarios reviewed:** 10 PNG + 10 JSON
**Mode:** advisory (M05 per PROTOCOL.md §8 — gate enforces from M06)

## Score: 22/30 → PASS-with-tickets

| Axis | Score | One-line finding |
|---|---|---|
| Clarity | 4/5 | Popover rows are now genuinely readable ("npm run dev", "claude-loop session-abc", CPU%/RSS) — huge win vs. M04. Dashboard list area renders empty header-only, hurting clarity. |
| Density & Hierarchy | 3/5 | Popover hierarchy is excellent (grouped sections, count chips, total memory). Dashboard wastes ~70% of horizontal width: middle list pinned to ~270pt while right pane is mostly empty. |
| Identity | 4/5 | Popover feels native macOS 14 (rounded chips, SF symbols, monochrome chrome, dark-mode parity). Dashboard source-bucket strip renders vertically-stacked text ("to/ta/l/5") — that one element looks broken. |
| Affordance | 4/5 | Inspector header has discoverable Stop / Hide / tabs (Overview / Logs / Config / Metrics) at parity with Linear's right-pane pattern. Popover Open Dashboard / Quit footer is clear. |
| Empty/Error | 4/5 | Empty popover (03) and empty dashboard (06) both have tray icon + 2-line guidance — better than Activity Monitor's blank table. Failure variant (10) adds a red "1 failed" chip + red status dot — readable delta. |
| Novelty / Polish | 3/5 | Popover would screenshot well next to Bartender/Stats. Dashboard polish lags: list body empty, strip layout broken in two scenes. |

## Per-scenario notes

### 01-menubar-popover-light.png — P2 polish only
- Excellent. Friendly titles ("npm run dev", "claude-loop session-abc", "daily-cleanup"), source-colored dots (green/blue/grey), CPU% in green + RSS in amber for live processes, em-dash for non-process rows, "289 MB" total in header chip, "updated 0s ago" with refresh affordance. T-005 fully delivered visually.
- Comparison: Stats menu groups by category with colored dots; Things 3 uses similar grouped lists with secondary metadata. This sits comfortably between them.
- Severity: none — minor: "on demand · session sess-abc" subtitle on the claude-loop row repeats the title's session ID. Polish.

### 02-menubar-popover-dark.png — P2 polish only
- Dark scheme parity is clean: same hierarchy, semantic colors preserved, section headers legible. No regression vs. light.
- Comparison: matches Bartender's dark popover — soft dividers, no harsh borders.
- Severity: none.

### 03-menubar-popover-empty-light.png — P2 polish only
- Two-section empty state with tray icon and dedicated copy per section ("No services running right now." / "Nothing scheduled in the next hour."). Counts shown as dimmed "0 running" / "0 scheduled" — answers T-008's question prospectively.
- Comparison: Things 3 empty inbox pattern (tray + microcopy). Better than Activity Monitor (no empty state at all).
- Severity: none.

### 04-dashboard-populated-light.png — P0
- The middle list shows column headers ("Name | Status | Sched...") and the bucket strip on top, but the **list body is completely empty** at 1200×700 with the populated fixture. Right pane shows the global "Select a service" empty state (correct since no row is selected).
- The **source-bucket strip** renders chips as vertical stripes with letters stacked ("to / ta / l / 5"). The five icon chips collapse to the same vertical-stripe shape. This looks like an SF Symbols rendering or layout-axis issue specific to the harness `NSHostingView` path.
- Comparison: Activity Monitor table always renders rows; here the list body silently swallows the populated data. Even if this is a known harness/`Table`/NSHostingView quirk (per tester's note), it ships in the critique set the ui-critic agent will read for M06+ — the harness needs to render true content.
- Severity: P0 (blocks M06 ui-critic gate from being meaningful — see T-014, T-015).

### 05-dashboard-populated-dark.png — P0
- Dark dashboard renders almost nothing: bucket strip area is fully white (light-mode bleed?), middle list shows column headers but no rows, right pane is entirely empty (no "Select a service" placeholder either).
- Compared to 04 this is worse: the right-pane empty state should still appear in dark mode and doesn't. Background color split between white (top-left) and dark (rest) suggests view-hierarchy / preferredColorScheme threading bug in `DashboardView` snapshot path.
- Comparison: would never ship in a real Mac app — appears half-rendered. Linear, Things, every Mac app of merit produces a fully-themed dark frame.
- Severity: P0.

### 06-dashboard-empty-light.png — P1
- Empty list state is good: tray icon + "No services discovered yet" + "Providers will populate this view as they discover work." Right pane echoes "Select a service" placeholder.
- Bucket strip shows the same vertical-stripe layout bug as 04 (now reading "to / ta / l / 0").
- Comparison: empty messaging matches Things 3 quality; strip rendering is regressive against any peer.
- Severity: P1 (strip bug is the issue, empty content is fine).

### 07-dashboard-inspector-light.png — P2 polish only
- Inspector right pane is genuinely well-designed: header with friendly title "daily-cleanup", monospace subtitle "daily at 9am", origin breadcrumb "Agent Jobs (local) · acme", command "agentjobs run cleanup", status pill "Scheduled" top-right, action row "Stop / Hide", tabs "Overview / Logs / Config / Metrics" with active-tab pill, then a 2-column metadata grid (Schedule, Project, Last Run, Next Run, Created, Origin, Session, Source Path).
- Linear's right-pane / Things 3 inspector pattern executed well.
- Left side still has the truncated bucket strip + empty list rendering — same P0 as 04.
- Severity: none for inspector itself; the left pane defects roll up to T-014/T-015.

### 08-dashboard-inspector-dark.png — P0
- Dark inspector renders only the "Scheduled" status pill (top right) and the active "Overview" tab pill — the entire metadata grid, header title, and action row are missing. This is the most broken PNG in the set.
- Half white / half dark background again, same as 05.
- Comparison: would be embarrassing to ship as-is. Even if this is a SwiftUI snapshot dark-mode quirk, the agent reading this in M06 cannot score Identity / Density honestly.
- Severity: P0 (covered by T-014).

### 09-dashboard-narrow-light.png — P2
- 900×600 narrow view: middle list keeps column headers, body still empty (P0 already filed), inspector collapses to "Select a service" placeholder. NavigationSplitView appears to take the narrow signal correctly (right pane narrows rather than scrolling). Bucket strip still vertical-stripe bug.
- Comparison: NavigationSplitView's responsive collapse is fine; but again the harness is rendering empty rows.
- Severity: P2 once T-014/T-015 land.

### 10-menubar-popover-with-failure-light.png — P2 polish only
- Adds a red "1 failed" chip after "1 scheduled" and turns the daily-cleanup row's status dot red. Clear, instantly readable delta vs. 01. Total memory unchanged.
- Comparison: Stats and iStat Menus use the same chip-list pattern for warning state. This is exactly right.
- Polish nit: the failed row could lift a "Retry" link in the row trailing slot (currently still shows "—") to give the user a recovery path inline. Defer to T-002 / M06 popover redesign.
- Severity: none for now.

## Key positives (don't lose these)

1. **T-005 visually delivered**: friendly titles + 1-line summaries are alive in popover rows. This was the marquee fidelity goal.
2. **T-006 visually delivered**: CPU% (green) + RSS (amber) actually render numerics for live processes; em-dash kept correctly for non-PID services.
3. **Popover dark/light parity** is real (compare 01/02 — same hierarchy, semantic colors preserved).
4. **Empty states** in both popover and dashboard are warm and informative.
5. **Inspector design** (07) is on par with Linear's right-pane spec.

## Key concerns

1. **Dashboard `Table` body never renders rows in the harness output** (04, 05, 06, 07 left pane, 08 left pane, 09). Tester noted this as an "NSTableView offscreen quirk" and confirmed `dashboard-row` baselines pass in the unit suite. But the critique set is what the ui-critic gate reads from M06 — if the harness doesn't render rows, the gate is blind to dashboard quality. **NEW ticket T-014.**
2. **`SourceBucketStrip` chip layout collapsed in dashboard** (04, 06, 07, 09): each chip becomes a vertical stripe with the label rotated/stacked one-letter-per-line ("to / ta / l / 5"). The popover renders the same data correctly as horizontal pills ("2 running", "2 scheduled"). Suggests width-constrained layout in `DashboardView` axis. **NEW ticket T-015.**
3. **Dark dashboard half-rendered** (05, 08): white background on top-left strip area while body is dark; right pane shows only pills, not metadata. **Folds into T-014** (likely the same root cause).

## Tickets filed (this review)

- **T-014  P0  visual-harness  Dashboard `Table` rows + dark scheme not rendering in capture-all output** (NEW)
- **T-015  P1  source-bucket-strip  Strip chips collapse to vertical-stripe layout in DashboardView** (NEW)
- **T-016  P2  popover-row  "Retry" affordance on failed-status rows** (NEW, defer behind T-002)

(Existing tickets cross-referenced — no double-filing:
T-002 popover redesign / width — popover already much improved this milestone but ticket scope (≥480pt + status pill + grouping) still partially open; defer to M06 as-tagged.
T-003 dashboard default size — N/A this review (harness uses 1200×700 by spec).
T-008 0-count chip dimming — partially addressed in popover empty state (03); dashboard strip story still open.)

## Verdict: PASS-with-tickets

Total 22/30, 3 new tickets (1 P0, 1 P1, 1 P2). The popover side of M05 is a substantive content-fidelity win over M04 — friendly titles and live CPU/RSS finally make the product say what it actually is. The dashboard side reveals real harness rendering gaps that the M06 gate must not inherit.

Per PROTOCOL.md §8, M05 ui-critic is **advisory** — recording PASS-with-tickets and transitioning to ACCEPTED. The new P0 (T-014) targets M06 because the harness rendering must be solid before the gate enforces.
