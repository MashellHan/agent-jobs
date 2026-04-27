# Retrospective M05

**Date:** 2026-04-24T00:00:00Z
**Cycles:** IMPL=1 REVIEW=1 TEST=1 UI-CRITIC=1 (first-try ACCEPTED across all 4 gates)
**Diff size:** +2460 −82 across 61 files
**Wall time:** ~2h41m (first PM commit 2026-04-27T11:21 → ship 14:02)
**Test count delta:** 266 → 317 (+51)
**Verdicts:** Reviewer 91/100, Tester 24/24, UI-Critic 22/30 advisory PASS-with-tickets
**Tickets:** 4 P0 closed (T-004/005/006/007); 3 newly filed (T-014 P0, T-015 P1, T-016 P2)

## Headline

First multi-deliverable milestone (4 bundled features) AND first milestone with a UI-CRITIC phase. Shipped clean: zero CRITICAL, zero rework cycles, every gate green on first attempt. The new ui-critic agent justified its existence by catching a P0 visual rendering gap (T-014) the tester had noted and waved past as "NSTableView offscreen quirk".

## What worked

- **Architect's option-A package surgery (`AgentJobsMacUI` library extraction)** sidestepped SPM's "cannot import executable target" bug cleanly. T01 landed first, the rest of the milestone built against the right module graph from the start. Impl-notes records only mechanical `import AgentJobsMac` → `import AgentJobsMacUI` rewrites and a handful of `public` visibility widenings — no logic drift, no architectural surprises mid-flight (`.workflow/m05/impl-notes.md` §T01).
- **Task ordering for 4 bundled deliverables held**: T01 (surgery) → T02 (harness skeleton) → T03/T04/T05 (independent content+sampler+diagnostics) → T06/T07 (harness internals) → T08 (CLI) → T09 (wire+baselines) → T10 (smoke) → T11 (PROTOCOL doc). Nothing starved; reviewer noted no implementer rush in any of the four (`.workflow/m05/review-cycle-001.md` "Wins" section: "every target has a focused responsibility"). Commit cadence shows the implementer worked the chain in ~1h45m (11:39 → 13:29) — fast, but linear, not skipped.
- **ui-critic caught what the tester missed**: tester recorded `04/05/06/07-left/08-left/09` Dashboard `Table` rows as a "known harness/Table/NSHostingView quirk" and PASSed AC-V-02 because `dashboard-row` unit baselines were green. UI-critic correctly escalated this to P0 because the critique set is what *the gate itself reads from M06*. T-014 + T-015 are real bugs surfaced by an extra pair of eyes. Three tickets is exactly the rubric's healthy band ("3-7 tickets per review is healthy").
- **E001 + E002 still hold cleanly two milestones post-ACCEPTED.** All perf ACs (`AC-P-01..04`) shipped strict-budget-gated behind `AGENTJOBS_PERF=1`; tester observed comfortable headroom (capture-all 1.66s vs 30s budget). Every new test file (`ServiceFormatterTests`, `LiveResourceSamplerTests`, `ProviderDiagnosticsTests`, `HarnessSnapshotTests`, `MenuBarInteractionTests`, `WindowInteractionTests`, `CritiqueReportTests`, `UICriticSmokeTests`) uses swift-testing — no XCTest creep across +51 tests.
- **Reviewer's M1 spec-amend resolution was the right move.** Implementer's scenario list (light/dark popover/dashboard variants) diverged from the spec table (`09-confirm-stop`, `10-hidden-toggle-on`). Reviewer offered "rename or amend"; tester chose amend because light/dark coverage is genuinely more useful for ui-critic than rigid scenario slots. Spec.md now records the amended set as the contract. This is healthy spec evolution, not silent drift — once it was named.
- **PROTOCOL.md UI-CRITIC phase landed as a numbered task (T11)**, not as an off-the-books edit. The advisory→enforcing distinction (M05 vs M06) is documented in §8. Lock-contract change was auditable.
- **Cron T-004 root-cause discipline**: PM did the diagnostic before writing the spec — found `~/.claude/scheduled_tasks.json` doesn't exist on the user's machine (legitimate empty bucket) AND found the silent-drop bug in `ClaudeSessionCronProvider.parseAll`. Spec scoped the fix to "surface the silent failure mode via diagnostics" rather than "make the empty bucket non-empty by faking data". Honest fix.

## What slowed us down

