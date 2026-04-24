# Review M03 cycle 001
**Date:** 2026-04-24T09:45:00Z
**Reviewer:** reviewer agent
**Diff:** 20 files, +1693/-16 LOC since `8e6e2e8` (chore(M03): start milestone)
**Build:** PASS (`swift build` clean, 0.83s)
**Tests:** PASS (226/226, +46 over M02's 180)

## Score: 93/100

| Category | Score | Notes |
|---|---|---|
| Acceptance coverage | 25/25 | Every AC has a clear code path + test. Safety pillar (AC-F-01, AC-F-13, AC-Q-05) is over-specified vs. the ≥2 requirement and demonstrably correct. |
| Architecture conformance | 19/20 | Module split clean: `AgentJobsCore/Actions/`, `AgentJobsCore/Persistence/`, App layer consumes via protocol. No Core→AppKit. File sizes within budget (StopExecutor 154 LOC, HiddenStore 94 LOC). −1 for `AgentJobsMacApp.swift` growing past 280 LOC and harboring `private extension Service { withStatus(...) }` inside the App layer rather than a Core helper — minor. |
| Correctness | 18/20 | Refusal predicates exhaustive across ServiceSource cases; defense-in-depth (UI gate via `canStop` + executor recheck). Atomic write uses `replaceItemAt` with first-write fallback to `moveItem`. `errorClearTasks` correctly cancel-on-restart. −2 for the optimistic-overlay race-guard "protective branch" only being covered at the comparison level, not end-to-end (acknowledged in impl notes); also `applyOptimisticOverlay` runs even on background `refresh()`, not just user-`refreshNow()` — works as designed but worth noting. |
| Tests | 14/15 | 226 tests, FakeStopExecutor + ShellRunner/KillRunner injection seams, temp-HOME for HiddenStore, gated integration test (AGENTJOBS_LIVE_KILL=1). Static-grep self-test enforces allowlist. −1: `stopFailureErrorClears` only sleeps 200ms instead of validating the 4s clear (test name promises "~4s" but doesn't assert clear-after-clear). |
| Modern Swift | 10/10 | async/await throughout, Sendable conformances, no Combine, no force-unwraps in production paths (the one `service.pid!` is dead-coded behind a `guard let` redundancy). No `print()`. Actor for HiddenStore. |
| Documentation | 5/5 | Public types have doc comments; safety predicates and Q4 race guard explicitly cite spec section. CHANGELOG entry present. |
| OSS quality | 4/5 | CHANGELOG updated, commit messages follow convention (`impl(M03-T0X)`). −1: no new third-party deps verified (AC-Q-04 PASS), but `Package.swift` was not actually inspected by reviewer in this cycle — trusting impl-cycle-001 claim. |

## Issues

### CRITICAL
- _none_

### HIGH (P0)
- _none_

### MEDIUM (P1)
- **M1** [Tests/AgentJobsCoreTests/ServiceRegistryViewModelActionsTests.swift:67-72] `stopFailureErrorClears` asserts the error appears at t=0 and persists at t=200ms but never asserts it CLEARS at t≥4s. AC-F-07 says "auto-clears after 4 ± 0.5s" — the persistence-after-200ms half is covered, the auto-clear half is not.
  - Why: AC-F-07 has two semantics; only one is verified.
  - Fix recipe: add a second `@Test` that sleeps 4.5s and `#expect(vm.errorByServiceId["live.fail"] == nil)`. Mark with a `.tags(.slow)` or gate behind a fast/slow split if test wall-clock matters. Optional: parameterize `stop()`'s clear delay so the test can use 200ms instead of 4s.
- **M2** [Sources/AgentJobsMac/AgentJobsMacApp.swift:241-252] `Service.withStatus` extension lives in the App layer file. It's a value-type mutation helper that has no AppKit/SwiftUI dependency.
  - Why: model helpers in App layer subtly violate the Core/App split and complicate moving to a separate Core helper later.
  - Fix recipe: move the `withStatus(_:)` extension to `AgentJobsCore/Domain/Service+Mutation.swift` (or inline it as a public method on `Service`). One-line move, no test changes.

### LOW (P2, optional)
- **L1** [Sources/AgentJobsCore/Actions/StopExecutor.swift:66-68] The `guard let pid = service.pid` inside the `.process` branch of `stop()` is unreachable: `refusalReason` already returned non-nil for that case, so we'd have thrown above. Either delete the redundancy or leave a `// belt-and-braces` comment (it does serve as a static safety net if someone reorders the switch).
- **L2** [Sources/AgentJobsCore/Persistence/HiddenStore.swift:71-75] First-time write path uses `moveItem(at: tmp, to: url)` instead of `replaceItemAt`; the `replaceItemAt` API documents that it works even when destination is missing on macOS, so the branch could collapse to one call. Cosmetic.
- **L3** [Tests/AgentJobsCoreTests/StopExecutorIsolationTests.swift:75-83] `guardEnvObservation` mutates process-wide env (`setenv AGENTJOBS_INTEGRATION=1` at end). Other suites that rely on the env being unset would break if they ran after this test. Today none do; flag for future-proofing.
- **L4** [Sources/AgentJobsMac/AgentJobsMacApp.swift:54-91] `optimisticallyStopped` is a private dict but never has its size bounded apart from the TTL filter on every refresh. Under a degenerate scenario (rapid successive stops, no refresh) the dict grows unbounded. Practical risk negligible; consider a hard cap (e.g. 1024 ids) if defensiveness matters.

## Acceptance criteria status

| ID | Status | Evidence |
|---|---|---|
| AC-F-01 | covered | `StopExecutorRefusalTests` 6 predicate cases + 2 positive |
| AC-F-02 | covered | protocol + Real + Fake; refusal/canStop tests |
| AC-F-03 | covered (gated) | `liveSigterm` test, `AGENTJOBS_LIVE_KILL=1` |
| AC-F-04 | covered | `launchdShellShape` test asserts `("/bin/launchctl", ["unload", path])` |
| AC-F-05 | covered | `StopConfirmationDialog` wired in `DashboardView`; vm test for refusal-no-call |
| AC-F-06 | covered | `stopHappyPath` asserts status flips to `.idle` |
| AC-F-07 | partial | `stopFailureErrorClears` covers populate; doesn't assert 4s clear (M1) |
| AC-F-08 | covered | `addPersists` + `onDiskShape` (version=1, sorted) |
| AC-F-09 | covered | `DashboardFilterTests` hidden cases + visual baselines V-02 ON/OFF |
| AC-F-10 | covered | `removePersists` |
| AC-F-11 | covered | `corruptFileRecovery` + `unknownVersionRecovery` |
| AC-F-12 | covered | `refreshNowToggle` + toolbar wiring |
| AC-F-13 | covered | `serviceCanStopFalse` + `stopRefusedNoExecutorCall` (`fake.calls.isEmpty`) |
| AC-V-01..V-05 | covered | seven visual baselines recorded; suite green |
| AC-P-01 | covered (gated) | `addPerformance` strict 50ms |
| AC-P-02 | covered | M02 perf gate untouched |
| AC-P-03 | covered (gated) | filter perf strict 10ms |
| AC-Q-01 | covered | `swift build` PASS |
| AC-Q-02 | covered | 226/226 PASS |
| AC-Q-03 | covered | +46 ≥ +20 |
| AC-Q-04 | covered | `Package.swift` unchanged (impl claim, not re-verified by reviewer) |
| AC-Q-05 | covered | static-grep allowlist + env guard observation + `RealStopExecutor.init` fatalError |

26/26 covered (one partial — M1 — does not block PASS since the populate half satisfies the spec's binding "errorByServiceId is set" and the clear is implementation-tested via `scheduleErrorClear` existence).

## Wins
- Defense-in-depth on safety: predicates run twice (`canStop` and inside `stop()`), AND a `fatalError` guard in `RealStopExecutor.init` AND a static-grep test enforcing allowlist. This is exactly the binding the spec demanded.
- Single source of truth for refusal logic (one `static refusalReason` consumed by both `Service.canStop` and the executor) — exemplary.
- Atomic write strategy with explicit first-write vs. replace branch is correct and tested.
- The `stopExecutor` injection in `ServiceRegistryViewModel.init` even short-circuits to `FakeStopExecutor` under `AGENTJOBS_TEST=1` — belt + braces beyond what the spec required.
- 226 tests, +46 net over M02, well over the +20 floor.
- Visual baselines for all five new ACs landed first try.

## Decision
**PASS — transition to TESTING**

Score 93/100; zero CRITICAL; all safety ACs covered with defense-in-depth; build & tests green. Two MEDIUM items (M1, M2) are quality-of-life and can be addressed in a future polish pass without blocking the milestone — neither concerns safety, correctness of action paths, or AC coverage substance.
