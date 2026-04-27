# M05 Acceptance Criteria

> 24 ACs grouped Functional / Visual / Performance / Quality / ui-critic. Each must be verifiable by the Tester (or, for the ui-critic group, by the ui-critic agent) without ambiguity.

## Functional (must all pass)

- [ ] **AC-F-01: `AgentJobsVisualHarness` library target builds standalone.** `cd macapp/AgentJobsMac && swift build --target AgentJobsVisualHarness` exits 0 with no warnings escalated. The target produces a static library artifact discoverable via `swift package describe --type json | jq '.targets[] | select(.name=="AgentJobsVisualHarness")'`.
- [ ] **AC-F-02: `capture-all` CLI produces all 10 scenario PNG/JSON pairs.** `swift run capture-all --out /tmp/m05-shots/` writes 20 files (10 `.png` + 10 `.json` sidecars) matching the names listed in spec.md §"Deliverable 5". Process exits 0.
- [ ] **AC-F-03: `MenuBarInteraction.clickMenuExtra()` actually opens the popover.** Test asserts the popover's hosting window is reachable via AX after the click and dismissed cleanly after `dismissPopover()`. (Closes T-007.)
- [ ] **AC-F-04: `WindowInteraction.resizeMainWindow(to:)` applies the new size.** Resizing to a target frame is observable on the next runloop tick within ±1pt.
- [ ] **AC-F-05: `CritiqueReport` JSON sidecar contains all required keys.** Each `.json` has `scenarioName`, `capturedAt` (ISO8601 valid), `appCommit` (40-char hex or `"unknown"` outside git), `osVersion`, `colorScheme` (`"light"|"dark"`), `datasetHash` (64-char hex).
- [ ] **AC-F-06: `ServiceFormatter.friendlyTitle` matches the pinned mapping table.** A table-driven test covers ≥12 input/output pairs (launchd vendor-bundle, launchd unmapped, process basename, cron, claude-scheduled, agent-jobs JSON pass-through, edge cases: empty name, only-numeric name, very-long name truncated to ≤60 chars).
- [ ] **AC-F-07: `ServiceFormatter.summary` produces non-empty 1-line strings.** For every fixture service in `Service.fixtures()`, `summary` returns a string of length ≤ 80 with no `\n`.
- [ ] **AC-F-08: `Service.id` is preserved across formatter wiring.** Snapshot `id`s for the entire fixture registry before and after the formatter is applied; assert exact equality.
- [ ] **AC-F-09: `LiveResourceSampler.sample(pid:)` returns populated metrics for the test process.** Test calls `sampler.sample(pid: getpid())` and asserts non-nil with `cpuPercent >= 0` and `rssBytes > 0`.
- [ ] **AC-F-10: `LiveResourceSampler` swallows `ESRCH` for dead pids.** Sampling pid `99999` (unlikely to exist) returns `nil`, throws nothing.
- [ ] **AC-F-11: Refresh tick merges sampled metrics into Service before publish.** Integration test wires a fake registry with one PID-bearing service, runs one refresh tick, asserts the published service has non-nil `metrics`.
- [ ] **AC-F-12: T-004 fix — `ClaudeSessionCronProvider` produces non-zero services for the committed JSONL fixture.** New test reads `Tests/.../Fixtures/claude-projects/` (synthetic project dir with 1 JSONL containing 1 paired CronCreate tool_use + tool_result), asserts ≥1 returned `Service` with `source.bucket == .claudeSession`.
- [ ] **AC-F-13: T-004 fix — `ServiceSource.bucket` mapping is internally consistent.** Test enumerates every `ServiceSource` case constructible (with placeholder associated values) and asserts the mapped `Bucket` is documented (no implicit placeholder fall-through). If a `.cron` bucket is added, all 6 chips appear in `Bucket.allCases` and are rendered by `SourceBucketStrip`.
- [ ] **AC-F-14: Provider `lastError` surfaces in the chip tooltip.** When `ClaudeScheduledTasksProvider` is constructed against a path that returns EACCES (test injects an error loader), the resulting `SourceBucketChip` for `claudeScheduled` carries an accessibility hint / tooltip string referencing the failure mode. (When the file is simply missing, no tooltip is required for M05.)

