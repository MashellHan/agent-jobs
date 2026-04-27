# M05 Architecture

> Closes T-004 / T-005 / T-006 / T-007. Introduces a third SwiftPM target — `AgentJobsVisualHarness` — plus a `capture-all` executable, the `ServiceFormatter` content layer, the `LiveResourceSampler` actor, and provider diagnostics. Tests are swift-testing per E002. Spec budgets gated by `AGENTJOBS_PERF=1` per E001.

## Decisions on PM's three open questions

### Q1 — Six buckets vs five

**Decision: keep five buckets for M05; remove the placeholder cruft.**

Rationale: introducing `Bucket.cron` with no provider feeding it ships an always-zero chip — exactly the "blank pane = looks broken" smell T-008 exists to fix. Today `defaultRegistry()` wires `LaunchdUserProvider` only for scheduler-shaped sources, so `.cron / .at / .brewServices / .loginItem` cannot be produced by any provider. The placeholder mappings are therefore dead code.

Concrete change: `ServiceSource.bucket` returns a non-optional `Bucket` with **only the five real cases** producing a value; the four placeholder cases (`.cron, .at, .brewServices, .loginItem`) become `fatalError("unreachable: no provider produces \(self)")`. A unit test (AC-F-13) iterates every constructible case and asserts the mapping is reachable from a wired provider. When a real `cron` provider lands (post-M05), the architect of that milestone adds `Bucket.cron` and the corresponding `displayName` / `sfSymbol` / strip ordering in one diff.

This is honest: the data model says "we know `.cron` exists, no provider populates it yet." A 6-bucket strip with one perpetual zero would teach the user to ignore that chip — the worst possible UX.

### Q2 — `capture-all` as separate executable target vs `swift test --filter`

**Decision: separate `executableTarget`.**

Rationale: ui-critic invokes `swift run capture-all` per `.claude/agents/ui-critic.md` — that line is non-negotiable. Routing through `swift test --filter` would require the test target to import AppKit + AX + CGEvent (it already does for visual baselines), couple PNG output to the test runner's lifecycle (parallel execution, randomized order, ephemeral working directory), and force the agent to parse `xunit` output to know if all 10 PNGs were produced. The executable target costs one additional ~80 LOC `main.swift` plus a build-matrix entry; it earns a clean CLI contract, deterministic exit codes, and `--out` argument handling.

Build cost: `swift build` already compiles the harness library for the test target; adding the executable adds one link step (~2 s on dev box). Acceptable.

### Q3 — `LiveResourceSampler` cadence (visibility-pause)

**Decision: yes, subscribe to `VisibilityProvider`. Wiring is ~20 LOC.**

The sampler does NOT own the visibility subscription. Instead, the existing `RefreshScheduler` continues to be the single fan-in for visibility-pause (M04 pattern). The sampler is invoked **inside** `ServiceRegistryViewModel.refresh()` after `discoverAllDetailed()` returns, so when visibility-pause suppresses a refresh tick, sampling is suppressed transitively — no new subscription needed. The sampler exposes a `func sampleAll(_ services: [Service]) async -> [Service.ID: ResourceMetrics]` that the view model awaits before publishing.

This means: zero CPU cost when popover is closed AND no app windows are visible (M04 contract preserved); CPU cost when refresh is allowed to fire (~10s cadence, throttled by the existing scheduler).

---

## Modules touched

