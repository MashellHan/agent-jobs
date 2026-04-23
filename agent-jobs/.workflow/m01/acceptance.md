# M01 Acceptance Criteria

> Binding contract for the Tester. Every checkbox below must be independently verifiable from the diff and the test suite. AC-V is intentionally empty — M01 ships no UI changes.

## Functional (must all pass)

### LsofProcessProvider
- [ ] **AC-F-01**: Provider type `LsofProcessProvider` exists in `Sources/AgentJobsCore/Discovery/Providers/`, conforms to `ServiceProvider`, declares `static let providerId = "lsof.process"` and `static let category = ServiceSource.Category.process`.
- [ ] **AC-F-02**: Provider exposes a test injection seam: `init(runner: Runner? = nil, psRunner: ((Int32) async throws -> String)? = nil)` (or equivalent named hooks) so unit tests can stub both `lsof` and `ps` without spawning processes.
- [ ] **AC-F-03**: Given the canonical `lsof -i -P -n -sTCP:LISTEN` header line plus rows for commands `node`, `python3`, and `bash`, the provider returns exactly 2 services (the `bash` row is filtered out per the relevant-commands allow-list).
- [ ] **AC-F-04**: Two `lsof` rows with the same PID (e.g. IPv4 + IPv6 listener on the same process) collapse to a single `Service`.
- [ ] **AC-F-05**: An `lsof` row with a parseable port populates `Service.pid` and surfaces the port either inside `name` (matching TS `friendlyLiveName` "name :port" form) or via a documented field — pick one in architecture and verify it.
- [ ] **AC-F-06**: When `inferAgent` matches `claude`, `cursor`, `copilot`, or `openclaw` against the full command string, the resulting `Service.origin?.agent` is set to the corresponding `AgentKind`. When no match, `origin` is `nil` (parity with TS `manual` ⇒ no enrichment).
- [ ] **AC-F-07**: Empty `lsof` output (zero rows past header) returns `[]` without throwing.
- [ ] **AC-F-08**: When the injected `lsof` runner throws, `discover()` throws `ProviderError.ioError` (so the registry can isolate it). It does **not** crash and does not return partial data.
- [ ] **AC-F-09**: Concurrency cap on the per-PID `ps` resolution is ≤ 8 in flight at any instant; verified by a test that records the high-water mark of concurrent calls into the injected `psRunner`.

### ClaudeScheduledTasksProvider
- [ ] **AC-F-10**: Provider type `ClaudeScheduledTasksProvider` exists in `Sources/AgentJobsCore/Discovery/Providers/`, conforms to `ServiceProvider`, declares `static let providerId = "claude.scheduled-tasks"` and `static let category = ServiceSource.Category.claude`.
- [ ] **AC-F-11**: Constructor accepts an optional override path (`init(tasksPath: URL? = nil)`) defaulting to `~/.claude/scheduled_tasks.json`.
- [ ] **AC-F-12**: Missing file → returns `[]` without throwing.
- [ ] **AC-F-13**: Empty file → returns `[]` without throwing.
- [ ] **AC-F-14**: Malformed JSON → returns `[]`, logs the parse error via `os.Logger`, does not throw.
- [ ] **AC-F-15**: JSON root that is not an array (e.g. `{}`) → returns `[]` without throwing.
- [ ] **AC-F-16**: Valid array of two entries returns 2 services, each with `source = .claudeScheduledTask(durable: true)`, `kind = .scheduled`, `status = .scheduled`, `schedule = .cron(<the cron string from JSON>)`, `owner = .agent(.claude)`.
- [ ] **AC-F-17**: Service `id` is stable across discovery calls for the same input (no timestamps in the id).
- [ ] **AC-F-18**: Read is bounded by the same 5 s timeout used by `AgentJobsJsonProvider`; a hung file read raises `ProviderError.timeout`.

### LaunchdUserProvider provenance fix
- [ ] **AC-F-19**: When `LaunchdPlistReader` finds the plist on disk for a label, the resulting `Service.createdAt` equals the plist file's `mtime`. When no plist is found, `createdAt` remains `nil` (no synthetic `Date()`).
- [ ] **AC-F-20**: Existing `LaunchdUserProvider` tests still pass (no regression).

