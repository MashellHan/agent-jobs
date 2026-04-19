# Code Review 002
**Date:** 2026-04-19T23:35:00Z
**Git HEAD:** cd7a43b
**Files scanned:** 13 Swift sources (1,443 LOC) + 4 test files (234 LOC, 22 cases) + Package.swift
**Previous review:** 001 (score 58/100)

## Overall Score: 89/100  (+31 vs 001)

Huge progress across four implementation cycles. The scaffold matured into a layered, testable, concurrency-correct skeleton with a single safe subprocess entry point (`Shell.run`), an actor-isolated registry, a humanized scheduler, and 22/22 green tests. All CRITICAL and HIGH items from review 001 are closed. Remaining gaps are quality polish, breadth of providers, and a couple of small async correctness nits in `Shell.swift`.

## Category Scores
| Category | Score | Prev | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (25) | 22 | 13 | +9  | GREEN  |
| Architecture (15) | 14 | 11 | +3  | GREEN  |
| Tests (20)        | 16 | 8  | +8  | YELLOW |
| Performance (10)  | 9  | 6  | +3  | GREEN  |
| Security (10)     | 9  | 7  | +2  | GREEN  |
| Modern Swift (10) | 9  | 7  | +2  | GREEN  |
| Documentation (5) | 5  | 4  | +1  | GREEN  |
| OSS Quality (5)   | 5  | 2  | +3  | GREEN  |
| **TOTAL** | **89** | **58** | **+31** | GREEN |

Tests (16/20) is the only category still under 80% of its budget — see M2 below. Coverage on the Discovery layer is solid for `AgentJobsJsonProvider` and `Shell`, but `ServiceRegistry`'s TaskGroup orchestration (provider-failure isolation) is not yet covered, and there are no UI snapshot or view-model tests.

## Top 3 actions for implementer (by ROI)

1. **[P0] `Sources/AgentJobsCore/Discovery/Shell.swift:56,77`** — `Failure.timeout(seconds:partialStdout:)` is constructed with `partialStdout: ""` always; the field is dead. Either drain the pipe before throwing, or drop the parameter. *Fix:* in the timeout-arm before `throw`, do `let partial = (try? outPipe.fileHandleForReading.availableData) ?? Data(); throw .timeout(seconds: timeout, partialStdout: String(data: partial, encoding: .utf8) ?? "")`. (If draining is risky on a still-running pipe, just remove the associated value.)

2. **[P0] `Sources/AgentJobsCore/Discovery/Shell.swift:75-99`** — `withTaskCancellationHandler` calls `process.terminate()` (SIGTERM) but never escalates to SIGKILL or waits for the child to actually exit. A pathological child that ignores SIGTERM keeps the pipe FDs open and the continuation never resumes → `Shell.run` will hang past its timeout. *Fix:* after `terminate()`, schedule a 0.5s grace timer; if `process.isRunning` still true, send `SIGKILL` via `kill(process.processIdentifier, SIGKILL)`.

3. **[P1] `Tests/AgentJobsCoreTests/`** — no test exercises `ServiceRegistry.discoverAll()`, the most architecturally important piece (provider-failure isolation, TaskGroup ordering). *Fix:* add `ServiceRegistryTests` with two stub providers conforming to `ServiceProvider`: one returns 2 services, the other throws — assert the result contains exactly those 2 services and the failing provider's error is logged but does not poison the group.

## Issues (full)

### CRITICAL
*(none)*

### HIGH
*(none)*

