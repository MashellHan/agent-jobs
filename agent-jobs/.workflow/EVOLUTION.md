# Workflow Evolution Log

> Tracks changes to agent prompts. Each change has a rationale, the diff, and (when measurable) the observed effect on subsequent milestones.

## Format

```
## E{NNN} — YYYY-MM-DD — agent-name

**Trigger:** which retrospective(s) prompted this
**Status:** PROPOSED | APPLIED | REVERTED
**Rationale:** why
**Diff:** unified diff of the prompt change
**Measured effect:** observed in next 1-3 milestones (filled in retroactively)
```

## E000 — 2026-04-23 — bootstrap

**Trigger:** Initial workflow setup. No retrospective exists yet.
**Status:** APPLIED
**Rationale:** Establish baseline agents (pm, architect, implementer, reviewer, tester, retrospective).
**Diff:** N/A (initial)
**Measured effect:** TBD after M01 completes.

---

## E001 — 2026-04-24 — implementer

**Trigger:** M02 retrospective
**Status:** ACCEPTED (graduated from PROPOSED in M03 retro 2026-04-24T10:35:00Z)
**Rationale:** In M02 cycle-1, the implementer relaxed the AC-P-02 perf budget from 3s (spec) to 5s (test) on the dev box, documented the workaround in impl-notes.md, and shipped to REVIEW. The test still failed on the reviewer's run (~8.7s on cold cache), forcing a REQUEST_CHANGES bounce and a full extra cycle. The implementer's own notes show they knew the test was fragile across machines. The fix (env-var gate restoring the strict 3s) was 3 lines in cycle-2 and could have been done up-front. Pattern: when a test cannot honestly enforce a spec budget on the author's machine, gating (env-var or trait) is strictly better than assertion-weakening. Evidence: `.workflow/m02/impl-notes.md` cycle-1 vs cycle-2 sections; `.workflow/m02/review-cycle-001.md` C1; `.workflow/m02/impl-cycle-002.md`.
**Diff:**
```diff
--- a/.claude/agents/implementer.md
+++ b/.claude/agents/implementer.md
@@ -76,6 +76,7 @@ If tester sent you back:
 | Force unwraps | `grep -rn '!' Sources` (review hits) | remove |
 | `print()` | `grep -rn 'print(' Sources` | replace with Logger |

+**Spec-budget rule:** if you cannot honestly enforce a spec budget (perf, size, latency) in a test on your own machine, GATE the test (env var or `.enabled(if:)` trait) preserving the strict spec assertion for opt-in runs. Do NOT relax the assertion to a "hopeful" looser number — that ships a known-fragile gate to reviewer/tester. Document the gate trigger in impl-notes.md and in the test's doc-comment.
+
 ## Anti-patterns
```
**Measured effect:** **CONFIRMED in M03.** All three perf ACs (AC-P-01 50 ms HiddenStore, AC-P-02 3 s discovery, AC-P-03 10 ms filter) shipped with strict spec budgets gated behind `AGENTJOBS_PERF=1`. Implementer did NOT relax any budget; tester ran them gated and observed 38–40× headroom (1.29 ms, 0.25 ms). Zero perf-test bounce in M03 (vs full extra cycle in M02). See `.workflow/m03/impl-cycle-001.md` AC matrix rows P-01..P-03 and `.workflow/m03/test-cycle-001.md` perf section.

---

## E002 — 2026-04-24 — architect

**Trigger:** M02 retrospective
**Status:** ACCEPTED (graduated from PROPOSED in M03 retro 2026-04-24T10:35:00Z)
**Rationale:** M02 tasks.md repeatedly referenced `XCTestCase` and `XCUITest` while the repo's existing 145 tests all use swift-testing (`@Suite`, `@Test`). Implementer silently translated and noted it in impl-cycle-001.md. Low cost in M02 because the translation was straightforward, but in a future milestone the framework mismatch could mis-spec a trait, tag, or skip mechanism (e.g., `.enabled(if:)` vs `XCTSkip`). One occurrence so far — borderline by the "≥2 occurrences" rule, but the root cause is clear (architect did not inspect existing test conventions) and the fix is one line. Evidence: `.workflow/m02/tasks.md` T01/T03/T08/T09 (XCTestCase mentions); `.workflow/m02/impl-cycle-001.md` §"Notable workarounds #3"; `.workflow/m02/impl-notes.md` "XCTest references in tasks.md mapped to swift-testing".
**Diff:**
```diff
--- a/.claude/agents/architect.md
+++ b/.claude/agents/architect.md
@@ -X,6 +X,7 @@ ## Procedure
   - Read `.workflow/m{N}/spec.md` and `acceptance.md`
   - Read `.workflow/PROTOCOL.md`
   - Read existing `Sources/` to understand current architecture
+  - Skim `Tests/` (at least one file) to confirm the test framework convention (XCTest vs swift-testing) and use that idiom in tasks.md — do NOT assume XCTest by default
```
(Note: exact insertion point depends on architect.md structure; apply at the "read inputs" step of the architect's procedure.)
**Measured effect:** **CONFIRMED in M03.** Architect opened `tasks.md` with a banner: *"Tests use swift-testing (`@Suite`, `@Test`, `#expect`) per E002. NOT XCTest."* All 10 tasks specify swift-testing test files. Implementer wrote ZERO framework-translation workarounds in `impl-cycle-001.md` (M02 had one). Test count grew from 180 → 226 (+46) all in swift-testing idiom, no XCTest-shaped scaffolding. See `.workflow/m03/tasks.md` header line 3.

---

## M03 retro outcome — 2026-04-24

**Trigger:** M03 retrospective (first-try PASS, IMPL=1 REVIEW=1 TEST=1, 93/100, 25/26 ACs PASS + 1 SKIP-as-designed).

**No new evolutions proposed.** Per retrospective.md anti-patterns rule (≥ 2 occurrences OR clear root cause), nothing in M03 cleared the bar:
- Reviewer trusted impl's `Package.swift` claim without re-checking (first occurrence; reviewer self-flagged with −1).
- One test suite leaked `AGENTJOBS_INTEGRATION=1` process-wide (first occurrence; cosmetic today).

Both go on the watch-list for M04. The retro's deliverable this cycle is the graduation of E001 + E002 to ACCEPTED based on direct M03 evidence — exactly the feedback loop the workflow is designed for.

See `.workflow/m03/retrospective.md` for full analysis.

---

(Future entries appended here)
