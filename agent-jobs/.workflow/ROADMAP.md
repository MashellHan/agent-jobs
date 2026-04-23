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
| M00 | Bootstrap workflow | IN PROGRESS | this file + .claude/ + .workflow/ created |
| M01 | Discovery audit + gap fill | PENDING | All 4 data sources working; tests pass |
| M02 | Live process scanner | PENDING | `lsof` provider returns running listeners; integrated into ServiceRegistry |
| M03 | Detail panel UI | PENDING | Click row → detail view with command/PID/port/history |
| M04 | Actions (stop/hide) | PENDING | Stop sends SIGTERM/launchctl unload; hide persists; both with undo |
| M05 | Auto-refresh + fs.watch | PENDING | jobs.json change → UI updates within 500ms |
| M06 | Hook migration to Swift | PENDING | Native Swift PostToolUse handler; Node CLI no longer required |
| M07 | Settings window | PENDING | Preferences UI; persists to UserDefaults |
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
