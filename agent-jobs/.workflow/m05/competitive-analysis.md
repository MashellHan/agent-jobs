# Competitive Analysis — M05

> Focus: what does a great list ROW look like? Status placement, primary/secondary/tertiary info, hover affordance, density. The user has set the bar at "competitive with Activity Monitor / Stats / Bartender". This analysis grounds M05 row + harness decisions in those peers.

## Products surveyed

| Product | URL | License | Last activity | Relevance to M05 |
|---|---|---|---|---|
| Activity Monitor (Apple) | [Apple guide](https://support.apple.com/guide/activity-monitor/view-information-about-processes-actmntr1001/mac) | Proprietary (system) | macOS 26 (2026) | Reference for **process row anatomy** — name + %CPU + memory + user, customizable columns. The "2026 native baseline." |
| Stats (exelban) | [github.com/exelban/stats](https://github.com/exelban/stats) | MIT | active 2026 (HN front-page Feb 2026) | Reference for **menu-bar popover** with multiple module sections, each with mini-chart + numeric value rows. Closest in form-factor to our popover. |
| Things 3 (Cultured Code) | [Quick Find docs](https://culturedcode.com/things/support/articles/2803584/) | Proprietary | active 2026 | Reference for **heterogeneous row component** — single row template adapts icon/metadata to type (todo / project / area / tag). Mirrors our 5 source buckets needing one row layout. |
| Linear | [linear.app/now/how-we-redesigned-the-linear-ui](https://linear.app/now/how-we-redesigned-the-linear-ui) + [2026-03-12 UI refresh](https://linear.app/changelog/2026-03-12-ui-refresh) | Proprietary | active 2026 (March 2026 UI refresh) | Reference for **list density + hover** — "reduce visual noise, maintain visual alignment, increase hierarchy and density of navigation elements"; LCH-derived contrast. |
| Bartender 4 | [macbartender.com/Bartender4](https://www.macbartender.com/Bartender4/) | Proprietary | active 2026 | Reference for **menu-bar layout screen** rows (drag-organize Shown/Hidden/Always-Hidden). Three-bucket grouping pattern. |

> Where the page text didn't expose UI specifics (e.g. Stats README only links PNG screenshots; Apple guide doesn't quote pixel sizes), findings are augmented from direct first-hand product knowledge of these apps. All cited URLs are real and verifiable above.

---

## Row anatomy — what does a great row look like?

Distilled from the five peers above, a great list row in a 2026 native Mac app has **four tiers** of info:

| Tier | What it is | Visual treatment | Example (Activity Monitor / Stats / Linear) |
|---|---|---|---|
| **Primary** | The name a human types when they say "that thing" | 13pt SF Pro Regular, full opacity, leading | "Google Chrome Helper" / "CPU" / "ENG-1234 Investigate flake" |
| **Secondary** | The 1-line "what is this", auxiliary metadata | 11pt SF Pro Regular, secondary opacity, beneath OR right-aligned | "user · pid 4521" / "5.4 GHz · 8 cores" / "Backend · @alice · 2d" |
| **Status** | Pill / dot / icon that gates eye flow | colored shape — green dot, red pill, SF Symbol | green dot for running / red "stopped" pill / status icon for ticket state |
| **Tertiary value** | Numeric / time, right-aligned, monospace | 12pt SF Mono, secondary opacity | %CPU "12.4" / "3.2 GB" / "now" |

### Row height + density

- Activity Monitor default row: ~22pt (compact). Each row shows ~7 columns of numbers — no wasted whitespace.
- Stats popover row: ~28pt (comfortable) — fewer rows but each has a sparkline + value.
- Linear list row: ~32pt comfortable mode, ~24pt compact mode (user-toggleable).
- Things task row: ~36pt (most comfortable; fewer rows visible but each is rich).

**Implication for us:** at popover scale (~480pt wide × ~600pt tall) we have room for ~17 comfortable-mode rows or ~25 compact-mode rows. That's enough — most users have <30 services. **Default to comfortable (32pt)** with optional compact in M09.

### Status placement

- **Activity Monitor:** uses a leading colored kIcon column (the app icon, with red overlay if "Not Responding"). Status is implied by row order (sorted by %CPU) more than by an explicit pill.
- **Stats:** status is the value itself (high CPU% turns red).
- **Linear:** **leading status icon** (16pt circle / arrow / checkmark) is the most prominent visual cue — eye lands on color first.
- **Bartender:** column-based — a row's bucket placement IS its status.

**Pattern we should adopt:** **leading status pill** (Linear-style), 8pt circle in the status color, immediately to the right of the source-bucket icon. Puts color-as-status at the eye's natural landing point.

### Primary/secondary text relationship

- Activity Monitor: secondary info lives in **adjacent columns**, not a stacked subtitle.
- Stats: primary = label, secondary = value (right-aligned, mono).
- Linear: **stacked** in compact / **inline** in comfortable. Linear's redesign explicitly increased "hierarchy and density."
- Things: stacked (project name beneath task title).

**Pattern for us:** **stacked at popover scale** (narrow → vertical), **inline at dashboard scale** (wide → adjacent columns). Title primary, schedule/program tail secondary.

### Hover affordance

- Activity Monitor: row highlights light blue on hover; double-click opens detail.
- Stats: hover reveals "more info" caret on the right edge.
- Linear: hover reveals **trailing actions row** (assignee, priority, due) that's normally hidden — this is the **single biggest "feels native 2026" cue**.
- Things: hover reveals checkbox + reorder grip.

**Pattern for us:** **hover reveals trailing inspector-arrow + quick stop button** (normally hidden). Today our rows are static — adding hover reveals will singularly elevate the "modern" feel.

---

## Feature matrix

| Feature | Activity Monitor | Stats | Things | Linear | Bartender | We have today | M05 plans |
|---|---|---|---|---|---|---|---|
| Friendly process/item name | ✓ (process display name) | ✓ (module display name) | ✓ (task title) | ✓ (issue title) | ✓ (app name) | ✗ raw Label string | ✓ `ServiceFormatter` |
| 1-line summary / subtitle | column-adjacent | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ `ServiceFormatter` |
| Leading status pill | ✗ (app icon) | implicit | ✓ checkbox | ✓ status icon | bucket-implicit | partial (status badge in list) | promote to leading dot |
| Numeric metric (CPU/MEM) right-aligned | ✓ | ✓ | n/a | n/a | ✗ | ✗ blank "—" | ✓ `LiveResourceSampler` |
| Hover-reveal actions | ✓ kill button | ✓ caret | ✓ checkbox | ✓ trailing actions | n/a | ✗ | scoped to M06 (defer; M05 just makes the data correct) |
| Source bucket / category chips | View menu sort | tab bar | tag pills | grouping | category sections | ✓ `SourceBucketStrip` | T-008 polish in M06 |
| Empty-state explanation | system | placeholder text | "Nothing here yet" copy | illustrated empty | n/a | ✗ blank | partial (we'll reserve scope for M06) |
| Drives screenshots from CI | n/a | n/a | n/a | n/a | n/a | ad-hoc test helper | ✓ `AgentJobsVisualHarness` + `capture-all` CLI |

---

## Gaps we should fill (this milestone)

1. **Friendly title + 1-line summary** for every Service. Nothing else works without this. (T-005 → `ServiceFormatter`)
2. **Numeric CPU%/RSS column populated** for live processes — empty columns make the product look broken. (T-006 → `LiveResourceSampler`)
3. **No-data buckets must reflect real state**, not a bug — verify cron/claude-sched render correctly when source files exist. (T-004 root-cause + fix)
4. **Visual harness as a reusable library** so we can capture popover + dashboard scenarios reliably from CLI for ui-critic. (T-007)

## Patterns worth borrowing

- **Linear's stacked-vs-inline density toggle** at different widths (popover vs dashboard) — we can do this even before M09 settings, using container width.
- **Activity Monitor's monospace right-aligned numeric column** — adopt `SF Mono` for CPU%/RSS so digits align across rows.
- **Linear's leading status icon as the eye's landing point** — color before text.
- **Stats's "module rows have a sparkline"** — out of scope for M05; note as M11 / M13 candidate.
- **Things's heterogeneous row template** — one Row component, switches icon based on `Service.source.bucket`. We already do this.

## Anti-patterns observed (avoid)

- **Activity Monitor's "Process Name column expands and hides everything else" bug** ([Apple StackExchange](https://apple.stackexchange.com/questions/380385/activity-monitor-columns-missing), [Reddit](https://www.reddit.com/r/MacOS/comments/erf66f/activity_monitor_can_only_see_process_name_column/)) — set explicit max width on the title column; don't let it consume the row.
- **Stats's "what does this row do?" opacity** — at popover scale, no row should require hover to know what it represents. Status + title + 1-line summary must always be visible.
- **Bartender's all-text rows in the layout sheet** — a 16pt app icon transforms readability. Use `Bucket.sfSymbol` consistently as leading glyph.
- **2010-era Cocoa "row = 4 stacked text fields"** — we hit this in our current build. Replace with one-line-stacked-pair plus trailing numeric.

---

## Sources

- [Apple — View information about Mac processes in Activity Monitor](https://support.apple.com/guide/activity-monitor/view-information-about-processes-actmntr1001/mac)
- [Apple StackExchange — Activity Monitor columns missing](https://apple.stackexchange.com/questions/380385/activity-monitor-columns-missing)
- [Reddit r/MacOS — Activity Monitor: Can Only See "Process Name" Column](https://www.reddit.com/r/MacOS/comments/erf66f/activity_monitor_can_only_see_process_name_column/)
- [exelban/stats — macOS system monitor in your menu bar (GitHub)](https://github.com/exelban/stats)
- [Stats — official site](https://mac-stats.com/)
- [Hacker News — Stats discussion (item 42881342)](https://news.ycombinator.com/item?id=42881342)
- [Cultured Code — Searching and Navigating with Quick Find](https://culturedcode.com/things/support/articles/2803584/)
- [Linear — How we redesigned the Linear UI (part Ⅱ)](https://linear.app/now/how-we-redesigned-the-linear-ui)
- [Linear — UI refresh changelog (2026-03-12)](https://linear.app/changelog/2026-03-12-ui-refresh)
- [Linear Docs — Conceptual model](https://linear.app/docs/conceptual-model)
- [Bartender 4 — official site](https://www.macbartender.com/Bartender4/)