| Module | Change kind |
|---|---|
| `AgentJobsCore/Domain/ServiceSource.swift` | edit — collapse placeholder bucket mappings, document |
| `AgentJobsCore/Discovery/ServiceProvider.swift` | edit — add `lastError: ProviderError?` surface |
| `AgentJobsCore/Discovery/Providers/ClaudeSessionCronProvider.swift` | edit — surface per-file parse errors via `lastError` actor box |
| `AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift` | edit — surface IO errors via `lastError` |
| `AgentJobsCore/Discovery/Providers/LiveResourceSampler.swift` | **new** |
| `AgentJobsCore/Formatting/ServiceFormatter.swift` | **new** |
| `AgentJobsCore/Discovery/ServiceRegistry.swift` | edit — collect `lastError` per provider, expose on registry |
| `AgentJobsMac/AgentJobsMacApp.swift` | edit — wire sampler into `refresh()`; expose `errorByBucket` for chip tooltips |
| `AgentJobsMac/Features/MenuBar/MenuBarViews.swift` | edit — primary text via `ServiceFormatter.friendlyTitle`; secondary via `summary` |
| `AgentJobsMac/Features/Dashboard/DashboardView.swift` | edit — same; CPU/Memory columns now non-blank for live procs |
| `AgentJobsMac/Features/Dashboard/SourceBucketChip.swift` | edit — read `errorByBucket` for tooltip when set |
| `AgentJobsMac/Features/Dashboard/ServiceInspector.swift` (or equivalent header file) | edit — header uses `friendlyTitle` + `summary` |
| `Sources/AgentJobsVisualHarness/*` | **new target** (5 files + capture-all main) |
| `Tests/AgentJobsCoreTests/Visual/ScreenshotHarness.swift` | delete — superseded by `AgentJobsVisualHarness.Snapshot` |
| `Tests/AgentJobsCoreTests/Visual/*` | edit — `import AgentJobsVisualHarness` |
| `Tests/AgentJobsCoreTests/Fixtures/claude-projects/` | **new** — synthetic JSONL fixture for AC-F-12 |
| `scripts/ui-critic-smoke.sh` | **new** — AC-UC-01 |
| `Package.swift` | edit — add library + executable targets + test-target dep |

## New types (with module placement)

### Layer 1 — `AgentJobsCore`

- `enum FormattedService` — `Formatting/ServiceFormatter.swift`. Pure value type:
  ```swift
  public struct FormattedService: Sendable, Hashable {
      public let title: String      // primary, ≤ 60 chars
      public let summary: String    // 1-line secondary, ≤ 80 chars, no \n
  }
  public enum ServiceFormatter {
      public static func format(_ s: Service) -> FormattedService
      public static func friendlyTitle(_ s: Service) -> String
      public static func summary(_ s: Service) -> String
  }
  ```
  Foundation-only; no SwiftUI / AppKit. Internal helper: a tiny `bundleIdMap: [String: String]` (≤ 30 entries) for known launchd labels (`com.apple.MobileSMS` → "iMessage", etc.).
- `actor LiveResourceSampler` — `Discovery/Providers/LiveResourceSampler.swift`:
  ```swift
  public actor LiveResourceSampler {
      public init(now: @Sendable () -> Date = { Date() })
      public func sample(pid: Int32) async -> ResourceMetrics?
      public func sampleAll(_ services: [Service]) async -> [Service.ID: ResourceMetrics]
      public func reset()  // test seam — clears the prev-sample cache
  }
  ```
  Internal `private var previous: [pid_t: PrevSample]` (CPU-tick + sampledAt). Calls `proc_pid_taskinfo()` from libproc.h via a `@_silgen_name` declaration or by importing `Darwin.sys.proc`. `ESRCH` → returns `nil`, no throw, no log noise.
- `struct ProviderHealth` — `Discovery/ServiceProvider.swift` extension:
  ```swift
  public struct ProviderHealth: Sendable, Hashable {
      public let providerId: String
      public let lastError: ProviderError?
      public let lastSuccessAt: Date?
  }
  ```
  Reported alongside services. `discoverAllDetailed()` already returns a struct; gain a `health: [ProviderHealth]` field.
- `actor LastErrorBox` — internal helper inside `ClaudeSessionCronProvider` and `ClaudeScheduledTasksProvider` so the (currently non-actor `struct`) providers can mutate per-call diagnostics without losing `Sendable`. Alternative: convert provider to actor — rejected (forces `discover() async throws` callers to suspend even when reading just `lastError`, blast radius too large for M05).

### Layer 2 — `AgentJobsVisualHarness`

New SwiftPM library at `macapp/AgentJobsMac/Sources/AgentJobsVisualHarness/`. Five files + executable.

