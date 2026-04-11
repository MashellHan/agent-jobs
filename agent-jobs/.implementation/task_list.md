# Task List — agent-jobs

## User Feedback Items

| # | Request | Status | Notes |
|---|---------|--------|-------|
| 1 | Schedule display: `cronToHuman()` for readable cron | DONE | `utils.ts` — converts `*/5 * * * *` → `every 5 min`, `always-on` → `daemon` |
| 2 | Registration time (`created_at`) in main table | DONE | Replaced LAST RUN with AGE column showing relative time (`7h ago`) |
| 3 | History view in detail panel | DESCOPED (v0.2.0) | Insufficient data model support in current hook architecture. The hook receives a single event per tool call — accumulating history requires persistent storage and dedup logic changes. Tracked for v0.2.0. |
| 4 | OpenClaw agent detection | DONE | Added to `scanner.ts` `inferAgent()` |

## Review Items Tracking

| Review | Items Fixed | Remaining |
|--------|------------|-----------|
| v001-v003 | Initial structure, TUI, detection patterns | Go binary, nested ts-demo/ |
| v004 | Async scanner, mock isolation, dedup test | Race condition, LaunchAgent, stdin |
| v005 | CLI regression, isDirectRun, shebang, job ID | — |
| v006 | Port extraction test, Next Run field, dts, splitting | — |
| v007 | Snapshot, Schedule+Agent in detail, README/CONTRIBUTING, coverage thresholds | History view |

## Architecture Decisions

1. **cronToHuman over raw cron display**: User feedback was clear — raw cron strings are unreadable. The utility handles common patterns and passes through unrecognized ones.
2. **AGE column replaces LAST RUN**: `created_at` relative time is more useful at a glance. Full timestamps remain in the detail panel.
3. **OpenClaw as agent type**: Added alongside claude-code, cursor, github-copilot. Matches the project's stated goal of being agent-agnostic.
4. **Coverage thresholds at 70/65/65/70**: Raised from initial 60/50/60/60. Current coverage (79/76/69/78) passes with margin.
5. **History view descoped to v0.2.0**: Hook architecture provides single-event capture per tool call. Accumulating per-job history requires persistent append storage and dedup rework — better suited for a dedicated feature cycle.

## Remaining Structural Issues

- [x] ~~Go binary in `agent-jobs/` root~~ — deleted (v012 restructure)
- [x] ~~Project nested in `ts-demo/`~~ — moved to repo root (v012 restructure)
- [ ] Registry write race condition — no file locking
- [ ] No LaunchAgent scanner
- [ ] `detect.ts` reads stdin with `readFileSync(0)` — should use streams
