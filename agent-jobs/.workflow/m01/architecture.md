# M01 Architecture — Discovery audit + gap fill

> Closes the parity gap with the legacy TS scanner by adding two new providers
> (`LsofProcessProvider`, `ClaudeScheduledTasksProvider`), plus a small
> provenance enrichment to `LaunchdUserProvider`. No changes to public
> protocol surfaces, no UI work, no new third-party dependencies.

## Modules touched

All work lives in **`AgentJobsCore`** (library). No file under
`Sources/AgentJobsMac/` is touched.

| Path | Change |
|---|---|
| `Sources/AgentJobsCore/Discovery/Providers/LsofProcessProvider.swift` | **NEW** |
| `Sources/AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift` | **NEW** |
| `Sources/AgentJobsCore/Discovery/Providers/LsofOutputParser.swift` | **NEW** (split from provider to keep both files ≤ 200 LOC) |
| `Sources/AgentJobsCore/Discovery/Providers/LiveProcessNaming.swift` | **NEW** (port of `friendlyLiveName` + `inferAgent`; pure functions; testable in isolation) |
| `Sources/AgentJobsCore/Discovery/Concurrency/AsyncSemaphore.swift` | **NEW** (8-way throttle helper for `ps` fan-out; `actor`-based) |
| `Sources/AgentJobsCore/Discovery/Providers/LaunchdPlistReader.swift` | **MODIFY** — extend `Enrichment` with `mtime: Date?`; populate from filesystem loader |
| `Sources/AgentJobsCore/Discovery/Providers/LaunchdUserProvider.swift` | **MODIFY** — pass `enrichment.mtime` into `Service.createdAt` |
| `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift` | **MODIFY** — `defaultRegistry()` adds the two new providers |
| `Tests/AgentJobsCoreTests/LsofOutputParserTests.swift` | **NEW** |
| `Tests/AgentJobsCoreTests/LiveProcessNamingTests.swift` | **NEW** |
| `Tests/AgentJobsCoreTests/LsofProcessProviderTests.swift` | **NEW** |
| `Tests/AgentJobsCoreTests/ClaudeScheduledTasksProviderTests.swift` | **NEW** |
| `Tests/AgentJobsCoreTests/AsyncSemaphoreTests.swift` | **NEW** |
| `Tests/AgentJobsCoreTests/LaunchdPlistReaderTests.swift` | **MODIFY** — `mtime` enrichment cases |
| `Tests/AgentJobsCoreTests/LaunchdUserProviderTests.swift` | **MODIFY** — assert `createdAt == mtime` when plist found |
| `Tests/AgentJobsCoreTests/ServiceRegistryTests.swift` | **MODIFY** — assert `providerCount == 4`; failure-isolation across 4 providers |
| `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.canonical.txt` | **NEW** |
| `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.dup-pid.txt` | **NEW** |
| `Tests/AgentJobsCoreTests/Fixtures/lsof.listen.empty.txt` | **NEW** |
| `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.valid.json` | **NEW** |
| `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.malformed.json` | **NEW** |
| `Tests/AgentJobsCoreTests/Fixtures/scheduled_tasks.non-array.json` | **NEW** |
| `Tests/AgentJobsCoreTests/FixtureLoader.swift` | **NEW** (shared `Bundle.module` helper) |

`Package.swift` gains a `resources: [.copy("Fixtures")]` entry on the test
target so fixture files are copied into the test bundle. **No source-target
manifest changes; no new dependencies.**

## New types (with module placement)

### `AgentJobsCore/Discovery/Providers/LsofProcessProvider`

```swift
public struct LsofProcessProvider: ServiceProvider {
    public static let providerId = "lsof.process"
    public static let displayName = "Listening processes"
    public static let category = ServiceSource.Category.process

    // Injection seams (test-only paths):
    public typealias LsofRunner = @Sendable () async throws -> String
    public typealias PsRunner   = @Sendable (Int32) async throws -> String

    public init(
        lsofRunner: LsofRunner? = nil,
        psRunner: PsRunner? = nil,
        psConcurrency: Int = 8                 // AC-F-09
    )

    public func discover() async throws -> [Service]
}
```

