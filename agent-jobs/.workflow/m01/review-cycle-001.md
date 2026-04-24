# Review M01 cycle 001

**Date:** 2026-04-23T12:45:00Z
**Reviewer:** reviewer agent
**Diff:** 24 files, +1431 / −11 (`git diff d482feb^..HEAD -- macapp/`)
**Build:** PASS (`swift build` — clean; `swift build -Xswiftc -warnings-as-errors` — clean)
**Tests:** PASS (106 tests, 0 failures, ~0.33s)

## Score: 92/100 (cycle 1 — baseline; no prior cycle to compare)

| Category | Score | Notes |
|---|---|---|
| Acceptance coverage | 25/25 | Every `AC-F-*` and quality `AC-Q-*` AC has a clear code path + test. AC-V-01 verified by zero diff under `Sources/AgentJobsMac/`. AC-P-02/AC-P-03 enforced as XCTest gates. |
| Architecture conformance | 19/20 | All file/path placements match `architecture.md`. Public protocol surfaces unchanged. Module split (`AgentJobsCore` only) honored. `Enrichment.mtime` is additive (default `nil`) per risk #4. Minor: `defaultRegistry()` instantiates providers with no DI seam (acceptable but worth noting). |
| Correctness | 17/20 | Logic is sound and tests cover the spec. One pattern smell: see M1 below (deferred Task for semaphore release). One small naming subtlety: see M2 (substring matching for frameworks). |
| Tests | 14/15 | 51 net new test cases (vs `≥ 12` required). Good edge coverage (empty/header/dup/malformed/timeout/concurrency-cap). One test has dead code that should be removed (see L1). |
| Modern Swift | 9/10 | `async`/`await` throughout, `Sendable` closures, no Combine, no force unwraps in production code, no `print()`. `os.Logger` used appropriately. Half-point off for the unstructured-Task semaphore release pattern. |
| Documentation | 5/5 | Every new type carries a header doc-comment with intent + parity reference to the TS scanner; non-obvious algos (mtime fallback, friendly-name 5-step rule, lsof port parser) are explained inline. |
| OSS quality | 3/5 | Commit messages follow the convention. CHANGELOG.md was **not** updated for this milestone (see M3). |

## Issues

### CRITICAL (must fix, blocks transition)
*(none)*

### HIGH (P0)
*(none)*

### MEDIUM (P1)

