# Review M01 cycle 002

**Date:** 2026-04-23T13:50:00Z
**Reviewer:** reviewer agent
**Scope:** focused re-review of diff `4f26b5d..HEAD` (5 IMPL commits) plus
verification that cycle-1 MEDIUMs M1/M2/M3 and tester cycle-1 FAIL on AC-Q-03
are resolved.
**Build:** PASS (`swift build` clean, 1.66 s)
**Tests:** PASS (`swift test` — 111 / 111, was 106, +5 net)

## Score: 97/100 (cycle 1 baseline 92/100; +5)

| Category | Score | Δ vs c1 | Notes |
|---|---|---|---|
| Acceptance coverage | 25/25 | 0 | All ACs still covered; AC-Q-03 now satisfied with real evidence (98.63% line coverage). |
| Architecture conformance | 20/20 | +1 | No new drift. R1-M2 framework anchoring keeps `LiveProcessNaming` faithful to the 5-step rule. |
| Correctness | 20/20 | +3 | M1 race window closed (structured `await semaphore.signal()`); M2 substring smell eliminated. |
| Tests | 14/15 | 0 | +5 new cases (3 real-FS coverage, 1 framework anchor pin, 1 fixture-backed smoke). One half-point reserved — see N1 below. |
| Modern Swift | 10/10 | +1 | Half-point restored: no more unstructured detached `Task` for permit release. |
| Documentation | 5/5 | 0 | Code comment on the framework loop documents the new behavior + rationale; CHANGELOG entries follow Keep-a-Changelog. |
| OSS quality | 3/5 | 0 | CHANGELOG now updated (M3 fixed). Half-point reserved — `## [Unreleased]` ends up with two `### Added` blocks because of the pre-existing cycle-14 entry below; harmless but stylistically odd. Not a blocker. |

## Verification of cycle-1 issues

| ID | Status | Evidence |
|---|---|---|
| **R1-M1** semaphore release race | **FIXED** | `LsofProcessProvider.swift:90` — `defer { Task { await semaphore.signal() } }` replaced with direct `await semaphore.signal()` after `runPs`. `runPs` is non-throwing so no try/catch wrapper needed. AC-P-03 high-water-mark test ("≤ 8") still passes — now measures a stricter contract. |
| **R1-M2** framework substring | **FIXED** | `LiveProcessNaming.swift:67-77` — tokenizes on whitespace, takes basename of each token, then `tokenBasenames.contains(fw)`. Existing `vite` test (`/usr/bin/vite`) still passes (basename is `vite`). New `frameworkTokenAnchored` test pins the negative case `node /opt/openssl-nextstep` → not `next`. |
| **R1-M3** CHANGELOG | **FIXED** | `macapp/AgentJobsMac/CHANGELOG.md` gains `## [Unreleased]` block with `### Added` (3 providers + AsyncSemaphore + Enrichment.mtime + ~50 tests), `### Changed` (defaultRegistry 2→4, LaunchdUserProvider createdAt provenance), `### Fixed` (the two cycle-2 fixes). |
| **T-test-01** AC-Q-03 coverage | **FIXED** | 3 new real-FS tests in `ClaudeScheduledTasksProviderTests.swift` (`realDiskValidJsonGoesThroughReadWithTimeout`, `realDiskEmptyFileGoesThroughReadWithTimeout`, `realDiskUnreadablePathHitsIoCatchBranch`). Implementer reports llvm-cov 69.18% → 98.63%. Tester to re-verify. |
| **T-test-02** AC-Q-09 fixture smoke | **FIXED** | New `ClaudeScheduledTasksProviderSmokeTests` suite stages a fixture-backed `$HOME/.claude/scheduled_tasks.json`, runs `ServiceRegistry.discoverAllDetailed()`, asserts `services.count == 2`, `succeededCount == 1`, `allFailed == false`. |
| **R1-L1** dead `_ = p` | **FIXED** | `hungLoaderTimesOut` collapsed to a single provider construction with the immediate-throw loader. No more discarded `p`. |
| **R1-L2** AsyncSemaphore doc | skipped (per cycle directive) — acceptable. |
| **R1-L3** parser breadcrumb | skipped (per cycle directive) — acceptable. |

## New issues found in cycle 2 diff

### CRITICAL / HIGH / MEDIUM
*(none)*

### NITS (P3, non-blocking)

- **N1** [`CHANGELOG.md`] — the `## [Unreleased]` section now contains
  **two** `### Added` blocks (the new M01 block, and immediately below it
  the pre-existing cycle-14 popover-material block). Keep-a-Changelog
  convention is one `### Added` per release. Trivial merge-style cleanup
  for `/ship`; not blocking.

- **N2** [`ClaudeScheduledTasksProviderTests.swift`
  `realDiskUnreadablePathHitsIoCatchBranch`] — relies on macOS
  `Data(contentsOf:)` throwing when given a directory URL. Behavior is
  documented but worth a comment that this is an OS contract; the test
  comment already explains the path through the provider, just doesn't
  call out the OS dependency. Not blocking.

## Wins (cycle 2 deltas)

- All three reviewer MEDIUMs landed as separate atomic commits, each
  with a tightly scoped diff and the build/test still green between
  every commit. Exemplary cycle-2 discipline.
- AC-Q-03 fix isn't a coverage trick — the new tests genuinely drive
  the production `readWithTimeout(url:seconds:)` path with real disk
  I/O, including the non-timeout I/O catch branch (directory-as-path).
  Coverage jump 69% → 98.63% reflects real behavior, not a sham.
- AC-Q-09 fixture smoke makes the previously hand-only AC reproducible
  in any CI that can write to `FileManager.temporaryDirectory`.
- R1-M1 fix tightens the AC-P-03 contract — the high-water-mark
  assertion is now meaningful instead of accidentally passing.
- R1-M2 fix anchors framework matching with a clear inline comment
  explaining the previous bug, the new behavior, and a negative test
  pinning it.

## Decision

**PASS** — transition to TESTING (cycle 002).

Rationale: zero CRITICAL, zero HIGH, zero MEDIUM. All three cycle-1
MEDIUMs verified fixed. AC-Q-03 + AC-Q-09 gaps closed with real-FS
tests. Build + tests green (111/111). Score 97/100 ≥ 75 threshold.
The two NITs are stylistic and can be batched into `/ship` cleanup if
desired.

Tester to re-run cycle-1 acceptance gates with the new test count and
re-verify AC-Q-03 with `--enable-code-coverage`.