- `Snapshot.swift` — `@MainActor public enum Snapshot { public static func capture<V: View>(...) async throws -> Data; public static func write<V: View>(... to: URL) async throws -> Data }`. Lifted verbatim from `Tests/.../Visual/ScreenshotHarness.swift` and renamed; same `CaptureError`. Depends on AppKit + SwiftUI (allowed in Layer 2).
- `MenuBarInteraction.swift` — `public enum MenuBarInteraction { public static func locateAgentJobsMenuExtra(bundleHint: String = "AgentJobs") throws -> CGRect; public static func clickMenuExtra() throws; public static func dismissPopover() throws }`. Uses `AXUIElementCreateApplication(pid)` over the running NSStatusItem-host process (typically `SystemUIServer` walked, then ours). Fallback path documented below. Throws `MenuBarInteractionError.{accessibilityDenied, notFound, eventPostFailed}`.
- `WindowInteraction.swift` — `public enum WindowInteraction { public static func locateMainWindow() throws -> NSWindow?; public static func resizeMainWindow(to: CGSize) throws; public static func scrollList(by: Int); public static func clickRow(at: Int) }`. AppKit-only.
- `CritiqueReport.swift` — `public struct Critique { public let name: String; public let kind: Kind; public let pngURL: URL; public let metadata: [String: String]; public func write(to: URL) throws }`. Kind = `.menubar | .popover | .dashboard | .inspector | .modal`. JSON sidecar emitted via `JSONEncoder` with `.sortedKeys + .prettyPrinted` for deterministic diffs.
- `DiffReport.swift` — `public struct DiffSummary { public let pixelsChanged: Int; public let percentage: Double; public let threshold: Double; public let verdict: Verdict }; public enum DiffReport { public static func compare(baseline: URL, candidate: URL, threshold: Double = 0.01) throws -> DiffSummary }`. Wraps existing `scripts/visual-diff.sh` via `Process` exec; parses its 1-line "X.YY%" output.

The library compiles standalone (`swift build --target AgentJobsVisualHarness` exits 0) — depends on `AgentJobsCore` (for `Service.fixtures()` references at test time, but the library code itself only imports Core at the `Snapshot` callsite where the tests pass it in) plus AppKit + SwiftUI + ApplicationServices (for AX).

### Layer 2 — `capture-all` executable

`Sources/CaptureAll/main.swift`. ≤ 150 LOC. Parses `--out <dir>`. Constructs `ServiceRegistryViewModel(registry: .fixtureRegistry())` (and `.emptyRegistry()`, `.failingRegistry()` for scenarios 03/04). Builds the SwiftUI views, calls `AgentJobsVisualHarness.Snapshot.write(...)` for each scenario, then `Critique.write(...)` for the JSON sidecar. Exit code 0 if all 10 pairs produced; 1 otherwise. Depends on `AgentJobsCore`, `AgentJobsMac` (the library product), and `AgentJobsVisualHarness`.

**Important Package.swift detail:** `AgentJobsMac` is currently `executableTarget`. SPM forbids importing an executable target. Therefore Package.swift surgery extracts the SwiftUI/views into a new **library product** that the executable thin-wraps. The two viable shapes:

  (A) Split `AgentJobsMac` into `AgentJobsMacUI` (library) + `AgentJobsMacApp` (executable). `CaptureAll` imports `AgentJobsMacUI`. Cleanest, but a 4-target package and renames the existing executable.

  (B) Keep `AgentJobsMac` executable; have `CaptureAll` import only the views it needs by **moving** the relevant SwiftUI files into the harness target (or a new `AgentJobsMacUI` library). Same as (A) under a different name.

  (C) Have `CaptureAll` re-implement minimal harness views by composing the public types in `AgentJobsCore` directly (the harness "drives" the SwiftUI views via `MenuBarPopoverView`, `DashboardView`, `ServiceInspector`). This requires those views to be `public` in a new library.

**Decision: option (A).** Rename `AgentJobsMac` executable target → `AgentJobsMacApp` executable (1-line product name change, no behavior change), introduce `AgentJobsMacUI` library target containing `Sources/AgentJobsMac/{Components,Features,Refresh}/**`. The thin executable target `Sources/AgentJobsMacApp/main.swift` (one ~10-line file containing only `@main` + `App` body) imports `AgentJobsMacUI` and `AgentJobsCore`. CaptureAll imports `AgentJobsMacUI`.

