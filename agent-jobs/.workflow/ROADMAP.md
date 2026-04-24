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
| M05 | Hook migration to Swift | PENDING | Native Swift PostToolUse handler; Node CLI no longer required |
| M06 | Settings window | PENDING | Preferences UI; persists to UserDefaults |
| M07 | Agent + Subagent inspector page | PENDING | **NEW major feature** — second top-level page; shows agent activity (Claude Code, Cursor, Copilot, OpenClaw), per-agent process tree, recent commands, sub-agent invocations |
| M08 | Packaging + auto-launch | PENDING | Notarized .dmg; LaunchAgent auto-start |
| M09 | History + analytics | PENDING | 7-day run history per service; agent attribution chart |
| M10 | v1.0 polish + ship | PENDING | All P0 issues closed; release notes; **switch to Phase B continuous mode** |

## Phase B (post-v1.0) themes

- Cross-machine sync via iCloud or self-hosted
- Notification center integration
- Sparkle auto-update
- Plug-in architecture for new agent types
- Web dashboard companion

## Update Log

- 2026-04-23: Initial roadmap. PM has not yet audited existing code; M01 is the first real milestone where PM writes a spec.
- 2026-04-23 (pm SPECCING M01): After auditing `src/scanner.ts`, the original M02 ("Live process scanner") is functionally a subset of M01's "Discovery audit + gap fill" goal — there is no value in shipping discovery half-complete. M02 is folded into M01. The complex Claude session-JSONL parser (`scanSessionCronTasks` in TS, ~170 LOC of streaming parse + 7-day age + dedup) is split out as new milestone **M01.5** so M01 stays at a 1–2 day equivalent and M01.5 can be tackled independently.