- **Tester treated a visual rendering gap as a quirk rather than a fail.** AC-V-02 said "dashboard rows render"; tester observed empty list body in `04-dashboard-populated-light.png`, attributed to NSHostingView/Table quirk, PASSed because unit-suite `dashboard-row` baselines were green. UI-critic flipped this to P0 (T-014) because the critique PNGs *are* the M06 gate's input. Net effect on M05: zero (ui-critic caught it). But it confirms the value of the new gate — and points to a tester-side blind spot when "the harness ate the data". Single occurrence, not yet evolution-grade.
- **Scenario-name drift between spec and impl.** Spec.md §Deliverable 5 enumerated 10 specific scenarios (`02-popover-default`, `09-confirm-stop`, etc.). Implementer shipped a different 10 (`01-menubar-popover-light`, `02-menubar-popover-dark`, …). Reviewer M1 caught it on filename grep; tester resolved via spec-amend in TESTING. Healthy outcome but the implementer adapted the scenario shape *during T08* without flagging the deviation in impl-notes — the surface for "I am changing the scope of what this task produces" is supposed to be a sentence in impl-notes, not silent. Single occurrence; not yet evolution-grade per the ≥2 rule, but on watch-list.
- **`AgentJobsMacUI.swift` is now ~530 LOC.** Reviewer L1: post-extraction it's the largest file in the codebase (post-T01 it absorbs `ServiceRegistryViewModel`, `AppDelegate`, `AgentJobsAppScene`, helpers). Mechanical extractions naturally leave a fat file; M06 can split. Not a milestone-blocker — noted for future.
- **Pre-existing AC-V-06 menubar-icon visual flake** continues to fail. Implementer correctly diagnosed via `git stash` against pre-M05 tree — environmental, not introduced by M05. Has been a watch-list item since M02; should either be `.disabled(if:)`-gated or moved to a CI-only lane in a future polish pass. M05's `locateBinary()` did update for the `AgentJobsMacApp` rename.

## What surprised us

- **Capture-all CLI is fast**: 1.66s wall for 10 PNG+JSON pairs (vs 30s AC-P-03 budget). 18× headroom. The harness will not be a CI-time bottleneck.
- **The UI-critic agent is sharper than expected on first run**. Score 22/30 with three correctly-prioritized tickets, no double-filing against existing T-002/T-003/T-008. The per-scenario notes are concrete ("source-bucket-strip renders chips as vertical stripes with letters stacked 'to / ta / l / 5'"). Comparable-product callouts (Stats, Things, Bartender, Activity Monitor, Linear) are grounded, not name-dropped. The advisory-mode result is a useful signal, not noise. Whether this holds in M06 enforcing-mode (where REJECT becomes possible) is the real test.
- **Public-API drift is easy to slip past architect.** Reviewer M2: `ProviderDiagnostics` shipped as a public actor on the provider, where architecture.md described `ProviderHealth` as the public surface and `LastErrorBox` as internal. Not a correctness bug — `ProviderHealth` IS produced — but architecture said one thing and code did another. Acknowledged as a M06 cleanup nit. Single occurrence.

## Per-agent notes

### pm
Strong. Ran the T-004 diagnostic before writing the spec — produced four numbered findings including the latent bucket-mapping bug at `ServiceSource.bucket:49` and the parser silent-drop. Three open questions to architect (5 vs 6 buckets, separate executable target, sampler cadence) had clear PM recommendations + clean delegation. The "scope (in)" carved cleanly into 5 deliverables; constraints section explicitly cited E001+E002. Nothing to evolve.

### architect
Decisive on all three open questions with rationale that survived implementation. Option-A package surgery (`AgentJobsMacUI` extraction) was the right call vs the two alternatives — five-target package compiles cleanly, no cycles. The `LiveResourceSampler` actor model with detached syscall (so the actor's serial executor isn't pinned during `proc_pid_taskinfo`) is textbook. One minor: `ProviderDiagnostics` ended up as a public actor where the architecture doc described `ProviderHealth` as the surface and `LastErrorBox` as internal — implementer drift, but architect's surface-document could have been one sentence stricter. Single occurrence; on watch-list.

### implementer
Workmanlike across 11 tasks in ~1h45m wall time. Package surgery clean (only mechanical import rewrites + necessary `public` widening). Actor models correct (Sampler + ProviderDiagnostics). No force-unwraps in new files; no `print()` outside the CaptureAll CLI where stdout is the contract. Two minor blind spots: (a) reshaped the Deliverable 5 scenario list during T08 without surfacing the deviation in impl-notes — reviewer caught via filename grep (M1); (b) widened `ProviderDiagnostics` to public surface vs architect's `ProviderHealth`-only contract — reviewer caught (M2). Both single occurrences; resolution paths are healthy (spec-amend, M06 cleanup). Not yet evolution-grade.

### reviewer
91/100 with the right call: zero CRITICAL, three graded findings (H1 CHANGELOG, M1 scenario-name drift, M2 public-API widening). M1's "either rename OR amend spec, the second is faster and arguably better — but it has to be a documented decision, not silent drift" is exactly the right framing. AC matrix concretely cited evidence (line numbers, sidecar JSON, file paths). Consistent with M03/M04 review quality.

### tester
24/24 PASS first-try. AC matrix evidence is concrete (commit shas in sidecars, byte counts, file outputs). Fixed H1 (CHANGELOG) and M1 (scenario rename via spec-amend) in TESTING per reviewer guidance — good "tester closes the small stuff" hygiene that's emerged across M03/M04. **One blind spot to watch:** treated empty Dashboard `Table` body in critique PNGs as "harness/NSTableView quirk" and PASSed AC-V-02 because unit baselines were green. UI-critic correctly upgraded this to P0 (T-014). The pattern is "harness output looks empty → unit baselines green → harness deemed unreliable → PASS". For M06 (where ui-critic enforces), an empty critique PNG should be treated as a failing AC-V, not a harness explanation. Single occurrence, on watch-list — if it recurs in M06 it becomes evolution-grade.

