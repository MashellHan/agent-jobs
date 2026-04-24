# M03 Acceptance Criteria

> Visual baselines live under `.workflow/m03/screenshots/baseline/`.
> Tests MUST inject `FakeStopExecutor`; tests that even reach `RealStopExecutor` MUST run with `AGENTJOBS_TEST=1` set, which causes `RealStopExecutor` to `fatalError` if invoked — the suite must never spawn `kill(2)` or `launchctl`.

## Functional (must all pass)

- [ ] **AC-F-01** — `Service` gains a pure `canStop: Bool` derived property whose value is `false` when any of the six refusal predicates in spec §"Safety rules" trips, `true` otherwise. Verified by unit tests covering each predicate (≥ 6 cases).
- [ ] **AC-F-02** — `StopExecutor` is a protocol declared in `AgentJobsCore` with one async-throwing method `func stop(service: Service) async throws`. Both `RealStopExecutor` (production) and `FakeStopExecutor` (tests) conform.
- [ ] **AC-F-03** — `RealStopExecutor.stop(service:)` for a `Service` with `source == .process` and a valid PID invokes `kill(pid, SIGTERM)` exactly once and returns. (Tested with a child `sleep 60` we ourselves spawned in a single integration test gated by `AGENTJOBS_INTEGRATION=1`; default CI run does NOT execute this test — assertion-only mocks elsewhere.)
- [ ] **AC-F-04** — `RealStopExecutor.stop(service:)` for a `Service` with `source == .launchdUser` and a resolvable plist URL invokes `Shell` with `["launchctl", "unload", <plist>]`. Verified via a `ShellRecorder` injected into a `RealStopExecutor` constructed under test (no real `launchctl` call).
- [ ] **AC-F-05** — Clicking the row-hover Stop button presents a SwiftUI `.confirmationDialog` whose body string contains the service name AND either the PID (live process) or the plist path (launchd). Cancel dismisses without calling the executor; Stop calls the executor exactly once. Verified by view-model unit test driving the binding.
- [ ] **AC-F-06** — On stop success, the row's status flips optimistically to `.idle` until the next `discoverAll()` reconciles. Verified by unit test on the view model with a `FakeStopExecutor` returning success.
- [ ] **AC-F-07** — On stop failure, an inline error string keyed by service id is set on the view model and auto-clears after 4 ± 0.5 s. Verified by unit test with a `FakeStopExecutor` returning a scripted error.
- [ ] **AC-F-08** — Clicking Hide on a row appends its id to `~/.agent-jobs/hidden.json` (atomic write — temp file then rename). The file's JSON shape is `{ "version": 1, "hiddenIds": [...] }`. Verified by `HiddenStoreTests` writing through a temp `HOME` directory.
- [ ] **AC-F-09** — The dashboard's `filteredServices` excludes hidden ids by default; flipping the dashboard toolbar's "Show hidden" toggle includes them again with a 50% opacity treatment and an "Unhide" action replacing "Hide". Verified by view-model unit test + visual AC-V-02.
- [ ] **AC-F-10** — Clicking Unhide removes the id from the persisted set and rewrites the file atomically. Verified by `HiddenStoreTests`.
- [ ] **AC-F-11** — `HiddenStore` recovers from a corrupt or unreadable `hidden.json` by treating the set as empty and overwriting the file on next mutate; does NOT throw out of `init` or `load()`. Verified by writing garbage bytes to the temp file then constructing the store.
- [ ] **AC-F-12** — Clicking the toolbar Refresh button invokes `ServiceRegistryViewModel.refreshNow()`, which calls `registry.discoverAll()` exactly once and toggles `isRefreshing` `true → false` around the await. Concurrent clicks while `isRefreshing == true` are no-ops. Verified by unit test using a stub registry that records calls.
- [ ] **AC-F-13** — When `service.canStop == false`, the row-hover Stop button and inspector Stop button render in disabled state and the confirmation dialog never appears on click. Verified by view-model + unit test asserting executor.callCount == 0.

## Visual (screenshot baselines)

