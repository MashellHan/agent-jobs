# M02 — Functional UI baseline

## Goal (one sentence)

Ship a stable, launchable Mac app whose menu-bar popover and Dashboard window render every service from all 5 discovery providers with a per-source summary header and an inline per-row detail panel — no crashes, no separate windows, screenshot-verifiable.

## User value (why now)

Discovery is feature-complete (M01 + M01.5). The user currently has no way to *see* what discovery produces — the only consumer is unit tests. M02 closes that gap so the user can launch the app, glance at the menu bar, and inspect any agent-managed background task without falling back to the legacy TS TUI.

## Scope (in)

1. **All 5 providers wired and rendered.** `AgentJobsJsonProvider`, `LsofProcessProvider`, `ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`, `LaunchdUserProvider` — each must have at least one row visible (or an explicit "0 from this source" indicator) on the Dashboard.
2. **Per-source summary header** on the Dashboard window: a single horizontal strip above the table with one chip per source showing `<icon> <displayName> <count>`. Clicking a chip filters the table to that source (re-uses the existing `categoryFilter` state — but switched from category to source-bucket grouping). Total count chip on the far right.
3. **Per-row detail panel.** Already-existing `ServiceInspector` is the right pane of `NavigationSplitView`. M02 ensures every row, regardless of source, populates these field groups:
   - Identity: name, source, project (or "—")
   - Schedule: humanized
   - Process: PID, CPU%, RSS, threads (only when source supplies them)
   - Provenance: createdAt, origin (agent + sessionId), file path / scheduled-task id when known
4. **Menu-bar popover stays functional.** Existing summary chips + Active Now / Scheduled Soon sections render; clicking "Open Dashboard" opens the main window.
5. **Launch reliability.** App launches via `swift run AgentJobsMac` without crash; menu-bar icon visible within 2 s; first discovery cycle completes within 3 s; auto-refresh continues every 30 s without leaks.
6. **Visual baselines committed.** Reference PNGs under `.workflow/m02/screenshots/baseline/` for menu-bar light/dark, Dashboard light/dark, and inspector populated.
7. **Empty / loading / error states render** without dead-locking the layout (skeleton rows during `.loading`, EmptyHintView per section, ErrorBanner when `phase == .error`).

## Out of scope (explicit non-goals)

- **No actions** (stop / hide / restart / focus terminal) — that's M03.
- **No fs.watch / push refresh** — only the existing 30 s polling. M04 lands fs.watch.
- **No log streaming, no raw-config viewer** — those are placeholders in the Inspector (already labelled as future).
- **No settings window, no preferences** — M06.
- **No packaging, no notarization, no auto-launch** — M08.
- **No new providers, no provider behaviour changes.** Discovery layer is frozen for M02.
- **No Agent/Subagent inspector page** — M07.
- **No new Domain model fields** beyond what already exists. If a UI region needs a field that isn't on `Service`, the spec says "render '—'", not "extend the model".

## Constraints

- **Tech**: SwiftUI on macOS 14+ (existing target). NavigationSplitView, MenuBarExtra(.window), SF Symbols only. No third-party deps beyond what's already in `Package.swift`.
- **Time**: User wants stable app by tomorrow. Prefer reusing existing `DashboardView`, `MenuBarPopoverView`, `ServiceInspector`, `SummaryChip`, `StatusBadge`. Net new code should be small (a per-source summary header + inspector enrichment).
- **Dependencies**: M01 + M01.5 RELEASED. `defaultRegistry()` already wires all 5 providers.
- **Testing**: Tester launches via `swift run`. XCUITest is acceptable; if XCUITest is too heavy, a plain `XCTestCase` that invokes the app target and uses `CGWindowListCopyWindowInfo` + `CGWindowListCreateImage` to capture the menu bar / window region is also acceptable. Decision deferred to architect — see Open questions.

## Data flow (which provider feeds which UI region)

| UI region | Data source(s) |
|---|---|
| Menu-bar icon label | `MenuBarSummary.from(services:)` — derived from union of all 5 providers |
| Menu-bar popover header chips | `MenuBarSummary` |
| Menu-bar popover "Active Now" | `services.filter { $0.status == .running }` (mostly `LsofProcessProvider`) |
| Menu-bar popover "Scheduled Soon" | `services.filter { $0.nextRun != nil }` (mostly Claude scheduled tasks + launchd calendar) |
| Dashboard summary header (NEW) | per-source bucket counts derived from `services` grouped by `ServiceSource` discriminator |
| Dashboard sidebar | `ServiceSource.Category` filter (existing) |
| Dashboard table | `services` filtered by sidebar selection + summary-chip selection |
| Dashboard inspector right pane | the selected `Service` — all field groups populated from existing `Service` properties |

