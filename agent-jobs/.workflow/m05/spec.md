# M05 — Content fidelity + Visual Harness library

> First milestone under the new UI-quality regime. Closes 4 P0 design tickets (T-004, T-005, T-006, T-007). Establishes the `AgentJobsVisualHarness` library that all subsequent milestones depend on for ui-critic gating.

## Goal (one sentence)

Make every row in agent-jobs **say what it actually is** (friendly title + 1-line summary), **show what it's actually doing** (CPU%/RSS for live processes), **reflect what's actually scheduled** (cron buckets non-zero when data exists), and ship a **reusable visual harness** with a `capture-all` CLI that drives the menu-bar popover from automation so the new ui-critic agent can score future milestones.

## User value (why now)

Today the product fails its own value-prop in two seconds: rows show `application.com.apple.MobileSMS.115...` (raw launchd Label), CPU/Memory columns show `—`, and one source bucket shows `0` when the user can see the source file is non-empty. A new user who clicks the menu bar icon cannot identify a single thing they're looking at. **Functional ACs proved the UI doesn't crash, not that it's good** — that's the gap M05 closes.

The visual harness piece exists because tonight's manual `osascript click` did NOT actually open the MenuBarExtra popover (T-007). Without programmatic popover capture, no future visual AC can prove popover quality. Every milestone after M05 leans on this library.

## Scope (in)

### Deliverable 1 — `AgentJobsVisualHarness` SwiftPM library target

New library target sibling to `AgentJobsCore` and `AgentJobsMac` at `macapp/AgentJobsMac/Sources/AgentJobsVisualHarness/`. Modules per `.workflow/DESIGN.md`:

- **`Snapshot.swift`** — `func snapshot(_ view: some View, size: CGSize, scheme: ColorScheme) async -> NSImage` (lift from existing test helper to library).
- **`MenuBarInteraction.swift`** — `func locateAgentJobsMenuExtra() throws -> CGRect` via `AXUIElement`; `func clickMenuExtra() throws` via `CGEventCreateMouseEvent`; `func dismissPopover() throws`. Closes T-007.
- **`WindowInteraction.swift`** — `func locateMainWindow() throws -> NSWindow?`; `func resizeMainWindow(to: CGSize) throws`; `func scrollList(by: Int)`; `func clickRow(at: Int)`.
- **`CritiqueReport.swift`** — `struct Critique { name: String; kind: Kind; pngURL: URL; metadata: [String: String] }`; writes paired `.png` + `.json` sidecar (timestamp, app version, OS version, scheme, scenario name, dataset hash).
- **`DiffReport.swift`** — wraps existing `scripts/visual-diff.sh`; returns structured `DiffSummary { pixelsChanged, percentage, threshold, verdict }`.
- **`capture-all` executable** — `swift run capture-all --out <dir>` produces the 10 PNGs listed below. Plain Swift executable target inside the same package.

The library must compile on its own (`swift build --target AgentJobsVisualHarness`) without depending on the test target, and existing visual tests should be migrated to import it (replacing ad-hoc helpers in `Tests/.../Visual/`).

### Deliverable 2 — `ServiceFormatter` (closes T-005)

New file `macapp/AgentJobsMac/Sources/AgentJobsCore/Formatting/ServiceFormatter.swift`. Pure value-type module:

- `static func friendlyTitle(_ s: Service) -> String` — derives a human title from `Service.source` + `Service.name` + `Service.command`. Concrete rules:
  - launchd label `com.apple.MobileSMS.115xxxx` → `"iMessage"` (strip vendor prefix, take last meaningful segment, title-case known map of bundle ids).
  - launchd label with no map match → last `.`-delimited segment, title-cased, drop numeric tail.
  - process services → process name from `command` first arg's basename.
  - cron / claude entries → already use `friendlyCronName`; just pass through.
  - agent-jobs JSON → existing `name` field (curated).
- `static func summary(_ s: Service) -> String` — 1-line auxiliary info:
  - launchd: program-path tail (`/usr/bin/foo` → `foo`) OR humanized schedule.
  - process: `pid 1234 · 1.2 GB`-style if metrics present, else `pid 1234`.
  - cron: humanized schedule (`every 10 min`).
  - claude scheduled: humanized schedule + `· session a1b2c3d4` if applicable.
- Rules pinned by tests (table-driven). No SwiftUI imports — pure Foundation.

Wired into:
- `MenuBarViews.swift` row template → primary text uses `friendlyTitle`, secondary text uses `summary`.
- `DashboardView.swift` list row → primary `friendlyTitle`; secondary as inline secondary column.
- `ServiceInspector.swift` header → `friendlyTitle` + `summary` line.

**Identity preservation:** `Service.id` MUST remain stable across formatter evolution. Formatter operates on display only; `id` is unchanged.

### Deliverable 3 — `LiveResourceSampler` (closes T-006)

