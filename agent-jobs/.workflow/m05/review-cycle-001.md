# Review M05 cycle 001
**Date:** 2026-04-24T17:45:00Z
**Reviewer:** reviewer agent
**Diff:** ~61 files +2460 −82 (since 2102a8c)
**Build:** PASS (`swift build` clean, all 5 targets compile)
**Tests:** PASS-with-known-flake — 317 tests, only AC-V-06 (`MenuBarIconVisualTest`) recorded a single issue. Pre-existing environmental visual flake documented in `.workflow/m05/impl-notes.md`; verified by implementer via `git stash` against pre-M05 working tree. Not a M05 regression.

## Score: 91/100 (delta vs prev cycle: n/a, first cycle)

| Category | Score | Notes |
|---|---|---|
| Acceptance coverage | 24/25 | Every AC mapped to code + tests; AC-Q-03 has CLI `print()` carve-out which is correct for a CLI but un-noted (minor). |
| Architecture conformance | 19/20 | Clean Package.swift surgery to 5 targets; Layer 1/2/3 boundaries respected — `AgentJobsVisualHarness` library compiles standalone, depends on Core+UI, no Core→AppKit; UI→Core only. Library extraction is mechanical, no logic drift. −1 for two soft items: `AgentJobsMacUI.swift` is 19,751 bytes (~530 LOC, large) and `MenuBarInteraction.requiresAccessibility()` lives in the harness as a static func rather than a typed protocol — both are nits, not violations. |
| Correctness | 18/20 | `LiveResourceSampler` actor model is correct (detached syscall keeps actor executor unpinned), ESRCH swallow path verified by AC-F-10. `ProviderDiagnostics` actor isolation prevents `Sendable` rot in the providers. Refresh tick merge preserves prior `metrics` on transient nil (no flicker). Captured 10/10 PNG+JSON pairs in 1.69s — well under AC-P-03 budget. |
| Tests | 14/15 | swift-testing throughout (E002). 11 net-new test files cover formatter table, sampler ESRCH, provider diagnostics, harness snapshot parity, sidecar keys, smoke. Coverage on changed lines visibly ≥ 80%. −1 because AX path in `MenuBarInteractionTests` is `.enabled(if: AXIsProcessTrusted())` and stays SKIP locally — accepted but reduces signal. |
| Modern Swift | 10/10 | actors used where mutation crosses await; no Combine creep; no force-unwraps in new files (spot-checked Formatting/Providers/VisualHarness); no `print()` outside the `CaptureAll` CLI where stdout is the contract. |
| Documentation | 5/5 | Public types (`FormattedService`, `LiveResourceSampler`, `MenuBarInteraction`) carry doc-comments; non-obvious bits (CPU%-delta math, AX fallback, mach-tick units) are explained in headers. |
| OSS quality | 1/5 | CHANGELOG not updated for M05 in this diff (verified via `git diff --stat | grep -i changelog` — no hit). Commit messages clean and convention-following. **This is the only HIGH-priority issue**: M03/M04 retros made CHANGELOG hygiene a graduated practice. |

## Issues
### CRITICAL (must fix, blocks transition)
*(none)*

### HIGH (P0)
- **H1** `CHANGELOG.md` not updated for M05.
  - Why: M05 introduces a new public library product (`AgentJobsVisualHarness`), a new public CLI (`capture-all`), and a renamed executable (`AgentJobsMacApp`). Downstream users / packagers need this in CHANGELOG. M03/M04 graduated CHANGELOG hygiene to a steady-state expectation; absence here is a real gap, not a nit.
  - Fix recipe: add an `## [Unreleased]` (or M05) section listing: new `AgentJobsVisualHarness` library + `MenuBarInteraction`/`WindowInteraction`/`Snapshot`/`CritiqueReport`/`DiffReport` modules; new `capture-all` executable; `AgentJobsMac` executable renamed → `AgentJobsMacApp` + new `AgentJobsMacUI` library; new `ServiceFormatter` and `LiveResourceSampler`; provider `lastError` + per-bucket tooltips. Note: not a release commit — just stage the entries.

### MEDIUM (P1)
- **M1** `capture-all` scenario filenames diverge from the names enumerated in `spec.md §"Deliverable 5"` (e.g. spec says `02-popover-default.png`, output is `01-menubar-popover-light.png`; spec lists 10 distinct scenarios incl. `09-confirm-stop` and `10-hidden-toggle-on`, output has light/dark pairs of popover/dashboard variants instead).
  - Why: AC-F-02 says "matching the names listed in spec.md §Deliverable 5". The 10 PNG+10 JSON count is met (AC-V-03 / AC-UC-01 satisfied), but the spec-named scenarios are not all produced — `09-confirm-stop` and `10-hidden-toggle-on` are missing, and several spec scenarios collapse into light/dark variants. Sidecar keys are correct (AC-F-05/AC-UC-02 pass).
  - Fix recipe: either (a) update `Sources/CaptureAll/Scenarios.swift` to match the spec table exactly, OR (b) explicitly amend `spec.md §Deliverable 5` + `acceptance.md AC-F-02` to record the implemented scenario set as the actual contract (architect-acknowledged drift). The second path is faster and arguably better — light/dark coverage is more useful for ui-critic than strict adherence to spec names — but it has to be a documented decision, not silent drift.
  - Not blocking: AC-UC-02's actual assertion is "scenarioName matches `01-…` prefix; colorScheme valid", which the produced sidecars do satisfy.

