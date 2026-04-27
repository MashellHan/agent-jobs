# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Mac app (Swift rewrite, in progress)

- **M05 — Content fidelity + Visual Harness library** (2026-04-24): New `AgentJobsVisualHarness` SwiftPM library (`Snapshot`, `MenuBarInteraction`, `WindowInteraction`, `CritiqueReport`, `DiffReport`) plus `capture-all` executable producing 10 PNG+JSON pairs in <2s for ui-critic gating. New `ServiceFormatter` (friendly title + 1-line summary) wired across popover row, dashboard row, inspector header. New `LiveResourceSampler` actor populating CPU%/RSS via `proc_pid_taskinfo` off the main thread. Cron T-004 root-cause fix: `ClaudeSessionCronProvider` no longer silently swallows per-file parse failures — `ProviderDiagnostics` actor surfaces `lastError` + per-file failure map; chip-tooltip plumbing added. Package surgery: `AgentJobsMac` executable renamed to `AgentJobsMacApp` (thin `@main`); new `AgentJobsMacUI` library extracted; 5-target package compiles cleanly. 24/24 ACs PASS.
- **M04 — Auto-refresh + fs.watch** (2026-04-24): `RefreshScheduler` actor with debounce + in-flight coalescing, DispatchSource-based `FileObjectWatcher`/`DirectoryEventWatcher` with atomic-rename re-open, `VisibilityProvider` for battery-saving pause, `PeriodicTicker` with keepalive, AutoRefreshIndicator 3-state (idle/refreshing/error) in both popover and dashboard toolbar; `WatchPaths` test seam + static-grep enforcement. 29/30 ACs PASS first-try. (+42 tests, 226 → 266)
- **M03 — Actions (stop/hide/refresh)** (2026-04-24): Row-hover + inspector stop buttons backed by `StopExecutor` (SIGTERM / `launchctl unload`); 6-predicate refusal (PID 0/1/self, missing PID/plist, unsupported sources) with defense-in-depth; `HiddenStore` actor with atomic persistence; manual refresh + spinner; destructive-action confirmation dialog; 7 visual baselines. 26/26 ACs PASS first-try. (+48 tests, 178 → 226)
- **M02 — Functional UI baseline** (2026-04-24): Dashboard shows all 5 discovery sources with `SourceBucketStrip` summary header (click-to-filter), inline `ServiceInspector` right pane, `.accessory` activation policy (menu bar icon as primary entry), visual-test harness with 6 committed screenshot baselines, app-launch smoke test. 26/26 ACs PASS. (+33 tests, 145 → 178)
- **M01.5 — Claude session-JSONL cron parser** (2026-04-24): Streams `~/.claude/projects/**/*.jsonl`, reconstructs CronCreate/CronDelete net set, dedups against `scheduled_tasks.json`. 15/15 ACs PASS. (+34 tests)
- **M01 — Discovery audit + gap fill** (2026-04-24): Adds `LsofProcessProvider` + `ClaudeScheduledTasksProvider`, wires both into the default registry, fixes launchd `createdAt` provenance from plist mtime. 37/37 ACs PASS. (+56 tests, 55 → 111)

## 0.1.0 (2026-04-11)

Initial public release.

### Features

- **TUI Dashboard**: Interactive terminal UI built with Ink (React for CLI)
  - Tab-based navigation (Dashboard, Settings)
  - Keyboard shortcuts: arrow keys, Enter to expand, q to quit
  - Inline detail panel with job metadata
- **Auto-Detection**: PostToolUse hook captures 14 service patterns
  - pm2, nohup, docker run, systemctl, launchctl, docker-compose
  - flask, uvicorn, gunicorn, next dev, vite dev, and more
- **Live Process Scanner**: Discovers running services via lsof
  - Port extraction, friendly names, framework detection
- **Cron Task Scanner**: Reads Claude Code scheduled tasks
- **Agent Support**: Claude Code, Cursor, GitHub Copilot, OpenClaw
- **Human-Readable Display**: cronToHuman schedules, relative time AGE column
- **CLI Commands**: `agent-jobs` (TUI), `agent-jobs list` (JSON), `agent-jobs setup`/`teardown`
- **Zero-Config Install**: postinstall hook auto-registers the PostToolUse hook
- **Atomic Writes**: temp-file-then-rename for jobs.json and settings.json