New file `macapp/AgentJobsMac/Sources/AgentJobsCore/Discovery/Providers/LiveResourceSampler.swift`. Sampling actor:

- `actor LiveResourceSampler` — `func sample(pid: Int32) async -> ResourceMetrics?` using `proc_pid_taskinfo()` (libproc.h) for RSS in bytes and CPU% computed from `pti_total_user + pti_total_system` ticks since previous sample.
- Internal cache `[pid: PreviousSample]` so CPU% is true-delta, not since-process-start.
- `func sampleAll(_ services: [Service]) async -> [String: ResourceMetrics]` — keyed by `Service.id`; only services with `pid != nil`.
- Wired into `RefreshScheduler` tick: after each `discover()`, call `sampleAll`, then merge `ResourceMetrics` into matching `Service` instances before publishing to the view model.
- **Threading:** sampling MUST happen off the main actor (sampler is its own actor). Main thread is only touched at the final merge → publish.
- Errors: `ESRCH` (process exited) → omit from result; never crash, never surface a user-facing error.

UI: `MetricTile` / `MemoryBadge` already render numeric values; nothing to change there.

### Deliverable 4 — Cron empty-bucket root-cause + fix (closes T-004)

See "Root cause" section below for findings. Fix scope:

a. **Bucket mapping fix** — in `ServiceSource.bucket` (line 49), `.cron, .at` currently map to `.launchd` placeholder. Add a real bucket case `cron` and update `Bucket.allCases` ordering. The `liveProcess` bucket gains `.brewServices`. Five buckets become six (or, alternative, fold cron+launchd into one labeled "schedulers" — architect's call).

b. **`ClaudeScheduledTasksProvider` empty-file UX** — provider already returns `[]` correctly when file is missing (verified). No code change. The empty bucket is **intentional state**, not a bug — but the strip currently can't differentiate "missing data" from "broken provider". This is T-008's territory (M06). For M05 we add an opt-in **diagnostics path**: provider exposes `lastError: ProviderError?` (nil if file simply absent vs `.ioError("permission denied")` if read failed); the view model surfaces it in the source-bucket-chip tooltip.

c. **`ClaudeSessionCronProvider` validation** — add a one-shot integration test that runs the real provider against a fixture directory (committed under `Tests/.../Fixtures/claude-projects/`) containing a synthetic JSONL with one CronCreate event, asserts non-empty result. This catches future regressions where parser silently drops everything.

### Deliverable 5 — `capture-all` CLI scenarios

> **Amended in TESTING cycle 1 (2026-04-24):** the implemented scenario set diverged
> from the table originally written here. Per reviewer M1 + tester decision, the
> actual implementation is recorded as the contract — light/dark coverage on the
> popover and dashboard is more useful for ui-critic than rigid `confirm-stop` /
> `hidden-toggle-on` slots which can be added in a later milestone. AC-F-02 +
> AC-V-03 + AC-UC-02 require ten `NN-…` PNG+JSON pairs with a valid sidecar; the
> exact slot list below is the implemented one.

Ten PNG/JSON pairs the CLI MUST produce when run against the M05 stub registry
(`StubServiceRegistry.populated()`-equivalent containing one entry per source so
every bucket renders non-zero):

| # | File | What it shows | Why ui-critic needs it |
|---|---|---|---|
| 01 | `01-menubar-popover-light.png` | Popover, populated, light scheme | Default popover row design check |
| 02 | `02-menubar-popover-dark.png` | Popover, populated, dark scheme | Dark-mode popover parity |
| 03 | `03-menubar-popover-empty-light.png` | Popover, empty registry, light | Empty-state quality (T-008 future) |
| 04 | `04-dashboard-populated-light.png` | Dashboard, populated, light, 1200x700 | Default dashboard row design |
| 05 | `05-dashboard-populated-dark.png` | Dashboard, populated, dark, 1200x700 | Dark-mode dashboard parity |
| 06 | `06-dashboard-empty-light.png` | Dashboard, empty registry, light | Empty-state quality |
| 07 | `07-dashboard-inspector-light.png` | Dashboard with row selected, inspector visible, light | Inspector header readability |
| 08 | `08-dashboard-inspector-dark.png` | Same, dark scheme | Dark-mode inspector parity |
| 09 | `09-dashboard-narrow-light.png` | Dashboard at narrow size 900x600 | Density / min-size guarantee |
| 10 | `10-menubar-popover-with-failure-light.png` | Popover with `AlwaysFailingProvider` wired | Error-state quality |

Each `.json` sidecar contains: `{ scenarioName, capturedAt (ISO8601), appCommit (sha), osVersion, colorScheme, datasetHash (SHA256 of fixture services payload) }`.

The CLI MUST exit non-zero if any scenario fails to capture and MUST clean up popover state between scenarios (so leftover popover doesn't bleed into the next dashboard shot).

## Out of scope (explicit non-goals)

- **Popover redesign** (≥480pt width, status pill, grouping by status) — that's T-002 / M06.
- **Dashboard default-size change** to 1280×800 — that's T-003 / M06. M05's `06-dashboard-1440x900` shot is for ui-critic context, not because we're changing the launch size.
- **Custom app icon** — T-001 / M07.
- **0-count chip dimming + tooltip behavior change** — T-008 / M06 (M05 only adds the data plumbing, not the UI).
- **ui-critic agent activation as a hard gate** — M06 is the first milestone with the gate enforcing. M05 ships the harness so the agent has something to invoke.
- **Brew / cron / login-item providers** — none added in M05. We fix the bucket mapping but no new sources discovered.
- **CPU% sampling for non-process services** (launchd, cron) — those legitimately have no PID; columns stay `—`.
- **Cross-process resource sampling on aggregate process trees** — single-pid only.

## Constraints

- **Identity stability:** `Service.id` unchanged across formatter rewrites. Tests pin this.
- **Main-thread discipline:** `LiveResourceSampler` runs as its own actor, off the main actor. Verified by Instruments-equivalent test (lightweight: assert sampler API is async + actor-isolated).
- **No `~/.agent-jobs/` writes from tests** — carry over E001 / E002 + WatchPaths discipline. `LiveResourceSampler` reads only via `proc_pidinfo`.
- **swift-testing**, not XCTest, per E002.
- **Spec budgets gated** by `AGENTJOBS_PERF=1` env var per E001 — applies to: ServiceFormatter latency, LiveResourceSampler latency.
- **No new third-party dependencies** unless architect documents rationale.
- **macOS 14+** target preserved.

## Root cause (T-004) — pre-investigated by PM

PM ran the diagnostic before writing this spec. Findings:

1. **`~/.claude/scheduled_tasks.json` does NOT exist on the user's current machine.** `ls` returns "No such file or directory". Therefore the `claudeScheduled` (= claude-sched) bucket showing `0` is **factually correct**, not a bug — there are no durable Claude scheduled tasks on this machine.

2. **`~/.claude/projects/` exists with 22 project subdirectories and 62 JSONLs modified within the last 7 days.** Of those, **3 sessions contain genuine `"name":"CronCreate"` tool_use entries** (1, 4, and 18 events respectively). So `claudeSession` (= claude-loop) bucket SHOULD show non-zero rows.

3. **Whether claude-loop bucket actually shows non-zero in the live UI is unverified** — the user reported "cron source bucket shows 0" but didn't disambiguate which of the two Claude-related buckets. T-004's ticket text says "claude-sched bucket displays 0" — that bucket is legitimately 0 here. It's possible the user conflated the two, or the session-cron parse silently failed at runtime.

4. **`ServiceSource.bucket` mapping has a placeholder bug** at line 49: `.cron, .at` → `.launchd` placeholder. There is **no unix-cron provider wired into `defaultRegistry()`** today (`AgentJobsJsonProvider`, `LaunchdUserProvider`, `LsofProcessProvider`, `ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`). So this bug doesn't fire in production yet, but it's a latent landmine for the moment a cron provider lands.

5. **Likely real-world failure mode for claude-loop = 0:** `ClaudeSessionCronProvider.parseAll` swallows per-file parse errors silently (returns `nil` from the task → filtered out). If `URL.lines` async streaming hits any single file with a transient I/O error, that file is dropped — and if that happens to be the only file with cron events, the bucket becomes 0 with no surfaced error. Add `lastError`/per-file diagnostics so this isn't invisible.

**Fix surface:**
- (a) Bucket mapping: introduce a real `cron` bucket OR document the placeholder explicitly; architect picks. PM recommendation: **introduce real `cron` bucket** so the model is honest, even if no provider populates it yet — it tees up a future cron provider cleanly.
- (b) Diagnostics: add `lastError` on providers; surface in chip tooltip.
- (c) Integration test: real provider against a committed JSONL fixture proves the parse → service path doesn't silently drop.
- (d) Empty-state UX (dimming + "no scheduled_tasks.json found" tooltip): defer to M06 / T-008.

## Open questions for architect

1. **Six buckets vs five-with-cleaner-mapping** — should we promote `cron` to its own bucket case in `Bucket` enum (forcing the strip to render 6 chips), or remove the placeholder cruft and document that `.cron` collapses into `launchd` until a real cron provider lands? PM recommendation above; final call is yours.
2. **`capture-all` CLI as separate executable target vs `swift test --filter` invocation** — separate executable is more portable (ui-critic agent can run it without the test target), but doubles the build matrix. Defer the call but please decide before architecture.md ships.
3. **`LiveResourceSampler` cadence** — sample on every refresh tick (10s today) wastes CPU when popover is closed. Should the sampler subscribe to `VisibilityProvider` so it pauses when no UI is visible, mirroring the M04 battery-pause pattern? PM leans yes; flag if the wiring is more than ~30 LOC.
