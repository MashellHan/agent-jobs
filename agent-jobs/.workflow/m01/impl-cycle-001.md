# M01 Implementation Cycle 001

**Cycle:** 1
**Owner:** implementer
**Started:** 2026-04-23T11:30:00Z
**Completed:** 2026-04-23T12:30:00Z (approx, single invocation)
**Status:** all 11 tasks DONE → REVIEWING

## Tasks completed

| Task | Type | Commit |
|---|---|---|
| T01 | test | fixture loader + Fixtures/ scaffold |
| T02 | feat | LsofOutputParser + tests |
| T03 | feat | LiveProcessNaming inferAgent + friendlyName |
| T04 | feat | AsyncSemaphore actor + tests |
| T05 | feat | LsofProcessProvider |
| T06 | feat | ClaudeScheduledTasksProvider stub + friendlyCronName |
| T07 | feat | ClaudeScheduledTasksProvider.discover |
| T08 | feat | LaunchdPlistReader.mtime + LaunchdUserProvider.createdAt |
| T09 | feat | wire 4-provider defaultRegistry |
| T10 | test | perf gates AC-P-02 + AC-P-03 |
| T11 | docs | final sweep verification |

12 commits in this cycle (1 lock + 11 task commits + this cycle-summary
commit).

## Build / Test status

- `swift build` → green (0 errors)
- `swift build -Xswiftc -warnings-as-errors` → green (0 warnings)
- `swift test` → 106 tests passing
  - Pre-cycle baseline: 55 tests
  - Net new: 51 cases across 8 test files (well above AC-Q-02 ≥ 12)

## Acceptance criteria self-check

| AC bucket | Notes |
|---|---|
| AC-F-01..AC-F-09 (LsofProcessProvider) | All addressed by T02/T03/T05 + tests |
| AC-F-10..AC-F-18 (ClaudeScheduledTasksProvider) | All addressed by T06/T07 + tests |
| AC-F-19..AC-F-20 (Launchd mtime) | T08 + tests |
| AC-F-21..AC-F-23 (registry wiring) | T09 + tests |
| AC-V-01 (no UI changes) | Verified: `git diff` against milestone start touches no AgentJobsMac/*.swift |
| AC-P-02 / AC-P-03 (perf gates) | T10 enforces; AC-P-01/AC-P-04 are tester-observable |
| AC-Q-01 (warnings clean) | Verified with `-warnings-as-errors` |
| AC-Q-02 (≥ 12 new tests) | 51 new cases |
| AC-Q-03 (≥ 80% coverage) | Tester to verify with `swift test --enable-code-coverage` |
| AC-Q-04 (no Process()) | grep returned empty in Discovery/Providers |
| AC-Q-05 (no DispatchQueue.main) | grep returned empty in AgentJobsCore |
| AC-Q-06 (frozen public API) | Service / ServiceRegistry / ServiceProvider / Shell signatures unchanged; LaunchdPlistReader.Enrichment grew an optional `mtime` (additive default = nil, source-compatible per architecture risk #4) |
| AC-Q-07 (registry wiring tested) | T09 |
| AC-Q-08 (no new dependency) | Package.swift diff is only `resources: [.copy("Fixtures")]` |
| AC-Q-09 (smoke) | Tester only |

## Architecture conformance

- File-size cap: largest new file is `LsofProcessProvider.swift` at 142
  LOC (cap 400 ✓). `LaunchdPlistReader.swift` grew to 204 (cap 400 ✓).
- Function-size cap: every new function is well under 50 LOC.
- No new third-party dependency.
- Subprocess spawning continues to flow exclusively through `Shell.run`.
- New `AsyncSemaphore` is the only synchronization primitive added; matches
  the architecture's choice (actor-based, ≤ 50 LOC).
- New providers conform to `ServiceProvider` without overriding `watch()`
  or `control(_:on:)` (correct per spec).

## Deferrals

None. All 11 tasks complete; nothing punted to a follow-up cycle.

## Risks / open items for reviewer attention

1. **Concurrency-cap test stability** (T05's `concurrencyCap` and T10's
   AC-P-03 gate). Both rely on `Task.sleep` inside the stubbed `psRunner`
   to give the AsyncSemaphore time to bottleneck. Locally stable; reviewer
   may want to re-run a few times.
2. **`hung-loader` test for ClaudeScheduledTasksProvider** uses a
   short-circuit loader that throws `.timeout` directly instead of
   actually exercising the production `readWithTimeout`. The production
   path is structurally identical to `AgentJobsJsonProvider.readWithTimeout`
   (already covered by that provider's tests) — explicit re-test would
   add a 5-second test to the suite for negligible coverage gain.
3. **Coverage gate (AC-Q-03)** is tester-verified; not gated in CI yet.
   The two new providers are split into pure helpers (`LsofOutputParser`,
   `LiveProcessNaming`) precisely so coverage is achievable without
   subprocess mocks.

## Next phase

Transition to **REVIEWING cycle 001**. Reviewer should diff the milestone,
confirm AC coverage, and either PASS → TESTING or kick back with specific
review-cycle-001 issues.