All visual ACs use the in-process `NSHostingView` harness from M02 + `scripts/visual-diff.sh` at the default 2% threshold, with the deterministic `StubServiceRegistry` from M02 extended with hidden-state and stop-error fixtures.

- [ ] **AC-V-01** — Dashboard row-hover state showing the action icon stack (Stop + Hide). Hover simulated by setting `isHovered = true` on the row view. Compared to `.workflow/m03/screenshots/baseline/row-hover-actions-light.png`.
- [ ] **AC-V-02** — Dashboard with "Show hidden" toggle ON, two hidden rows visible at 50% opacity with Unhide buttons. Compared to `.workflow/m03/screenshots/baseline/show-hidden-on-light.png`. Companion baseline `show-hidden-off-light.png` for the OFF state must also exist (rendered from the same fixture set).
- [ ] **AC-V-03** — Confirmation dialog open over the dashboard, body showing "{service name}" + PID. The dialog is the SwiftUI `.confirmationDialog` content view captured via the harness (NOT a system NSAlert). Compared to `.workflow/m03/screenshots/baseline/stop-confirm-dialog-light.png`.
- [ ] **AC-V-04** — Inspector action bar showing both enabled (live-process fixture) and disabled (claude-scheduled fixture) Stop button states side-by-side via two render passes producing `.workflow/m03/screenshots/baseline/inspector-stop-enabled-light.png` and `.workflow/m03/screenshots/baseline/inspector-stop-disabled-light.png`. Disabled state must be visibly distinct (lower opacity / system disabled style).
- [ ] **AC-V-05** — Toolbar Refresh button in the in-flight state: button disabled + spinner visible. Compared to `.workflow/m03/screenshots/baseline/refresh-spinner-light.png`.

## Performance

- [ ] **AC-P-01** — `HiddenStore.add(_:)` (and `.remove(_:)`) round-trip (mutate set + atomic write to disk under temp HOME) completes in < 50 ms median over 50 runs on the dev box. Test prints the median; gate at 50 ms strict. Gated behind `AGENTJOBS_PERF=1` per implementer evolution rule E001 — strict-budget version is the only one in the test.
- [ ] **AC-P-02** — Manual `refreshNow()` against the production `defaultRegistry()` returns within the same budget already established in M02 (3 s spec / dev-box gate per E001). No new perf regression introduced by M03 wiring.
- [ ] **AC-P-03** — `Dashboard.filteredServices` over 1000 services with 200 hidden ids and Show-hidden OFF computes in < 10 ms median over 100 runs. Verified with synthetic `Service.fixtures`-style array.

## Quality gates

- [ ] **AC-Q-01** — `swift build` is green on the package root.
- [ ] **AC-Q-02** — `swift test` is green; coverage on changed lines (the new `Actions/`, `Persistence/`, and view-model action paths) ≥ 80 %.
- [ ] **AC-Q-03** — Test count net-positive: at least +20 tests over the M02 final count (178), spanning unit (refusal predicates, hidden store, view-model), visual (5 ACs above), and one integration test gated off by default.
- [ ] **AC-Q-04** — No new third-party Swift package dependency added to `Package.swift`.
- [ ] **AC-Q-05** — No code path can reach a real `kill(2)` or `Shell launchctl unload` invocation under `swift test` without `AGENTJOBS_INTEGRATION=1` set; the default test run is provably side-effect-free against the OS. Verified by the `RealStopExecutor` fatalError-on-`AGENTJOBS_TEST=1` guard plus a static grep test asserting no test file imports `RealStopExecutor` outside the gated integration test.

---

**Total: 26 ACs (13 Functional / 5 Visual / 3 Performance / 5 Quality).**
**Safety-specific ACs (refuse self, refuse PID 1, refuse on missing PID, defense-in-depth at executor): AC-F-01 (≥ 6 predicate cases including PID 0/1/self), AC-F-13 (UI pre-disable), AC-Q-05 (test-suite cannot reach real exec). Three explicit safety-pillar ACs, exceeding the ≥ 2 requirement.**
