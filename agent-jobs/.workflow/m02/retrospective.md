# Retrospective M02 — Functional UI baseline

**Date:** 2026-04-24T06:50:00Z
**Cycles:** IMPL=2 REVIEW=2 TEST=1
**Diff size:** ~+1,300 / -8 LOC across 16 files (per review-cycle-001) + 3-line fix in cycle-2
**Wall time:** ~2h 42m (12:46 → 15:28 local, including a long ~1h45m gap between IMPL handoff and REVIEW pickup)
**Test count delta:** 145 → 178 (+33)
**Final score:** 92/100 (review-cycle-002), 26/26 ACs PASS (1 conditional)

## What worked

- **Architect's clear decision matrix on screenshot strategy.** The architecture doc resolved Open Question #1 with explicit rationale (in-process `NSHostingView` over XCUITest) AND laid out the recording flow (first run records baseline + passes with `[BASELINE_RECORDED]`). Result: the entire visual harness (T07) shipped first try, six baselines committed in T08, all six visual ACs PASS in cycle-1 with no rework. This is the model for resolving open questions in future architecture docs.
- **Task sizing instinct.** 9 atomic tasks, each ≤150 LOC, all landed as 9 atomic commits. No task ballooned, no task split. Implementer notes show zero "had to escalate to architect" events. Continue current sizing heuristic.
- **Pre-emptive impl-notes.md.** Implementer documented every workaround (perf budget relax, scripts/ gitignore force-add, swift-testing vs XCTest mismatch) before handing off. Reviewer cycle-001 explicitly credits this with saving ~10 minutes of detective work. Keep this practice.
- **Reusable Bucket abstraction.** Adding `ServiceSource.Bucket` orthogonal to existing `Category` (rather than overloading the latter) preserved sidebar API while enabling the new chip strip. Architect made the right call confirming PM's recommendation.
- **Cycle-2 was minimal-touch.** Reviewer offered three fix options for C1; implementer picked option (b) (env-gate) AND went better — restored the strict 3s spec budget rather than relaxing further. 3-line guard, 1 file, done in 13 minutes.
- **Stub registry + frozen-date fixtures.** Pixel-deterministic visual tests came for free once `Service.fixtures(frozenAt:)` existed. This pattern unlocked AC-V-01..06 with no flakiness.

## What slowed us down

- **Cycle-1 perf-test failure was self-flagged but not gated.** Implementer's `impl-notes.md` correctly identified that AC-P-02 was relaxed from 3s→5s on the dev box, but the test still tripped at ~8.7s when reviewer ran it. The implementer KNEW the test was fragile across machines but shipped it anyway with a hopeful number, costing one full review cycle (cycle-1 REQUEST_CHANGES → cycle-2 fix → cycle-2 PASS = ~5 min reviewer + ~15 min impl + ~3 min reviewer). The signal was there in impl-notes — the discipline to gate it before handoff was missing.
- **Gap between impl handoff and review pickup (~1h45m).** Not an agent-prompt issue; orchestration latency. Noted but not actionable here.
- **swift-testing vs XCTest mismatch in tasks.md.** Architect's tasks repeatedly said "XCTestCase / XCUITest" while the repo has used swift-testing for 145 tests. Implementer silently translated. Low cost this time but a future architect cycle could mis-spec a test trait or annotation. Worth a one-line clarification in architect's prompt to inspect existing test conventions before authoring tasks.

## Per-agent notes

### pm
Spec was tight, well-scoped (in/out scope explicit), and posed three open questions to architect that were all good ones. No friction.

### architect
Decision matrix style on open questions worked beautifully. Minor: tasks.md referenced XCTestCase/XCUITest; the repo uses swift-testing. One-line addition to architect prompt to check existing test framework would prevent this drift.

### implementer
Strong overall: 9 atomic commits, comprehensive impl-notes, conservative model usage (no Service-model extension). Single miss: shipped a known-fragile perf test rather than gating it. Pattern to add to prompt: when relaxing/widening a spec budget in a test, prefer env-var gating over assertion weakening.

### reviewer
Cycle-1 review was on-target: identified C1 cleanly, offered three fix recipes with tradeoffs, didn't bikeshed. Cycle-2 turnaround was fast and acknowledged the implementer chose the "even better than asked" option (restoring strict 3s). No prompt changes warranted.

### tester
Surfaced AC-P-02 honestly as conditional pass with measured number (3.96s), tied back to reviewer-002's explicit acceptance, and made the right call not to bounce for a calibration issue. Good judgment under the user's "don't reject on nits" directive. No prompt changes.

## Patterns to extract

- **Frozen-date fixtures + stub providers** make visual testing tractable. Worth canonizing in a future architect-prompt note for any future visual milestone.
- **Decision matrix in architecture.md** for open questions (state Decision: + Rationale: + cost) is the format that worked. Architect prompt could explicitly require this format.
- **impl-notes.md as a living workaround log** updated within the same cycle as changes — keep encouraging.

## Anti-patterns observed

- **Hopeful number in a perf test.** Picking a relaxed budget that still fails on the author's own machine is worse than gating the test entirely. The author KNEW (per impl-notes) and shipped anyway.
- **Silent translation of cross-framework references.** Implementer translated XCTestCase→swift-testing without flagging back to architect. Defensible (small cost, consistent with repo) but the architect prompt should pre-empt by checking conventions first.

## Proposed evolutions

See `.workflow/EVOLUTION.md` entries E001 and E002 (PROPOSED).
