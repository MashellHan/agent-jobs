# M01.5 Released

**Date:** 2026-04-24
**Cycles:** IMPL=1 REVIEW=1 TEST=1 (first-try ACCEPTED)

## Summary
Claude session-JSONL cron parser. Streams `~/.claude/projects/**/*.jsonl`, reconstructs CronCreate/CronDelete net set, dedups against `scheduled_tasks.json` so durable entries take precedence. Adds `SessionJSONLParser`, `CronTaskDeduper`, `ClaudeSessionCronProvider`. Wired into `defaultRegistry()` (now 5 providers).

## Acceptance
All 15/15 ACs PASS. Coverage on new files: 90.83% / 100% / 96.50%.

## Test count
145 → 145 (M01.5 added 34, M01 was 145 already... wait, this number rolled from 111 → 145 after T01-T04). Net: +34 tests across M01.5.
