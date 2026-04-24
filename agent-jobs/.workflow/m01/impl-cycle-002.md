# Implementation M01 cycle 002

**Date:** 2026-04-23T13:35:00Z
**Implementer:** implementer agent
**Trigger:** tester cycle-001 FAIL on AC-Q-03 (ClaudeScheduledTasksProvider line coverage 69.18% < 80%)
**Build:** PASS (`swift build` clean — 0 errors, 0 warnings)
**Tests:** PASS (`swift test` — 111 / 111, was 106 in cycle 1, +5 net)

## Summary

Cycle 2 closed the AC-Q-03 coverage gap (the only FAIL from tester cycle-001),
made AC-Q-09 testable in any environment via a fixture-backed smoke, and
addressed all three reviewer cycle-001 MEDIUMs as separate atomic commits.

## Commits in this cycle (5)

| SHA | Subject |
|---|---|
| 4a3ae53 | chore(M01): implementer acquired IMPLEMENTING lock cycle 2 |
| 736f756 | fix(M01): T-test-01 — real-FS coverage tests for ClaudeScheduledTasksProvider (AC-Q-03 69.18% → 98.63%); T-test-02 — fixture smoke for AC-Q-09 |
| 32a96a8 | fix(M01): R1-M1 — release ps semaphore via structured await, drop unstructured Task |
| 240f22a | fix(M01): R1-M2 — anchor framework name match on token basenames |
| ecc5e4e | fix(M01): R1-M3 — record M01 entries in CHANGELOG under Unreleased |

`swift build` + `swift test` were green between every commit. No `git push`.

## Fix details

### T-test-01 — Real-FS coverage for ClaudeScheduledTasksProvider (mandatory, AC-Q-03)

Added three new `@Test` cases to
`Tests/AgentJobsCoreTests/ClaudeScheduledTasksProviderTests.swift`:

1. **`realDiskValidJsonGoesThroughReadWithTimeout`** — copies the
   `scheduled_tasks.valid.json` fixture to `FileManager.temporaryDirectory`,
   constructs a `ClaudeScheduledTasksProvider(tasksPath:)` **without**
   a `loader:` override, and asserts `discover()` returns 2 services.
   This drives the production `Self.readWithTimeout(url:seconds:)` path
   (lines 110-125) end-to-end.
2. **`realDiskEmptyFileGoesThroughReadWithTimeout`** — same shape but
   with an empty file; verifies the `data.isEmpty → []` short-circuit
   reached via the real-disk path.
3. **`realDiskUnreadablePathHitsIoCatchBranch`** — points `tasksPath`
   at a directory. `FileManager.fileExists(atPath:)` returns true so
   the missing-file short-circuit is bypassed; `Data(contentsOf:)` then
   throws a non-timeout I/O error which the provider's catch-all
   (lines 54-58) must swallow as `[]`.

**Coverage delta** (`xcrun llvm-cov report`):
- `ClaudeScheduledTasksProvider.swift` lines: **69.18% → 98.63%** (PASS ≥ 80%)
- functions: **— → 94.64%**
- regions: **— → 97.98%**

### T-test-02 — Fixture-based smoke for AC-Q-09

Added `ClaudeScheduledTasksProviderSmokeTests` suite. It stages a fake
`$HOME/.claude/scheduled_tasks.json` under a temp HOME-like directory by
copying `scheduled_tasks.valid.json` into it, then constructs a
`ServiceRegistry` with that one provider pointed at the staged file and
runs `discoverAllDetailed()`. Asserts `services.count == 2`,
`succeededCount == 1`, `allFailed == false`. Exercises the same end-to-end
path the AC-Q-09 manual smoke would cover, just deterministically.

### R1-M1 — semaphore release pattern

`LsofProcessProvider.swift:90` previously released the semaphore through
`defer { Task { await semaphore.signal() } }` — an unstructured detached
`Task` that could let the surrounding `withTaskGroup` child return before
the permit was credited back, briefly inflating the high-water above the
configured concurrency cap. Replaced with the structured
`await semaphore.signal()` directly inside the closure (after the `runPs`
call, which never throws).

All 111 tests still pass — including the AC-P-03 high-water-mark
assertion ("ps concurrency cap: 200 PIDs, max in-flight ≤ 8"), which now
measures a stricter contract.

### R1-M2 — framework name anchored

`LiveProcessNaming.friendlyName` step 2 previously did
`cmdLower.contains(fw)` for the framework allow-list, so a path like
`node /opt/openssl-nextstep` would mislabel as `next`. Now we tokenize on
whitespace, take each token's basename, and only match `frameworks` against
that set. Existing `vite` test (which has `node /usr/bin/vite --port 5173`)
still passes because `/usr/bin/vite` basename is `vite`. New negative test
`frameworkTokenAnchored` pins the new behavior.

### R1-M3 — CHANGELOG entry for M01

Added an `## Unreleased` block at the top of
`macapp/AgentJobsMac/CHANGELOG.md` with M01 bullets for: the two new
providers (`LsofProcessProvider`, `ClaudeScheduledTasksProvider`), the
`AsyncSemaphore` helper, the additive `LaunchdPlistReader.Enrichment.mtime`
field, the registry expanding from 2 → 4 default providers, and the
`LaunchdUserProvider` `createdAt` provenance fix. Also recorded the two
cycle-2 fixes (semaphore release pattern, framework token match) under
"Fixed" so the changelog reflects the milestone as actually shipped.

### LOWs (skipped per cycle directive)

- L1 (dead `_ = p` in `hungLoaderTimesOut`) — addressed incidentally as
  part of the test-file rewrite for T-test-01 / T-test-02; the hung-loader
  test was simplified.
- L2 (AsyncSemaphore doc-comment) — skipped (doc polish only).
- L3 (parser debug log breadcrumb) — skipped (additive nice-to-have).

## Verification

- `swift build` — clean, 0 errors, 0 warnings.
- `swift test` — 111 / 111 tests pass (was 106; +5 net = 4 new tests +
  1 net from collapsing the cycle-1 hung-loader test that constructed
  two providers).
- `swift test --enable-code-coverage` + `xcrun llvm-cov report`:
  - `ClaudeScheduledTasksProvider.swift` line coverage = **98.63%** (was 69.18%)
  - `LiveProcessNaming.swift` line coverage = **97.98%**
  - `LsofProcessProvider.swift` line coverage = **77.87%** (unchanged from
    cycle 1; outside the AC-Q-03 file scope but reported for context)

## Open follow-ups

None. AC-Q-03 satisfied. All reviewer MEDIUMs addressed. Ready for review
cycle 002.

## Decision

**IMPLEMENTING → REVIEWING (cycle 002)**
