# Design Tickets

> Append-only design ticket log. Filed by `ui-critic` agent, retrospective agent, or directly by user. PM reads this when speccing each milestone — open P0 tickets must be addressed in the next milestone or explicitly deferred with reason.

## Format

```
- [ ] T-NNN  P{0-2}  {area}  {short title}
       Source: {ui-critic|user|retro}  Filed: ISO8601  Target: M{X}
       Why: {grounded observation, 1-2 sentences}
       Done-when: {how a future PM/architect knows it's resolved}
```

## Open

- [ ] T-001  P0  menu-bar-icon  Icon doesn't communicate "background tasks"
       Source: user  Filed: 2026-04-27  Target: M07
       Why: Current placeholder SF Symbol (circle) is generic; users can't tell what the app does from the icon. Peers: Stats uses a layered chart glyph, Bartender uses a stylized bar.
       Done-when: Custom icon that reads as "background services / tasks watcher" at 16pt; running-count badge optional but tested in two states (0 / N).

- [ ] T-004  P0  data  Cron source bucket shows 0 entries
       Source: user  Filed: 2026-04-27  Target: M05
       Why: claude-sched bucket displays 0 even when scheduled_tasks.json contains entries; need to root-cause (provider not wired? bucket mapping broken? path resolution?).
       Done-when: Cron + Claude-scheduled buckets show non-zero counts when source files have entries; visual AC with stub registry containing one entry per source proves rendering.

- [ ] T-005  P0  content  Job names unreadable; missing program/command summary
       Source: user  Filed: 2026-04-27  Target: M05
       Why: Rows display launchd Label strings (e.g., "application.com.apple.MobileSMS.115...") instead of "what is this". The product's whole value-prop is "I can see what's running"; raw IDs defeat the purpose.
       Done-when: New `ServiceFormatter` produces (a) friendly title from Label/Program/process name, (b) one-line summary (program path tail OR cron description OR command first-arg). Apply across popover row, dashboard row, inspector header.

- [ ] T-006  P0  content  CPU and Memory columns blank for live processes
       Source: user  Filed: 2026-04-27  Target: M05
       Why: Columns exist but show "—". `LsofProcessProvider` knows the PID; `proc_pid_taskinfo` gives CPU% + RSS — currently not sampled.
       Done-when: New `LiveResourceSampler` populates `Service.metrics` for live processes every 10s tick; columns show numeric value or remain "—" only for non-process sources (launchd off, cron off).

- [ ] T-007  P1  visual-harness  Visual harness can't drive menu bar popover
       Source: user  Filed: 2026-04-27  Target: M05
       Why: Tonight's `osascript click` did not actually open the MenuBarExtra popover; visual ACs cannot capture popover scenarios from automation. Blocks any future popover visual AC.
       Done-when: `MenuBarInteraction.clickMenuExtra()` reliably opens popover; verified by AX tree assertion + screenshot diff.

- [ ] T-009  P0  meta-feature  Live Agent Observability — Sessions panel
       Source: user  Filed: 2026-04-27  Target: M10
       Why: User wants to see "current agent is implementing agent-jobs app, iterating feature X" — a meta view of which AI agents are working and on what. Project's identity is "the watcher for AI-agent-launched stuff"; without showing the agents themselves we're missing half the value prop. Research (see m05 competitive-analysis): disler/claude-code-hooks-multi-agent-observability, simple10/agents-observe, ClaudeUsageBar all converge on session-list + "currently doing X" headline pattern.
       Done-when: New top-level "Sessions" page shows one row per active Claude Code session (JSONL mtime within last 30min); each row displays: session UUID short, project (cwd basename), agent kind, "currently doing X" 1-liner derived from latest non-terminal tool_use, time since last event. Sortable by activity. Updates within 2s of new JSONL append.

