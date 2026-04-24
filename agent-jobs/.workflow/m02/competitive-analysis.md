# Competitive Analysis — M02 (Functional UI baseline)

> Time-boxed scan. Goal: borrow proven dense-list + summary-header + detail-panel patterns from mature menu-bar / process-monitor apps. We do NOT need to re-derive UX from scratch.

## Products surveyed

| Product | URL | License | Relevance |
|---|---|---|---|
| Stats (exelban) | https://github.com/exelban/stats / https://mac-stats.com | MIT | Open-source menu-bar system monitor. Reference for menu-bar popover layout, summary chips, dark-mode polish. |
| SwiftBar | https://github.com/swiftbar/SwiftBar | MIT | Menu-bar plugin host. Reference for compact rows, sub-menu / inline-expand behaviour, keyboard-quit. |
| Activity Monitor (Apple) | https://support.apple.com/guide/activity-monitor/welcome/mac | proprietary | Canonical macOS process list + detail-panel UX. Tab-segmented categories, info ⓘ inspector, search-box. |
| Bartender 5 | https://www.macbartender.com | proprietary | Reference for per-row hover affordances + drag-reorder feel (we're not copying drag, just hover hints). |
| iStat Menus | https://bjango.com/mac/istatmenus/ | proprietary | Reference for the "summary header counts + dense-list under it" composition the user explicitly called out. |

## Patterns worth borrowing (3-5, concrete)

1. **Activity Monitor's "category tab" header** — a horizontal segmented header that doubles as both filter and count display. We already have a sidebar with per-category counts (DashboardView); we will add a top-of-list **summary strip** that shows ONE chip per data source (registered / live / claude-scheduled / claude-session / launchd) with count, so the user sees the 5-source story at a glance without expanding the sidebar. Source: Apple's Activity Monitor guide [1].

2. **Activity Monitor inspector pattern (info ⓘ → modal-ish panel with grouped sections)** — process detail surfaces Parent / User / Open Files / Statistics. We mirror this in the existing `ServiceInspector` (already in the right shape) but ensure the four required field groups render for every source: Identity (name/source/project), Schedule, Process (PID/CPU/Mem when live), Provenance (origin / createdAt / file path). We deliberately keep this as the **right pane of NavigationSplitView** (inline) — NOT a separate window — per the user's explicit ask. Source: Apple guide [1].

3. **Stats summary-strip chips** — Stats puts colored, icon+number chips across the top of its dropdown ("CPU 12% · RAM 8.4G · Net ↑↓"). Our menu-bar popover already does this (`SummaryChip`). Pattern: keep chips short (icon + count + 1 word), color-coded by status (green=running, blue=scheduled, red=failed). Carry this exact pattern into the Dashboard window header so the menu-bar and the main window feel like the same product. Source: exelban/stats README [2].

4. **SwiftBar dense rows + alt-key alternates** — SwiftBar's rows are 1-line, mono-spaced for command, with an "alt key reveals a second line" affordance. We adopt the dense single-line look (already in `ServiceRowCompact`) and add a hover-to-reveal secondary line (command tail or `nextRun`) — keeps the list scannable while not hiding info. Source: SwiftBar plugin API [3].

5. **NavigationSplitView 3-column layout (sidebar / table / inspector)** — the standard Apple HIG pattern (Mail, Notes, Finder column view). Already chosen in our scaffolding. Pattern reinforcement: sidebar = filter by source category, middle = sortable Table, right = inspector. We will NOT introduce a separate inspector window. Source: Apple HIG / NavigationSplitView docs.

## Anti-patterns observed (avoid)

- **Stats issues #3120 / #3107** show what happens when the menu-bar item silently disappears on macOS updates — we mitigate with a visual AC that asserts the menu-bar icon is visible after launch (XCUITest screenshot of the menu bar region).
- **SwiftBar's deeply-nested submenus** become unscannable past ~2 levels. We avoid sub-sub-menus; the Dashboard window is the place for depth.
- **Modal "process info" window in Activity Monitor** loses context. We keep the inspector inline (right pane) — already the user's explicit requirement.
- **Bartender-style hidden rows** that require hover to discover are confusing on first launch. Our rows render fully by default.

## Sources

- [1] Apple — Activity Monitor User Guide: https://support.apple.com/guide/activity-monitor/welcome/mac
- [2] exelban/stats: https://github.com/exelban/stats and https://mac-stats.com
- [3] SwiftBar: https://github.com/swiftbar/SwiftBar
- [4] Bartender 5: https://www.macbartender.com
- [5] iStat Menus: https://bjango.com/mac/istatmenus/
