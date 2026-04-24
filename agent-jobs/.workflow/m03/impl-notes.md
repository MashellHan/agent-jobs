# M03 Implementation Notes (cycle 001)

## Re-recorded baseline: dashboard-inspector-populated-light

The M02 baseline `.workflow/m02/screenshots/baseline/dashboard-inspector-populated-light.png` was 13.7% pixel-diff from the current render after T07 added the inspector action bar (Stop / Hide buttons above the tab chip row). This is an INTENTIONAL visual change called out in M03 architecture.md (`ServiceInspector` portion: "add an action bar above TabChipRow").

The baseline was deleted and re-recorded so the test passes; the new baseline reflects the M03-shipping inspector layout.

## AGENTJOBS_INTEGRATION env var leaks across tests

`StopExecutorShellTests` calls `setenv("AGENTJOBS_INTEGRATION", "1", 1)` so the `RealStopExecutor` init guard does not fatal during shell-shape unit tests. Once T08 adds the bundle-wide `AGENTJOBS_TEST=1` setup, this env var's "leak" across other tests does not relax safety because:

1. Other tests that touch executors use `FakeStopExecutor`.
2. Production code never sets `AGENTJOBS_INTEGRATION`; shipped binaries land in the "neither flag set" branch and proceed normally.
3. The static-grep self-test (T08) ensures no test source file outside `StopExecutorShellTests.swift` references `RealStopExecutor`.

## Dashboard 3-arg filter overload preserved

Existing M02 `DashboardFilterTests` still call `filter(_:category:bucket:)`. T07 keeps this signature alive as a thin overload that calls the new 5-arg signature with `hiddenIds: []` and `showHidden: true`. No M02 tests had to change.
