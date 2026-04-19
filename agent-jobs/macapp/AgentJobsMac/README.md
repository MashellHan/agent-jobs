# AgentJobsMac

Native macOS menubar + dashboard app for monitoring every kind of background
"service" your Mac runs: OS daemons (launchd), cron, brew services, login items,
Claude Code scheduled tasks, and live agent loops — all with **CPU + memory**
at a glance.

## Why

`agent-jobs` started as a TUI. The TUI is great for power users in a terminal,
but most people want a **menubar dot + a real window** they can click. This
app surfaces the same service registry through a SwiftUI front-end with
inline detail panes, visible auto-refresh, and proper accessibility.

## Architecture (one screen)

```
┌─────────────── AgentJobsMac.app ──────────────┐
│                                               │
│  MenuBarExtra(.window)        Window("dash")  │
│  ┌────────────────┐           ┌─────────────┐ │
│  │ MenuBarPopover │           │ Dashboard   │ │
│  │ • summary chips│           │ Sidebar /   │ │
│  │ • active list  │   share   │ Table /     │ │
│  │ • upcoming list│ ───────►  │ Inspector   │ │
│  │ • mem total    │  registry │ (tabs)      │ │
│  └────────────────┘           └─────────────┘ │
│           ▲                          ▲        │
│           │ @Observable view model   │        │
│           ▼                          ▼        │
│      ┌────────────────────────────────────┐   │
│      │  ServiceRegistryViewModel (MainAct.)│  │
│      │  • services / summary / phase       │  │
│      │  • auto-refresh task (30s)          │  │
│      └────────────────────────────────────┘   │
│                       │                       │
│                       ▼                       │
│            ┌─────────────────────┐            │
│            │ ServiceRegistry actor│           │
│            │ TaskGroup discoverAll│           │
│            └─────────────────────┘            │
│            ┌──────┬──────┬──────┐             │
│            │ Prov │ Prov │ Prov │ ← M2 plan   │
│            └──────┴──────┴──────┘             │
└───────────────────────────────────────────────┘
```

Detailed design: [`../../.implementation/macapp-architecture.md`](../../.implementation/macapp-architecture.md).
Sandbox decision: [`../../.implementation/sandbox-decision.md`](../../.implementation/sandbox-decision.md).

## Modules

| Module | Path | Purpose |
|---|---|---|
| `AgentJobsCore` | `Sources/AgentJobsCore/` | Domain types, Provider protocol, Discovery actors, Design tokens |
| `AgentJobsMac` | `Sources/AgentJobsMac/` | SwiftUI views (MenuBar + Dashboard), view-model |
| Tests | `Tests/AgentJobsCoreTests/` | Swift Testing — Providers, CronHumanizer, MenuBarSummary |

All source files target ≤ 400 LOC, all functions ≤ 50 LOC.

## Build & Run

```bash
cd macapp/AgentJobsMac
swift build           # debug build
swift run             # launches the menubar app
swift test            # 17/17 tests as of cycle 3
```

Requires Swift 5.9+ / macOS 14+. No Xcode required (uses SwiftPM + the
`swift-testing` package; on Swift 6 toolchains the in-tree testing module
will replace the dependency).

## Status

| Milestone | State |
|---|---|
| M1 SwiftUI scaffold (menubar + dashboard) | ✅ landed |
| M2 Service discovery layer | 🟡 1/9 providers (`AgentJobsJsonProvider`); registry actor wired |
| M3 Code review agent loop | ✅ active (30 min) |
| M4 Design review agent loop | ✅ active (30 min, +15 offset) |
| M5 Concurrent loop orchestration | ✅ landed |
| M6 Integration with `.review_strict/` | ✅ landed |

## Development loop

Three concurrent agents drive this codebase:

- `code-reviewer` → every 30 min → `.review/code/code-NNN.md`
- `design-reviewer` → every 30 min (+15) → `.design-review/design-NNN.md`
- `implementer` → every 15 min → reads ALL three streams (incl. `.review_strict/`)

Implementer ingests strict-review CRITICAL/HIGH first, then internal P0s.
Each cycle commits + pushes; impl notes go to `.implementation/impl-<ts>.md`.

Termination: all three streams report `DECLARE-DONE` for 2 consecutive cycles
AND `swift test` green AND `_open_issues.md` CRITICAL/HIGH empty → write
`.implementation/COMPLETE.md` to stop the loop.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md).

## License

Inherited from the parent repo.