Migration cost: move `AgentJobsMacApp.swift`'s `@main struct` into `Sources/AgentJobsMacApp/main.swift`; the rest of `AgentJobsMacApp.swift` (the `ServiceRegistryViewModel` etc.) moves into `Sources/AgentJobsMacUI/AgentJobsMacUI.swift`. Existing tests that import `AgentJobsMac` change to `import AgentJobsMacUI`. Estimated 6-file diff, no logic change. **Tracked as T01 in tasks.md** so it lands first.

## Protocols / interfaces

```swift
// AgentJobsCore — net-new
public struct FormattedService: Sendable, Hashable { … }
public enum ServiceFormatter { … }
public actor LiveResourceSampler { … }
public struct ProviderHealth: Sendable, Hashable { … }

// AgentJobsCore — modified
public struct DiscoveryResult { let services: [Service]; let allFailed: Bool; let health: [ProviderHealth] }   // .health added

// AgentJobsVisualHarness — net-new (Layer 2)
@MainActor public enum Snapshot { … }
public enum MenuBarInteraction { … }
public enum WindowInteraction { … }
public struct Critique { … }
public enum DiffReport { … }
```

## Data flow diagram

```
                  ┌─────────────── refresh tick ───────────────┐
                  │                                            │
ServiceRegistry──▶discoverAllDetailed()                        │
                  │  → [Service] + [ProviderHealth]            │
                  ▼                                            │
       LiveResourceSampler.sampleAll(services)  (actor, off-MA)│
                  │  → [Service.ID: ResourceMetrics]           │
                  ▼                                            │
       merge metrics into Service instances                    │
                  │                                            │
                  ▼                                            │
       publish to ServiceRegistryViewModel  (@MainActor)       │
                  │                                            │
                  ▼                                            │
       Views read svc → ServiceFormatter.format(svc)           │
       → FormattedService { title, summary }                   │
                  │                                            │
                  ▼                                            │
       MenuBarPopoverView · DashboardView · ServiceInspector ──┘

For chip tooltip:
  view-model exposes errorByBucket: [Bucket: String] derived from
  health[*].lastError.localizedDescription. SourceBucketChip reads it
  in .help() modifier — only when non-nil.

For capture-all:
  CaptureAll executable
    → ServiceRegistryViewModel(.fixtureRegistry()).refresh()
    → AgentJobsMacUI.MenuBarPopoverView(...)
    → AgentJobsVisualHarness.Snapshot.write(view, size, to: out/02-popover-default.png)
    → Critique(name:"02-popover-default", kind:.popover, …).write(out/02-popover-default.json)
```

## Concurrency model

- `LiveResourceSampler` is an **actor** (Sendable boundary). Owns mutable `previous: [pid_t: PrevSample]`. All API calls are `async`; never blocks. `proc_pid_taskinfo` is a syscall wrapped in `Task.detached(priority: .utility)` inside the actor's method so the actor's executor isn't pinned during the syscall (≤ 50 µs each, 100 PIDs = ~5 ms total well under AC-P-02's 100 ms).
- `LastErrorBox` is also an actor (per provider). Only the provider's `discover()` writes; the registry's `discoverAllDetailed()` reads after the await. No concurrent writers on a single provider instance.
- `ServiceFormatter` is **stateless pure functions**. Sync, hot path. AC-P-01: < 50 µs/call.
- `Snapshot.capture` is `@MainActor` — must be (NSHostingView, RunLoop). The executable's `main.swift` enters MainActor via `@main` + `await MainActor.run { … }`.
- `MenuBarInteraction` is sync (CGEvent + AX are sync APIs); callers are responsible for not invoking it from inside the SwiftUI render closure.

## Persistence schema changes

**None.** No new files written under `~/Library/Application Support/AgentJobs/` or `~/.agent-jobs/`. The synthetic JSONL fixture lives entirely under `Tests/AgentJobsCoreTests/Fixtures/claude-projects/` and is loaded via `Bundle.module`.

## `MenuBarInteraction` design (closes T-007)

### Approach

