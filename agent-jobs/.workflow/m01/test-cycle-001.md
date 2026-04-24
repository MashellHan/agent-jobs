# Test M01 cycle 001
**Date:** 2026-04-23T13:15:00Z
**Tester:** tester agent
**Build:** PASS (clean rebuild — 0 errors, 0 warnings)
**Unit tests:** 106 pass / 0 fail
**Runtime launch:** N/A — M01 is Discovery layer only, no UI changes (per spec & AC-V-01)

## Acceptance criteria results

### Functional — LsofProcessProvider
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-F-01 | PASS | `Sources/AgentJobsCore/Discovery/Providers/LsofProcessProvider.swift` lines 24-27: `public struct LsofProcessProvider: ServiceProvider`, `static let providerId = "lsof.process"`, `static let category = ServiceSource.Category.process` | |
| AC-F-02 | PASS | LsofProcessProvider.swift lines 37-46: `init(lsofRunner: LsofRunner? = nil, psRunner: PsRunner? = nil, psConcurrency: Int = 8)` | Both seams present |
| AC-F-03 | PASS | LsofOutputParserTests + `LsofProcessProviderTests.swift` rely on relevant-commands allow-list verified by parser test "filters allowed commands"; `bash` is excluded by allow-list | |
| AC-F-04 | PASS | LsofOutputParser dedups by PID (verified by parser tests) | |
| AC-F-05 | PASS | `LsofProcessProviderTests.swift:86` — `@Test("name carries ' :<port>' when port > 0")` | Port surfaced inside `name` |
| AC-F-06 | PASS | `LsofProcessProviderTests.swift:98` — `@Test("agent inferred → owner is .agent(.claude) and origin set")` + `LiveProcessNamingTests` (13 tests) cover claude/cursor/copilot/openclaw match + nil-on-no-match | |
| AC-F-07 | PASS | `LsofProcessProviderTests.swift:8` — `@Test("empty lsof output → []")` | |
| AC-F-08 | PASS | `LsofProcessProviderTests.swift:18` — `@Test("lsof failure → throws ProviderError.ioError")` | |
| AC-F-09 | PASS | `LsofProcessProviderTests.swift:115` — `@Test("ps concurrency cap: 200 PIDs, max in-flight ≤ 8")` records high-water mark via injected counter | |

### Functional — ClaudeScheduledTasksProvider
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-F-10 | PASS | `ClaudeScheduledTasksProvider.swift` lines 9-12: type, conformance, providerId="claude.scheduled-tasks", category=.claude | |
| AC-F-11 | PASS | `ClaudeScheduledTasksProvider.swift` line 23: `init(tasksPath: URL? = nil, loader: Loader? = nil)`; default at line 27-28 expands to `~/.claude/scheduled_tasks.json` | |
| AC-F-12 | PASS | `ClaudeScheduledTasksProviderTests.swift:60` — `@Test("missing file → []")` | |
| AC-F-13 | PASS | `ClaudeScheduledTasksProviderTests.swift:69` — `@Test("empty file → []")` | |
| AC-F-14 | PASS | `ClaudeScheduledTasksProviderTests.swift:76` — `@Test("malformed JSON → []")` | |
| AC-F-15 | PASS | `ClaudeScheduledTasksProviderTests.swift:84` — `@Test("non-array root → []")` | |
| AC-F-16 | PASS | `ClaudeScheduledTasksProviderTests.swift:92` — `@Test("valid 2-entry array → 2 services with correct shape")` | |
| AC-F-17 | PASS | `ClaudeScheduledTasksProviderTests.swift:119` — `@Test("id stable across discovery calls for same input")` (sha8 of prompt+cron, no timestamp) | |
| AC-F-18 | PASS | `ClaudeScheduledTasksProviderTests.swift:128` — `@Test("hung loader (timeout) → throws ProviderError.timeout")`; same 5 s default as AgentJobsJsonProvider (`readTimeoutSeconds = 5`) | |

### Functional — LaunchdUserProvider provenance fix
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-F-19 | PASS | `LaunchdUserProviderTests.swift:76` (mtime present) + `:97` (mtime nil, no synthetic Date) | |
| AC-F-20 | PASS | All existing LaunchdUserProvider tests (9 cases) + LaunchdPlistReader (19) green | |

### Functional — ServiceRegistry integration
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-F-21 | PASS | `ServiceRegistryTests.swift:178` — `@Test("defaultRegistry() ships with 4 providers (M01)")` asserts `providerCount == 4` | |
| AC-F-22 | PASS | `ServiceRegistryTests.swift:185` — `@Test("failure isolation across 4 providers: 1 throws → 3 succeed")` asserts `succeededCount == 3, totalCount == 4`, surviving services in result | |
| AC-F-23 | PASS | `ServiceRegistryTests.swift:200` — `@Test("4 disjoint stubs: discoverAll() yields union, deterministic across 10 runs")` | |

### Visual
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-V-01 | PASS | `git diff 4bc9c3c..HEAD -- macapp/AgentJobsMac/Sources/AgentJobsMac/` produces empty output (no UI files modified during M01) | |

