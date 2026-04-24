# Retrospective M03 — Actions (stop / hide / refresh)

**Date:** 2026-04-24
**Cycles:** IMPL=1 REVIEW=1 TEST=1 (first-try ACCEPTED)
**Diff size:** 20 files, +1693 / -16 LOC since `8e6e2e8`
**Wall time:** ~1h45m (milestone-start 15:46 → ship 17:33, all on 2026-04-24)
**Test count delta:** 180 → 226 (+46), well above the +20 floor
**Score:** 93/100 (reviewer); 25 PASS / 1 SKIP-as-designed / 0 FAIL (tester)

## Headline

M03 was the first milestone to ship on the very first IMPL/REVIEW/TEST attempt
since workflow bootstrap. Both M02 retro proposals (E001 strict-perf-gate, E002
test-framework-check) appear to have **demonstrably worked silently** in this
cycle:

- **E002 → architect.** `tasks.md` opens with a banner line: *"Tests use
  swift-testing (`@Suite`, `@Test`, `#expect`) per E002. NOT XCTest."* Architect
  evidently skimmed `Tests/` (per E002) and propagated the convention. Zero
  framework-translation workarounds in `impl-cycle-001.md` (M02 had one).
- **E001 → implementer.** All three perf ACs (P-01, P-02, P-03) shipped with
  strict spec budgets (50 ms / 3 s / 10 ms) gated behind `AGENTJOBS_PERF=1`.
  Implementer did NOT relax any budget; tester ran them gated and saw 38–40×
  headroom. Zero perf-test bounce this cycle (M02 had a full extra cycle for
  exactly this).

Both evolutions are graduating PROPOSED → ACCEPTED in `EVOLUTION.md` under
this retro.

## What worked

1. **PM spec was unusually load-bearing and specific.** The "Safety rules"
   section enumerated six refusal predicates with reason strings *verbatim*.
   Architect lifted them into a single `static refusalReason(...)` helper;
   implementer copied them into tests; tester used the same names in the AC
   matrix. End-to-end the predicate list never mutated. **This is a pattern
   to keep:** when safety/correctness behaviour is enumerable, list it
   exhaustively in the spec and let downstream agents quote it.

2. **Architect resolved all four open questions inline.** `architecture.md`
   opens with "Open questions — resolved" answering Q1–Q4 from spec with
   concrete file paths and ≤ 15-LOC implementation sketches. No back-and-forth
   needed. Implementer didn't have to invent an answer for any of them.

3. **Defense-in-depth was specified, not improvised.** Spec named four safety
   layers (UI gate → executor recheck → init fatalError under
   `AGENTJOBS_TEST=1` → static-grep allow-list test). All four shipped. Reviewer
   called this out explicitly as a Win. The pattern of *naming* the
   defense-in-depth layers in spec instead of leaving "make it safe" to the
   implementer is what made this happen.

4. **Atomic 10-task decomposition with explicit AC→Task matrix.** Architect's
   tasks.md ends with a coverage table mapping every one of 26 ACs to ≥ 1
   task. Implementer worked top-to-bottom; one commit per task. No re-ordering,
   no "I didn't realize T07 also covered AC-F-13" surprises.

5. **Test-injection seams were spec'd up-front.** `StopExecutor` protocol +
   `ShellRunner`/`KillRunner` typealiases were in architecture.md before
   implementation started. Implementer didn't have to retrofit testability.
   Result: zero OS-side-effecting unit tests AND no test-double design churn
   in impl-cycle-001's "workarounds" section.

## What slowed us down

Honestly: very little.

- **One M02 baseline had to be re-recorded** (`dashboard-inspector-populated-light.png`,
  13.7% diff). This was anticipated — architecture.md flagged the inspector
  was getting an action bar — but the workflow has no formal "intentional
  baseline-rotation" gesture, so it landed in `impl-notes.md` as a workaround.
  Borderline; not yet a recurring pattern.
- **One env-var leak** (`AGENTJOBS_INTEGRATION` set process-wide by a test
  suite, never unset). Reviewer flagged as L3, tester noted as non-blocking.
  No actual failure today, but suite ordering could expose it later.

Neither is severe enough on first occurrence to warrant a prompt evolution
(per retrospective.md anti-pattern: "≥ 2 occurrences or clear root cause").

## Easier scope, or genuinely converging?

Honest assessment: **mostly converging, with a modest scope tailwind.**

Arguments for "easier scope":
- M03 added a layer (Actions) on top of frozen Discovery + Dashboard, rather
  than altering existing surface. Pure additive milestones are intrinsically
  lower-risk than refactors.
- No new third-party deps, no new platform APIs (just `Darwin.kill` + `Shell`).
- Visual ACs (5) re-used the M02 harness without modification.