1. `locateAgentJobsMenuExtra() -> CGRect`:
   - `let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier` is wrong for menu extras (they live in our own pid). Use `let pid = ProcessInfo.processInfo.processIdentifier`.
   - `let app = AXUIElementCreateApplication(pid)`
   - Read `kAXChildrenAttribute` to find the `AXMenuExtra` element. Match by `kAXTitleAttribute` containing "Agent Jobs" or `kAXIdentifierAttribute` if set (we'll set `.accessibilityIdentifier("agent-jobs.menubar")` on `MenuBarLabel` as part of T01).
   - Read `kAXPositionAttribute` + `kAXSizeAttribute` → `CGRect` in screen coords.
2. `clickMenuExtra()`:
   - Get `CGRect` from above; compute center.
   - `CGEventCreateMouseEvent(nil, .leftMouseDown, center, .left)` then `.leftMouseUp`. Post both via `CGEventPost(.cgSessionEventTap, …)`.
   - Return after a 100 ms `Task.sleep` so the popover hosting window is reachable on the next AX query.
3. `dismissPopover()`: post an Escape key event (`CGEventCreateKeyboardEvent(nil, 53, true)` then false), or a click outside the popover frame.

### Permissions

- **Required:** Accessibility (`AXIsProcessTrustedWithOptions`). Without it, `AXUIElementCopyAttributeValue` returns `kAXErrorCannotComplete` for foreign-app elements. For our **own** process (which the menu extra IS), AX queries succeed without TCC consent in most macOS 14 builds — but `CGEventPost` to the global event tap requires Accessibility consent.
- **Detection:** `MenuBarInteraction.requiresAccessibility() -> Bool` returns `!AXIsProcessTrusted()`. The `capture-all` executable calls this at startup; if denied, prints a `stderr` diagnostic with the `tccutil` reset / System Settings path and exits non-zero.
- **Fallback (AX denied):** `MenuBarInteraction.openPopoverViaApp()` — sends an internal NotificationCenter post (`AgentJobsRequestOpenPopover`) that `AgentJobsMacUI`'s app-side observer translates into programmatic `MenuBarExtra` toggle (via a `@State` binding the observer flips). This bypasses AX entirely but only works in the running CaptureAll build (it's in-process). Documented in the harness header doc-comment as the "in-process fallback."

In the CaptureAll context, **the in-process fallback is the primary path** — CaptureAll IS the running app, so it can flip the popover binding directly without ever touching AX. The AX/CGEvent path is the path real ui-critic invocations would prefer when driving an externally-launched app build. AC-F-03 verifies the AX path works; the in-process fallback is exercised by every `02-popover-*` scenario.

## `ServiceFormatter` design (closes T-005)

Lives in `AgentJobsCore/Formatting/ServiceFormatter.swift`. **Stays in Core** because the formatter is pure logic with zero UI dependency, and Core already owns `CronHumanizer` (peer module). No need for a new module.

### Rules (pinned by AC-F-06 table-driven test, ≥ 12 cases)

`friendlyTitle(_ s: Service) -> String`:

1. `s.source == .agentJobsJson` → `s.name` (already curated).
2. `s.source == .claudeScheduledTask` or `.claudeLoop` → `s.name` (already filtered through `friendlyCronName`).
3. `s.source == .launchdUser`:
   - Lookup `bundleIdMap[s.name]` (e.g. `"com.apple.MobileSMS"` → `"iMessage"`). If hit, return.
   - Else strip vendor prefix (`com.apple.`, `com.microsoft.`, `com.google.`, etc., regex `^[a-z]+\.[a-z]+\.`).
   - Drop trailing numeric tail (`/\.\d+$/`).
   - Take the last `.`-delimited segment, title-cased (`MobileSMS` → `Mobile SMS` via camel-split).
   - Truncate to 60 chars with `…` suffix.
4. `s.source == .process(matched:)`:
   - Take basename of first whitespace-token of `s.command` (`"npm run dev"` → `"npm"`). If `s.name` is more descriptive (longer), prefer it.
5. Default: `s.name` (truncated to 60 chars).
6. Empty / numeric-only `s.name` falls back to `s.source.bucket.displayName` + suffix `" (\(s.id.suffix(6)))"`.

`summary(_ s: Service) -> String`:

1. `.launchdUser`: program-path tail of `s.command` (`/usr/local/bin/foo --bar` → `foo`); if path empty, `s.schedule.humanDescription`.
2. `.process(matched:)`: `"pid \(pid)"` + `" · \(formatBytes(rss))"` if metrics present.
3. `.claudeLoop(sessionId:)`: `"\(s.schedule.humanDescription) · session \(sessionId)"`.
4. `.claudeScheduledTask`: `s.schedule.humanDescription`.
5. `.agentJobsJson`: `s.schedule.humanDescription`.
6. Default: `s.schedule.humanDescription`.

