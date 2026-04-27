# M06 Competitive Analysis — Information Architecture

**Scope:** dashboard 3-pane sizing + column choices, popover anatomy (grouping, density), list density. Three peers studied. ~1 page.

## 1. Activity Monitor (macOS 14) — 3-pane sizing + columns

**What:** Apple's built-in process viewer. Single-window app, no menu bar surface.

**Sizing.** Default window opens at ~1100 × 700; the **single table** dominates the frame. There is no left sidebar in the default mode; the toolbar's segmented control (CPU / Memory / Energy / Disk / Network) replaces a sidebar. When "Inspector" opens (double-click row), it appears as a **separate floating window**, not a third pane.

**Columns.** Process Name | % CPU | CPU Time | Threads | Idle Wake-Ups | Kind | % GPU | GPU Time | PID | User. Default visible: Process Name, % CPU, CPU Time, Threads, Idle Wake-Ups, %GPU, PID, User. Headers are sortable; right-click column header reveals add/remove menu.

**Density.** Comfortable single-line rows. Process Name is the widest, semi-bold; numerics are right-aligned, mono-spaced.

**What we steal:**
- Process Name as widest column, semi-bold; matches our friendly-title precedence.
- Numerics right-aligned + mono (CPU%, RSS) — already partly in M05; reinforce in M06.
- Default window large enough that the primary table never feels pinned (their ~1100, ours ≥1280).

**What we don't steal:**
- Inspector as floating window — we keep our 3-pane NavigationSplitView (richer per-service detail, tabs Overview/Logs/Config/Metrics).
- Segmented top toolbar instead of left sidebar — our SourceBucketStrip + sidebar source-filter is closer to a Mail/Things model.

## 2. Things 3 — popover anatomy (grouping, density)

**What:** Cultured Code's task manager. Famous for menu-bar Quick Entry popover and grouped list density.

**Popover.** Quick Entry popover is ~540pt wide. Bigger surface = "Today" sheet view, also a popover-style window, ~480-560pt wide. Typical popover height 480-700pt before scrolling.

**Grouping.** Lists group by status/section with **uppercase grey section headers** ("Today", "This Evening", "Upcoming"). Each section is collapsible; section header carries a count chip when collapsed.

**Row density.** Comfortable rows ~36-44pt tall: checkbox/icon, title (regular weight), one-line subtitle (lighter grey, smaller, sometimes a project tag pill), trailing chip (date, tag, or recurrence icon). Hover reveals trailing actions (drag handle, info button).

**What we steal:**
- ≥480pt popover width as a comfortable lower bound — directly informs our T-002 ≥480pt decision.
- Group-by-status with uppercase section headers + count chip — directly informs our T-002 grouping requirement.
- Title (primary) + 1-line subtitle (secondary) + trailing slot (status / action) — exact pattern we want.
- Hover-reveal Retry on failed rows (T-016) is a Things-style trailing action.

**What we don't steal:**
- Checkbox affordance (Things is task-completion oriented; our rows aren't user-completable).
- Soft pastel project tag pills (defer to M07 color tokens).

## 3. Linear — list density

**What:** Issue tracker. Reference for high-information-density lists in modern Mac/Web app design.

**List density.** Compact rows ~28-32pt tall, single-line, status icon + ID + title (truncating) + assignee avatar + label chips + due date + priority icon. No section headers in default backlog view; uses **virtualized infinite list** with a sticky filter bar.

**Hierarchy.** Title weight is regular (not bold). Status icon (8pt circle, semantic color) carries the categorical visual weight; ID is monospace grey; title fills the remaining width.

**Right-pane inspector.** Selecting an issue opens a **right-side panel** ~400-480pt wide, with tabs and a multi-section detail (description, sub-issues, comments, activity). Same pattern we already use in M05's `ServiceInspector`.

**What we steal:**
- 8pt semantic status dot as the left-most categorical anchor — already in our M05 design, keep.
- Title fills horizontal width with truncation rather than wrapping to two lines — matches our 1-line summary discipline.
- Right-pane inspector at ~360-400pt — informs our 360pt inspector default in T-003.

**What we don't steal:**
- 28pt compact row density — too tight for our context (we want comfortable, not compact, since each row is a service the user must understand quickly). Keep ~40pt rows.
- No section headers — we explicitly want grouping (Things 3 wins this argument for our use case because failure/running/scheduled is a meaningful taxonomy).

## Synthesis — M06 IA decisions justified

| Decision | Source | Rationale |
|---|---|---|
| Popover ≥ 480pt | Things 3 (540), Linear inspector (400-480) | Comfortable read width; sub-480 forces truncation. |
| Popover rows grouped by status with uppercase section headers | Things 3 | Status taxonomy is the dominant mental model for our user. |
| Title regular, summary lighter, trailing slot | Things 3 + Linear | Two-line max, hierarchy via weight + color, not size. |
| Dashboard ≥ 1280×800 default | Activity Monitor (1100), our richer 3-pane | Smaller defaults pin the middle list; we have an inspector AM doesn't. |
| Sidebar 220 / inspector 360 / list = rest | Linear inspector ~400, Mail sidebar ~200 | Middle list earns the bulk of horizontal space. |
| Inspector tabs Overview / Logs / Config / Metrics | Linear right pane | Already in M05; M06 doesn't change this. |
| 0-count chip dimmed + tooltip | Stats menu app (peer cited in T-008) | Disambiguates "broken" vs "no data". |
| Retry on failed row | Stats / iStat Menus | Inline recovery, no full-window trip. |

## Anti-patterns avoided

- **Activity Monitor's no-empty-state**: blank table with no copy. We keep our M05 empty states.
- **Linear's no-grouping**: works because Linear users live in the app; our user opens the popover for 3 seconds.
- **Cramped popovers (M05's 360pt)**: ours grew to ≥480 explicitly to avoid this trap.
- **Floating inspector windows (Activity Monitor)**: breaks the single-window mental model we've established.