## UX layout (text wireframe)

### Menu-bar popover (existing, unchanged in shape)
```
┌────────────────────────────────────────────────┐
│ ⬢ Agent Jobs                  ↻ 12s ago  ⟳    │
├────────────────────────────────────────────────┤
│ 🔥 3 running   ⏰ 5 scheduled         ▤ 412 MB │
├────────────────────────────────────────────────┤
│ ACTIVE NOW                                     │
│   ▸ claude-loop session-abc   ⚡  88 MB        │
│   ▸ npm run dev               ⚡  201 MB       │
│ SCHEDULED SOON                                 │
│   ▸ daily-cleanup    daily 09:00               │
│   ▸ claude-task-42   in 4 m                    │
├────────────────────────────────────────────────┤
│ Open Dashboard ⌘D              Quit ⌘Q         │
└────────────────────────────────────────────────┘
```

### Dashboard window (NEW: source summary strip above table)
```
┌─────────────────┬───────────────────────────────────────────────┬──────────────────────┐
│ Filters         │  Per-source summary strip (NEW)               │  Inspector           │
│  All        12  │  📄 registered 2 · 🧠 claude-sched 3 ·        │  ┌────────────────┐  │
│ Categories      │  📄 claude-loop 1 · 🖥 launchd 4 ·            │  │ ⚡ npm run dev │  │
│  Claude     4   │  ⚡ live-proc 2                  total: 12    │  │ Process · acme │  │
│  Launchd    4   │ ┌───────────────────────────────────────────┐ │  │ ────────────── │  │
│  Cron       0   │ │ Name        Status  Sched   Created  CPU │ │  │ Schedule:      │  │
│  Brew       0   │ │ npm run dev RUN     —       2m ago   3% │ │  │   on demand    │  │
│  Login      0   │ │ daily-clean SCHED   09:00   3d ago   —  │ │  │ PID: 4231      │  │
│  AgentJobs  2   │ │ claude-task SCHED   in 4m   today    —  │ │  │ Owner: user    │  │
│  Processes  2   │ │ ...                                      │ │  │ Project: acme  │  │
│                 │ └───────────────────────────────────────────┘ │  └────────────────┘  │
└─────────────────┴───────────────────────────────────────────────┴──────────────────────┘
```

The summary strip is a single `HStack` of `SourceSummaryChip` views above the existing `Table`. Click a chip → toggle `sourceFilter`. The sidebar `categoryFilter` and the chip `sourceFilter` both narrow `filteredServices`; both can be cleared by clicking the active chip / "All" sidebar entry.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Screenshot regression flakiness on different machines (DPI, font rendering) | High | Use 1.0× capture + odiff threshold of 2% (not 1%). Render in a fixed-size Window with explicit `.frame(width:height:)` for the screenshot fixture. Capture in light + dark modes. |
| `swift run` doesn't background-launch the menu-bar (LSUIElement etc. may be missing) | Medium | Architect must verify `Info.plist` / `Package.swift` resources declare `LSUIElement = true` so the app runs without dock icon. If not, AC-Q-04 fails. |
| Per-source bucketing requires a new derived collection — risk of recomputation cost on every frame | Low | Compute once per `services` change (use `@Observable`'s `didSet` or a computed cached property). Service count is < 100 in practice. |
| User has 0 services in `agentJobs.json` so the "registered" chip shows 0 → looks broken | Low | Show all 5 chips always, including 0-count chips, with secondary styling for zero. Spec says ALL 5 must be visible. |
| Dashboard window doesn't open from `swift run` (only the menu-bar) | Medium | Tester scenario opens it via menu-bar "Open Dashboard" or directly via `openWindow(id: "dashboard")` in a launcher script. |

## Open questions for architect

1. **Screenshot capture mechanism** — XCUITest, or a lighter `XCTestCase` that uses `NSWindow.dataWithPDF(inside:)` / `NSView.bitmapImageRepForCachingDisplay(in:)` against an in-process headless render? Simpler-ships-sooner preference: in-process render of a deterministic preview Scene per AC. Architect picks.
2. **Source-bucket grouping** — should `ServiceSource` get a new `bucket` accessor that returns one of the 5 user-facing labels (registered / live / claude-scheduled / claude-session / launchd), separate from existing `category`? PM recommends yes — `category` is too coarse (lumps both Claude sources together; doesn't separate registered-jobs.json from launchd plists) and a new `bucket` keeps the existing `Category` API stable for the sidebar. Architect to confirm.
3. **odiff vs ImageMagick `compare`** — both work; pick whichever the existing tooling already has. If neither, install `odiff` (small Rust binary).
