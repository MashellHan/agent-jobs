# M03 Tasks

> Tests use **swift-testing** (`@Suite`, `@Test`, `#expect`) per E002.
> NOT XCTest. Each task = one atomic local commit, ≤150 LOC diff. Order
> respects dependency: Core (Domain → Persistence → Actions) before App
> (view model → views → visual tests).

Conventions:
- Estimated diff size: **S** ≤ 50 LOC, **M** ≤ 100 LOC, **L** ≤ 150 LOC.
- After each task: `swift build` + `swift test` green before commit.
- Commit message format: `impl(M03/T0X): <one-line summary>`.
- All new public types need swift-testing unit tests in the same task or
  a follow-up task explicitly listed.

---

## T01 — `LaunchdPlistReader.plistURL(forLabel:)` helper + tests
- Files:
  - **modify** `Sources/AgentJobsCore/Discovery/Providers/LaunchdPlistReader.swift` (+ ≤30 LOC)
  - **modify** `Tests/AgentJobsCoreTests/LaunchdPlistReaderTests.swift` (+ 2 `@Test` cases)
- Depends on: none
- Acceptance: `LaunchdPlistReader.plistURL(forLabel:)` returns the first
  existing `~/Library/LaunchAgents/<label>.plist` or
  `/Library/LaunchAgents/<label>.plist`, else `nil`. Tests cover the
  hit, miss, and tilde-resolution cases.
- Maps to AC: enables AC-F-04 + safety predicate #5 (consumed in T02/T03).
- Estimated diff: **S**

## T02 — `Service.canStop` + `RealStopExecutor.refusalReason` (pure refusal logic)
- Files:
  - **new** `Sources/AgentJobsCore/Actions/StopExecutor.swift` (protocol + `StopError` + `RealStopExecutor` skeleton with `static refusalReason` only — no `stop()` body yet, ~80 LOC)
  - **modify** `Sources/AgentJobsCore/Domain/Service.swift` (+ `canStop` extension, ~15 LOC)
  - **new** `Tests/AgentJobsCoreTests/StopExecutorRefusalTests.swift` (~120 LOC, ≥7 `@Test` cases covering the six refusal predicates + one positive `canStop == true`)
- Depends on: T01
- Acceptance: All refusal predicates from spec §"Safety rules" return the
  expected reason string. `canStop` returns `false` for each refusal case
  and `true` for a clean `.process` service with valid PID. Tests run
  without spawning any subprocess or sending any signal.
- Maps to AC: **AC-F-01**, **AC-F-02** (protocol declared), **AC-F-13**
  (canStop pre-disable basis).
- Estimated diff: **M**

## T03 — `RealStopExecutor.stop()` body + `FakeStopExecutor` + shell-shape tests
- Files:
  - **modify** `Sources/AgentJobsCore/Actions/StopExecutor.swift` (+ `stop()` impl, `FakeStopExecutor`, `init` guard for `AGENTJOBS_TEST=1`; ~80 LOC)
  - **new** `Tests/AgentJobsCoreTests/StopExecutorShellTests.swift` (~140 LOC; uses injected `ShellRunner` + `KillRunner` recorder closures; one `@Test` gated by `AGENTJOBS_INTEGRATION=1` env spawns `/bin/sleep 60` and verifies the live SIGTERM path)
- Depends on: T02
- Acceptance:
  - `RealStopExecutor.stop(.process)` calls injected `killRun` exactly once
    with `(pid, SIGTERM)`.
  - `RealStopExecutor.stop(.launchdUser)` calls injected `shellRun` with
    `("/bin/launchctl", ["unload", <plist>])`.
  - `FakeStopExecutor` records calls + replays scripted result.
  - `RealStopExecutor.init` `fatalError`s under `AGENTJOBS_TEST=1` without
    `AGENTJOBS_INTEGRATION=1`.
  - Default `swift test` run does NOT execute the live SIGTERM test.
- Maps to AC: **AC-F-02**, **AC-F-03**, **AC-F-04**.
- Estimated diff: **L**

## T04 — `HiddenStore` actor + atomic write + corrupt-recovery + tests
- Files:
  - **new** `Sources/AgentJobsCore/Persistence/HiddenStore.swift` (~140 LOC)
  - **new** `Tests/AgentJobsCoreTests/HiddenStoreTests.swift` (~150 LOC, temp HOME via `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)`)
- Depends on: none (parallelizable with T01-T03)
- Acceptance:
  - `add(_:)` / `remove(_:)` round-trip persists + reloads.
  - Atomic write via `replaceItemAt` proven by mid-write crash simulation
    (write a sentinel `.tmp`, assert `hidden.json` either contains old
    state or new state — never partial).
  - Corrupt JSON → load returns empty set + log; next `add` overwrites.
  - Unknown version → load returns empty set + log; next `add` overwrites.
  - Perf test (gated `AGENTJOBS_PERF=1`) asserts median round-trip
    < 50 ms over 50 runs (strict per E001).