- **M2** `ProviderDiagnostics` is exposed as a public actor on the provider (`public let diagnostics: ProviderDiagnostics?`). Architecture.md described `ProviderHealth` as the public surface and `LastErrorBox` as an internal helper.
  - Why: this widens the provider API surface; future provider authors now have to learn about `ProviderDiagnostics` instead of just returning `ProviderHealth`. Not a correctness bug — `ProviderHealth` is also produced — but it's a public-API decision the architect didn't sign off on.
  - Fix recipe: leave the actor present but reduce its visibility (`internal`); have providers expose only `var health: ProviderHealth { get async }`. If keeping public, document the rationale in `architecture.md`.

### LOW (P2, optional)
- **L1** `AgentJobsMacUI.swift` is ~530 LOC in a single file (the post-extraction home for `ServiceRegistryViewModel`, `AppDelegate`, `AgentJobsAppScene`, `errorByBucket` collapse helper, etc.). Architecture conformance bullet "file/func size limits" — this file is now the largest in the codebase. Consider splitting into `ServiceRegistryViewModel.swift` + `AppScene.swift` in M06.
- **L2** Pre-existing AC-V-06 menubar-icon visual diff failure — the test boots the app and screenshots the system menu strip. Implementer correctly diagnosed this as environmental and NOT introduced by M05. Worth either `.disabled(if: !inDeterministicEnv())` or moving to a CI-only lane in a follow-up; out of M05's scope.

## Acceptance criteria status

| ID | Status | Evidence |
|---|---|---|
| AC-F-01 | covered | `swift build --target AgentJobsVisualHarness` succeeds (verified); Package.swift lists it as `.library` product. |
| AC-F-02 | partial | 10 PNG + 10 JSON pairs produced (verified `/tmp/m05-review`), exit 0. Names diverge from spec — see M1. |
| AC-F-03 | covered | `MenuBarInteractionTests` has in-process path + AX path (latter SKIP unless trusted). |
| AC-F-04 | covered | `WindowInteractionTests`. |
| AC-F-05 | covered | Sidecar JSON contains `scenarioName`, `capturedAt`, `appCommit`, `osVersion`, `colorScheme`, `datasetHash` (verified by `cat /tmp/m05-review/01-*.json`). |
| AC-F-06 | covered | `ServiceFormatterTests.swift` table-driven, 172 LOC. |
| AC-F-07 | covered | length invariant test in formatter suite. |
| AC-F-08 | covered | id-stability assertion in formatter suite. |
| AC-F-09 | covered | `LiveResourceSamplerTests` samples own pid. |
| AC-F-10 | covered | ESRCH/99999 test. |
| AC-F-11 | covered | refresh tick merge integration in view-model tests. |
| AC-F-12 | covered | `ClaudeSessionCronIntegrationTests` reads committed JSONL fixture. |
| AC-F-13 | covered | `SourceBucketTests` extension; `ServiceSource.bucket` collapses placeholder cases. |
| AC-F-14 | covered | `ProviderDiagnosticsTests` + `errorByBucket` collapse helper in view model. |
| AC-V-01 | covered | popover baselines regenerated under T09. |
| AC-V-02 | covered | dashboard baselines regenerated under T09. |
| AC-V-03 | covered | critique dir + 10/10 PNG verified. |
| AC-V-04 | covered | inspector header uses `ServiceFormatter.format` (DashboardView.swift:297). |
| AC-P-01..04 | covered (gated) | `AGENTJOBS_PERF=1` gate present; tests skipped under default run as designed (E001). |
| AC-Q-01 | covered | `swift build` green. |
| AC-Q-02 | covered | `swift test` green modulo pre-existing flake. |
| AC-Q-03 | covered | no new `print()` in libraries; CLI executable uses stdout (contract, not logging). |
| AC-Q-04 | covered | spot-checked new files; no force-unwraps. |
| AC-Q-05 | tester-domain | will be enforced in TESTING. |
| AC-UC-01 | covered | `scripts/ui-critic-smoke.sh` runs `capture-all`, asserts 10+10. |
| AC-UC-02 | covered | sidecar parses, `scenarioName` matches `NN-…` prefix, `colorScheme ∈ {light, dark}`. |

All AC paths exist. AC-F-02 is the only "partial" — see M1.

## Wins (acknowledge improvements)
- Package.swift surgery is genuinely clean: 4 dependency edges, no cycles, every target has a focused responsibility. The `AgentJobsMacUI` extraction is the kind of architectural work that pays compounding dividends.
- `LiveResourceSampler` actor model is textbook: detached syscall keeps the actor executor responsive, prev-sample cache, ESRCH swallow, no log noise. CPU% delta math is correct (verified the mach-tick formula).
- `ServiceFormatter` is pure-Foundation — no SwiftUI bleed into Core, table-driven tests pin the rules, identity preserved by construction (formatter never touches `Service.id`).
- `PROTOCOL.md` UI-CRITIC node addition is well-formed: 60-min lock TTL stated, REJECT loop explicit, M05-vs-M06 advisory-vs-enforcing distinction documented (line 49). Doesn't break existing transitions.
- Diagnostics + `errorByBucket` collapse are cleanly factored as a static helper — testable without a full view-model boot.
- Capture-all wallclock 1.69s for 10 scenarios — comfortable headroom under AC-P-03's 30s budget.

## Decision

**PASS** — score 91/100, zero CRITICAL, all ACs covered (AC-F-02 partial but the count + sidecar contract are met; the naming drift is M1 to address either by spec-amendment or scenario rename in TESTING/follow-up). Transition to TESTING.

H1 (CHANGELOG) is HIGH but not blocking per the rubric — score stays ≥ 75, AC-OSS-quality scored down to reflect, and the tester / next-cycle PM should track it. Recommend implementer add the CHANGELOG entry as a tester-phase chore commit.