- [ ] T-010  P0  meta-feature  Live Agent Observability — Subagent tree view
       Source: user  Filed: 2026-04-27  Target: M10
       Why: User wants to see "which subagents are working, doing what specific work". JSONL `parentUuid` chain forms a true DAG (Task tool spawns nest under parent assistant turn with own sessionId). Flat log scales poorly past 2 agents (OpenHands viewer hits this wall — anti-pattern noted in research).
       Done-when: Selecting a session opens a collapsible tree view; nodes color-coded by event kind (AGENT/LLM/TOOL/CHAIN per OpenInference taxonomy); leaf nodes show tool name + 1-line preview; subagent boundaries (`subagent_type` Task calls) are visually distinct (indent + border). Stuck detection: nodes idle > 60s show pulse indicator.

- [ ] T-011  P1  meta-feature  Self-observation banner (this app's own session)
       Source: user  Filed: 2026-04-27  Target: M10
       Why: When Claude Code is editing THIS repo, surface it specially — read `.workflow/CURRENT.md` and overlay milestone/phase/owner. Demonstrates the "dogfooding" loop and gives the user instant context on their own collaboration.
       Done-when: When a session's cwd matches `agent-jobs/` repo, the Sessions row gets a 🪞 badge and an extra line "M{N} {phase} (owner: {agent})"; clicking opens the session detail with the workflow overlay (current milestone goal pinned at top).

- [ ] T-012  P1  meta-feature  Multi-agent kind support beyond Claude Code
       Source: user-implied  Filed: 2026-04-27  Target: M10 (or M10.5)
       Why: Vision says "Cursor, Copilot, OpenClaw" too. Cursor logs at `~/.cursor/...`, Aider at `.aider.chat.history.md`, Codex CLI has its own format. Architecting only for Claude JSONL would lock us in.
       Done-when: `AgentSessionProvider` protocol with `ClaudeCodeProvider` (M10) + at least 1 stub `CursorProvider` proving the protocol holds. Full Cursor/Aider impls deferred to M10.5 if found expensive.

- [ ] T-013  P2  meta-feature  Hook-based push channel (low-latency complement)
       Source: research  Filed: 2026-04-27  Target: M10.5 or later
       Why: JSONL polling is ground truth but lags ~1-2s. Claude Code hooks (PreToolUse/PostToolUse/Notification/Stop) push events with <100ms latency. Research warning: SubagentStop hook drops events for parallel Task spawns (anthropics/claude-code#27755) — never use as sole source.
       Done-when: Optional Swift hook handler writes to a ring buffer SQLite; UI merges hook events with JSONL tail, dedup by uuid. Strictly additive.

- [ ] T-019  P2  dashboard-list  Name column too narrow at 1280pt default; "Last Run" header clipped
       Source: ui-critic  Filed: 2026-04-27T22:45:00Z  Target: M07
       Why: At 1280pt with sidebar 220 + inspector 360 + 5 visible columns (Status, Schedule, Created, CPU, Memory) plus Last Run, the Name column gets ~80pt and truncates every row title to 8-9 chars ("daily-cle...", "claude-t...", "claude-l...", "npm run..."). The Last Run header text is also clipped to "Last R...". Activity Monitor's Process Name column is the widest by default; ours is the narrowest.
       Done-when: Name column claims at least 30% of the list pane's horizontal width (proportional or `min:` constraint); Last Run header reads in full at 1280pt default; lower-priority columns (Created, Last Run) are demotable / hideable behind a column-config menu.

- [ ] T-T01  P1  tokens-color  Centralize status + source-bucket palette as `DesignTokens.Color`
       Source: pm  Filed: 2026-04-27T08:22:49Z  Target: M07
       Why: Status pills + source chips currently use scattered `Color(.systemX)` literals + ad-hoc tints. M07 visual identity needs one source of truth so the palette can be tuned once and re-applied across popover, dashboard, inspector. Also unblocks light/dark + accessibility-variant work in M14.
       Done-when: `DesignTokens.Color` namespace exposes `statusRunning/Scheduled/Failed/Idle` + `sourceRegistered/ClaudeSched/ClaudeLoop/Launchd/LiveProc`; values resolve via asset-catalog color sets (not hardcoded RGB); adopted in popover row, dashboard chip, inspector status pill.

- [ ] T-T02  P1  tokens-type  Typography scale: `display / title / body / caption / mono`
       Source: pm  Filed: 2026-04-27T08:22:49Z  Target: M07
       Why: Ad-hoc `.font(.system(size: 13))` calls scattered across popover + dashboard + inspector. No shared scale means future identity tweaks need an N-callsite hunt. Apple `Font.TextStyle` under our namespace gives intent-revealing callsites without losing Dynamic Type.
       Done-when: `DesignTokens.Font` namespace with the 5 tokens; adopted in ≥3 callsites (popover row, dashboard list row, inspector header); maps to Apple `Font.TextStyle` per competitive-analysis §7.

- [ ] T-T03  P2  tokens-spacing  Spacing scale: `xs/sm/md/lg/xl` (4/8/12/16/24)
       Source: pm  Filed: 2026-04-27T08:22:49Z  Target: M07
       Why: Inconsistent padding magic numbers across popover row internals and dashboard chrome. A 5-step scale covers every gap the M07 surfaces need; incremental adoption is fine.
       Done-when: `DesignTokens.Spacing` exposes the 5 values; adopted in ≥2 callsites; not required to be exhaustive.

- [ ] T-020  P2  dashboard-chrome  Bucket-strip header bar does not span sidebar pane
       Source: ui-critic  Filed: 2026-04-27T22:45:00Z  Target: M07
       Why: In critique 04/06/07, the horizontal bucket strip (registered/claude-sched/claude-loop/launchd/live-proc/total N) starts at the list pane's left edge. The sidebar pane shows a separate "Filters" header at top that does not visually align with the strip. The strip looks orphaned above only the list pane; a visual rhythm break for a chrome element that conceptually applies to all sources.
       Done-when: Either (a) the bucket strip extends to span the full window width (becomes a global toolbar above the split view), or (b) the sidebar's "Filters" header band is heightened to match the strip's top edge so they read as one chrome row.

## Closed

- [x] T-002  P0  popover  Popover too cramped, list rows information-poor
       Source: user  Filed: 2026-04-27  Target: M06  Closed: 2026-04-27
       Why: Default popover ~360pt wide; rows show only Label string + cron expression. User cannot tell what each entry actually does. Peer: Activity Monitor row shows process name + %CPU + memory + user.
       Done-when: Each row shows program-friendly-name (resolved from Label/Program) as primary, status pill, and a one-line summary (last-run-relative or schedule-humanized). Default popover ≥ 480pt wide.

- [x] T-003  P0  dashboard-default-size  Default window size too small, list area cramped
       Source: user  Filed: 2026-04-27  Target: M06  Closed: 2026-04-27
       Why: Default ~900x600; the 3-pane NavigationSplitView leaves the middle list with ~300pt usable width — Name column truncates aggressively. Manually resizing helps but defaults shouldn't require it.
       Done-when: Default dashboard launches at ≥ 1280x800; sidebar 220pt; inspector 360pt; middle list gets the rest. List min width 480pt before inspector hides.

- [x] T-008  P1  empty-state  Source bucket chips show 0 with no explanation
       Source: ui-critic-implied  Filed: 2026-04-27  Target: M06  Closed: 2026-04-27
       Why: A 0-count chip is indistinguishable from "feature broken" vs "no data this run". Peers (Stats) put a hairline icon when zero is intentional.
       Done-when: 0-count chip has hover tooltip ("No claude-loop crons found in ~/.claude/projects/") and a subtle dimming.

- [x] T-014  P0  visual-harness  Dashboard `Table` rows + dark scheme not rendering in capture-all output
       Source: ui-critic  Filed: 2026-04-24T18:35:00Z  Target: M06  Closed: 2026-04-27
       Why: Critique screenshots 04/05/06/07/09 show the dashboard middle list with column headers ("Name | Status | Sched...") but no row content — populated fixture should render ≥3 rows. Dark variants (05, 08) additionally show half-white / half-dark background and a fully-blank inspector body (only "Scheduled" pill + active tab pill render). Tester noted this as a known NSTableView/NSHostingView snapshot quirk; that's fine for unit baselines but blocks the M06 ui-critic gate from honestly scoring dashboard quality.
       Done-when: `04-dashboard-populated-light.png` shows ≥3 list rows with friendly titles + status + schedule. `05-dashboard-populated-dark.png` and `08-dashboard-inspector-dark.png` render fully in dark scheme (no white background bleed) with all inspector grid cards visible. Verified by visual diff against new committed baselines.

- [x] T-015  P1  source-bucket-strip  Strip chips collapse to vertical-stripe layout in DashboardView
       Source: ui-critic  Filed: 2026-04-24T18:35:00Z  Target: M06  Closed: 2026-04-27
       Why: Critique 04/06/07/09 show the source-bucket strip with each chip rendered as a narrow vertical stripe and the "total 5" label stacked one letter per line ("to / ta / l / 5"). Popover renders the same data correctly as horizontal pills ("2 running", "2 scheduled"). Likely a flex/axis or fixed-width constraint issue in the DashboardView's SourceBucketStrip embedding; not present in MenuBarViews.
       Done-when: Strip in DashboardView renders horizontal pill chips matching the popover treatment; "total N" label reads on one line; visual baseline added.

- [x] T-016  P2  popover-row  "Retry" affordance on failed-status rows
       Source: ui-critic  Filed: 2026-04-24T18:35:00Z  Target: M06 (alongside T-002)  Closed: 2026-04-27
       Why: Critique 10 (failure variant) shows the failed `daily-cleanup` row with a red dot and a red "1 failed" chip up top — readable delta. But the row's trailing slot still shows "—"; user has no inline recovery path. Peers (Stats, iStat Menus) put a small inline action when a service is in error.
       Done-when: When a Service is in `.failed` state, the popover row trailing slot exposes a "Retry" tap target (or arrow → opens dashboard row); design choice up to M06 PM.

- [x] T-017  P0  visual-harness  Dark dashboard chrome + inspector header bleed light (M06 recurrence of M05 P0)
       Source: ui-critic  Filed: 2026-04-27T22:45:00Z  Target: M06 (cycle 2 — REJECT blocker)  Closed: 2026-04-27
       Why: Critique 05 and 08 reproduce the M05 P0 white-bleed condition in a different surface region. In 05 the sidebar pane is light grey (not dark), the top ~25pt band above the table renders fully white, and the right inspector pane is empty (no "Select a service" placeholder). In 08 the inspector pane shows ONLY the "Scheduled" status pill and the "Overview" active tab pill — the friendly title, breadcrumb, command, action row, and 8-cell metadata grid all fail to render in dark scheme. Tester's 4-corner luma sample (max 0.141 < 0.3) missed this because the bleed lives in the sidebar interior + top header band + inspector header, not at the corners. AC-D-07 explicitly names this as a rubric REJECT trigger.
       Done-when: `05-dashboard-populated-dark.png` shows fully dark sidebar, fully dark top header band (bucket strip on dark), and a "Select a service" placeholder in dark scheme. `08-dashboard-inspector-dark.png` shows the full inspector grid (title, breadcrumb, command, Stop/Hide, all 4×2 metadata cards) on a fully-dark frame. Verified by sampling at least 3 non-corner regions (sidebar interior, top-of-list-pane band, inspector header band) and confirming luma < 0.3 in all three.

- [x] T-018  P1  empty-popover  Empty popover regressed vs. M05 — restore group-header scaffolding
       Source: ui-critic  Filed: 2026-04-27T22:45:00Z  Target: M07  Closed: 2026-04-27
       Why: Critique 03 renders only the EmptyHintView ("No services discovered yet.") at 480×360. Header chips show "0 running" / "0 scheduled" / "Zero KB", but the RUNNING / SCHEDULED / FAILED group-header scaffolding is absent. M05's 03 had two sections with per-section microcopy ("No services running right now." / "Nothing scheduled in the next hour.") — strictly better. Architect §3.2 specified `includeEmpty: true` to render group headers + 0-count chips; impl falls through to `EmptyHintView` instead (reviewer Finding #2; tester carried forward).
       Done-when: Empty popover shows RUNNING(0) / SCHEDULED(0) section headers with per-section microcopy below each (Things 3 empty-inbox pattern). Popover height extends to ≥ 480pt (matches populated default). Either implement, or update spec/architecture to canonicalize the EmptyHintView path and document the deliberate departure from M05.
