# M04 Tasks

> Tests use **swift-testing** (`@Suite`, `@Test`, `#expect`) per E002. NOT XCTest.
> Perf-sensitive tests gated behind `AGENTJOBS_PERF=1` per E001 — strict spec
> assertion only, no relaxed fallback.
> AC-F-15 was DROPPED by architect (rationale in architecture.md §"Open
> questions"). AC-V-05 was KEPT (dashboard-toolbar indicator placement).
> Final AC scope: F=14 + V=5 + P=5 + Q=6 = 30 ACs.

8 tasks total. Each ≤ 150 LOC diff. Order by dependency.

---

## T01 — Refresh primitives (WatchPaths + RefreshTrigger + RefreshScheduler) [DONE]

- **Files (create):**
  - `Sources/AgentJobsCore/Refresh/WatchPaths.swift` (~50 LOC)
  - `Sources/AgentJobsCore/Refresh/RefreshTrigger.swift` (~30 LOC)
  - `Sources/AgentJobsCore/Refresh/RefreshScheduler.swift` (~120 LOC)
  - `Tests/AgentJobsCoreTests/Refresh/RefreshSchedulerTests.swift` (~140 LOC, 6 `@Test`s)
- **Depends on:** none
- **Acceptance:** AC-F-01, AC-F-14, AC-P-02 (gated). Unit tests cover:
  - 5 triggers within 100 ms → exactly 1 sink call within 250+50 ms of LAST trigger
  - In-flight guard: trigger arriving during sink await → exactly 2 sink calls total
  - `flushNow()` skips the debounce + still respects in-flight guard
  - Mixed trigger sources (.fileEvent, .periodic, .manual) all collapse
  - `cancel()` drops a pending work item without firing the sink
  - `lastTriggers` records the storm for logging
- **Estimated diff size:** M (~340 LOC)

## T02 — FileObjectWatcher (DispatchSource + atomic-rename re-open) [DONE]

- **Files (create):**
  - `Sources/AgentJobsCore/Refresh/FileObjectWatcher.swift` (~150 LOC)
  - `Tests/AgentJobsCoreTests/Refresh/FileObjectWatcherTests.swift` (~140 LOC, 6 `@Test`s)
- **Depends on:** T01 (none in code, but conceptually follows)
- **Acceptance:** AC-F-02, AC-F-03, AC-F-04, AC-F-13. Unit tests cover:
  - Plain write through same fd fires `onEvent` within 100 ms
  - Two consecutive temp+rename writes fire `onEvent` TWICE; watcher remains live
  - Re-open succeeds within 200 ms after `.delete`/`.rename`
  - Install on non-existent path: NOT crash, calls `onInstallFailure` after 3 retries
  - `stop()` releases fd cleanly (verify by re-installing on same path)
  - Two-instance independence (jobs.json and scheduledTasks watchers don't cross-fire)
- **Estimated diff size:** M (~290 LOC)

## T03 — DirectoryEventWatcher (FSEventStream for ~/.claude/projects/) [DONE]

- **Files (create):**
  - `Sources/AgentJobsCore/Refresh/DirectoryEventWatcher.swift` (~120 LOC)
  - `Tests/AgentJobsCoreTests/Refresh/DirectoryEventWatcherTests.swift` (~110 LOC, 4 `@Test`s)
- **Depends on:** none
- **Acceptance:** AC-F-05, AC-F-13. Unit tests cover:
  - Create `subdir/session.jsonl` under temp dir → `onEvent` fires within 500 ms
  - Modify existing `session.jsonl` → `onEvent` fires
  - Path filter: a `.DS_Store` write under the dir does NOT fire `onEvent`
  - Install on non-existent dir: calls `onInstallFailure`, does not crash
  - No spurious history-replay events in first 250 ms after install (uses `kFSEventStreamEventIdSinceNow`)
- **Estimated diff size:** M (~230 LOC)

## T04 — PeriodicTicker + VisibilityProvider (protocol + Fake) [DONE]

- **Files (create):**
  - `Sources/AgentJobsCore/Refresh/PeriodicTicker.swift` (~80 LOC)
  - `Sources/AgentJobsCore/Refresh/VisibilityProvider.swift` (~80 LOC)
  - `Tests/AgentJobsCoreTests/Refresh/PeriodicTickerTests.swift` (~120 LOC, 4 `@Test`s)
- **Depends on:** none
- **Acceptance:** AC-F-06, AC-F-12, AC-P-03 (gated). Unit tests cover:
  - `start()` then wait 250 ms with interval=100 ms → ≥ 2 ticks observed
  - `pause()` then wait 1 s with interval=100 ms → 0 periodic ticks (keepalive long enough)
  - `resume()` after pause → immediate catch-up tick within 50 ms + re-arm
  - `cancel()` then verify task is `.isCancelled`; no further ticks
  - `FakeVisibilityProvider.set(false)` flips the AsyncStream value within one iteration
- **Estimated diff size:** M (~280 LOC)

## T05 — ServiceRegistryViewModel rewire (startWatchers + lastRefreshError + popoverOpen) [DONE]

- **Files (modify):**
  - `Sources/AgentJobsMac/AgentJobsMacApp.swift` (~+90 LOC, ~−15 LOC)
  - `Sources/AgentJobsMac/Features/MenuBar/MenuBarViews.swift` (set/clear `popoverOpen`, ~+8 LOC)
- **Files (create):**
  - `Sources/AgentJobsMac/Refresh/AppKitVisibilityProvider.swift` (~120 LOC)
  - `Tests/AgentJobsCoreTests/ServiceRegistryViewModelWatchersTests.swift` (~150 LOC, 6 `@Test`s)
- **Depends on:** T01, T02, T03, T04
- **Acceptance:** AC-F-07, F-08, F-09, F-10, F-11, F-12, P-01 (gated), P-04 (gated). Unit tests cover:
  - `init(watchPaths: nil)` resolves to `.production` (paths under `NSHomeDirectory()`) — assertion only on URL string shape, no FS touch
  - `startWatchers()` is idempotent (second call no-op)
  - End-to-end: write to temp `jobs.json` → `vm.services` reassigned within median 500 ms over 20 runs (gated AC-P-01)
  - `isRefreshing` flips true→false around any refresh trigger; `lastRefreshError` non-nil iff `result.allFailed`
  - 10 consecutive refreshes against identical-output stub → `services.count` never transiently 0; `id` ordering identical across all frames
  - Visibility false → ticker pauses; visibility true → catch-up tick fires within 250 ms
  - `stop()` cancels scheduler, all 3 watchers, ticker, visibility task; assert references nilled / Tasks cancelled
  - Watcher install failure for `jobsJson` → `lastRefreshError` set, OTHER watchers still installed (AC-F-13)
  - Main-thread non-block: 8 ms checkpoint loop during refresh asserts no inter-checkpoint gap > 16 ms (gated AC-P-04)
- **Estimated diff size:** L (~370 LOC; if it bleeds, split tests into a second file)

## T06 — AutoRefreshIndicator three-state rewrite + dashboard toolbar placement [DONE]

- **Files (modify):**
  - `Sources/AgentJobsMac/Features/MenuBar/AutoRefreshIndicator.swift` (rewrite, ~+90 LOC, −20 LOC)
  - `Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift` (insert indicator into toolbar, ~+20 LOC)
- **Depends on:** T05 (consumes `viewModel.lastRefreshError`)
- **Acceptance:** drives AC-V-01, V-02, V-03, V-05. Indicator renders three states from view-model state; placed in BOTH popover (existing) and dashboard toolbar (new — left of M03 Refresh button). Tooltip names the failure when in error state. Pulse animation gated by `accessibilityReduceMotion`.
- **Estimated diff size:** S (~110 LOC net)

## T07 — Visual baselines: 3 indicator states + placement + selection persistence [DONE]

- **Files (create):**
  - `Tests/AgentJobsCoreTests/Visual/AutoRefreshIndicatorVisualTests.swift` (~140 LOC, 4 `@Test`s)
  - `Tests/AgentJobsCoreTests/Visual/SelectionPersistenceVisualTests.swift` (~100 LOC, 1 `@Test`, 10× refresh inside)
- **Files (create — baselines):**
  - `.workflow/m04/screenshots/baseline/indicator-idle-light.png`
  - `.workflow/m04/screenshots/baseline/indicator-idle-dark.png`
  - `.workflow/m04/screenshots/baseline/indicator-refreshing-light.png`
  - `.workflow/m04/screenshots/baseline/indicator-error-light.png`
  - `.workflow/m04/screenshots/baseline/popover-with-indicator-light.png`
  - `.workflow/m04/screenshots/baseline/dashboard-toolbar-with-indicator-light.png`
  - `.workflow/m04/screenshots/baseline/dashboard-selection-preserved-light.png`
  - (recorded on first run via `[BASELINE_RECORDED]` flow inherited from M02)
- **Depends on:** T06
- **Acceptance:** AC-V-01, V-02, V-03, V-04, V-05. Reuses M02 `ScreenshotHarness` + `scripts/visual-diff.sh` at 2 % threshold. Refreshing-state baseline captured with `accessibilityReduceMotion = true` to suppress pulse-phase jitter. Selection-persistence test runs 10 refreshes against an identical-output stub registry with row #3 selected; all post-refresh frames must match the pre-refresh baseline.
- **Estimated diff size:** M (~240 LOC + 7 PNGs)

## T08 — Static-grep guards + remove obsolete `startAutoRefresh()` references

- **Files (modify):**
  - Whichever file currently hosts `StaticGrepRogueRefsTests` (extend with M04 patterns), or create `Tests/AgentJobsCoreTests/StaticGrepRogueRefsTests.swift` if absent (~120 LOC)
  - `Sources/AgentJobsMac/AgentJobsMacApp.swift` (final cleanup — confirm `startAutoRefresh` is gone, both `.task` callers route through `startWatchers`)
- **Depends on:** T05, T06, T07
- **Acceptance:** AC-Q-04, AC-Q-06. Tests:
  - No test file string-references `.agent-jobs/`, `.claude/scheduled_tasks.json`, `.claude/projects`, or `NSHomeDirectory()` outside a documented allow-list (the watchers default-paths-resolution test in `ServiceRegistryViewModelWatchersTests`)
  - Every test file that constructs `ServiceRegistryViewModel(` ALSO calls `.stop()` in the same file (or uses a `withViewModel` helper if architect later extracts one — out of M04 scope)
  - Assert `Package.swift` has no new dependency entries vs M03 baseline (AC-Q-05)
  - Assert `swift build` passes (delegated to CI / AC-Q-01)
- **Estimated diff size:** S (~140 LOC test scaffolding)

---

## AC → Task coverage matrix

| AC | Task(s) |
|---|---|
| AC-F-01 funnel through scheduler | T01 |
| AC-F-02 jobs.json watcher | T02, T05 |
| AC-F-03 scheduled_tasks watcher | T02, T05 |
| AC-F-04 atomic-rename re-open | T02 |
| AC-F-05 FSEventStream on claude/projects | T03, T05 |
| AC-F-06 periodic 10 s tick | T04, T05 |
| AC-F-07 visibility pause/resume | T04, T05 |
| AC-F-08 file watchers stay armed during pause | T05 |
| AC-F-09 isRefreshing + lastRefreshError | T05 |
| AC-F-10 in-place mutation, no transient empty | T05, T07 (visual stress) |
| AC-F-11 WatchPaths Sendable + production resolution | T01, T05 |
| AC-F-12 stop() cancels everything | T01, T02, T03, T04, T05 |
| AC-F-13 watcher-install failure surfaces error | T02, T03, T05 |
| AC-F-14 in-flight guard | T01 |
| ~~AC-F-15~~ DROPPED — covered indirectly by M03 tests under AC-Q-01 | (none) |
| AC-V-01 idle baseline | T06, T07 |
| AC-V-02 refreshing baseline | T06, T07 |
| AC-V-03 error baseline | T06, T07 |
| AC-V-04 selection-persistence | T07 |
| AC-V-05 popover + dashboard placement | T06, T07 |
| AC-P-01 500 ms median latency (gated) | T05 |
| AC-P-02 debounce correctness (gated) | T01 |
| AC-P-03 zero ticks while hidden (gated) | T04, T05 |
| AC-P-04 main-thread ≤ 16 ms (gated) | T05 |
| AC-P-05 no M02/M03 perf regression | T08 (re-runs existing perf suite) |
| AC-Q-01 swift build green | all (CI) |
| AC-Q-02 ≥ 80 % coverage on changed lines | all |
| AC-Q-03 +20 tests over M03 (target +30) | T01, T02, T03, T04, T05, T07, T08 |
| AC-Q-04 no real `~/` writes from tests | T08 |
| AC-Q-05 no new package dependency | T08 |
| AC-Q-06 every VM construction has matching .stop() | T08 |

Every kept AC has ≥ 1 task. AC-F-15 is the only gap and is intentionally dropped per architect decision.

---

## Sequencing rationale

- T01 → T02/T03/T04 in parallel (all consume `RefreshTrigger`/`RefreshScheduler` only conceptually). Implementer may interleave.
- T05 needs all of T01-T04 (it composes them).
- T06 needs T05 (indicator reads new view-model state).
- T07 needs T06 (rendering must exist before baselines are recorded).
- T08 is a guard-rail / cleanup pass at the end — runs against the finished state.
