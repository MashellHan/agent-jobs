# M03 Implementation Cycle 001

**Status:** complete; ready for REVIEWING.
**Implementer commits:** T01 → T10 (one per task) + this summary.
**Test count:** 226 passing (M02 finished at 180 → +46, exceeds AC-Q-03 ≥ +20 floor).

## Tasks completed

| Task | Title | Commit |
|---|---|---|
| T01 | LaunchdPlistReader.plistURL helper | impl(M03-T01) |
| T02 | Service.canStop + RealStopExecutor.refusalReason | impl(M03-T02) |
| T03 | RealStopExecutor.stop body + FakeStopExecutor + shell-shape tests | impl(M03-T03) |
| T04 | HiddenStore actor + atomic write + recovery | impl(M03-T04) |
| T05 | ServiceRegistryViewModel actions + tests | impl(M03-T05) |
| T06 | RowActionStack, ServiceRowNameCell, StopConfirmationDialog views | impl(M03-T06) |
| T07 | Dashboard toolbar + inspector action bar + hidden filter | impl(M03-T07) |
| T08 | Test-isolation static-grep + env-guard observation | impl(M03-T08) |
| T09 | 7 visual baselines + fixture overload | impl(M03-T09) |
| T10 | Quality gate sweep + CHANGELOG | impl(M03-T10) |

## Quality gates (AC-Q-01..05)

- AC-Q-01 `swift build` — green.
- AC-Q-02 `swift test` — 226/226 passing.
- AC-Q-03 test count net-positive — +46 over M02's 180 (≥ +20 required).
- AC-Q-04 no new third-party deps — `Package.swift` deps unchanged.
- AC-Q-05 no rogue RealStopExecutor refs — static-grep test passes;
  env-detection regression guard passes; integration tests gated by
  `AGENTJOBS_INTEGRATION=1` (only `StopExecutorShellTests` opts in).

## AC matrix (all 26)

| AC | Status | Coverage |
|---|---|---|
| AC-F-01 | PASS | StopExecutorRefusalTests (≥ 6 predicate cases) |
| AC-F-02 | PASS | `StopExecutor` protocol + Real + Fake + canStop test |
| AC-F-03 | GATED | StopExecutorShellTests `liveSigterm` (AGENTJOBS_LIVE_KILL=1) |
| AC-F-04 | PASS | StopExecutorShellTests `launchdShellShape` |
| AC-F-05 | PASS | StopConfirmationDialog wired in DashboardView; vm tests |
| AC-F-06 | PASS | ServiceRegistryViewModelActionsTests `stopHappyPath` |
| AC-F-07 | PASS | ServiceRegistryViewModelActionsTests `stopFailureErrorClears` |
| AC-F-08 | PASS | HiddenStoreTests `addPersists` + `onDiskShape` |
| AC-F-09 | PASS | DashboardFilterTests hidden cases + visual show-hidden ON/OFF |
| AC-F-10 | PASS | HiddenStoreTests `removePersists` |
| AC-F-11 | PASS | HiddenStoreTests `corruptFileRecovery` + `unknownVersionRecovery` |
| AC-F-12 | PASS | ServiceRegistryViewModelActionsTests `refreshNowToggle` |
| AC-F-13 | PASS | StopExecutorRefusalTests `serviceCanStopFalse` + vm `stopRefusedNoExecutorCall` |
| AC-V-01 | PASS | row-hover-actions-light baseline recorded |
| AC-V-02 | PASS | show-hidden-on/off baselines recorded |
| AC-V-03 | PASS | stop-confirm-dialog-light baseline recorded |
| AC-V-04 | PASS | inspector-stop-enabled/disabled baselines recorded |
| AC-V-05 | PASS | refresh-spinner-light baseline recorded |
| AC-P-01 | GATED | HiddenStoreTests `addPerformance` (AGENTJOBS_PERF=1, strict 50 ms) |
| AC-P-02 | PASS | M02 perf gate untouched (no new deps, no auto-refresh changes) |
| AC-P-03 | GATED | DashboardFilterTests `filterPerf` (AGENTJOBS_PERF=1, strict 10 ms) |
| AC-Q-01 | PASS | swift build green |
| AC-Q-02 | PASS | swift test green (226/226) |
| AC-Q-03 | PASS | +46 tests (≥ +20) |
| AC-Q-04 | PASS | Package.swift deps unchanged |
| AC-Q-05 | PASS | StopExecutorIsolationTests static-grep + env-guard |

26 of 26 ACs PASS or GATED-as-designed (per E001 strict-budget rule).

## Notable workarounds

1. **M02 inspector baseline re-recorded.** The M02
   `dashboard-inspector-populated-light.png` baseline was 13.7% pixel-diff
   from the M03 render after T07 added the inspector action bar. This is
   an intentional visual change called out in M03 architecture. Baseline
   was deleted and re-recorded; documented in `impl-notes.md`.

2. **AGENTJOBS_INTEGRATION env leak across tests.** `StopExecutorShellTests`
   sets the env var to bypass the `RealStopExecutor` init guard for its
   suite. Side effects analyzed in `impl-notes.md` — not a safety
   regression because (a) other tests use `FakeStopExecutor`, (b)
   production never sets the var, and (c) the static-grep test ensures
   only allow-listed test files reference `RealStopExecutor`.

3. **AC-V-03 confirmation dialog rendered as a static panel.** SwiftUI
   `.confirmationDialog` chrome cannot be deterministically captured by
   `NSHostingView` — per spec risk row, we capture the dialog's body
   content view instead (title + body string + button labels). Documented
   in the test's doc comment.

4. **Optimistic-flip semantics test inversion.** The architect's Q4 race
   guard says: "older flips are discarded (the refresh has had a chance
   to observe the real state)". The unit test was written to match this
   semantic — a stop followed by a refresh DROPS the optimistic overlay
   when the refresh started AFTER the flip. The protective branch (refresh
   started BEFORE flip) is exercised at the implementation level by the
   `flip > refreshStartedAt` comparison; covering the protective branch
   end-to-end would require a stub registry whose `discoverAll` blocks
   pending a release signal — out of scope for the M03 unit tier.

## Hand-off to REVIEWING

- All ten tasks DONE in tasks.md.
- 226 tests passing locally on Sonoma with `swift test`.
- No `git push` performed (per protocol; reviewer + tester gates first).
- Lock cleared; phase advanced to REVIEWING in CURRENT.md.