Production defaults wrap `Shell.run("/usr/sbin/lsof", args: ["-i","-P","-n","-sTCP:LISTEN"])`
and `Shell.run("/bin/ps", args: ["-p","\(pid)","-o","args="])`. Both runners
translate `Shell.Failure` → `ProviderError.ioError` (or `.timeout`). The
`psRunner` failures are **swallowed per-PID** (return `""`) — parity with TS
`getFullCommand` returning empty string on error; one bad `ps` must not
poison the whole scan. The outer `lsof` failure **does** propagate as
`ProviderError.ioError` (AC-F-08).

### `AgentJobsCore/Discovery/Providers/LsofOutputParser`

```swift
enum LsofOutputParser {
    struct Entry: Equatable, Sendable {
        let pid: Int32
        let command: String   // lower-cased
        let port: Int         // 0 when not parseable
    }
    static let relevantCommands: Set<String> = [
        "node","python","python3","go","ruby","java",
        "deno","bun","uvicorn","gunicorn","tsx"
    ]
    static func parse(_ output: String) -> [Entry]   // dedup on PID, drops header
}
```

Mirrors TS `parseLsofOutput` byte-for-byte: skips header line, requires ≥ 9
whitespace-split fields, filters `command` (lower-cased) by allow-list,
dedups on PID, parses port from last `:` segment of field 8.

### `AgentJobsCore/Discovery/Providers/LiveProcessNaming`

```swift
enum LiveProcessNaming {
    /// Maps lower-cased `fullCmd` substring → AgentKind (parity with TS `inferAgent`).
    /// Returns nil when no match (TS `manual`).
    static func inferAgent(fullCommand: String) -> AgentKind?

    /// Mirrors TS `friendlyLiveName`. Returns the form `"<name> :<port>"` when
    /// port > 0, else `"<name>"`. Encodes the `GENERIC_SCRIPTS` skip rule and
    /// the framework / agent-subcommand fallbacks.
    static func friendlyName(
        command: String, fullCommand: String, port: Int, agent: AgentKind?
    ) -> String
}
```

Pure functions, no I/O, fully unit-testable; this isolates the bulk of the
parity logic from the subprocess plumbing.

`inferAgent` mapping (parity with TS lower-cased substring tests):

| Substring | `AgentKind` |
|---|---|
| `claude` | `.claude` |
| `cursor` | `.custom("cursor")` |
| `copilot` | `.custom("github-copilot")` |
| `openclaw` or `claw` | `.openclaw` |
| (else) | `nil` |

Rationale for `.custom("cursor")` / `.custom("github-copilot")`: the existing
`AgentKind` enum has only `claude`, `codex`, `openclaw`, `custom(String)`;
adding new cases would expand the public API surface — out of scope for M01.
`AgentKind.custom(_:)` keeps the agent visible to UI/logs without an enum
change. (See AC-F-06.)

### `AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider`

```swift
public struct ClaudeScheduledTasksProvider: ServiceProvider {
    public static let providerId = "claude.scheduled-tasks"
    public static let displayName = "Claude scheduled tasks"
    public static let category = ServiceSource.Category.claude

    public let tasksPath: URL                            // AC-F-11
    public init(tasksPath: URL? = nil)                   // default ~/.claude/scheduled_tasks.json

    public func discover() async throws -> [Service]     // AC-F-12..18
}
```

Reuses `AgentJobsJsonProvider`-style `readWithTimeout` (we'll factor the
helper to `Discovery/IO/JSONFileReader.swift` only **if** the second use
demands it; M01 keeps it inline as a static method to avoid scope-creep —
~8 LOC duplication is acceptable here per "do not design for 10 use cases").

Behaviour table:

| Disk state | `discover()` result | Throws? |
|---|---|---|
| File missing | `[]` | No |
| File empty (0 bytes) | `[]` | No |
| Malformed JSON | `[]` (logs error) | No |
| Root not array (`{}`, `null`, scalar) | `[]` | No |
| Array of N entries | N services | No |
| Read times out (5 s) | — | `ProviderError.timeout` |

### `AgentJobsCore/Discovery/Concurrency/AsyncSemaphore`

```swift
actor AsyncSemaphore {
    init(value: Int)
    func wait() async
    func signal()
}
```

