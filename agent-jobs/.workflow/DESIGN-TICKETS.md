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

- [ ] T-002  P0  popover  Popover too cramped, list rows information-poor
       Source: user  Filed: 2026-04-27  Target: M06
       Why: Default popover ~360pt wide; rows show only Label string + cron expression. User cannot tell what each entry actually does. Peer: Activity Monitor row shows process name + %CPU + memory + user.
       Done-when: Each row shows program-friendly-name (resolved from Label/Program) as primary, status pill, and a one-line summary (last-run-relative or schedule-humanized). Default popover ≥ 480pt wide.

- [ ] T-003  P0  dashboard-default-size  Default window size too small, list area cramped
       Source: user  Filed: 2026-04-27  Target: M06
       Why: Default ~900x600; the 3-pane NavigationSplitView leaves the middle list with ~300pt usable width — Name column truncates aggressively. Manually resizing helps but defaults shouldn't require it.
       Done-when: Default dashboard launches at ≥ 1280x800; sidebar 220pt; inspector 360pt; middle list gets the rest. List min width 480pt before inspector hides.

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

- [ ] T-008  P1  empty-state  Source bucket chips show 0 with no explanation
       Source: ui-critic-implied  Filed: 2026-04-27  Target: M06
       Why: A 0-count chip is indistinguishable from "feature broken" vs "no data this run". Peers (Stats) put a hairline icon when zero is intentional.
       Done-when: 0-count chip has hover tooltip ("No claude-loop crons found in ~/.claude/projects/") and a subtle dimming.

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

## Closed

(empty)