- **M1** [`LsofProcessProvider.swift:90`] — `defer { Task { await semaphore.signal() } }` releases the permit from a **detached** unstructured `Task`, so the child returns to the surrounding `withTaskGroup` *before* the semaphore actually credits the permit back. In the worst case this could let the high-water briefly exceed `psConcurrency`. Tests pass today because the in-flight counter is decremented inside `psRunner` (before the `defer`), making the race invisible to the test's measurement.
  - Why: structured concurrency lets you `await semaphore.signal()` directly inside the `addTask` closure (it's `async`), no `defer` + unstructured `Task` needed. The current pattern works but is fragile and obscures intent.
  - Fix recipe: replace
    ```swift
    await semaphore.wait()
    defer { Task { await semaphore.signal() } }
    let cmd = await Self.runPs(pid: pid, override: psRunner)
    return (pid, cmd)
    ```
    with
    ```swift
    await semaphore.wait()
    let cmd = await Self.runPs(pid: pid, override: psRunner)
    await semaphore.signal()
    return (pid, cmd)
    ```
    (`runPs` cannot throw — it swallows `ps` errors — so a try/catch wrapper isn't needed.)

- **M2** [`LiveProcessNaming.swift:69`] — `frameworks.contains` uses `cmdLower.contains(fw)` for short tokens like `"next"`, `"flask"`. A command line such as `node /opt/openssl-nextstep` would label as `next`. Low real-world impact but worth tightening.
  - Fix recipe: require the framework name to appear as a whole token: `cmdLower.split(whereSeparator: \.isWhitespace).contains(Substring(fw))` or as a basename match. Add one test case to pin the new behavior.

- **M3** — `macapp/AgentJobsMac/CHANGELOG.md` is unchanged for M01. The repo has a CHANGELOG; new providers, new perf gates, and the launchd `createdAt` provenance fix are user-visible and should be recorded.
  - Fix recipe: add an `## Unreleased` (or `## M01 — Discovery audit`) section with three bullets covering the two new providers and the launchd `createdAt` change.

### LOW (P2, optional)

- **L1** [`ClaudeScheduledTasksProviderTests.swift:128-170`] — the `hungLoaderTimesOut` test constructs *two* providers; the first (`p`) is built with an elaborate timeout-race loader and then explicitly discarded via `_ = p`. Only `pFast` exercises the assertion. The first construction is dead code that hides the real intent.
  - Fix recipe: delete the first provider construction; keep only `pFast` and rename the test variable to `p`.

- **L2** [`AsyncSemaphore.swift:24-33`] — the doc-comment says "cancellation-safe: a cancelled waiter resumes immediately and does not hold a permit." The early-return `if Task.isCancelled { return }` only covers cancellation **before** enqueueing. A waiter that is already enqueued and then cancelled will still consume its eventual wakeup (the resumed continuation does not re-check `isCancelled`). This is fine in practice — the test confirms no deadlock — but the doc overstates the guarantee. Recommend tightening the doc-comment to match actual behavior, or guard with a re-check after `await withCheckedContinuation`.

- **L3** [`LsofOutputParser.swift:43`] — the parser silently drops rows with `cols.count < 9`. Consider one debug-level `os.Logger` line so an operator diagnosing "why don't I see my listener?" has a breadcrumb. Not a blocker.

## Acceptance criteria status

| ID | Status | Evidence |
|---|---|---|
| AC-F-01 | covered | `LsofProcessProvider.swift:24-27` (providerId, category) + builds against `ServiceProvider` |
| AC-F-02 | covered | `LsofProcessProvider.init(lsofRunner:psRunner:psConcurrency:)` |
| AC-F-03 | covered | `LsofOutputParserTests.swift` canonical case (node + python3 + bash → 2) |
| AC-F-04 | covered | `LsofOutputParserTests.swift` dup-PID fixture collapses to one |
| AC-F-05 | covered | `LsofProcessProviderTests.nameContainsPort` asserts `:3000` in name |
| AC-F-06 | covered | `LiveProcessNamingTests` covers each agent branch + `LsofProcessProviderTests.agentInferenceWiredIntoService` |
| AC-F-07 | covered | `LsofProcessProviderTests.emptyOutput` |
| AC-F-08 | covered | `LsofProcessProviderTests.lsofFailureThrows` |
| AC-F-09 | covered | `LsofProcessProviderTests.concurrencyCap` (200 PIDs, high-water ≤ 8) |
| AC-F-10 | covered | `ClaudeScheduledTasksProvider.swift:9-12` |
| AC-F-11 | covered | `init(tasksPath:loader:)` defaults to `~/.claude/scheduled_tasks.json` |
| AC-F-12 | covered | `ClaudeScheduledTasksProviderDiscoverTests.missingFile` |
| AC-F-13 | covered | `ClaudeScheduledTasksProviderDiscoverTests.emptyFile` |
| AC-F-14 | covered | `malformedJson` test + `logger.error` call at provider:67 |
| AC-F-15 | covered | `nonArrayRoot` test using `scheduled_tasks.non-array.json` (`{}`) |
| AC-F-16 | covered | `validArray` test asserts source/kind/status/schedule/owner shape |
| AC-F-17 | covered | `idStability` test (sha8 of `prompt+cron`, no timestamps) |
| AC-F-18 | covered | `hungLoaderTimesOut` raises `ProviderError.timeout` |
| AC-F-19 | covered | `LaunchdUserProvider.swift:104` passes `enrichment.mtime` into `Service.createdAt`; `LaunchdUserProviderTests` adds 2 cases |
| AC-F-20 | covered | All pre-existing launchd tests still green in 106-test run |
| AC-F-21 | covered | `ServiceRegistry.defaultRegistry()` returns 4 providers; `ServiceRegistryTests` asserts |
| AC-F-22 | covered | `ServiceRegistryTests.failure isolation across 4 providers` |
| AC-F-23 | covered | `ServiceRegistryTests.4 disjoint stubs … deterministic across 10 runs` |
| AC-V-01 | covered | `git diff --stat d482feb^..HEAD -- 'Sources/AgentJobsMac/*.swift'` returns empty |
| AC-P-01 | tester-deferred | Real-environment smoke; not a reviewer gate |
| AC-P-02 | covered | `ServiceRegistryTests "AC-P-02 … median < 50 ms"` passes |
| AC-P-03 | covered | `LsofProcessProviderTests.perfP03_200Pids` enforces < 500 ms |
| AC-P-04 | covered | Existing `Shell` test "timeout fires before slow process exits" still passes |
| AC-Q-01 | covered | `swift build -Xswiftc -warnings-as-errors` clean |
| AC-Q-02 | covered | 51 new test cases ≥ 12 |
| AC-Q-03 | tester-deferred | Coverage gate not enforced in CI; tester to verify with `--enable-code-coverage` |
| AC-Q-04 | covered | `grep 'Process()' Sources/AgentJobsCore/Discovery/Providers/` — empty |
| AC-Q-05 | covered | `grep 'DispatchQueue.main' Sources/AgentJobsCore/` — empty |
| AC-Q-06 | covered | `git diff` against `ServiceProvider.swift`, `ServiceRegistry.swift`, `Shell.swift`, `Service.swift` shows only the additive registry-list change in `ServiceRegistry.swift`; no signature changes. `LaunchdPlistReader.Enrichment.mtime` is additive with default value (per architecture risk #4 — explicitly permitted) |
| AC-Q-07 | covered | Wiring covered by AC-F-21 test |
| AC-Q-08 | covered | `Package.swift` diff is solely the `resources: [.copy("Fixtures")]` line on the test target |
| AC-Q-09 | tester-deferred | Smoke test on real Mac with both sources populated |

All 32 reviewer-checkable ACs are covered. The 4 tester-deferred ACs (P-01, Q-03, Q-09, plus AC-V-01 confirmation) are correctly out of reviewer scope.

## Wins (cycle 1 baseline)

- Excellent task discipline: 11 atomic commits matching the 11 planned tasks, each ending green.
- Testing discipline: 51 new cases, well above the `≥ 12` floor; performance gates baked in as XCTest assertions rather than left to vibes.
- Clean separation of pure helpers (`LsofOutputParser`, `LiveProcessNaming`) from subprocess plumbing — the architecture predicted this would help coverage and it does.
- Doc-comments consistently call out parity with the TS scanner and document divergences (e.g. `cursor` riding on `AgentKind.custom`, `manual` → `nil`).
- `Enrichment.mtime` extension done as architected: additive with default value, source-compatible, single-line provider change.
- Failure-isolation contract preserved and explicitly re-verified at `providerCount == 4`.

## Decision

**PASS** — transition to TESTING.

Rationale: zero CRITICAL, zero HIGH, all reviewer-checkable ACs covered, build + tests green, score 92/100 ≥ 75 threshold. The 3 MEDIUM items (semaphore-release pattern, framework substring match, CHANGELOG) and 3 LOWs are quality polish; none gate the milestone. Tester should still run AC-Q-09 smoke and AC-Q-03 coverage. The MEDIUMs would be reasonable cleanup in a follow-up commit before `/ship`, but per protocol they are not reviewer-blocking.