### MEDIUM
- **M1** `Sources/AgentJobsCore/Discovery/Shell.swift:56,77` — `Failure.timeout.partialStdout` always empty (see Top-3 #1).
- **M2** `Tests/AgentJobsCoreTests/` — Discovery coverage estimated ~60–70%, below the rubric's 85% target. Missing: `ServiceRegistry` orchestration test, `AgentJobsJsonProvider.readWithTimeout` timeout-arm test (only happy-path covered), `Service.history` round-trip test. *Fix:* add 3-5 cases per the Top-3 #3 plus a test that points the provider at a path on a stalled fixture (e.g. a FIFO that never closes) to fire the 5s race.
- **M3** `Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift` — 267 LOC; approaching the 400-line guidance, and `StatusBadge`, `MetricTile`, sidebar item enum, and inspector tab content are all defined inline. *Fix:* extract `Components/StatusBadge.swift`, `Components/MetricTile.swift`, `Sidebar/SidebarItem.swift`. Will also unlock cross-feature reuse from MenuBar.
- **M4** `Sources/AgentJobsCore/Discovery/Shell.swift:52-64` — when the runProcess arm wins the race, the timeout arm is left "cancelled" but the `Task.sleep` may still log a `CancellationError` swallowed by the throwing group. Behavior is correct, but log-noise risk under Swift 6 strict concurrency. *Fix:* catch `is CancellationError` in the sleep arm and `return` a sentinel value the group ignores, OR convert to `withThrowingDiscardingTaskGroup` if you only need the first non-throwing result.

### LOW
- **L1** `Sources/AgentJobsCore/Discovery/Shell.swift:14` — `Result` shadows `Swift.Result`. Works because of nesting, but call sites that `import AgentJobsCore` then do `Shell.Result` are fine; ad-hoc `Result<...>` references inside the same file might confuse. Consider `ProcessOutput` or `Output`.
- **L2** `Sources/AgentJobsCore/Discovery/Shell.swift:47-51` — `executable: String` accepts any string. Per the doc-comment "Avoid PATH lookup — explicit paths are auditable." Enforce with a `precondition(executable.hasPrefix("/"))` or accept `URL` instead.
- **L3** `Sources/AgentJobsMac/Features/MenuBar/MenuBarViews.swift` — file is 262 LOC and growing. SkeletonRow, ServiceRowCompact, EmptySection helper are reusable across contexts. Same fix recipe as M3.
- **L4** No `LICENSE` file at repo root for the macapp module (rubric OSS Quality). Currently scored 5/5 on the strength of CHANGELOG and README; add a `LICENSE` to lock it in for next round.
- **L5** Public types `Shell`, `Shell.Result`, `Shell.Failure` have doc-comments — nice. But `Shell.defaultTimeoutSeconds` could note "applies to discovery commands; long-running tools should pass an explicit value".
- **L6** `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift:39` — `defaultRegistry()` only includes `AgentJobsJsonProvider`. The architecture spec promised 4 sources (registered, live, cron, launchd). Tracked as deferred; not a defect, just a visibility nudge.

## Diff since previous review

**Fixed (from code-001):**
- C1 ✅ `Service.createdAt`, `Service.history`, `Service.origin`, `AgentKind`, `HistoryEvent`, `ServiceOrigin` all landed (cycle 2).
- C2 ✅ `.implementation/sandbox-decision.md` written; Option A accepted.
- C3 ✅ `scripts/build-mac.sh` exists; `swift test` shows 22/22 green.
- H1 ✅ `AgentJobsJsonProvider` now logs malformed JSON via `os.Logger`.
- H2 ✅ `SidebarItem` enum landed in DashboardView.
- H3 ✅ `Service.command` is non-optional `String`.
- H4 ⏳ Test count grew 4 → 22 (+450%); per-provider golden fixtures still missing for *future* providers (none yet added).
- M1 ✅ `ResourceColor` thresholds documented.
- M2 ✅ `ServiceSource.calendar` fixed by `CronHumanizer`.
- M3 ✅ Menubar uses `OpenWindowAction`.
- M4 ✅ `schemaVersion` aware in JobsFile.
- L1 ✅ CHANGELOG present and well-maintained.
- L3 ✅ `AgentKind` enum replaced string param.
- L4 ⏳ `Service`, `ServiceProvider`, `ResourceMetrics` still without DocC comments — small gap but won't block.

**Still open:**
- L2 (LICENSE symlink for SwiftPM consumers) — minor.
- L4 from review 001 (DocC on public types) — partial.

**New this cycle:**
- M1 (Shell.timeout.partialStdout always empty)
- M2 (Discovery coverage target 85% not yet met)
- M3 (DashboardView 267 LOC extraction)
- M4 (Shell timeout-arm Swift 6 strict concurrency log-noise)
- L1–L6 as above.

## Communication to implementer

- Excellent execution since cycle 1. The `Shell` wrapper is the right abstraction at the right time, and tying it to `sandbox-decision.md` makes the security model auditable. Keep that as the *only* `Process` instantiation site — add a CI grep in a future cycle that fails the build if `Process()` appears outside `Shell.swift`.
- Cross-stream alignment with **design-001**: design-002 is expected to flag continued M3-style extraction (StatusBadge / MetricTile components live in DashboardView). Doing M3 now resolves both reviews simultaneously.
- Cross-stream alignment with **strict-review iter-003 (PASS)**: the strict reviewer's open register is empty, but my M1+M2 above are not strict-CRITICAL/HIGH, so they don't block the strict termination — but they do block *this* stream from reaching the 90/100 declare-done bar.
- Per repo memory `feedback_auto_commit_push`: continue committing + pushing every cycle. I noticed cycle-5's Shell.swift + ShellTests.swift landed in a single clean commit — perfect.
- Suggested next cycle's Module focus (per round-robin): "Discovery + tests" (cycle 6 mod 3 == 0). The `LaunchdUserProvider` via `Shell.run("/bin/launchctl", ["list"])` would be high-leverage and would naturally drag in the `ServiceRegistry` orchestration test (Top-3 #3).

## Termination check
- Score >= 90 for 2 consecutive reviews? **no** (89 this round, was 58 last round; this is the first time we're near the bar)
- `swift test` green? **yes** (22/22 in 0.313s)
- Recommendation: **CONTINUE**

One more cycle that addresses M1+M2+M3 and we should clear 90/100 — at which point this stream will DECLARE-DONE.