Arguments for "genuinely converging":
- M01 took 2 cycles (review bounce on perf gate). M01.5 was first-try (15 ACs).
  M02 took 2 cycles (perf gate AGAIN; framework mismatch). **M03 first-try
  with 26 ACs and a critical safety pillar.**
- The two M02 retro proposals (E001, E002) exactly correspond to the M02
  bounce causes — and exactly those bounce causes are absent in M03, despite
  M03 having more ACs (26 vs 26 same), more LOC (~1700 vs ~1100), and a
  larger surface (3 user-facing actions + safety layer vs 1 dashboard).
- Spec quality went up: M03 spec named risks, predicates, and risk
  mitigations explicitly; M02 spec was sparser.

Net read: prompts are converging — **the pattern of having retro evolutions
target the previous milestone's exact failure modes is producing measurable
results within one cycle.** This is the workflow's intended feedback loop
working as designed.

## Per-agent notes

### pm
Spec was the strongest yet — explicit safety rules, explicit out-of-scope,
named risks with mitigations, four open questions for architect. No
ambiguity reported by downstream agents. **Keep doing this.**

### architect
Resolved all four PM open questions with file paths + LOC budgets + code
sketches. Adopted E002 explicitly (banner in tasks.md). Tasks ordered by
dependency, every AC mapped. **Keep doing this.** No identified weakness.

### implementer
Ten tasks, one commit each, ≤150 LOC per task as estimated. Adopted E001
strict-budget rule across three perf ACs without relaxing any. Defense-in-
depth implementation went beyond what spec required (e.g., the
`AGENTJOBS_TEST=1` short-circuit in `ServiceRegistryViewModel.init` was a
belt-and-braces extra). **Keep doing this.** Minor: one intentional baseline
re-record landed in workarounds; not yet pattern-worthy.

### reviewer
93/100 with two MEDIUM and four LOW items. Score breakdown was honest (gave
−1 on architecture conformance for `withStatus` in App layer, −1 on tests for
the M1 "doesn't actually wait 4s" gap, −1 on OSS quality for trusting the
impl claim that `Package.swift` had no new deps without re-checking). Decision
rationale (PASS at 93) cites zero CRITICAL + safety-AC defense-in-depth.
**Keep doing this.** Minor: the −1 for "trusted impl claim, didn't verify
Package.swift myself" is a real anti-pattern signal but only first occurrence.

### tester
Ran the suite, ran the perf-gated suite, ran the runtime-launch sanity
check, did an independent static-grep of `Tests/` for `RealStopExecutor`,
`kill(`, `launchctl unload`, `signal(SIGTERM` (more thorough than the
in-suite static-grep test). Surfaced no new issues. Correctly classified the
single SKIP as design-intent rather than a hole. **Keep doing this.**

### retrospective
This file. No self-modification (per retro.md rule).

## Patterns to extract

- **Spec-as-source-of-truth for enumerable safety:** when behaviour is a
  finite list (refusal predicates, sources we support, error categories),
  enumerate it in spec and let architect/implementer/tester quote it. M03's
  six refusal predicates traveled unmutated through five artifacts.
- **Defense-in-depth named in spec:** spec listed four safety layers; all
  four shipped. This is the inverse of "make it safe and we'll review for
  rigor" — instead, "here are the four mechanisms; verify each."
- **AC→Task coverage table at the bottom of tasks.md:** trivial to author,
  high-value at audit time.

## Anti-patterns observed

- Reviewer trusted impl's claim about `Package.swift` instead of re-checking
  with one command (acknowledged in their own −1). Single occurrence; flag
  for next retro if it recurs.
- Process-wide env mutation in a test suite (`AGENTJOBS_INTEGRATION=1` never
  unset). Cosmetic today; would break suite-ordering invariants if a future
  test relied on the unset state. Single occurrence.

## Evolutions proposed this retro

**Zero.**

By the retrospective.md rules ("≥ 2 occurrences or clear root cause", "do
NOT manufacture changes", "max 3 per retro"), nothing in this cycle clears
the bar. The two known anti-patterns are first-occurrence and small. The
two existing PROPOSED evolutions (E001, E002) graduated to ACCEPTED based
on this cycle's evidence; that itself counts as the retro's deliverable.

If M04 surfaces a recurrence of either anti-pattern (reviewer-trusts-impl
or env-leak), revisit then with two data points.

## Next milestone signal

M04 is *Auto-refresh + fs.watch* per CURRENT.md. Things to watch:
- First milestone that *modifies* the Discovery layer (no longer frozen for
  M04 if fs.watch wires into provider re-trigger paths). Refactor risk.
- First milestone with a real-time / event-driven correctness AC; perf
  budgets (E001) may need to evolve from "median over N runs" to
  "p99 latency under load."
- Visual ACs may need a "spinner mid-animation" baseline strategy beyond
  the static-frame approach M03 used for the refresh spinner.