## Visual (screenshot baselines + critique set)

> Two distinct screenshot pipelines: **`screenshots/baseline/`** is pixel-diff regression (1% threshold) carried over from M02; **`screenshots/critique/`** is the new harness output that ui-critic will read in M06+ (M05 only proves it's produced).

- [ ] **AC-V-01: `screenshots/baseline/popover-light.png` and `popover-dark.png` regenerated with the new `ServiceFormatter` titles** match committed baselines within 1% pixel diff (per the existing `scripts/visual-diff.sh`). Title text in the rendered PNG must be a friendly title (`"iMessage"` not `"application.com.apple.MobileSMS.115..."`).
- [ ] **AC-V-02: `screenshots/baseline/dashboard-row.png` light + dark** show CPU% and Memory columns populated with numeric values (not `—`) for the live-process fixture rows. Within 1% pixel diff vs committed baselines.
- [ ] **AC-V-03: `screenshots/critique/` directory exists after `capture-all` run** and contains all 10 scenarios from spec.md §"Deliverable 5" with file sizes > 0 bytes and PNG magic bytes valid.
- [ ] **AC-V-04: Inspector header uses `friendlyTitle` + `summary`.** Snapshot test renders `ServiceInspector` for one fixture; first text node = friendly title; second = summary string.

## Performance (gated by `AGENTJOBS_PERF=1` per E001)

- [ ] **AC-P-01: `ServiceFormatter.friendlyTitle` runs in < 50µs per call (median over 1000 invocations)** on the dev box. Gated; assertion preserves the spec budget.
- [ ] **AC-P-02: `LiveResourceSampler.sampleAll` for 100 PIDs completes in < 100ms.** Gated.
- [ ] **AC-P-03: `capture-all` CLI completes all 10 scenarios in < 30s.** Wall clock; gated.
- [ ] **AC-P-04: Refresh tick latency (discover → sample → publish) does NOT regress beyond 20% vs M04 baseline** for the populated stub registry. Gated.

## Quality gates

- [ ] **AC-Q-01: `swift build` green** for all 3 targets (Core, Mac, VisualHarness) and the `capture-all` executable.
- [ ] **AC-Q-02: `swift test` green; coverage on changed lines ≥ 80%.**
- [ ] **AC-Q-03: No new `print()` calls; all logging uses `os.Logger`** (per existing convention).
- [ ] **AC-Q-04: No new force-unwraps in `Sources/`** (`grep -rn '!' Sources/AgentJobsCore/Formatting/ Sources/AgentJobsCore/Discovery/Providers/LiveResourceSampler.swift Sources/AgentJobsVisualHarness/` returns only documented exceptions).
- [ ] **AC-Q-05: No `~/.agent-jobs/` writes from any test** — `find ~/.agent-jobs -newer .build -type f 2>/dev/null` empty after full test run.

## ui-critic gate (NEW — reserves the slot for M06 onward)

> M05 does NOT enforce a ui-critic verdict (the agent activates as a hard gate in M06). These two ACs verify the **plumbing the gate depends on** is in place.

- [ ] **AC-UC-01: `ui-critic` agent can locate and invoke the `capture-all` CLI from the documented path.** Smoke test: a shell harness in `scripts/ui-critic-smoke.sh` runs the same command the agent would (`cd macapp/AgentJobsMac && swift run capture-all --out .workflow/m05/screenshots/critique/`) and exits 0 with all 10 PNGs present. (Closes the T-007 enabler for the agent.)
- [ ] **AC-UC-02: Each `screenshots/critique/*.json` sidecar carries enough metadata for the rubric scoring.** Per-file assertion: every `.json` parses, `scenarioName` matches the file's `01-…` prefix, `colorScheme` is one of the supported set. ui-critic's per-axis rubric depends on `scenarioName` to know which axis weighting to apply; a missing sidecar key would silently break scoring.