Output ≤ 80 chars, no `\n`. AC-F-07 enforces.

`format(_ s: Service) -> FormattedService` returns both. **Identity:** `Service.id` is unmodified — formatter operates on display copies only. AC-F-08 snapshots ids before/after wiring.

## `LiveResourceSampler` design (closes T-006)

Lives in `AgentJobsCore/Discovery/Providers/LiveResourceSampler.swift`. Actor.

### Sampling cadence

Invoked from `ServiceRegistryViewModel.refresh()` after `discoverAllDetailed()`:

```swift
let result = await registry.discoverAllDetailed()
let metricsById = await sampler.sampleAll(result.services)
let merged = result.services.map { svc in
    if let m = metricsById[svc.id] { return svc.with(metrics: m) }
    return svc
}
self.services = merged   // publish on MainActor
```

`Service.with(metrics:)` is a tiny `extension Service` (replaces the immutable struct with `metrics` substituted). One-line addition.

Cadence inherits from refresh tick (10 s baseline; visibility-paused; manual flush). No separate timer — this is the key simplification the PM asked about in Q3.

### Off-main-thread guarantees

- `LiveResourceSampler` is an actor → never the MainActor.
- Inside `sampleAll`, the sampler `await`s `Task.detached(priority: .utility) { proc_pid_taskinfo(…) }` so the syscall runs on the cooperative pool, not the actor's serial executor. (Actors have their own serial executor; running blocking work on it would queue all subsequent calls behind the syscall.)
- The view model awaits `sampleAll` at a single point; the merge + publish is back on the MainActor.

### Error swallowing

