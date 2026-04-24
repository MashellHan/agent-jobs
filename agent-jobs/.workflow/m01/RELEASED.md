# M01 Released

**Date:** 2026-04-24
**Final commit:** 538b638
**Cycles:** IMPL=2 REVIEW=2 TEST=2

## Summary
Discovery layer parity with the legacy TS scanner. Adds `LsofProcessProvider` (live process scanning via lsof) and `ClaudeScheduledTasksProvider`, wires both into the default registry, fixes launchd `createdAt` provenance from plist mtime, adds pure-helper splits (`LsofOutputParser`, `LiveProcessNaming`), and lifts test count from 55 → 111.

## Acceptance
All 37/37 acceptance criteria PASS (see `test-cycle-002.md`).

| Category | Pass |
|---|---|
| Functional | 23/23 |
| Performance | 4/4 |
| Quality gates | 9/9 |
| Visual (no UI changes) | 1/1 |

## Modules touched
- `AgentJobsCore.Discovery.Providers` — 2 new providers
- `AgentJobsCore.Discovery` — pure helpers (parser + naming + AsyncSemaphore)
- `AgentJobsCore.Discovery.LaunchdPlistReader` — additive `Enrichment.mtime`
- `Package.swift` — test target gains `resources: [.copy("Fixtures")]`
- No `AgentJobsMac` (UI) changes

## Deferred to future milestones
- `LsofProcessProvider.swift` line coverage at 77.87% (slightly under 80%) — pick up in a small coverage-push slot
- M01.5 — Claude session-JSONL parser (`CronCreate`/`CronDelete` net set + dedup against scheduled_tasks.json)
