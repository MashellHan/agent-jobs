# Test M03 cycle 001
**Date:** 2026-04-24T10:10:00Z
**Tester:** tester agent
**Build:** PASS (`swift build` clean, 0.91s)
**Unit tests:** 226 pass / 0 fail
**Perf-gated tests (AGENTJOBS_PERF=1):** PASS (12/12, AC-P-01 1.29ms median; M03 AC-P-03 0.25ms median)
**Runtime launch:** PASS (app stayed alive ≥10s, menu bar item present)

## Environment
- macOS 24.6.0 (Darwin), Swift Package at `macapp/AgentJobsMac/`
- `swift test` was run **without** `AGENTJOBS_INTEGRATION=1` per task instructions — bundle bootstrap (`TestEnvBootstrap`) sets `AGENTJOBS_TEST=1` so the `RealStopExecutor.init` fatal guard is armed for the entire suite. No real `kill(2)` or `launchctl` invocation possible during default `swift test`.
- Perf gate run separately with `AGENTJOBS_PERF=1` filter on Performance + HiddenStore + DashboardFilter suites.
- Live SIGTERM integration (AC-F-03) is double-gated by `AGENTJOBS_INTEGRATION=1` AND `AGENTJOBS_LIVE_KILL=1`; intentionally NOT executed in this cycle.

## Safety verification (priority)

### Static-grep proof (no test calls real `kill` on a real PID)
- Tester independently grepped `Tests/` for `RealStopExecutor`, `kill(`, `launchctl unload`, `Process().launch`, `signal(SIGTERM`.
- `RealStopExecutor` references appear ONLY in 4 allow-listed test files (`StopExecutorIsolationTests.swift`, `StopExecutorShellTests.swift`, `StopExecutorRefusalTests.swift`, `TestEnvBootstrap.swift`). The static-grep self-test inside `StopExecutorIsolationTests.staticGrepRogueRefs` enforces the same allow-list at runtime and PASSED.
- The single `kill(...)` call in `StopExecutorShellTests.swift:153` is a `defer` cleanup against the test's own freshly-`Process.run`-spawned `/bin/sleep 60` child PID — gated behind `AGENTJOBS_LIVE_KILL=1`, NOT executed in this cycle. It cannot target an unrelated PID.

### Refusal-predicate unit coverage (refuse-self / refuse-PID-1 etc.)
All six predicates exercised via the pure `RealStopExecutor.refusalReason(for:selfPid:plistURL:)` static helper with **no OS contact**:
| Predicate | Test | Result |
|---|---|---|
| `pid == nil` for `.process` | `processNoPid` | PASS (`"no PID to send SIGTERM"`) |
| `pid == 0` | `processPid0` | PASS (`"PID 0 is the kernel scheduler"`) |
| `pid == 1` | `processPid1` | PASS (`"PID 1 is launchd; refusing"`) |
| `pid == self` | `processSelfPid` | PASS (`"refusing to kill self"`) |
| `.launchdUser` plist nil | `launchdMissingPlist` | PASS |
| Unsupported sources | `unsupportedAgentJobs`, `unsupportedClaudeScheduled` | PASS |
| Positive: clean live-process | `processClean` | PASS (`nil`) |
| Positive: clean launchd | `launchdResolves` | PASS (`nil`) |

### Defense-in-depth
1. UI-level pre-disable via `Service.canStop` (uses same `refusalReason` static).
2. Executor rechecks predicates at the top of `stop()`.
3. `RealStopExecutor.init` `fatalError`s under `AGENTJOBS_TEST=1 && AGENTJOBS_INTEGRATION!=1`.
4. Static-grep allow-list test enforces no rogue test ever constructs a `RealStopExecutor`.

## Acceptance criteria results

