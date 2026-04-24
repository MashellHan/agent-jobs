# M01 Tasks

> 11 atomic commits. Order is dependency-strict: T01 unblocks all parsing
> tests; T02–T03 are pure helpers; T04 the throttle; T05 wires lsof; T06–T07
> wires Claude; T08 the launchd enrichment; T09 the registry wire-up; T10
> the integration tests; T11 the perf tests.
>
> Each task ≤ 150 LOC diff. Each task = one commit. Each task ends with
> `swift build` + `swift test` green before the next begins.

---

## T01 — Test fixture loader + Fixtures/ scaffold [DONE]
- **Files (create):**
  - `Tests/AgentJobsCoreTests/FixtureLoader.swift`
  - `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.canonical.txt`
  - `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.dup-pid.txt`
  - `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.empty.txt`
  - `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.valid.json`
  - `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.malformed.json`
  - `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.non-array.json`
- **Files (modify):** `macapp/AgentJobsMac/Package.swift` — add
  `resources: [.copy("Fixtures")]` to the test target.
- **Depends on:** none
- **Acceptance:** `Bundle.module` finds each fixture; `swift test` still
  green (no test changes yet, just plumbing).
- **Estimated diff size:** S

## T02 — `LsofOutputParser` + tests [DONE]
- **Files (create):**
  - `Sources/AgentJobsCore/Discovery/Providers/LsofOutputParser.swift`
  - `Tests/AgentJobsCoreTests/LsofOutputParserTests.swift`
- **Depends on:** T01 (fixtures)
- **Acceptance:** AC-F-03, AC-F-04, AC-F-07 covered. Parser is a pure
  enum, ≤ 80 LOC. Allow-list matches TS `RELEVANT_CMDS` exactly. Dedup on
  PID. Tests cover empty / header-only / canonical / dup-PID / malformed
  line / missing port.
- **Estimated diff size:** S

## T03 — `LiveProcessNaming` (`inferAgent` + `friendlyName`) + tests [DONE]
- **Files (create):**
  - `Sources/AgentJobsCore/Discovery/Providers/LiveProcessNaming.swift`
  - `Tests/AgentJobsCoreTests/LiveProcessNamingTests.swift`
- **Depends on:** none (pure)
- **Acceptance:** AC-F-06 covered. `inferAgent` returns `AgentKind?` per
  the mapping table in architecture.md. `friendlyName` reproduces TS
  branches: scriptArg, generic-script-skip-when-agent, framework, agent
  fallback, plain command. Each branch has ≥ 1 test case.
- **Estimated diff size:** M

## T04 — `AsyncSemaphore` actor + tests [DONE]
- **Files (create):**
  - `Sources/AgentJobsCore/Discovery/Concurrency/AsyncSemaphore.swift`
  - `Tests/AgentJobsCoreTests/AsyncSemaphoreTests.swift`
- **Depends on:** none
- **Acceptance:** ≤ 60 LOC; no deadlock with 100 concurrent waiters at
  value=8; high-water ≤ 8 verified by an atomic counter in the test;
  cancellation of half the waiters does not stall the rest.
- **Estimated diff size:** S

## T05 — `LsofProcessProvider` + tests [DONE]
- **Files (create):**
  - `Sources/AgentJobsCore/Discovery/Providers/LsofProcessProvider.swift`
  - `Tests/AgentJobsCoreTests/LsofProcessProviderTests.swift`
- **Depends on:** T02, T03, T04
- **Acceptance:** AC-F-01, AC-F-02, AC-F-05, AC-F-08, AC-F-09 covered.
  Provider conforms to `ServiceProvider`. `discover()` runs lsof, parses,
  fans out `ps` calls through `AsyncSemaphore(8)`, maps via
  `LiveProcessNaming`, sorts by PID for determinism. Service ID format:
  `lsof:<pid>`. `Service.name` carries the friendly form including
  `:<port>` when port > 0 (AC-F-05 documented choice). Production paths
  use `Shell.run("/usr/sbin/lsof", …)` and `Shell.run("/bin/ps", …)`.
  Per-PID `ps` failures swallowed → empty fullCmd; outer lsof failure
  → `ProviderError.ioError`. File ≤ 200 LOC.
- **Estimated diff size:** M

## T06 — Claude friendly-cron-name helper + tests
- **Files (create):**
  - Inline static helper in `ClaudeScheduledTasksProvider.swift` (created
    in T07) — but its tests live in `ClaudeScheduledTasksProviderTests.swift`.
  - For T06 commit alone: stub the provider file with only the helper
    + its 5-case test, no `discover()` body yet (returns `[]`).
- **Depends on:** none
- **Acceptance:** Helper implements the 5-step rule from architecture.md
  (trim/collapse, strip-punct, 6 words, 40 char + ellipsis, empty →
  `"Claude task"`). 5 test cases pin each branch.
- **Estimated diff size:** S

> **Note:** T06 and T07 could merge; kept split because (a) the naming
> rule is the only piece that matters for human review and (b) it
> isolates a bisectable commit if the rule needs tuning later.

## T07 — `ClaudeScheduledTasksProvider.discover()` + tests
- **Files (modify):**
  - `Sources/AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift`
  - `Tests/AgentJobsCoreTests/ClaudeScheduledTasksProviderTests.swift`
