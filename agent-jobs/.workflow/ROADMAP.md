# Roadmap

> Owned by `pm` agent. Updated each time PM enters SPECCING phase. Reflects current understanding of the product trajectory; later milestones may shift as earlier ones complete.

## Vision (one paragraph)

A native macOS app that replaces the existing TUI tool (`agent-jobs` Node CLI). Aggregates background services created by AI coding agents (Claude Code, Cursor, Copilot, OpenClaw) into a single menu bar + window UI. Adds rich content (per-service detail, history, cron humanization, resource metrics) and direct interaction (stop, hide, restart, focus terminal). Long-term: cross-machine sync, agent attribution analytics, scheduled reports.

## Status Snapshot (as of 2026-04-23)

Existing Swift work at `macapp/AgentJobsMac/`:
- ✅ Package.swift (AgentJobsCore lib + AgentJobsMac app)
- ✅ Menu bar entry (`AgentJobsMacApp.swift`, `MenuBarViews.swift`, `AutoRefreshIndicator.swift`)
- ✅ Dashboard view scaffolding (`DashboardView.swift`)
- ✅ ~10 reusable components (StatusBadge, MetricTile, MemoryBadge, etc.)
- ✅ Discovery layer skeleton (ServiceRegistry, AgentJobsJsonProvider, LaunchdUserProvider, LaunchdPlistReader, Shell)
- ✅ Domain models (Service, ServiceSource, ResourceMetrics, CronHumanizer)
- ✅ 7 unit test files
- ❌ No live process scanner (lsof equivalent)
- ❌ No Claude Code cron scanner
- ❌ No detail panel
- ❌ No actions (stop/hide/restart)
- ❌ No PostToolUse hook (still depends on Node CLI)
- ❌ No fs.watch for auto-refresh
- ❌ No settings, no auto-start, no packaging

## Milestone Plan

| ID | Theme | Status | Acceptance summary |
|---|---|---|---|
| M00 | Bootstrap workflow | DONE | this file + .claude/ + .workflow/ created |
| M01 | Discovery audit + gap fill | DONE | Adds `LsofProcessProvider` + `ClaudeScheduledTasksProvider`; wires both into default registry; launchd `createdAt` provenance fixed; +56 new tests; no UI changes |
| M01.5 | Claude session-JSONL cron parser | DONE | Streams `~/.claude/projects/**/*.jsonl`, reconstructs CronCreate/Delete net set, dedups against `scheduled_tasks.json` (parity with TS `scanSessionCronTasks`); +34 tests |
| M02 | Functional UI baseline | DONE | Main list shows all 5 sources via `SourceBucketStrip` summary header + click-to-filter, inline `ServiceInspector`, `.accessory` activation policy, visual-test harness (`NSHostingView` + ImageMagick `compare`) with 6 committed baselines, app-launch smoke test; 26/26 ACs PASS, +33 tests |
| M03 | Actions (stop/hide/refresh) | DONE | `StopExecutor` (SIGTERM/launchctl unload) with 6-predicate safety refusal + defense-in-depth; `HiddenStore` actor with atomic persistence + Show-hidden toggle; manual refresh; confirmation dialog; 26/26 ACs PASS first-try, +48 tests |
| M04 | Auto-refresh + fs.watch | DONE | `RefreshScheduler` actor (debounce + coalescing) + `FileObjectWatcher`/`DirectoryEventWatcher` (atomic-rename re-open) + `VisibilityProvider` (battery pause) + `PeriodicTicker`; AutoRefreshIndicator 3-state in popover + dashboard toolbar; 29/30 ACs PASS first-try, +42 tests |
| M05 | **Content fidelity** + visual harness lib | PENDING | **Reshaped 2026-04-27.** Three things: (a) `AgentJobsVisualHarness` SwiftPM library (Snapshot + MenuBarInteraction + WindowInteraction + CritiqueReport + `swift run capture-all` CLI); (b) `ServiceFormatter` produces friendly title + 1-line summary from Label/Program/process name (closes T-005); (c) `LiveResourceSampler` populates CPU% + RSS via `proc_pid_taskinfo` every tick (closes T-006); (d) root-cause empty cron buckets (closes T-004). First milestone with ui-critic agent active as soft gate. |
| M06 | **Information architecture** | PENDING | **NEW.** Popover redesign: ≥480pt wide, rich rows (program-friendly-name primary, status pill, 1-line summary), grouped by status (closes T-002). Dashboard default ≥1280x800, sidebar 220 / inspector 360 / list gets the rest (closes T-003). 0-count chips dimmed + tooltip (closes T-008). ui-critic gate active. |
| M07 | **Visual identity** | PENDING | **NEW.** Custom `agent-jobs.icns` glyph that reads as "background services watcher" at 16pt; running-count badge variant (closes T-001). System app icon (1024 master). Color tokens (status palette, source colors), typography scale, density modes (compact/comfortable). Spacing tokens. ui-critic gate active. |
| M08 | Hook migration to Swift | PENDING | Native Swift PostToolUse handler; Node CLI no longer required (was M05) |
| M09 | Settings window | PENDING | Preferences UI; persists to UserDefaults; density mode + auto-launch toggle (was M06) |
| M10 | **Live Agent Observability** (Sessions + Subagent tree) | PENDING | **Major feature, expanded 2026-04-27.** Second top-level page. Three surfaces: (a) **Sessions panel** — list every active Claude Code / Cursor / Aider session detected from `~/.claude/projects/**/*.jsonl` (and equivalents) with "currently doing X" headline; (b) **Subagent tree** — collapsible `parentUuid` DAG view, color-coded by event kind using OpenInference taxonomy (AGENT/LLM/TOOL/CHAIN/RETRIEVER); (c) **Self-banner** — special-case row when a Claude Code session is editing THIS repo, showing milestone + phase from `.workflow/CURRENT.md`. Closes T-009/T-010/T-011. Reuses M01.5 `SessionJSONLParser`. Inspired by disler/claude-code-hooks-multi-agent-observability + Arize Phoenix span tree + OpenHands trajectory-visualizer. |
| M11 | **Motion + micro-interactions** | PENDING | **NEW.** SF Symbol effects, smooth list reorder, hover/press states, empty-state illustrations, error-state recovery affordances. Anti-flicker auditing on auto-refresh path. |
| M12 | Packaging + auto-launch | PENDING | Notarized .dmg; LaunchAgent auto-start (was M08) |
| M13 | History + analytics | PENDING | 7-day run history per service; agent attribution chart (was M09) |
| M14 | **Visual polish pass + accessibility** | PENDING | **NEW.** Full ui-critic audit, sweep all open P1 design tickets, VoiceOver labels, Dynamic Type, Reduce Motion compliance, dark mode pixel-parity. |
| M15 | v1.0 polish + ship | PENDING | All open P0 design tickets closed; release notes; first public release; **switch to Phase B continuous mode** (was M10) |