Plain counting semaphore using a continuation queue. Used by
`LsofProcessProvider` to wrap each per-PID `psRunner` call inside a
`TaskGroup`. Decision: an actor-based semaphore is simpler and `Sendable`-clean
versus a `TaskGroup` + manual counter, and reusable for future providers
(e.g. M01.5 session-cron parser).

### `AgentJobsCore/Discovery/Providers/LaunchdPlistReader` (modify)

Extend `Enrichment` with `mtime: Date?`. The default filesystem loader
becomes `(label) -> (Data, Date?)?` internally; the public `Loader` typealias
remains `(String) -> Data?` to preserve the existing test injection seam
(no public-API break). For `mtime`, the production reader stat()s the
candidate URL and returns its modification date; tests can override with a
new `init(loader:mtimeLoader:)` that defaults the new closure to a `nil`-returning
stub when only `loader` is supplied (additive, source-compatible).

`LaunchdUserProvider` passes `enrichment.mtime` into `Service.createdAt`.
When no plist matched, `createdAt` stays `nil` (AC-F-19).

## Protocols / interfaces

**No public protocol changes.** `ServiceProvider`, `ServiceRegistry`,
`Service`, and `Shell` signatures are frozen for this milestone (AC-Q-06).

The two new providers conform to existing `ServiceProvider`. Both override
none of the protocol's default extensions: `watch()` returns `nil`,
`control(_:on:)` returns the default `ProviderError.unsupported`. (Spec
§Out-of-scope — actions are M04.)

## Data flow

```
                ┌──────────────────────────────────────────────────────┐
                │           ServiceRegistry.discoverAllDetailed()      │
                │           (TaskGroup, per-provider isolation)        │
                └──────────────────────────────────────────────────────┘
                       │              │                │             │
            ┌──────────┘    ┌─────────┘    ┌───────────┘     ┌───────┘
            ▼               ▼              ▼                 ▼
   AgentJobsJsonProvider  LaunchdUserProvider  LsofProcessProvider  ClaudeScheduledTasksProvider
            │                    │                  │                       │
            │                    │                  │                       │
   Data(contentsOf)      Shell.run(launchctl)   Shell.run(lsof)        Data(contentsOf
       jobs.json         + LaunchdPlistReader   → LsofOutputParser      ~/.claude/
                              (+ mtime)              │                  scheduled_tasks.json)
                                                     ▼                        │
                                          TaskGroup over PIDs                 ▼
                                          throttled by AsyncSemaphore(8)  JSONDecoder([Entry])
                                              │                               │
                                              ▼                               ▼
                                          Shell.run(ps -o args=)     friendlyCronName(prompt)
                                              │                               │
                                              ▼                               ▼
                                       LiveProcessNaming                  Service[]
                                          .friendlyName()
                                          .inferAgent()
                                              │
                                              ▼
                                          Service[]
```

Each leaf can throw → `ServiceRegistry` catches → other providers' results
survive (existing failure-isolation contract). M01 does not modify this
plumbing; AC-F-22 verifies it still holds with 4 providers.

## Concurrency model

- **`ServiceRegistry`** remains a `actor` running providers concurrently in
  a `TaskGroup` (unchanged).
- **`LsofProcessProvider.discover()`** is a single `async` function on a value
  type (the provider is `Sendable`). Internally:
  1. One `Shell.run("/usr/sbin/lsof", …)` (5 s timeout).
  2. Synchronous `LsofOutputParser.parse(...)`.
  3. `withTaskGroup(of: (Int, Service?).self)` over deduped PIDs.
     Each child `await semaphore.wait()` → `psRunner(pid)` → `semaphore.signal()`.
  4. Collect into a stable order (by PID ascending) so test assertions are
     deterministic across runs.
- **`ClaudeScheduledTasksProvider.discover()`** is a single `async` function
  with one timeout-wrapped read; no internal task groups.
- **No `DispatchQueue.main`. No main-actor work.** AC-Q-05.
- **`AsyncSemaphore`** is the only synchronization primitive added. It is an
  `actor` with `Sendable` continuations.

### Why an `AsyncSemaphore` over alternatives

| Option | Why not |
|---|---|
| Plain `TaskGroup` + counter | Counter must be actor-isolated anyway; no LOC saved, less reusable. |
| Batched `ps` (single `ps -p p1,p2,…`) | Faster but a parser rewrite; output format differs. Out of scope, may revisit in retro. |
| `swift-async-algorithms` `AsyncChannel` | New third-party dependency; spec forbids. |

