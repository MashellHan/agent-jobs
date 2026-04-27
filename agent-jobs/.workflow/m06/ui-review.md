# M06 UI Review (ui-critic)

**Captured:** 2026-04-27T06:46:20Z (per sidecar `capturedAt`)
**App commit:** 4998988 (per sidecar)
**Scenarios reviewed:** 10 PNG + 10 JSON, baseline + critique sets are byte-identical (confirmed by tester).
**Mode:** ENFORCING (M06 is the first milestone where visual P0 can REJECT to IMPLEMENTING per PROTOCOL.md §8 and DESIGN.md).
**Rubric threshold (per acceptance.md AC-D-*):** Total ≥ 24/30 to PASS. AC-D-07 lists "white-bleed / half-rendered dark frame" as a rubric REJECT trigger independent of total score.

---

## Score: 20/30 → REJECT

| Axis | Score | One-line finding |
|---|---|---|
| Clarity | 4/5 | Popover (01/02/10) is exemplary; dashboard 04 truncates Name + "Last R..." at 1280pt. |
| Density & Hierarchy | 4/5 | Popover grouped sections + count chips + total-memory chip read at a glance; dashboard list pane gets the ~700pt bulk it deserves. |
| Identity | 3/5 | Popover feels like a 2026 Mac app and inspector pane (07) is Linear-tier; dark dashboards (05/08) show light-mode sidebar and white header bands — does not feel native. |
| Affordance | 4/5 | Retry button on failed row (10) reads as recoverable; inspector Stop/Hide + tabs are obvious; group headers read as labels not buttons. |
| Empty/Error | 2/5 | Dashboard empty (06) and "Select a service" copy are warm; empty popover (03) regresses vs. M05 — single "No services discovered yet." line, no group-header scaffolding, no per-section microcopy. |
| Novelty / Polish | 3/5 | Popover would screenshot well; dark dashboard 08 is half-rendered (only "Scheduled" pill + "Overview" tab pill on a partially-light frame) — embarrassing to ship. |

**Rubric REJECT trigger fired:** AC-D-07 ("half-rendered or white-bleed dark frame (M05 P0 condition recurs)") — scenarios 05 and 08 reproduce the M05 P0 condition in a different surface region.

---

## Per-scenario notes

### 01-menubar-popover-light.png — clean
- RUNNING(2) / SCHEDULED(2) / OTHER(1) sections with count chips; rows show pill + friendly title + monospace summary + CPU%/RSS in semantic green/amber. "289 MB" total chip in header. "updated 0s ago" + refresh affordance.
- Comparison: matches Things 3 grouped list density + Stats colored-dot taxonomy. Comfortable at 480pt — no truncation.
- Severity: none.

### 02-menubar-popover-dark.png — clean
- Full-frame dark, hierarchy preserved, semantic colors hold. Status pills slightly muted but readable.
- Comparison: parity with Bartender's dark popover.
- Severity: none.

### 03-menubar-popover-empty-light.png — P1 design regression
- Renders only the EmptyHintView ("No services discovered yet.") at 480×360. Header chips show "0 running"/"0 scheduled"/"Zero KB" (T-008 dimming behavior is not visible in static capture but functionally tested). **No RUNNING / SCHEDULED / FAILED group-header scaffolding.** Tester flagged this; reviewer flagged it; ui-critic confirms on rendered surface.
- Comparison: M05's 03 had two sections with per-section microcopy ("No services running right now." / "Nothing scheduled in the next hour.") — strictly better. Things 3 empty inbox keeps section structure. Activity Monitor's no-empty-state is the anti-pattern, but we're closer to it now than we were in M05.
- Severity: P1 (does not REJECT alone, but contributes to Empty/Error 2/5).

### 04-dashboard-populated-light.png — major win + P2 polish
- T-014 substantively fixed: 5 rows render with friendly titles + status pills + schedule + Created + CPU/Memory + Last Run. Bucket strip is horizontal (T-015 fixed): registered 1 / claude-sched 1 / claude-loop 1 / launchd 1 / live-proc 1 / total 5.
- Polish: Name column truncates at the list width ("daily-cle...", "claude-t...", "claude-l...", "npm run...") — at 1280pt with sidebar 220 + inspector 360 + 5 columns the Name column gets ~80pt. The trailing "Last R..." column header is also clipped. Bucket strip header bar starts at the list pane left edge — sidebar pane shows a separate "Filters" header that does not visually align with the strip; the strip looks orphaned above only the list.
- Comparison: Activity Monitor's Process column is the widest by default; ours is the narrowest. We've over-prioritized other columns.
- Severity: P2 polish (Name column width). The bucket-strip-not-spanning-sidebar is a discoverable visual-rhythm bug — P2.

### 05-dashboard-populated-dark.png — P0 (AC-D-07 REJECT trigger)
- The middle-list body is dark and rows render correctly. **But:** sidebar pane is light grey (not dark), the top ~25pt band above the table (where the bucket strip would render) is fully white, and the right inspector pane is empty (no "Select a service" placeholder rendered, just blank). Tester's 4-corner luma sample landed in dark pixels and missed this — the bleed regions are the sidebar interior and the top header band, not the corners.
- This is the M05 P0 condition recurring in a different surface region. AC-D-07 explicitly names this as a rubric REJECT trigger.
- Comparison: Linear, Things 3, every Mac app of merit produces a fully-themed dark frame including chrome bars and sidebars.
- Severity: **P0**.

