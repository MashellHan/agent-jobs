# M05 Tasks

> 11 atomic tasks. Tests use **swift-testing** (`@Suite`, `@Test`, `#expect`) per E002. Spec budgets gated by `AGENTJOBS_PERF=1` per E001. Each task ≤ 150 LOC diff.

## Ordering rationale

Package surgery (T01) lands first so every subsequent task builds against the right module graph. Then library skeleton (T02) so `AgentJobsVisualHarness` can be imported. Content layer (T03 ServiceFormatter, T04 LiveResourceSampler) and provider diagnostics (T05) are independent of the harness; do them in parallel-friendly order. Then the harness implementations (T06 MenuBarInteraction + WindowInteraction, T07 CritiqueReport + DiffReport). Then the executable (T08). Then visual baseline regen (T09 — depends on T03's title rewrites). Then ui-critic plumbing (T10) and the optional PROTOCOL phase update (T11).

---

## T01 — Package.swift surgery: extract `AgentJobsMacUI` library; add `AgentJobsVisualHarness` library + `CaptureAll` executable [DONE]

- **Files:**
  - `macapp/AgentJobsMac/Package.swift` (edit)
  - `macapp/AgentJobsMac/Sources/AgentJobsMacApp/main.swift` (new, ~10 lines — `@main App`)
  - `macapp/AgentJobsMac/Sources/AgentJobsMacUI/AgentJobsMacUI.swift` (move from existing `Sources/AgentJobsMac/AgentJobsMacApp.swift`)
  - rename directory `Sources/AgentJobsMac/` → `Sources/AgentJobsMacUI/` (preserves the `Components/`, `Features/`, `Refresh/` subtrees)
  - new empty target dirs: `Sources/AgentJobsVisualHarness/`, `Sources/CaptureAll/`
  - all test files: `import AgentJobsMac` → `import AgentJobsMacUI` (mechanical sed)
- **Depends on:** none
- **Acceptance:** `swift build` green for all 4 targets. Existing test suites still pass (no logic change). `swift package describe --type json` lists `AgentJobsCore`, `AgentJobsMacUI`, `AgentJobsVisualHarness` as library targets and `AgentJobsMacApp`, `CaptureAll` as executables. **Enables AC-F-01, AC-Q-01.**
- **Estimated diff size:** M (mostly mechanical moves)

## T02 — `AgentJobsVisualHarness` skeleton + lift `Snapshot` from tests [DONE]

- **Files:**
  - `Sources/AgentJobsVisualHarness/Snapshot.swift` (lift from `Tests/.../Visual/ScreenshotHarness.swift`, rename, make public)
  - `Sources/AgentJobsVisualHarness/MenuBarInteraction.swift` (stub — types + signatures, body throws `.notImplemented`)
  - `Sources/AgentJobsVisualHarness/WindowInteraction.swift` (stub)
  - `Sources/AgentJobsVisualHarness/CritiqueReport.swift` (stub)
  - `Sources/AgentJobsVisualHarness/DiffReport.swift` (stub)
  - delete `Tests/AgentJobsCoreTests/Visual/ScreenshotHarness.swift`
  - update existing visual tests to `import AgentJobsVisualHarness` and reference `Snapshot.capture` (was `ScreenshotHarness.capture`)
  - `Tests/AgentJobsCoreTests/Visual/HarnessSnapshotTests.swift` (new — parity-check the lifted code renders identically by re-running M02-M04 baselines through it)
- **Depends on:** T01
- **Acceptance:** `swift build --target AgentJobsVisualHarness` exits 0 with no warnings. M02-M04 visual baselines stay green (within 1% pixel diff). **Enables AC-F-01, AC-V-03 (the directory exists once executable lands).**
- **Estimated diff size:** S

## T03 — `ServiceFormatter` (closes T-005) [DONE]

- **Files:**
  - `Sources/AgentJobsCore/Formatting/ServiceFormatter.swift` (new — `FormattedService` + `ServiceFormatter` + `bundleIdMap`)
  - `Tests/AgentJobsCoreTests/ServiceFormatterTests.swift` (new — table-driven, ≥12 cases; identity preservation; perf gated)
- **Depends on:** T01
- **Acceptance:** AC-F-06 (table), AC-F-07 (length invariant), AC-F-08 (id stability), AC-P-01 (gated < 50µs).
- **Estimated diff size:** M

## T04 — `LiveResourceSampler` actor (closes T-006) [DONE]

- **Files:**
  - `Sources/AgentJobsCore/Discovery/Providers/LiveResourceSampler.swift` (new — actor + `proc_pid_taskinfo` bridge)
  - `Sources/AgentJobsCore/Domain/Service.swift` (add `func with(metrics: ResourceMetrics) -> Service`)
  - `Tests/AgentJobsCoreTests/LiveResourceSamplerTests.swift` (new — sample own pid, ESRCH for 99999, perf gated)
- **Depends on:** T01
- **Acceptance:** AC-F-09 (own pid populated), AC-F-10 (ESRCH → nil, no throw), AC-P-02 (gated 100 PIDs < 100 ms).
- **Estimated diff size:** M

## T05 — Provider diagnostics + `ClaudeSessionCronProvider` `lastError` surface (closes T-004) [DONE]

- **Files:**
  - `Sources/AgentJobsCore/Discovery/ServiceProvider.swift` (add `ProviderHealth` struct)
  - `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift` (`DiscoveryResult.health: [ProviderHealth]`; collect from each provider)
  - `Sources/AgentJobsCore/Discovery/Providers/ClaudeSessionCronProvider.swift` (add `ProviderDiagnostics` actor + per-file failure recording)
  - `Sources/AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift` (same diagnostics shape)
  - `Sources/AgentJobsCore/Domain/ServiceSource.swift` (collapse placeholder bucket cases per arch §Q1; document)
  - `Tests/AgentJobsCoreTests/Fixtures/claude-projects/-Users-fixture-acme/fixture-session.jsonl` (new — 1 paired CronCreate)
  - `Tests/AgentJobsCoreTests/ClaudeSessionCronIntegrationTests.swift` (extend — fixture-driven non-zero result)
  - `Tests/AgentJobsCoreTests/ProviderDiagnosticsTests.swift` (new — EACCES injection → lastError populated; missing file → lastError nil)
  - `Tests/AgentJobsCoreTests/SourceBucketTests.swift` (extend — AC-F-13 enumerate constructible cases)
- **Depends on:** T01
- **Acceptance:** AC-F-12 (fixture parses to ≥1 service), AC-F-13 (mapping consistent), AC-F-14 (tooltip surface).
- **Estimated diff size:** L (split possible: T05a fixture + integration test, T05b diagnostics actor — keep as one if under 150 LOC net)

## T06 — `MenuBarInteraction` + `WindowInteraction` real implementations (closes T-007)

- **Files:**
  - `Sources/AgentJobsVisualHarness/MenuBarInteraction.swift` (replace stub: AX locate + CGEvent click + Escape dismiss + `requiresAccessibility()` check + in-process fallback)
  - `Sources/AgentJobsVisualHarness/WindowInteraction.swift` (replace stub: `NSWindow` lookup + `setFrame` + scroll/click via responder chain)
  - `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarViews.swift` (add `.accessibilityIdentifier("agent-jobs.menubar")` on label)
  - `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` (add NotificationCenter observer for in-process popover toggle fallback)
  - `Tests/AgentJobsCoreTests/MenuBarInteractionTests.swift` (new — in-process path verified; AX path `.enabled(if: AXIsProcessTrusted())`)
  - `Tests/AgentJobsCoreTests/WindowInteractionTests.swift` (new)
- **Depends on:** T02
- **Acceptance:** AC-F-03 (popover opens + reachable via AX after click), AC-F-04 (resize ±1pt observable).
- **Estimated diff size:** M

## T07 — `CritiqueReport` + `DiffReport` real implementations

- **Files:**
  - `Sources/AgentJobsVisualHarness/CritiqueReport.swift` (replace stub: `Critique` struct + JSON sidecar writer)
  - `Sources/AgentJobsVisualHarness/DiffReport.swift` (replace stub: `Process` exec of `scripts/visual-diff.sh`, parse output)
  - `Tests/AgentJobsCoreTests/CritiqueReportTests.swift` (new — sidecar key set per AC-F-05)
  - `Tests/AgentJobsCoreTests/DiffReportTests.swift` (new — known-identical PNG → 0% pixels changed)
- **Depends on:** T02
- **Acceptance:** AC-F-05 (sidecar keys: scenarioName, capturedAt, appCommit, osVersion, colorScheme, datasetHash).
- **Estimated diff size:** S

## T08 — `capture-all` CLI executable + 10 scenarios

- **Files:**
  - `Sources/CaptureAll/main.swift` (new — argparse + 10 scenario closures)
  - `Sources/CaptureAll/Scenarios.swift` (new — table of `(name, kind, viewBuilder, size)` so `main.swift` stays thin)
- **Depends on:** T02, T03, T04, T06, T07
- **Acceptance:** AC-F-02 (10 PNG + 10 JSON pairs), AC-V-03 (directory present, files non-empty + valid PNG magic), AC-P-03 (gated < 30 s).
- **Estimated diff size:** L (≤150 LOC if scenario table is data-driven)

## T09 — Wire `ServiceFormatter` + `LiveResourceSampler` into views; regenerate baselines

- **Files:**
  - `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` (instantiate `LiveResourceSampler`; call `sampleAll` after `discoverAllDetailed`; expose `errorByBucket: [Bucket: String]`)
  - `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarViews.swift` (row template uses `ServiceFormatter.format`)
  - `Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift` (row template uses formatter; CPU/Memory columns now bind to `metrics`)
  - `Sources/AgentJobsMacUI/Features/Dashboard/ServiceInspector.swift` (header uses `friendlyTitle` + `summary`) — file may need to be created/located
  - `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketChip.swift` (`.help(...)` modifier reads `errorByBucket`)
  - `Tests/AgentJobsCoreTests/Visual/screenshots/baseline/popover-light.png` etc. (regenerate)
  - `Tests/AgentJobsCoreTests/Visual/VisualBaselineTests.swift` (assert friendly titles render; AC-V-04)
- **Depends on:** T03, T04, T05
- **Acceptance:** AC-V-01 (popover baselines show friendly titles within 1%), AC-V-02 (CPU%/RSS populated), AC-V-04 (inspector header), AC-F-11 (refresh tick merges metrics), AC-F-14 (tooltip).
- **Estimated diff size:** M

## T10 — `scripts/ui-critic-smoke.sh` + ui-critic plumbing checks

- **Files:**
  - `scripts/ui-critic-smoke.sh` (new — runs `cd macapp/AgentJobsMac && swift run capture-all --out .workflow/m05/screenshots/critique/`; asserts 20 files; exits 0/1)
  - `Tests/AgentJobsCoreTests/UICriticSmokeTests.swift` (new — invokes the shell script via `Process`, asserts AC-UC-01 + AC-UC-02 sidecar parsing)
- **Depends on:** T08
- **Acceptance:** AC-UC-01 (smoke runs the documented command, exits 0, all 10 PNGs present), AC-UC-02 (each `.json` parses, scenarioName matches `01-…` prefix, colorScheme valid).
- **Estimated diff size:** S

## T11 — `PROTOCOL.md`: add UI-CRITIC phase to state machine

- **Files:**
  - `.workflow/PROTOCOL.md` (edit — add `UI-CRITIC` between `TESTING` and `ACCEPTED` in the diagram; add row to "Agent ↔ Phase Mapping" table; add ui-critic lock TTL note: 60 min)
- **Depends on:** none (documentation-only; can land any time)
- **Acceptance:** Diagram shows `TESTING → UI-CRITIC → ACCEPTED` with the REJECT loop back to `IMPLEMENTING (cycle++)` per `.workflow/DESIGN.md`. Table lists `ui-critic` agent owning the UI-CRITIC phase, reading `m{N}/screenshots/critique/`, writing `m{N}/ui-review.md`. **Note:** M05 does NOT enforce the gate (per spec §"Out of scope"); this task is documentation that the M06 PM/architect will rely on.
- **Estimated diff size:** S
- **Descope rule:** if cumulative M05 diff exceeds budget, T11 may be deferred to M06 prep — the `ui-critic` agent prompt already documents the gate semantics and can run advisory in M05.

---

## AC traceability matrix

| AC | Task(s) |
|---|---|
| AC-F-01 (harness builds standalone) | T01, T02 |
| AC-F-02 (capture-all 10 PNG/JSON pairs) | T08 |
| AC-F-03 (clickMenuExtra opens popover) | T06 |
| AC-F-04 (resizeMainWindow ±1pt) | T06 |
| AC-F-05 (sidecar keys) | T07 |
| AC-F-06 (friendlyTitle table ≥12) | T03 |
| AC-F-07 (summary length invariant) | T03 |
| AC-F-08 (id stability across formatter) | T03 |
| AC-F-09 (sample own pid) | T04 |
| AC-F-10 (ESRCH swallowed) | T04 |
| AC-F-11 (refresh tick merges metrics) | T04, T09 |
| AC-F-12 (cron provider non-zero on fixture) | T05 |
| AC-F-13 (bucket mapping consistent) | T05 |
| AC-F-14 (lastError surfaces in chip tooltip) | T05, T09 |
| AC-V-01 (popover baselines, friendly titles) | T09 |
| AC-V-02 (dashboard baselines, CPU/RSS populated) | T09 |
| AC-V-03 (critique dir produced) | T08, T10 |
| AC-V-04 (inspector header) | T09 |
| AC-P-01 (formatter <50µs gated) | T03 |
| AC-P-02 (sampleAll 100 PIDs <100ms gated) | T04 |
| AC-P-03 (capture-all <30s gated) | T08 |
| AC-P-04 (refresh-tick latency no regress) | T09 |
| AC-Q-01 (swift build green) | all |
| AC-Q-02 (swift test green, ≥80% coverage) | all |
| AC-Q-03 (no print()) | reviewer-enforced |
| AC-Q-04 (no force-unwraps) | reviewer-enforced |
| AC-Q-05 (no ~/.agent-jobs writes) | tester-enforced |
| AC-UC-01 (ui-critic-smoke.sh works) | T10 |
| AC-UC-02 (sidecar metadata parses) | T07, T10 |

Every AC is addressed by at least one task.