- Maps to AC: **AC-F-08**, **AC-F-10**, **AC-F-11**, **AC-P-01**.
- Estimated diff: **L**

## T05 — `ServiceRegistryViewModel` action methods + tests
- Files:
  - **modify** `Sources/AgentJobsMac/AgentJobsMacApp.swift` (+ `hiddenIds`, `errorByServiceId`, `isRefreshing`, `optimisticallyStopped`, injected `stopExecutor` + `hiddenStore`, methods `stop(_:)`, `hide(_:)`, `unhide(_:)`, `refreshNow()`; existing `refresh()` gains optimistic-merge step; ~120 LOC net add)
  - **new** `Tests/AgentJobsCoreTests/ServiceRegistryViewModelActionsTests.swift` (~150 LOC, uses `FakeStopExecutor` + `HiddenStore` against a temp HOME; stub registry from `StubServiceRegistry`)
- Depends on: T03, T04
- Acceptance:
  - `stop()` calls the injected executor exactly once on success; flips
    the row optimistically to `.idle`; survives a subsequent `refresh()`
    landing with stale `.running` data (Q4 guard).
  - `stop()` failure populates `errorByServiceId[id]` and clears it
    after 4 ± 0.5 s.
  - `hide()` / `unhide()` mutate `hiddenIds` AND persist via the store.
  - `refreshNow()` is a no-op when already in flight; toggles
    `isRefreshing` true→false around the await.
  - `vm.stop()` with `service.canStop == false` does NOT call the
    executor (assertion: `fakeExecutor.calls.isEmpty`).
- Maps to AC: **AC-F-05** (binding-side), **AC-F-06**, **AC-F-07**,
  **AC-F-09** (vm side), **AC-F-12**, **AC-F-13** (vm side).
- Estimated diff: **L**

## T06 — `RowActionStack` + `ServiceRowNameCell` + `StopConfirmationDialog` views
- Files:
  - **new** `Sources/AgentJobsMac/Features/Dashboard/RowActionStack.swift` (~100 LOC)
  - **new** `Sources/AgentJobsMac/Features/Dashboard/ServiceRowNameCell.swift` (~120 LOC; `@State isHovered`, reveals stack on hover OR selected, calls `vm.pendingStop = service` etc.)
  - **new** `Sources/AgentJobsMac/Features/Dashboard/StopConfirmationDialog.swift` (~80 LOC; `ViewModifier` with `Binding<Service?>` for pending target, body text per source variant)
- Depends on: T05
- Acceptance:
  - Building succeeds; views render in a SwiftUI Preview.
  - No business logic in the views — only bind to the view model.
  - `RowActionStack` accepts `.iconOnly` or `.withLabels` style, disables
    Stop when `!service.canStop` with a tooltip explaining the reason.
- Maps to AC: scaffolding for **AC-F-05**, **AC-F-13**, AC-V-01..V-04.
- Estimated diff: **L**

## T07 — Wire dashboard toolbar + Inspector action bar + filter on hidden
- Files:
  - **modify** `Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift`:
    - Replace inline Name column content with `ServiceRowNameCell`.
    - Add toolbar group `[Show hidden Toggle] [Refresh button]` with
      `ProgressView()` overlay when `vm.isRefreshing`.
    - Extend `filter(_:category:bucket:)` → add `hiddenIds:` and
      `showHidden:` parameters; keep the existing 3-arg signature alive
      via a default-argument overload to not break tests.
    - Hang `StopConfirmationDialog` on the body root; bind to a new
      `@State pendingStop: Service?`.
    - Add empty-state branch for "all services hidden + show off".
    - Modify `ServiceInspector` to render an action bar above
      `TabChipRow` (uses `RowActionStack(.withLabels)`) and an
      `ErrorBanner` when `vm.errorByServiceId[service.id] != nil`.
  - **modify** `Tests/AgentJobsCoreTests/DashboardFilterTests.swift`:
    add cases for hidden-id filtering with showHidden on/off + perf
    case for AC-P-03 (gated `AGENTJOBS_PERF=1`).
- Depends on: T06
- Acceptance:
  - Toolbar hosts the toggle + refresh button.
  - Refresh button is disabled and shows a spinner when `isRefreshing`.
  - Hidden ids filtered out by default; toggle reveals them at 50%
    opacity with Unhide action replacing Hide.
  - Stop click on a row arms the dialog with that row as `pending`.
  - Filter perf test passes the < 10 ms median budget over 100 runs.
- Maps to AC: **AC-F-05** (UI side), **AC-F-09**, **AC-F-12** (UI side),
  **AC-F-13** (UI side), **AC-P-03**.
- Estimated diff: **L**

