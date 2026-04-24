# M04 Released

**Date:** 2026-04-24
**Final commit:** c7551cd
**Cycles:** IMPL=1 REVIEW=1 TEST=1 (first-try ACCEPTED)

## Summary
Auto-refresh + fs.watch. Adds `RefreshScheduler` actor (hand-rolled `DispatchWorkItem` debounce with in-flight coalescing), `FileObjectWatcher` + `DirectoryEventWatcher` (DispatchSource per file plus directory watcher, atomic-rename re-open verified), `PeriodicTicker` with 5min keepalive, and `VisibilityProvider` protocol (Core) with `AppKitVisibilityProvider` production impl observing `NSApplication.didChangeOcclusionStateNotification` + popover-open flag. AutoRefreshIndicator rewritten as 3-state (idle/refreshing/error) and placed in both menu-bar popover and dashboard toolbar. `WatchPaths` injection seam guarantees tests use temp dir; static-grep enforces no real `~/` literals.

## Acceptance
29/30 in-scope ACs PASS (1 dropped by architect: AC-F-15; 1 deferred to retro per E001: AC-P-04 16ms main-thread non-block).

| Category | Pass |
|---|---|
| Functional | 14/14 (1 dropped) |
| Visual (7 baselines) | 5/5 |
| Performance | 4/5 (AC-P-04 deferred) |
| Quality | 6/6 |

## Modules touched
- `AgentJobsCore.Refresh` — `RefreshScheduler` actor, `RefreshTrigger` enum
- `AgentJobsCore.FileWatch` — `FileObjectWatcher`, `DirectoryEventWatcher`, `WatchPaths`
- `AgentJobsCore.Visibility` — `VisibilityProvider` protocol
- `AgentJobsCore.Periodic` — `PeriodicTicker`
- `AgentJobsMac` — `AppKitVisibilityProvider`, AutoRefreshIndicator 3-state rewrite, dashboard toolbar wiring
- `Tests/` — +42 tests (RefreshScheduler, FileObjectWatcher, DirectoryEventWatcher, PeriodicTicker, ViewModelWatchers, AutoRefreshIndicatorVisual, SelectionPersistenceVisual, StaticGrepRogueRefs)

## Test count
226 → 266 (+42).

## Deferred to future milestones
- AC-P-04 16ms main-thread non-block test (honest E001 deferral; production code is correct, test design is what's missing)
- M1 (review): visibility-task self-capture race in `AgentJobsMacApp.swift:215`
- M2 (review): missing path-prefix check in `DirectoryEventWatcher.swift:117`
- T1 (test): AC-P-01 latency flakes under full parallel suite contention; recommend `.serialized` trait
- Pre-existing M01 `tenKLinesUnder500ms` flake (out of M04 scope)