## Phase B (post-v1.0) themes

- Cross-machine sync via iCloud or self-hosted
- Notification center integration
- Sparkle auto-update
- Plug-in architecture for new agent types
- Web dashboard companion

## Update Log

- 2026-04-23: Initial roadmap. PM has not yet audited existing code; M01 is the first real milestone where PM writes a spec.
- 2026-04-23 (pm SPECCING M01): After auditing `src/scanner.ts`, the original M02 ("Live process scanner") is functionally a subset of M01's "Discovery audit + gap fill" goal — there is no value in shipping discovery half-complete. M02 is folded into M01. The complex Claude session-JSONL parser (`scanSessionCronTasks` in TS, ~170 LOC of streaming parse + 7-day age + dedup) is split out as new milestone **M01.5** so M01 stays at a 1–2 day equivalent and M01.5 can be tackled independently.

- **2026-04-27 (major reshape — UI-quality pivot)**: User reviewed live app screenshots and filed 6 P0 design tickets covering icon identity, popover information density, dashboard default size, missing data (cron empty), unreadable job names, and missing CPU/memory values. Root cause: functional ACs proved the UI doesn't crash, not that it's good. Three structural changes:
  1. **Visual harness promoted to first-class architecture pillar** (`.workflow/DESIGN.md`). New SwiftPM target `AgentJobsVisualHarness` with `MenuBarInteraction` + `WindowInteraction` + `CritiqueReport` + `capture-all` CLI. Lifts visual snapshotting out of test files; reusable across tests, CI, and the new ui-critic agent.
  2. **New `ui-critic` agent** (`.claude/agents/ui-critic.md`) runs after TESTING in every milestone from M05 on. Scores screenshots against a 6-axis rubric (Clarity, Density/Hierarchy, Identity, Affordance, Empty/Error states, Novelty). Files tickets to `.workflow/DESIGN-TICKETS.md`. Soft gate (can REJECT only on visual P0).
  3. **Roadmap rebuilt around UI quality.** Old M05-M10 (6 milestones) → new M05-M15 (11 milestones). Three new milestones inserted before functional work resumes: M05 (content fidelity + visual harness), M06 (information architecture), M07 (visual identity). Originally-planned features (Hook migration, Settings, Agent inspector, Packaging, History) shift +3. Two new polish milestones added before v1.0 ship: M11 (motion) and M14 (visual polish + a11y). Old M07 "Agent inspector" stays the second flagship feature, now at M10.
  Goal: by v1.0 (M15) the app should be visually competitive with Stats, Bartender, Activity Monitor — not just functionally complete.
