# M02 Acceptance Criteria

> Binding contract for the Tester. Tester launches the app via `swift run AgentJobsMac` (or equivalent) from `macapp/AgentJobsMac/` and verifies each item below. Visual ACs reference baseline PNGs under `.workflow/m02/screenshots/baseline/` (committed by implementer; the FIRST tester run captures the initial baseline if missing, then asserts subsequent cycles match).

## Functional (must all pass)

- [ ] **AC-F-01** — `swift build` succeeds on macOS 14+ with no warnings classified as errors.
- [ ] **AC-F-02** — `swift run AgentJobsMac` launches the app process; the process is alive 3 seconds after launch (no immediate crash). Verify via `ps -p $PID`.
- [ ] **AC-F-03** — Within 2 seconds of launch, a menu-bar icon labeled by `MenuBarLabel` is present in the system menu bar. Verify by enumerating `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` and finding a window owned by `AgentJobsMac` in the menu-bar layer (`kCGStatusWindowLevel`).
- [ ] **AC-F-04** — `defaultRegistry()` is wired with all 5 providers (`AgentJobsJsonProvider`, `LsofProcessProvider`, `ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`, `LaunchdUserProvider`). Verify by a unit test asserting `ServiceRegistry.defaultRegistry().providerCount == 5` (or equivalent introspection).
- [ ] **AC-F-05** — Dashboard window's source summary header renders exactly 5 source chips, in this order: `registered`, `claude-scheduled`, `claude-session`, `launchd`, `live-process`. Each chip shows an SF Symbol icon + display label + integer count (count ≥ 0).
- [ ] **AC-F-06** — Clicking a source chip filters the table to services whose `ServiceSource` belongs to that bucket. Clicking the active chip again clears the filter. Verifiable in a SwiftUI ViewInspector / unit-test of the filter binding.
- [ ] **AC-F-07** — Selecting any row in the Dashboard table populates the right-pane `ServiceInspector` with at minimum: name, source displayName, status badge, schedule humanized, project (or "—"), createdAt (or "—"). The inspector is rendered in the same window's right pane (NavigationSplitView `detail`), NOT a new window. Verify by enumerating `NSApp.windows` after selection — count must equal pre-selection count.
- [ ] **AC-F-08** — When `Service.pid` is set, the inspector's Overview tab additionally renders the PID and Owner tiles. When `pid` is nil, those tiles are absent (not "0").
- [ ] **AC-F-09** — Menu-bar popover header chip "running" count equals the number of services with `status == .running` in the registry's services list at the moment of capture. (Test by injecting a stub registry with known fixtures.)
- [ ] **AC-F-10** — Menu-bar popover footer "Open Dashboard" button opens the Dashboard window (`Window` scene with id `dashboard`). After click, `NSApp.windows` contains a window with `identifier == "dashboard"` that is `isVisible == true`.
- [ ] **AC-F-11** — Empty-state: when `registry.services.isEmpty` and `registry.phase == .loaded`, the Dashboard table region shows the existing `ContentUnavailableView` with the "No services discovered yet" copy. App does not crash; layout does not collapse.
- [ ] **AC-F-12** — Error-state: when a stub registry returns `allFailed = true`, the menu-bar popover shows the `ErrorBanner` with the message "All providers failed to respond" and a Retry button.

## Visual (screenshot baselines — odiff threshold 2%)

> Baseline files live at `.workflow/m02/screenshots/baseline/<name>.png`. Each AC names the exact XCUITest / capture scenario. Implementation may use either XCUITest UI launching or an in-process deterministic preview render (architect's choice — both produce a PNG to compare).

- [ ] **AC-V-01** — `menubar-popover-light.png`: launch the app, force `colorScheme == .light`, inject the fixture registry (see Q-fixture below), open the menu-bar popover, capture the popover window region (360 × auto-height). Compare with baseline within 2% pixel diff.
- [ ] **AC-V-02** — `menubar-popover-dark.png`: same as AC-V-01 but `colorScheme == .dark`.
- [ ] **AC-V-03** — `dashboard-empty-light.png`: open Dashboard window with an empty registry (phase `.loaded`, `services == []`). Capture the full window at 1200 × 700. Verify the empty-state ContentUnavailableView is visible. Compare within 2%.
- [ ] **AC-V-04** — `dashboard-populated-light.png`: open Dashboard with the fixture registry (≥1 service per source bucket — 5 minimum), no row selected. Capture full window 1200 × 700. Verify the source summary strip shows all 5 chips with non-zero counts and the table renders ≥5 rows. Compare within 2%.
- [ ] **AC-V-05** — `dashboard-inspector-populated-light.png`: same as AC-V-04 but with the first row programmatically selected. Capture full window. Verify the right pane inspector header shows the selected service's name + status badge. Compare within 2%.
- [ ] **AC-V-06** — `menubar-icon-visible.png`: capture only the menu-bar strip via `CGWindowListCreateImage` filtered to status-bar windows. Verify the AgentJobs icon is present (template image rendering). Compare within 5% (menu bar varies more across systems).

### Fixture registry for visual ACs

A test-only `StubServiceRegistry` (architect to design) returns a deterministic `[Service]` of 5 items, one per source bucket: one `agentJobsJson`, one `claudeScheduledTask(durable: true)`, one `claudeLoop(sessionId:)`, one `launchdUser`, one `process(matched:)`. Field values are fixed (no `Date()` calls — use a frozen reference date) so the rendered pixels are deterministic across runs.

## Performance

- [ ] **AC-P-01** — Cold launch to first paint of menu-bar popover ≤ 1500 ms on Apple Silicon (M1 or later). Measured by `Date()` between `applicationDidFinishLaunching` and the menu-bar `MenuBarExtra` `body` first invocation.
- [ ] **AC-P-02** — First discovery cycle (`registry.refresh()` from cold) completes in ≤ 3000 ms on a developer machine (real `defaultRegistry`, real `~/.claude` and `~/Library/LaunchAgents` scan). Logged via `os_signpost` in dev builds.
- [ ] **AC-P-03** — Auto-refresh runs every 30 s (± 2 s) for ≥ 3 cycles without leaking tasks. Verify by counting `Task` instances or via instrumentation.
- [ ] **AC-P-04** — Dashboard table scrolls smoothly with 100 fixture services: a programmatic scroll from top to bottom via `ScrollViewProxy.scrollTo(_:anchor:)` completes within 250 ms and no `NSException` fires.

## Quality gates

- [ ] **AC-Q-01** — `swift test` exits 0; all existing 145+ tests pass.
- [ ] **AC-Q-02** — Net-new code in M02 has line coverage ≥ 80% (measured per file in the diff).
- [ ] **AC-Q-03** — No new Swift warnings introduced (compare `swift build 2>&1 | grep warning` count before vs. after).
- [ ] **AC-Q-04** — `Info.plist` / `Package.swift` correctly declare `LSUIElement = true` (or equivalent for SPM macOS app) so the app runs as a menu-bar accessory without a Dock icon. Verify by inspecting the running app's activation policy.

---

**Total ACs: 22** (Functional 12, Visual 6, Performance 4, Quality 4 — wait, 12+6+4+4=26; recount: F=12, V=6, P=4, Q=4 → **26**.)

Tester decision rule: any single AC failure → milestone returns to IMPLEMENTING (or ARCHITECTING if structural). Three consecutive TEST failures → STUCK per PROTOCOL §Escalation.