- `proc_pid_taskinfo` returns `< 0` → set `errno`. If `errno == ESRCH`, the process exited; return `nil` from `sample(pid:)`. No log.
- Any other errno → log at `.debug` level, return `nil`. Never throws, never surfaces a user-facing error (process sampling is best-effort).
- `sampleAll` collects only non-nil entries; the merge step preserves the prior `metrics` value if the sampler returned `nil` (so a transient ESRCH doesn't blank-flicker the column).

### CPU% calculation

`pti_total_user + pti_total_system` is in mach-time absolute units. CPU% = `Δticks / (Δwall × ticksPerSec) × 100`. Cache the previous `(ticks, wallClock)` per pid. First sample for a pid → return `cpuPercent: 0` (we have no delta yet); column shows `0.0%` until the second sample. Acceptable.

## `ClaudeSessionCronProvider` `lastError` surface (closes T-004)

### Approach

Provider is currently a `struct` returning silently when individual file parses fail (line 174-179: `catch { logger.error(…); return nil }`). M05 adds:

```swift
public actor ProviderDiagnostics {
    public private(set) var lastError: ProviderError?
    public private(set) var perFileFailures: [String: String]  // filename → error
    public func record(_ file: String, _ err: Error) { … }
    public func clear() { … }
    public func snapshot() -> (ProviderError?, [String: String])
}
public struct ClaudeSessionCronProvider: ServiceProvider {
    public let diagnostics: ProviderDiagnostics
    …
}
```

Rules:

- A **0-result-is-valid** call (no JSONLs, no project dir, parse returns 0 cron entries) → `lastError = nil`, `perFileFailures = [:]`. The empty bucket is intentional.
- A call where **at least one** file failed to parse → `lastError = .ioError("N file(s) failed to parse")`, `perFileFailures` populated.
- The chip tooltip (M05 surface) shows `"\(perFileFailures.count) source file(s) failed to parse — see Console.app for details"` when `lastError != nil`. When file is simply absent, no tooltip.

`ServiceRegistry.discoverAllDetailed()` reads `provider.diagnostics.snapshot()` after each provider's `discover()` resolves and packs into `[ProviderHealth]`.

### Why this preserves 0-result-is-valid

`lastError` is `nil` UNLESS a file was attempted-and-failed. Empty `projectsRoot` → no files attempted → `nil`. Missing `scheduled_tasks.json` (handled by `ClaudeScheduledTasksProvider` analogously) → `nil`. Only EACCES, EIO, malformed JSON in an attempted file flips `lastError`.

### AC-F-12 integration test

Synthetic fixture committed at `Tests/AgentJobsCoreTests/Fixtures/claude-projects/-Users-fixture-acme/fixture-session.jsonl`. Contains 1 paired `CronCreate` + `CronUpdate` `tool_use`/`tool_result` exchange (per the existing `SessionJSONLParserTests` shape). Test constructs `ClaudeSessionCronProvider(projectsRoot: bundleFixtureURL)`, asserts `.discover()` returns ≥ 1 `Service` whose `source.bucket == .claudeSession`, and `diagnostics.lastError == nil`. Catches the silent-drop regression PM identified in spec §"Root cause" finding 5.

## `capture-all` CLI scenarios

Ten PNG/JSON pairs. CLI structure:

```
swift run capture-all --out <dir>
  → for each scenario:
     - construct view-model + view per scenario table below
     - await refresh
     - Snapshot.write(view, size, to: dir/<NN-name>.png)
     - Critique(...).write(dir/<NN-name>.json)
  → exit 0 iff 20 files written
```

| # | File | Fixture | View | Size | Notes |
|---|---|---|---|---|---|
| 01 | `01-menubar-icon.png` | `.fixtureRegistry()` | `MenuBarLabel(state: .running(3))` | 64×64 | Composite light+dark via two captures + side-by-side merge |
| 02 | `02-popover-default.png` | `.fixtureRegistry()` | `MenuBarPopoverView` | 480×600 | Default content |
| 03 | `03-popover-empty-state.png` | `.emptyRegistry()` | `MenuBarPopoverView` | 480×600 | Zero services |
| 04 | `04-popover-error-state.png` | `.failingRegistry()` | `MenuBarPopoverView` | 480×600 | All providers throw |
| 05 | `05-dashboard-1024x768.png` | `.fixtureRegistry()` | `DashboardView` | 1024×768 | Smallest supported |
| 06 | `06-dashboard-1440x900.png` | `.fixtureRegistry()` | `DashboardView` | 1440×900 | Recommended |
| 07 | `07-dashboard-resized-min.png` | `.fixtureRegistry()` | `DashboardView` | 900×560 | Enforced minimum |
| 08 | `08-inspector-row-selected.png` | `.fixtureRegistry()` selecting fixture[2] | `DashboardView` | 1280×800 | Inspector visible |
| 09 | `09-confirm-stop.png` | `.fixtureRegistry()` w/ stop dialog open | `DashboardView` overlay `StopConfirmationDialog` | 1280×800 | Modal copy |
| 10 | `10-hidden-toggle-on.png` | `Service.fixtures(includingHidden: 1)` w/ `showHidden=true` | `DashboardView` | 1280×800 | Hidden row visible |

JSON sidecar keys (per AC-F-05 / AC-UC-02): `scenarioName, capturedAt, appCommit, osVersion, colorScheme, datasetHash`.

`appCommit`: `git rev-parse HEAD` via `Process`; on failure, `"unknown"`.
`osVersion`: `ProcessInfo.processInfo.operatingSystemVersionString`.
`datasetHash`: SHA256 of `JSONEncoder().encode(services)` from the chosen fixture.
`colorScheme`: `"light"` for all 10 by default; scenarios 01 includes both via composite (the JSON records `"light+dark"`).

CLI cleans up popover state between scenarios via `MenuBarInteraction.dismissPopover()` (or its in-process equivalent — flip the popover binding to `false`).

## ui-critic gate integration

ui-critic agent already exists at `.claude/agents/ui-critic.md` per the system prompt. The gate becomes ACTIVE in M06 (per spec §"Out of scope"). M05 ships:

- The `capture-all` CLI it invokes.
- `scripts/ui-critic-smoke.sh` (AC-UC-01) that proves the agent can run the documented command and get all 10 PNGs.

**`PROTOCOL.md` UI-CRITIC phase update is deferred to T11 (a numbered task in M05).** Rationale: editing the phase machine is a 5-line diff (one row in the diagram + table) but it changes the lock contract for every subsequent agent. Doing it as an explicit task keeps the change auditable. If T11 is descoped (over budget), the gate still works in M06 — ui-critic can run between TESTING and ACCEPTED via the agent's own discipline; the diagram is documentation, not enforcement.

## Testing strategy

All tests use **swift-testing** (`@Suite`, `@Test`, `#expect`) per E002.

| Surface | Test file | Coverage |
|---|---|---|
| `ServiceFormatter` | `Tests/.../ServiceFormatterTests.swift` | AC-F-06 table (≥12 cases), AC-F-07 80-char invariant, AC-F-08 id stability, AC-P-01 (`AGENTJOBS_PERF=1`) |
| `LiveResourceSampler` | `Tests/.../LiveResourceSamplerTests.swift` | AC-F-09 (own pid), AC-F-10 (ESRCH), AC-F-11 (refresh-tick merge integration), AC-P-02 gated |
| `ClaudeSessionCronProvider` real fixture | `Tests/.../ClaudeSessionCronIntegrationTests.swift` (extend) | AC-F-12 |
| `ServiceSource.bucket` mapping | `Tests/.../SourceBucketTests.swift` (extend) | AC-F-13 |
| Provider `lastError` → chip tooltip | `Tests/.../ProviderDiagnosticsTests.swift` | AC-F-14 |
| `AgentJobsVisualHarness.Snapshot` | `Tests/.../HarnessSnapshotTests.swift` | parity check vs old `ScreenshotHarness` (must match within 1px since impl is lifted verbatim) |
| `MenuBarInteraction` | `Tests/.../MenuBarInteractionTests.swift` | AC-F-03 (in-process fallback path; AX path tagged `.disabled(if: !AXIsProcessTrusted())`) |
| `WindowInteraction` | `Tests/.../WindowInteractionTests.swift` | AC-F-04 |
| `CritiqueReport` | `Tests/.../CritiqueReportTests.swift` | AC-F-05 sidecar key set |
| `capture-all` CLI smoke | `scripts/ui-critic-smoke.sh` invoked via shell test trampoline | AC-UC-01, AC-F-02, AC-V-03, AC-UC-02 |
| Visual baseline regen | `Tests/.../Visual/VisualBaselineTests.swift` (edit) | AC-V-01, AC-V-02, AC-V-04 |

Coverage on changed lines ≥ 80% (AC-Q-02). No `~/.agent-jobs/` writes (AC-Q-05) — the CaptureAll executable writes only to `--out` and the synthetic JSONL fixture is a static resource.

## Open risks

1. **AX consent on the dev box during CI** — if AX is denied, `MenuBarInteraction` AC-F-03 falls back to the in-process path (covered) but the AX-true path stays untested. Risk accepted; the AX path is gated by `.enabled(if: AXIsProcessTrusted())` and recorded as a SKIP with reason rather than a fail.
2. **`proc_pid_taskinfo` permissions on hardened runtime / sandboxed builds** — works for our own pid + same-user pids on macOS 14. For other users' processes, returns `EPERM` → sampler returns `nil` → column stays `—` for those rows. Documented behavior, not a bug.
3. **`Snapshot` lifted verbatim from tests** — the existing helper has been pixel-stable across M02-M04. Lifting it to a library should not change rendering, but baselines will be regenerated as part of T-005 wiring (titles change `application.com.apple.MobileSMS.115...` → `iMessage`). New baselines are committed in the same task as the formatter wiring; reviewer compares to spec §"Deliverable 2" rules table.
4. **`AgentJobsMac` rename to `AgentJobsMacApp` + `AgentJobsMacUI` library extraction** — touches every test file's `import AgentJobsMac`. Single mechanical search-replace; tracked as T01 so the rest of the milestone builds cleanly.
5. **`capture-all` runtime under `swift run`** — must complete < 30 s (AC-P-03). Each scenario is one SwiftUI render + one PNG encode; expect ≤ 1 s/scenario on dev box. Headroom comfortable.
6. **Bucket mapping `fatalError` for placeholder cases** — if any code path in M05 inadvertently constructs `.cron / .at / .brewServices / .loginItem`, the app crashes. Mitigation: AC-F-13 enumerates every constructible case; static-grep test (`StaticGrepRogueRefsTests`) ensures no in-source construction sites exist for those cases. Acceptable trade-off for surfacing the dead-code state.
