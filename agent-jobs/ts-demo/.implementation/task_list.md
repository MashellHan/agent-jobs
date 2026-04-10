# Task List — agent-jobs

## User Feedback Items

| # | Request | Status | Notes |
|---|---------|--------|-------|
| 1 | Schedule display: `cronToHuman()` for readable cron | DONE | `utils.ts` — converts `*/5 * * * *` → `every 5 min`, `always-on` → `daemon` |
| 2 | Registration time (`created_at`) in main table | DONE | Replaced LAST RUN with AGE column showing relative time (`7h ago`) |
| 3 | History view in detail panel | NOT STARTED | Requires data model change (`history` array on Job type) |
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
4. **Coverage thresholds at 60%**: Set as first milestone (v8 provider). Scanner system code pulls down aggregate — consider `v8 ignore` for lsof/ps calls.

## Remaining Structural Issues

- [ ] Go binary (4.9MB) in `agent-jobs/` root — should be deleted
- [ ] Project nested in `ts-demo/` — should be moved to repo root for npm publish
- [ ] Registry write race condition — no file locking
- [ ] No LaunchAgent scanner
- [ ] `detect.ts` reads stdin with `readFileSync(0)` — should use streams
