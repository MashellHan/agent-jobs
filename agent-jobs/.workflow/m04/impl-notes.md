# M04 Implementation Notes (cycle 1)

Running impl notes for blockers, workarounds, and design clarifications.

## T01 — RefreshScheduler primitives

DONE.

### Workaround #1 — flaky pre-existing M01 perf test

`ClaudeSessionCronProviderTests.tenKLinesUnder500ms` (M01 AC-P-02, parses
10k jsonl lines) is occasionally fails the 500 ms budget under load
(observed 586–646 ms when run inside the full `swift test` suite, 177 ms
solo). Reproducible across multiple runs of the full suite. This test is
NOT gated by `AGENTJOBS_PERF=1` and is **pre-existing** (M01 code path
untouched by M04).

Per E001 a fix would be to gate it behind `AGENTJOBS_PERF=1`. That's an
M01 / M03-retro concern, not M04. Leaving it untouched and noting the
flake here so reviewer doesn't blame M04.

### Workaround #2 — actor-test continuation field shadow

Initial `CallCounter` actor named the continuation property `release` and
the helper method also `release()` → invalid redeclaration. Renamed
property to `pendingContinuation`.

### Workaround #3 — in-flight guard test polling

The in-flight guard test originally used fixed `Task.sleep` waits
between observations. Under full-suite load these were too short.
Replaced with bounded polling (200 × 10 ms) for both the "first sink
started" and "follow-up fired" checkpoints, plus a final dwell to
verify no spurious third fire. Stable now.