- **Depends on:** T01, T06
- **Acceptance:** AC-F-10..AC-F-18 covered. Constructor accepts optional
  `tasksPath`. Read uses inline `readWithTimeout` (5 s). Result mapping:
  `id = "claude.scheduled-tasks:<index>:<sha8(prompt+cron)>"` — index
  guarantees unique, `sha8` makes id stable across reorderings of the
  same content. Each entry: `source = .claudeScheduledTask(durable: true)`,
  `kind = .scheduled`, `status = .scheduled`, `schedule = .cron(<cron>)`,
  `owner = .agent(.claude)`, `createdAt = nil`, `name = friendlyCronName(prompt)`,
  `command = prompt`. Hung-loader test asserts `.timeout`.
- **Estimated diff size:** M

## T08 — `LaunchdPlistReader.mtime` + `LaunchdUserProvider.createdAt`
- **Files (modify):**
  - `Sources/AgentJobsCore/Discovery/Providers/LaunchdPlistReader.swift`
    — add `mtime` to `Enrichment` (default `nil` initializer arg);
      filesystem loader stat()s the matched URL; new `init(loader:mtimeLoader:)`
      additive overload with default `nil` mtime loader.
  - `Sources/AgentJobsCore/Discovery/Providers/LaunchdUserProvider.swift`
    — pass `enrichment.mtime` into `Service.createdAt`.
  - `Tests/AgentJobsCoreTests/LaunchdPlistReaderTests.swift` — add 2 cases
    (mtime present / absent).
  - `Tests/AgentJobsCoreTests/LaunchdUserProviderTests.swift` — add 2 cases
    (`createdAt == mtime` when plist found; `nil` when not).
- **Depends on:** none
- **Acceptance:** AC-F-19, AC-F-20. Existing tests untouched and still
  pass. Public `Loader` typealias unchanged.
- **Estimated diff size:** S

## T09 — Wire new providers into `ServiceRegistry.defaultRegistry()`
- **Files (modify):**
  - `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift`
  - `Tests/AgentJobsCoreTests/ServiceRegistryTests.swift`
- **Depends on:** T05, T07
- **Acceptance:** AC-F-21, AC-F-22, AC-F-23, AC-Q-07. `defaultRegistry()`
  returns a 4-provider registry. New tests: `providerCount == 4`,
  failure-isolation across 4 providers (one stubbed thrower → 3/4
  succeeded), 10-run determinism with 4 disjoint stubs returning unioned
  result with no duplicates.
- **Estimated diff size:** S

## T10 — Performance + concurrency-cap tests (XCTMeasure)
- **Files (create / modify):**
  - `Tests/AgentJobsCoreTests/LsofProcessProviderTests.swift` — add
    200-PID throughput case with concurrency-cap assertion (AC-P-03).
  - `Tests/AgentJobsCoreTests/ServiceRegistryTests.swift` — add
    100-iteration `XCTMeasure` block on stubbed registry (AC-P-02).
- **Depends on:** T05, T09
- **Acceptance:** AC-P-02 median < 50 ms; AC-P-03 < 500 ms with high-water
  ≤ 8. Tests skip on CI environments where measurement is noisy by checking
  an env flag; locally they enforce.
- **Estimated diff size:** S

## T11 — Final sweep: warnings, no-Process check, doc lines
- **Files (modify):** any file flagged by `swift build -warnings-as-errors`
  or by the `grep 'Process()' Sources/AgentJobsCore/Discovery/Providers/`
  check (expected: none); add header doc comments on the two new providers
  to match the existing style.
- **Depends on:** T01..T10
- **Acceptance:** AC-Q-01 (0 errors / 0 warnings), AC-Q-04, AC-Q-05,
  AC-Q-06, AC-Q-08. `swift test --enable-code-coverage` verifies AC-Q-03.
  Diff to `Sources/AgentJobsMac/` is empty (AC-V-01).
- **Estimated diff size:** S

---

## Acceptance criterion → task coverage matrix

| AC | Task |
|---|---|
| AC-F-01 | T05 |
| AC-F-02 | T05 |
| AC-F-03 | T02 |
| AC-F-04 | T02 |
| AC-F-05 | T05 |
| AC-F-06 | T03 |
| AC-F-07 | T02 |
| AC-F-08 | T05 |
| AC-F-09 | T04 (helper) + T05 (use) + T10 (perf) |
| AC-F-10 | T07 |
| AC-F-11 | T07 |
| AC-F-12..F-15 | T07 |
| AC-F-16 | T07 |
| AC-F-17 | T07 (`sha8`-anchored id) |
| AC-F-18 | T07 |
| AC-F-19 | T08 |
| AC-F-20 | T08 |
| AC-F-21 | T09 |
| AC-F-22 | T09 |
| AC-F-23 | T09 |
| AC-V-01 | T11 (verified by diff) |
| AC-P-01 | (Tester smoke; no task — observable from M01 build) |
| AC-P-02 | T10 |
| AC-P-03 | T10 |
| AC-P-04 | (existing `Shell` guarantee; T11 verifies no regression) |
| AC-Q-01 | T11 |
| AC-Q-02 | T02+T03+T05+T07+T08+T09+T10 (≥ 12 new cases) |
| AC-Q-03 | T11 (coverage gate) |
| AC-Q-04 | T11 |
| AC-Q-05 | T05 + T11 (verify) |
| AC-Q-06 | T08 + T09 + T11 (additive only) |
| AC-Q-07 | T09 |
| AC-Q-08 | T11 (`Package.swift` diff = test resources only) |
| AC-Q-09 | (Tester smoke; no task) |

Every functional, performance, and quality AC is addressable. The
visual AC is empty by design and verified by diff. The two smoke ACs are
Tester-only and require no implementation work.