### Performance
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-P-01 | PASS | Approximate measurement on this Apple-Silicon Mac via `/tmp/p1.swift` harness (lsof + 8-way ps fanout): 3 runs = 76ms / 79ms / 71ms total. Other providers (`AgentJobsJsonProvider`, `ClaudeScheduledTasksProvider`) hit `[]` fast-path because their files don't exist on this dev machine; `LaunchdUserProvider` adds at most one `launchctl list` (~tens of ms). Median full discovery comfortably under 1500 ms. | Documented per AC-P-01 "subjective" instruction. |
| AC-P-02 | PASS | `ServiceRegistryTests.swift:221` — `@Test("AC-P-02: 100 iterations of discoverAll() on 4-stub registry — median < 50 ms")` passing in 0.017 s | |
| AC-P-03 | PASS | `LsofProcessProviderTests.swift:156` — `@Test("AC-P-03: 200 PIDs through stubbed lsof + ps complete in < 500 ms")` passing in 0.024 s | |
| AC-P-04 | PASS | `ShellTests.swift:39` — `@Test("timeout fires before slow process exits")` passing in 0.328 s; `Shell.swift` defines `defaultTimeoutSeconds + sigtermGraceSeconds`, two-stage SIGTERM/SIGKILL reap (lines 100-115). M01 made no changes to Shell.swift. | |

### Quality gates
| ID | Status | Evidence | Notes |
|---|---|---|---|
| AC-Q-01 | PASS | `swift package clean && swift build` → `Build complete! (35.78s)` with 0 errors and 0 warnings (full output captured in `/tmp/m01-build.log`) | |
| AC-Q-02 | PASS | `swift test` → `Test run with 106 tests passed`. New M01 test cases counted from new test files: `LsofProcessProviderTests` (9) + `ClaudeScheduledTasksProviderTests` (12) + `AsyncSemaphoreTests` (2) + new mtime tests in `LaunchdPlistReaderTests` and `LaunchdUserProviderTests` (4 added) = ≥ 27 new test cases, well above 12 required | |
| **AC-Q-03** | **FAIL** | `xcrun llvm-cov report` on changed providers: `LsofProcessProvider.swift` = **84.55%** line coverage (PASS). `ClaudeScheduledTasksProvider.swift` = **69.18%** line coverage (FAIL — threshold ≥ 80%). Uncovered region is the production `readWithTimeout(url:seconds:)` static function (lines 110-125) and the non-timeout I/O error branch (lines 46-49, 55-57). Tests exercise the `loader` injection seam exclusively, leaving the real-disk read path untested. | **Blocks acceptance.** Implementer must add ≥ 1 test that drives `Self.readWithTimeout` through the production code path (e.g. point `tasksPath` at a real temp file and call `discover()` without injecting `loader`), plus a test that triggers the non-timeout I/O error branch (e.g. unreadable path / permission denied). |
| AC-Q-04 | PASS | `grep -nR 'Process()' Sources/AgentJobsCore/Discovery/Providers/` returns nothing. The only `Process()` site in the module is the canonical `Sources/AgentJobsCore/Discovery/Shell.swift:73` (which is the wrapper providers route through). | |
| AC-Q-05 | PASS | `grep -nR 'DispatchQueue.main\|.sync' Sources/AgentJobsCore/Discovery/Providers/` returns no real matches (only typealias signatures whose identifier strings happen to contain the word "sync"). No main-thread blocking introduced. | |
| AC-Q-06 | PASS | `git diff 4bc9c3c..HEAD -- ServiceProvider.swift ServiceRegistry.swift Shell.swift Service.swift` returns empty output. No public API surface change. | |
| AC-Q-07 | PASS | `ServiceRegistry.defaultRegistry()` (lines 66-73) lists all four providers; coverage by `ServiceRegistryTests.swift:178` (AC-F-21). | |
| AC-Q-08 | PASS | `git diff 4bc9c3c..HEAD -- macapp/AgentJobsMac/Package.swift` shows only `resources: [.copy("Fixtures")]` added to the test target. No new dependencies. | |
| AC-Q-09 | SKIP | This dev machine has neither `~/.claude/scheduled_tasks.json` nor `~/.agent-jobs/jobs.json`. `ls` confirmed both absent. Cannot perform the smoke test required by this AC in the current environment. **Not auto-passed.** Recommend implementer or human reviewer creates synthetic fixtures and runs the smoke test, OR PM relaxes this AC for the dev environment. | Tester cannot satisfy without real-environment data; flagging for follow-up. |

## Summary counts
- PASS: 35 / 37
- FAIL: 1 / 37 (AC-Q-03)
- SKIP: 1 / 37 (AC-Q-09 — environment limitation)

## New issues found (not in acceptance criteria but blocking)
- **T1 [HIGH]** Real-disk read path of `ClaudeScheduledTasksProvider` (`Self.readWithTimeout` and the non-timeout `catch` branch) has zero coverage. This is the same code shape as `AgentJobsJsonProvider.readWithTimeout`; the latter likely has the same gap, but it's outside the M01 changed-file scope so not graded here.

## Evidence index
- `/tmp/m01-build.log` — full clean-build output
- `/tmp/m01-tests.log` — full unit-test output (106 tests)
- `/tmp/p1.swift` — AC-P-01 perf harness used to measure real-env timing
- llvm-cov report excerpt above (line counts per file)

## Decision
**FAIL — back to IMPLEMENTING (test cycle: 1/3)**

Reason: AC-Q-03 binding threshold (≥ 80% changed-line coverage) not met for `ClaudeScheduledTasksProvider` (actual 69.18%). All other functional, perf, and visual ACs verified PASS or justified-SKIP.

### Recommended fix scope (minimal)
1. Add `discover()` test that points `tasksPath` at a real temp file (no `loader` override) so the production `readWithTimeout` is exercised.
2. Add a test that triggers the non-timeout I/O catch branch (e.g. `tasksPath` pointing at a directory or a path with a denied permission), expecting `[]`.

This should bump line coverage of `ClaudeScheduledTasksProvider.swift` from 69.18% over the 80% bar without further functional change.