### ui-critic (NEW agent, first run)
Earned its keep on first invocation. Score 22/30 with three correctly-prioritized tickets (T-014 P0 dashboard rendering, T-015 P1 source-bucket-strip vertical-stripe layout, T-016 P2 retry affordance). Per-scenario notes are concrete and cite peer products (Stats, Things, Bartender, Activity Monitor, Linear). Did NOT double-file against existing tickets (cross-referenced T-002/T-003/T-008 inline). Recognized M05's advisory mode and recorded "M05 ui-critic is advisory" without overstepping. Caveat: M05 was a content-fidelity milestone — the popover content was the deliverable, so visible improvement was front-loaded into the inputs. M06 (information architecture) is the real test, where the agent must score visual *changes* against an already-improved baseline AND wield REJECT.

## Patterns to extract

- **Pre-spec investigation closes ambiguity early.** PM's T-004 root-cause finding (`scheduled_tasks.json` doesn't exist; the legitimately-empty bucket isn't a bug) prevented the implementer from chasing a phantom. Repeated pattern from M03/M04 PM behavior.
- **Big structural changes go first.** T01 (Package.swift surgery) landed before any feature task. M03's pattern; held for M05's largest structural change to date.
- **Reviewer's "amend spec" escape valve** is healthier than "force impl to match outdated spec text" when the implementer's adaptation is genuinely better. M05 deliverable-5 scenario list is the case study.
- **The new gate finds gaps the old gates were structurally blind to.** Tester reads ACs; ui-critic reads the artifact the *next* milestone's gate will read. Different lens, different bugs.

## Anti-patterns observed

- **"Harness quirk" as a PASS rationale** for empty visual output (tester AC-V-02 reasoning). Single occurrence, on watch-list.
- **Silent reshape of a numbered deliverable's surface** during impl without flagging in impl-notes. Single occurrence (T08 scenario-name drift), on watch-list.
- **Public surface widening past the architect's named type** without documenting (T05 `ProviderDiagnostics` vs architect's `ProviderHealth`). Single occurrence, on watch-list.

## Did E001 + E002 still hold?

**Yes, both. No drift.**
- **E001 (perf-budget gating):** AC-P-01 (formatter <50µs), AC-P-02 (sampler 100 PIDs <100ms), AC-P-04 (refresh-tick latency) all shipped strict-budget-gated behind `AGENTJOBS_PERF=1`. Implementer did not relax any budget. AC-P-03 (capture-all wallclock) measured 1.66s vs 30s — well inside budget. Three milestones running.
- **E002 (swift-testing convention):** Architect's tasks.md banner cites "Tests use swift-testing per E002". Every one of +51 new tests uses `@Suite`/`@Test`/`#expect`. Zero XCTest creep across the diff. Three milestones running.

Both graduate to "settled practice" — no further measurement needed.

## Proposed prompt evolutions

**None this milestone.** Per `retrospective.md` anti-patterns rule (`≥ 2 occurrences OR clear root cause`), no observation cleared the bar:

- Tester "harness quirk → PASS" reasoning: 1st occurrence; ui-critic caught it (the gate worked as designed). On watch-list for M06.
- Implementer scenario-name drift in impl-notes: 1st occurrence; reviewer caught and resolved cleanly. On watch-list.
- Implementer public-surface widening: 1st occurrence; reviewer flagged as M2. On watch-list.
- ui-critic agent quality: too early to evolve — first run was advisory. Wait for M06 enforcing-mode signal.

This continues the M03 retro precedent of NOT manufacturing evolutions when the workflow is performing well. The deliverable this cycle is the on-watch list and the empirical confirmation that E001 + E002 have settled.

If any one of the three watch-list items recurs in M06, propose at that retro.

## Watch-list carry-forward to M06

1. **Tester treatment of empty critique-PNG content.** If M06 produces another scenario where the harness output is empty AND the tester PASSes by appealing to unit baselines, propose an evolution: "if a scenario is enumerated in `capture-all`, its rendered PNG content is part of the AC, not a harness implementation detail."
2. **Implementer surface drift surfaceability.** If impl reshapes a numbered deliverable (e.g. scenario list, type signature, public surface) without flagging in impl-notes, propose an evolution: "before re-shaping a numbered deliverable's surface, write a one-sentence deviation in impl-notes naming the spec line being re-interpreted."
3. **ui-critic enforcing-mode behavior.** Watch whether REJECT is wielded sensibly when M06 first allows it. If false-positive REJECTs appear, tighten the rubric. If the agent under-uses REJECT (i.e. P0s pile up unfixed), tighten the verdict thresholds.
4. **`AgentJobsMacUI.swift` size (~530 LOC).** Split in M06 if convenient; otherwise will compound.
5. **Pre-existing AC-V-06 environmental flake.** Either gate or move to CI-only lane in a polish pass.