### ServiceRegistry integration
- [ ] **AC-F-21**: `ServiceRegistry.defaultRegistry()` returns a registry whose `providerCount == 4` (was 2): `AgentJobsJsonProvider`, `LaunchdUserProvider`, `LsofProcessProvider`, `ClaudeScheduledTasksProvider`.
- [ ] **AC-F-22**: With one of the new providers stubbed to throw, `discoverAllDetailed()` reports `succeededCount == 3, totalCount == 4` and the surviving providers' services are still in the merged result. (Failure-isolation contract intact.)
- [ ] **AC-F-23**: With all four providers stubbed to return non-empty disjoint sets, `discoverAll()` returns the union with no duplicates and no order-dependent flakiness across 10 consecutive runs.

## Visual

- [ ] **AC-V-01**: *(none — M01 ships no UI changes; SwiftUI files under `Sources/AgentJobsMac/` must be unmodified in the milestone diff. Tester verifies via `git diff --stat main...HEAD -- 'Sources/AgentJobsMac/*.swift' | wc -l` returning 0.)*

## Performance

- [ ] **AC-P-01**: `ServiceRegistry.defaultRegistry().discoverAll()` completes in **< 1500 ms wall-clock** on an Apple-Silicon Mac in the median of 5 consecutive runs against the developer's real environment (subjective check; document number observed in test cycle log).
- [ ] **AC-P-02**: With all real subprocess runners replaced by stubs returning canned data, `discoverAll()` completes in **< 50 ms median** over 100 runs (proves the provider plumbing itself is not the bottleneck).
- [ ] **AC-P-03**: A 200-row stub `lsof` output (every row with a unique PID) completes in **< 500 ms** with the 8-way `ps` concurrency cap applied (proves the cap throttles correctly without serializing).
- [ ] **AC-P-04**: A `Shell.run` invocation that exceeds its timeout reaps the child within `defaultTimeoutSeconds + sigtermGraceSeconds = 5.5 s`. (Existing guarantee; M01 must not regress it.)

## Quality gates

- [ ] **AC-Q-01**: `swift build` (in `macapp/AgentJobsMac/`) is green with **0 errors and 0 warnings**.
- [ ] **AC-Q-02**: `swift test` is green; all existing tests pass and the new provider test files together add **≥ 12 new test cases** (covering at minimum each `AC-F-*` clause above for the two new providers).
- [ ] **AC-Q-03**: Coverage on the two new provider files is **≥ 80%** of statements (verified by `swift test --enable-code-coverage` and `xcrun llvm-cov`).
- [ ] **AC-Q-04**: No new file under `Sources/AgentJobsCore/` references `Process` directly; all subprocess invocation goes through `Shell.run`. (Verified by `grep -nR 'Process()' Sources/AgentJobsCore/Discovery/Providers/` returning empty.)
- [ ] **AC-Q-05**: No new file under `Sources/AgentJobsCore/` introduces a `DispatchQueue.main` call or a synchronous wait on the main thread.
- [ ] **AC-Q-06**: Public API surface of `ServiceProvider`, `ServiceRegistry`, `Service`, and `Shell` is unchanged from the start of the milestone (verified by `git diff main...HEAD -- Sources/AgentJobsCore/Discovery/ServiceProvider.swift Sources/AgentJobsCore/Discovery/ServiceRegistry.swift Sources/AgentJobsCore/Discovery/Shell.swift Sources/AgentJobsCore/Domain/Service.swift` — only additive comment / doc changes allowed, no signature changes).
- [ ] **AC-Q-07**: New providers are wired into `ServiceRegistry.defaultRegistry()` and the wiring is covered by at least one test (see AC-F-21).
- [ ] **AC-Q-08**: No new dependency added to `Package.swift`.
- [ ] **AC-Q-09**: Tester runs the built menu-bar app once on a Mac with both `~/.claude/scheduled_tasks.json` populated and at least one listening dev process; both new sources appear in the existing dashboard list. Smoke test only — no UI assertions.