`AsyncSemaphore` is < 50 LOC, pure Swift concurrency, reusable. Picked.

## Persistence schema changes

**None.** No on-disk format evolves in M01:
- `jobs.json` schema unchanged.
- `~/.claude/scheduled_tasks.json` is **read** with the schema the Claude
  CLI already writes; we tolerate any shape (array → parse, anything else
  → `[]`). No version negotiation needed.
- `Service` model gains no fields (AC-Q-06).
- No new files written by the app.

No migration plan required.

## Friendly-name rule for Claude scheduled tasks

(Open question #3 — architect decision.)

Function `LiveProcessNaming.friendlyClaudeCronName(_ prompt: String) -> String`
(or, if it leaks into being reusable, lift to a sibling `ClaudeNaming` enum;
M01 keeps it as a static helper inside `ClaudeScheduledTasksProvider` since
it has exactly one caller).

**Rule (deterministic, test-pinnable):**

1. Trim, collapse internal whitespace runs to a single space.
2. Strip leading punctuation.
3. Take the first 6 whitespace-separated words.
4. If the result is > 40 characters, truncate to 40 and append `…` (U+2026).
5. If the result is empty after trimming, return the literal string
   `"Claude task"`.

Tests pin all five branches with one case each.

## Provenance decisions (Open Q #4, #5)

- **`Service.metrics` for lsof entries:** **`nil` in M01.** Spec recommends
  it; M01 honors that. Adding `ps -o rss,%cpu` doubles the per-PID subprocess
  count (16 spawns at 200 PIDs); the perf budget (AC-P-03) only allows 8 in
  flight, so wall-clock would worsen ~2×. Defer to M02 detail panel.
- **`Service.createdAt` for Claude scheduled tasks:** **`nil`.** The JSON has
  no per-task timestamp, and synthesizing `Date()` would lie about
  provenance (same reasoning that drove the `LaunchdUserProvider` M-006
  fix). Sortability is achievable in the UI by file `mtime` of
  `scheduled_tasks.json` if needed later — outside M01.

## Provider id naming (Open Q #6)

Confirmed:
- `lsof.process`
- `claude.scheduled-tasks`

Matches the existing dotted-namespace style (`agent-jobs.json`, `launchd.user`).

## Test fixture management (Open Q #7)

A new `Tests/AgentJobsCoreTests/Fixtures/` directory holds payloads larger
than ~5 lines; smaller cases stay inline (matches existing test style).
A tiny `FixtureLoader` wraps `Bundle.module.url(forResource:withExtension:)`
and reads the file as `String`/`Data`. `Package.swift` test target gets a
`resources: [.copy("Fixtures")]` line.

## Testing strategy

### Unit tests (XCTest, per existing `Tests/AgentJobsCoreTests/` style)

| Test file | Cases | AC coverage |
|---|---|---|
| `LsofOutputParserTests` | empty input; header-only; canonical 3-row output (node + python3 + bash → 2); duplicate PID rows collapse; missing port; malformed line skipped | AC-F-03, F-04, F-07 |
| `LiveProcessNamingTests` | inferAgent: each of claude/cursor/copilot/openclaw/manual; friendlyName: scriptArg path, generic-script skip-when-agent, framework match, agent fallback, port-prefix form | AC-F-06 |
| `LsofProcessProviderTests` | empty lsof → `[]`; lsof failure → throws `.ioError`; ps failure for one PID → that service still surfaces with empty fullCmd; concurrency cap (200 stubbed PIDs, recorded high-water ≤ 8); deterministic order | AC-F-02, F-03..F-09 |
| `ClaudeScheduledTasksProviderTests` | missing file; empty file; malformed JSON; non-array root; valid 2-entry → 2 services with correct source/kind/status/schedule/owner; id stability across calls; injected hung loader → `.timeout` | AC-F-10..F-18 |
| `AsyncSemaphoreTests` | 100 concurrent waiters with value=8 → max-in-flight ≤ 8, all eventually signal, no deadlock | (supports F-09) |
| `LaunchdPlistReaderTests` (modify) | When loader returns data + mtime → `Enrichment.mtime` populated; when nil → `mtime == nil` | AC-F-19 |
| `LaunchdUserProviderTests` (modify) | When enrichment supplies mtime → `Service.createdAt == mtime`; when no plist → `nil`; existing assertions unchanged | AC-F-19, F-20 |
| `ServiceRegistryTests` (modify) | `defaultRegistry().providerCount == 4`; with one stub-throwing provider, `succeededCount == 3 / totalCount == 4`; 10× run determinism with 4 disjoint stubs | AC-F-21..F-23 |

Total **new** test cases: 12 (parser) + 8 (naming) + 8 (provider lsof) +
8 (provider claude) + 1 (semaphore) + 2 (plist mtime) + 2 (launchd
provider) + 3 (registry) ≥ 12 — comfortably meets AC-Q-02.

Coverage target ≥ 80% on each new file (AC-Q-03). The two providers split
their parser/naming logic into pure helper enums precisely so coverage is
achievable without subprocess mocks.

### Integration smoke (manual, by Tester)

- App launches; menu bar opens; both new sources appear in the dashboard
  list when the local environment has them. AC-F-Q09.

### Performance (timed under XCTest)

- AC-P-02: 100-iteration `XCTMeasure` of `discoverAll()` on a registry of
  4 stubbed providers; assert median < 50 ms.
- AC-P-03: 200 unique stub PIDs through `LsofProcessProvider` with `psRunner`
  returning instantly; assert wall-clock < 500 ms and high-water ≤ 8.
- AC-P-01 / AC-P-04 are existing guarantees; the test cycle log records the
  observed numbers without asserting hard thresholds for AC-P-01.

### Static checks (Reviewer / Tester)

- `grep 'Process()' Sources/AgentJobsCore/Discovery/Providers/` returns
  empty (AC-Q-04).
- `git diff main...HEAD -- 'Sources/AgentJobsMac/*.swift' | wc -l` returns
  0 (AC-V-01).
- `git diff main...HEAD --` of public API files shows only doc/comment
  changes (AC-Q-06).

## Open risks

1. **`/usr/sbin/lsof` availability.** macOS ships it at `/usr/sbin/lsof`.
   Confirmed for macOS 14. If a future system removes it, the provider
   throws `.ioError` and the registry isolates the failure — acceptable
   degradation.
2. **`AsyncSemaphore` correctness under cancellation.** A cancelled waiter
   must still allow other waiters to make progress. We will write a test
   that cancels half the waiters mid-flight and asserts the remaining all
   complete. If the simple actor-based design fails this test, fall back
   to a `TaskGroup` + counter inside the provider (≤ 30 LOC) and ship without
   the reusable helper. Decision deferred to T05 implementation; recorded
   here as a known risk.
3. **Test-bundle resource copying.** `swift test` requires the
   `resources: [.copy("Fixtures")]` line on the test target in
   `Package.swift`. If `Bundle.module` doesn't expose the files at runtime
   (occasional SwiftPM gotcha on certain Xcode versions), fall back to
   inline string literals. Tester verifies on first cycle; not a blocker.
4. **`LaunchdPlistReader` source-compat for `Enrichment`.** Adding `mtime`
   to a public struct's stored properties is a SemVer-major change *only*
   if a downstream module pattern-matches all fields. Internal callers
   (just `LaunchdUserProvider`) use named accessors; no risk inside this
   repo. Add a default value (`mtime: Date? = nil` on the initializer) so
   any future caller compiles unchanged.
5. **TS scanner divergence.** The TS `friendlyLiveName` does string
   manipulation on the `agent` value as a string. We map TS's `manual` →
   Swift `nil`, and TS's `claude-code`/`cursor`/`github-copilot`/`openclaw`
   → typed `AgentKind`. The fallback branch (line 117 of `scanner.ts`) uses
   `agent.replace(/-/g, ".")` to build a regex against the full command;
   we replicate the *intent* (try to extract a sub-command after the agent
   binary) but not the regex byte-for-byte — exact regex parity adds 30 LOC
   of escaping for marginal user value. We document this in
   `LiveProcessNaming` doc-comments and pin behavior with focused tests.
6. **Total task count = 11.** Within 5–12 limit. No PM pushback.
