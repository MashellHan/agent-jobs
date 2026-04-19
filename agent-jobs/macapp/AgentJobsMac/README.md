# AgentJobsMac

Native macOS menubar app for monitoring every kind of background "service":
OS daemons (launchd), cron, brew services, login items, Claude Code scheduled
tasks, and live agent loops — all with **CPU + memory** at a glance.

## Build

```bash
cd macapp/AgentJobsMac
swift build
swift run
```

## Test

```bash
swift test
```

## Architecture

See `../../.implementation/macapp-architecture.md`.

Three concurrent loops drive development:

- `code-reviewer` agent — every 30 min → `.review/code/`
- `design-reviewer` agent — every 30 min (offset +15) → `.design-review/`
- `implementer` agent — every 15 min, ingests both review streams

Termination: both reviewers ≥ 90/100 for two consecutive cycles AND tests green.