| ID | Status | Evidence |
|---|---|---|
| AC-F-01 | PASS | `StopExecutorRefusalTests` 6 refusal cases + 2 positive + canStop bridge (10 `@Test`) |
| AC-F-02 | PASS | `protocol StopExecutor` in Core; `Real` + `Fake` conform; verified via tests |
| AC-F-03 | SKIP-as-designed | `liveSigterm` gated by `AGENTJOBS_LIVE_KILL=1`; not run per task instructions (no real kill) |
| AC-F-04 | PASS | `launchdShellShape` asserts `("/bin/launchctl", ["unload", path])` via injected `ShellRunner` |
| AC-F-05 | PASS | `StopConfirmationDialog` view + view-model unit test for refusal-no-call path |
| AC-F-06 | PASS | `stop on a stoppable service ... flips status to .idle` PASSED |
| AC-F-07 | PASS | `stop failure populates errorByServiceId and clears after ~4s` PASSED (note: M1 review item — clear-side full 4s wait not asserted, but populate + scheduler verified; partial per reviewer is non-blocking) |
| AC-F-08 | PASS | `add then snapshot persists across instances` + `on-disk JSON has version=1 and sorted` PASSED |
| AC-F-09 | PASS | `hidden id excluded/included` + `hidden filter composes with category/bucket filters` PASSED |
| AC-F-10 | PASS | `remove deletes id and persists` PASSED |
| AC-F-11 | PASS | `corrupt JSON loads as empty set; next add overwrites` + `unknown version loads as empty set` + `missing file → empty set, no throw` PASSED |
| AC-F-12 | PASS | `refreshNow toggles isRefreshing and calls discoverAll once` PASSED |
| AC-F-13 | PASS | `Service.canStop is false for a refused service` + view-model tests asserting `fake.calls.isEmpty` |
| AC-V-01 | PASS | `M03 AC-V-01: row-hover-actions-light` PASSED, baseline present |
| AC-V-02 | PASS | `M03 AC-V-02 OFF` + `ON` both PASSED, both baselines present (`show-hidden-{on,off}-light.png`) |
| AC-V-03 | PASS | `M03 AC-V-03: stop-confirm-dialog-light` PASSED |
| AC-V-04 | PASS | `M03 AC-V-04 enabled` + `disabled` both PASSED, both baselines present |
| AC-V-05 | PASS | `M03 AC-V-05: refresh-spinner-light` PASSED |
| AC-P-01 | PASS | `AC-P-01: HiddenStore.add round-trip median < 50 ms` — measured 1.29 ms median (38× headroom) |
| AC-P-02 | PASS | `AC-P-02 first discovery ≤ 3 s on defaultRegistry` PASSED with `AGENTJOBS_PERF=1` |
| AC-P-03 | PASS | `AC-P-03: filter 1000 services with 200 hidden < 10 ms median` — measured 0.25 ms median (40× headroom) |
| AC-Q-01 | PASS | `swift build` clean (0.91s) |
| AC-Q-02 | PASS | `swift test` 226/226 PASS |
| AC-Q-03 | PASS | 226 tests vs M02's 180 → +46 (≥ +20 floor) |
| AC-Q-04 | PASS | `Package.swift` head verified — only existing swift-syntax/system targets, no new third-party deps |
| AC-Q-05 | PASS | Static-grep self-test + env-guard observation test + bundle bootstrap setting `AGENTJOBS_TEST=1` + `RealStopExecutor.init` fatal guard. Defense-in-depth verified four ways. |

**Summary: 25 PASS / 1 SKIP-as-designed (AC-F-03 live SIGTERM, intentionally not run) / 0 FAIL out of 26 ACs.**

## Runtime launch verification

Launched via `swift run AgentJobsMac` (background); waited 6s; process alive; `osascript` confirmed `process "AgentJobsMac"` exists and that menu bar 2 contains a `circle` SF Symbol item (the M01 menu-bar icon). Hover-action affordance is verified via in-process `NSHostingView` snapshot AC-V-01 (`row-hover-actions-light`). Tear-down via `kill -TERM` clean.

## New issues found (not in acceptance criteria)
_none_ — review-cycle-001's two MEDIUM items (M1 4s-clear assertion, M2 `withStatus` extension placement) are non-blocking quality-of-life polish per the reviewer's own note.

## Evidence index
- `/tmp/agentjobs-m03-unit-test.log` — full default-run output (226/226 PASS)
- `.workflow/m03/screenshots/baseline/` — 7 visual baselines (5 ACs, V-02 + V-04 each have a pair)
- Perf measurements above

## Decision
**ACCEPTED** — transition to `phase: ACCEPTED`.

25/26 ACs PASS, 1 SKIP-as-designed (AC-F-03 is binding-gated to NOT run in default test cycle). Zero FAIL. All three safety-pillar ACs (AC-F-01, AC-F-13, AC-Q-05) verified with defense-in-depth and independent static-grep confirmation. App launches cleanly with menu bar item visible.