## T08 — Test-isolation guard + `Package.swift` env wiring
- Files:
  - **modify** `Package.swift` — set `AGENTJOBS_TEST=1` on the test target
    via `swiftSettings` `.define()` is not a runtime env; instead use
    `unsafeFlags` is wrong too. Concrete: add a tiny test bootstrap that
    sets `setenv("AGENTJOBS_TEST", "1", 1)` in a `@Suite(.serialized)`
    `init`. Easier: a `TestEnvSetup.swift` file in `Tests/` that runs at
    suite-discovery time:
    ```swift
    import Foundation
    @_cdecl("setupTestEnv") public func setupTestEnv() {}
    private let _ = { setenv("AGENTJOBS_TEST", "1", 1); return () }()
    ```
    via a top-level `let _ = …` initializer in the test bundle.
  - **new** `Tests/AgentJobsCoreTests/StopExecutorIsolationTests.swift`
    (~80 LOC):
    - `@Test` that scans `Tests/` via `Shell.run("/usr/bin/grep", ["-rl",
      "RealStopExecutor", "Tests/"])` and asserts the only matches are
      `StopExecutorIsolationTests.swift` itself and the gated integration
      test in `StopExecutorShellTests.swift`.
    - `@Test` that constructs `RealStopExecutor` inside a child
      `Process` with `AGENTJOBS_TEST=1` AND `AGENTJOBS_INTEGRATION` unset,
      asserts the child exits with a fatal-error termination signal.
- Depends on: T03
- Acceptance:
  - `AGENTJOBS_TEST=1` is observed in test runs (printable via a one-line
    `Logger.info` in `RealStopExecutor.init` guard).
  - Static-grep test passes (no rogue `RealStopExecutor` references in
    test code).
  - Child-process self-test asserts the fatalError fires.
- Maps to AC: **AC-Q-05** (the single biggest safety AC).
- Estimated diff: **M**

## T09 — Visual baselines (5 new) + harness fixture extension
- Files:
  - **modify** `Sources/AgentJobsCore/Testing/StubServiceRegistry.swift`
    (+ `Service.fixtures(includingHidden:withStopError:)` overload, ~40 LOC)
  - **modify** `Tests/AgentJobsCoreTests/Visual/VisualBaselineTests.swift`
    (+ five `@Test` cases, ~150 LOC):
    - `rowHoverActions_light` → AC-V-01
    - `showHiddenOn_light` + `showHiddenOff_light` → AC-V-02
    - `stopConfirmDialog_light` → AC-V-03
    - `inspectorStopEnabled_light` + `inspectorStopDisabled_light` → AC-V-04
    - `refreshSpinner_light` → AC-V-05
  - **new** `.workflow/m03/screenshots/baseline/*.png` (committed by
    implementer on first run via the M02 record-mode flow).
- Depends on: T07
- Acceptance:
  - All five visual `@Test` cases pass at the 2% threshold against the
    first-run baselines.
  - Render uses the existing harness; no new harness code.
- Maps to AC: **AC-V-01..V-05**.
- Estimated diff: **L**

## T10 — Quality gate sweep + acceptance cross-check
- Files:
  - **modify** `macapp/AgentJobsMac/CHANGELOG.md` (+ M03 entry, ~20 LOC)
  - **modify** `macapp/AgentJobsMac/README.md` if any user-visible
    behavior needs documenting (≤20 LOC; otherwise skip)
- Depends on: T01-T09
- Acceptance:
  - `swift build` green (AC-Q-01).
  - `swift test` green (AC-Q-02).
  - Test count net-positive ≥ +20 over M02 final 178 (AC-Q-03) — count
    via `swift test 2>&1 | grep "Test run with .* tests"`.
  - `Package.swift` diff is **empty** of new third-party deps (AC-Q-04;
    note T08 only modifies env wiring, not deps).
  - Manual diff review confirms no `Tests/` file imports
    `RealStopExecutor` outside the gated path (AC-Q-05).
  - Implementer writes `.workflow/m03/impl-cycle-001.md` with the
    AC matrix filled in.
- Maps to AC: **AC-Q-01..Q-05**, plus AC matrix audit.
- Estimated diff: **S**

---

## AC → Task coverage matrix (audit)

| AC | Task(s) |
|---|---|
| AC-F-01 | T02 |
| AC-F-02 | T02, T03 |
| AC-F-03 | T03 (gated) |
| AC-F-04 | T03 |
| AC-F-05 | T05, T06, T07 |
| AC-F-06 | T05 |
| AC-F-07 | T05 |
| AC-F-08 | T04 |
| AC-F-09 | T05, T07 |
| AC-F-10 | T04 |
| AC-F-11 | T04 |
| AC-F-12 | T05, T07 |
| AC-F-13 | T02, T05, T06, T07 |
| AC-V-01 | T09 |
| AC-V-02 | T09 |
| AC-V-03 | T09 |
| AC-V-04 | T09 |
| AC-V-05 | T09 |
| AC-P-01 | T04 |
| AC-P-02 | T07 (no regression — re-run M02's gated test) |
| AC-P-03 | T07 |
| AC-Q-01 | T10 |
| AC-Q-02 | T10 |
| AC-Q-03 | T10 |
| AC-Q-04 | T10 |
| AC-Q-05 | T08 |

All 26 ACs are covered by at least one task.

---

## Total: 10 tasks. Within the 5-12 task range.