### 06-dashboard-empty-light.png — clean (small polish)
- Empty list state is good: tray icon + "No services discovered yet" + "Providers will populate this view as they discover work." Right pane echoes "Select a service". Bucket strip horizontal with all 0 counts. Sidebar with all "0" right-aligned counts.
- The strip header bar still doesn't span the sidebar — same alignment quibble as 04.
- Severity: none.

### 07-dashboard-inspector-light.png — exemplary
- Inspector right pane is genuinely well-designed: friendly title "daily-cleanup", monospace subtitle "daily at 9am", origin breadcrumb "Agent Jobs (local) · acme", command "agentjobs run cleanup", status pill "Scheduled" top-right, action row "Stop / Hide", tabs "Overview / Logs / Config / Metrics" with active-tab pill, then a 4×2 metadata grid (Schedule, Project, Last Run, Next Run, Created, Origin, Session, Source Path).
- Selected row has discoverable inline icons (x to deselect / eye to hide). Linear-tier execution.
- Severity: none.

### 08-dashboard-inspector-dark.png — P0 (AC-D-07 REJECT trigger, severe)
- The most broken PNG in the M06 set. Same pattern as M05's 08: sidebar light, top header band white, inspector pane shows ONLY the "Scheduled" status pill and the "Overview" active tab pill — the friendly title, breadcrumb, command, Stop/Hide actions, AND the entire 8-cell metadata grid are missing. This is approximately the same defect ui-critic filed in M05; tester's harness fix (T-014) addressed the list body and dashboard chrome but did not fully reach the inspector dark path.
- Comparison: would be embarrassing to ship as v1.0. The reason this milestone exists is to make the M06+ ui-critic gate honest; if dark inspector still half-renders, the gate inherits the same blind spot.
- Severity: **P0**.

### 09-dashboard-narrow-light.png — clean
- 1024×700: list keeps rendering all 5 rows, inspector collapses to "Select a service" placeholder at ~360pt. NavigationSplitView responsive collapse behaves. Sidebar still shows full filter list. Bucket strip horizontal, "live..." truncates at the right edge with "total 5" still visible — acceptable.
- Severity: none.

### 10-menubar-popover-with-failure-light.png — exemplary
- Adds FAILED(1) section with red pill, "daily-cleanup" row showing red FAILED chip + Retry icon (arrow.clockwise) in the trailing slot. "1 failed" chip joins "2 running" / "1 scheduled" in the header row. SCHEDULED(1) and OTHER(1) groups still render below.
- Comparison: matches Stats / iStat Menus failed-state pattern with inline retry. T-016 delivered.
- Severity: none.

---

## Why this is REJECT, not PASS-with-tickets

Two independent reasons:

1. **Rubric REJECT trigger fires.** AC-D-07 literally says "Rubric REJECT trigger: half-rendered or white-bleed dark frame (M05 P0 condition recurs)." Scenarios 05 and 08 both meet this condition. The trigger is independent of the 24/30 threshold by design — the spec author (PM) knew that white-bleed is the kind of visual defect that can hide in a 24/30 score but still ship a broken UI.

2. **Total 20/30 ≤ 20/30 REJECT band** per the agent rubric in `.claude/agents/ui-critic.md`. Empty/Error 2/5 (popover regression) and Identity 3/5 (dark-frame bleed) drag the total under the line.

The popover side of M06 is genuinely strong — possibly the best the product has looked. But this is a 6-axis rubric and the dark-dashboard half-render isn't a polish ticket; it's the same defect that motivated T-014 to be the gating task in the first place. Letting it ship would mean the M06+ enforcing gate inherits a blind spot to the inspector dark path forever — which is exactly what the milestone existed to prevent.

The fix is scoped — the inspector dark surface and the dashboard chrome (sidebar + top band) need to inherit `preferredColorScheme(.dark)` (or the equivalent NSHostingView config) consistently. Cycle 2 implementing should be tractable.

---

## Tickets filed (this review)

- **T-017  P0  visual-harness  Dark dashboard chrome + inspector header bleed light** (NEW)
- **T-018  P1  empty-popover  Empty popover regressed vs. M05 — restore group-header scaffolding** (NEW)
- **T-019  P2  dashboard-list  Name column too narrow at 1280pt default; "Last Run" header clipped** (NEW)
- **T-020  P2  dashboard-chrome  Bucket-strip header bar does not span sidebar pane** (NEW)

(See `.workflow/DESIGN-TICKETS.md` for full entries.)

T-014, T-015 partially closed by M06 cycle 1 — light-mode dashboard rows + horizontal strip both work. T-014 NOT fully closed because dark inspector remains half-rendered — escalates into T-017.

---

## Verdict: REJECT

Per PROTOCOL.md §8 (M06+ ENFORCING) and acceptance.md AC-D-07: phase → IMPLEMENTING, cycle → 2, last_actor → ui-critic. Implementer cycle 2 should focus on T-017 (P0); T-018/T-019/T-020 may be opportunistically addressed but are not required to lift the REJECT.

**Total: 20/30. P0 rubric trigger: AC-D-07 (white-bleed dark frame, half-rendered inspector — M05 P0 condition recurs).**
