# Retrospective M07

**Date:** 2026-04-27
**Cycles:** IMPL=2 REVIEW=2 TEST=2 UI-CRITIC=1 (cycle-1 ui-critic skipped — tester REJECTed first per PROTOCOL.md)
**Test count delta:** 332 → 358 (+26)
**Verdicts:** Reviewer cycle-1 91/100, cycle-2 93/100; Tester cycle-1 **REJECT 24/26**, cycle-2 PASS 18/18 testable; UI-Critic cycle-2 PASS 25/30 (threshold 24/30; cycle-1 skipped)
**Tickets:** 10 closed (T-001 + T-019 + T-020 + T-T01..T-T03 + WL-A..E); 2 new P2 filed → M14 (T-021, T-022)

## Headline

Second ENFORCING ui-critic milestone. The cycle-1 REJECT came from **tester**,
not ui-critic — exactly as the M06 retro's E003 evolution promised: tester's
holistic luma probe (now 22-named-region 8×8 block-average per E003) caught
the placeholder glyph's central-luma over white (AC-V-01) AND the dark
icon's fully-transparent capture (AC-V-04) before ui-critic ever ran. The
cycle-1 → cycle-2 swap-in was already authorized by architecture §7
(placeholder-then-real glyph 2-cycle pattern); cycle-2 implementer closed
both via real service-tray glyph + a private SwiftUI `Canvas` mirror in the
dark branch. Reviewer F1 resources warning closed cleanly. UI-critic cycle-2
PASS 25/30, two new P2 polish tickets filed (both M14). Five M06 watch-list
items folded in and closed (WL-A..E).

## What went well

- **E003 paid off on its first ENFORCING-mode invocation.** Tester's cycle-1
  22-region 8×8 block-average sample (across 02/05/06/09) caught a defect
  ui-critic would otherwise have surfaced — but more importantly, it
  *prevented a false-positive*: a single-pixel sample at (400, 20) on
  scenario 06 measured 0.784 (looked like white-bleed); the same region
  block-averaged resolved to 0.141 (text-glyph density, not chrome bleed).
  Exactly the corner-only blind spot E003 was promoted to prevent. **E003
  measurement criterion: settled after one milestone of confirmation.**
- **Placeholder-then-real glyph 2-cycle pattern worked as designed.**
  Architecture §7 explicitly authorized cycle-1 ship-with-placeholder and
  predicted AC-V-01 REJECT-recovery in cycle-2. Cycle-2 implementer
  delivered without scope creep: SVG + Swift `Canvas` mirror in lockstep,
  central luma 0.000 light / 0.968 dark — both clear targets with margin.
  The architect risk-budgeting was honest; cost was a single REJECT-recovery
  cycle (no STUCK escalation, no human intervention).
- **Reviewer F1 resources warning closed cleanly.** Cycle-1 reviewer flagged
  the empty `Sources/AgentJobsCore/Resources/` tree (architect-skipped
  colorset duplication leftover) as F1 with one-line fix. Cycle-2
  implementer deleted the dir. Zero-warning build restored.
- **Five WL items (WL-A..E) all closed in cycle 1.** WL-A rename + dark-only
  precondition; WL-B PNG + JSON byte-stable short-circuit (verified
  `0 captured / 14 unchanged` on rerun); WL-C dead-code purge enforced via
  `DeadCodeTests`; WL-D canonical-schema sentence in `.workflow/DESIGN.md`
  + `SidecarSchemaDocTests`; WL-E flaky wallpaper-sampling replaced by
  deterministic asset-catalog + offscreen-render check. Carrying watch-list
  items as concrete deliverables in the next milestone's spec is now a
  proven pattern (M06 → M07 = 5/5 closure).
- **Token rollout discipline held.** Architect scoped `SemanticColor` /
  `Typography` / `Spacing` namespaces additively, with legacy `StatusColor`
  typealiased so M02–M06 baselines stayed byte-stable. Reviewer cycle-1
  confirmed M02–M06 baseline diffs empty since milestone-start commit.
- **Older-milestone baselines regenerated in a dedicated commit.** Six M02/
  M03/M04 baselines shifted as fallout from T-019/T-020 layout work; the
  implementer landed them in commit `aa7c508` separate from feature work,
  matching the M06 cycle-1 precedent. Reviewer accepted the diff with
  rationale already present.

## What surprised us

- **`capture-all` capture-CWD-relative `--out` path created stray
  `.workflow/` in CWD, breaking `StaticGrepRogueRefsTests.repoRoot()`.**
  Tester cycle-2 hit this during rerun (`rm -rf` resolved it; not a code
  regression). The tool's `--out` flag is relative to the invoker's CWD;
  when invoked from `macapp/AgentJobsMac/`, it materialized
  `macapp/AgentJobsMac/.workflow/m07/screenshots/` which the static-grep
  rogue-refs scanner then treated as a second repo root. Workflow-ergonomics
  bug, not a code defect; would benefit from absolute `--out` defaulted to
  repo-root, never CWD-relative.
- **SwiftUI offscreen renderer drops template-flagged `Image` silently.**
  Root cause behind AC-V-04 dark-transparency. The `Image(nsImage:)` of a
  template-flagged `NSImage` renders nothing in SwiftUI's offscreen
  rendering context (works at runtime via `NSStatusItem`'s appearance
  inversion). Implementer worked around it by mirroring the SVG geometry in
  a SwiftUI `Canvas` for the dark scenario only, gated on
  `@Environment(\.colorScheme)` — keeping the light branch verbatim
  production code so scenarios 01/11/12 stayed exact. Pragmatic fix; the
  cost is a dual source of truth (SVG + Canvas) for the icon glyph until
  SwiftUI template-image support improves in offscreen contexts.

## Carry-forward watch-list to M08

1. **T-021 P2** — bucket-strip floats mid-pane in empty dashboard
   (scenario 07). Triage M14 visual polish.
2. **T-022 P2** — bucket-strip / sidebar-header baseline still ~13pt off
   after T-020 option (b). Triage M14 visual polish.
3. **`capture-all` `--out` CWD-relative path bug** — workflow-ergonomics
   issue; absolute path defaulted to repo-root would prevent the
   stray-`.workflow/` failure mode entirely. See E005 below.
4. **SVG ↔ Canvas dual source of truth in the dark icon branch.** The
   SwiftUI `Canvas` mirror duplicates the SVG geometry. Consolidate when
   SwiftUI template-image support in offscreen contexts improves; until
   then, any glyph design change must update both files in lockstep.
   See E006 below.
5. **AC-F-15 sidecar schema delta** — closed by WL-D doc-it option
   (`.workflow/DESIGN.md` declares `scenarioName / metadata.viewportWidth/
   Height / colorScheme / appCommit` canonical). Real rename or further
   doc remains optional future work if schema needs to evolve.
6. **AC-V-06 menubar-icon flake** (M02-era environmental). T-001's full
   asset-catalog rebuild + WL-E deterministic test rewrite *should* have
   closed it. Verify next milestone — if M08 captures don't flake, formally
   retire the watch-list item.

## Evolution proposals

**Two new candidates, both single-occurrence — listed for watch-list, not
yet promoted.** E001/E002 still settled (4 milestones running each); E003
settled this milestone (one confirmation run as designed); E004 watch
continues (no recurrence in M07).

### E005 candidate (1 occurrence — watch-list) — capture-all `--out` should be absolute, not CWD-relative

**Pattern observed (1×):** Tester cycle-2 ran `capture-all` from
`macapp/AgentJobsMac/` and got a stray `macapp/AgentJobsMac/.workflow/m07/
screenshots/` tree, which `StaticGrepRogueRefsTests.repoRoot()` then
treated as a second repo root and fail-closed. The fix was `rm -rf`. The
shape of the bug is workflow-ergonomic: any developer or CI run from a
non-repo-root CWD reproduces it.

**Why list it now:** Tester self-resolved without a code change, but the
**second occurrence** would mean the harness UX has a fail-mode that
recurs across hands. Promote to convention (capture-all defaults `--out`
to a hardcoded repo-root resolution; CWD-relative paths require explicit
flag) **if recurs in M08+**.

### E006 candidate (1 occurrence — watch-list) — SwiftUI offscreen renderer + template `NSImage` requires Canvas mirror

**Pattern observed (1×):** AC-V-04 dark-scheme idle glyph captured fully
transparent because SwiftUI's offscreen renderer silently drops
`Image(nsImage:)` of a template-flagged `NSImage`. Implementer mirror-fix
(SwiftUI `Canvas` redrawing the SVG geometry in the dark branch) works
but creates a dual source of truth.

**Why list it now:** This is the first M07 instance where production code
disagrees with the harness's offscreen-render fidelity in a non-color-
scheme way (M05/M06 dark-frame issues were color-scheme propagation, not
template-image silent-drop). Promote to convention (any harness scenario
that includes a template-flagged Image must use a `Canvas` mirror) **if
recurs in M08+**, especially during M11 (motion + micro-interactions)
where SF Symbol effects are a near-certain re-trigger.

## Per-agent notes (brief)

- **pm:** Strong M07 spec. Sequenced T-001 as gating task #1, named WL-A..E
  explicitly, baked E003 holistic-luma language into AC-V wording in
  advance, deferred density modes to M14 with documented rationale,
  capped capture-all scenario growth at 14 with ≤2s wallclock budget.
  Risks/callouts §3 ("template-image rules are strict") + §4 ("count-badge
  legibility at 16pt") + §6 ("AC-V-06 known flake → re-design as
  deterministic check") all anticipated cycle-1 footguns. Spec held under
  REJECT-recovery cycle without churn. Nothing to evolve.
- **architect:** Decisive on T-020 (option b sidebar-header heightens)
  and WL-D (doc-it instead of rename). Authorized cycle-1 placeholder
  glyph with explicit cycle-2 REJECT-recovery prediction in §7 — saved
  cycle-1 from being blocked on icon design. Single near-miss: empty
  `Sources/AgentJobsCore/Resources/` tree triggered F1 resources warning
  (architect-skipped colorset duplication leftover). Cycle-2 implementer
  cleaned up; not a structural issue.
- **implementer:** Cycle-1 workmanlike across 5 tasks + 6 commits +
  WL-A..E in a single sweep + 6 older-milestone baselines in a dedicated
  commit. Cycle-2 was decisive on both REJECT items: real glyph design +
  procedural Canvas mirror in dark branch — both grounded in actual root-
  cause investigation (template-image silent-drop in offscreen render).
  Lockstep SVG + Swift `Canvas` is the right pragmatic fix; flagged as
  F2 nit (dual source of truth) but accepted by reviewer.
- **reviewer:** Cycle-1 91/100 with 7 nits all correctly non-blocking;
  cycle-2 93/100 with 4 nits none blocking. Caught the F1 resources
  warning at cycle 1 with one-line fix recommendation; cycle-2 confirmed
  closure. Cycle-2 spot-checked AC-V-01 / AC-V-04 luma on committed
  baselines (0.186 / 0.968) — correct margin discipline.
- **tester:** Cycle-1 REJECT 24/26 was concrete and grounded: AC-V-01
  central-8×8 luma 0.631 over white > 0.2 target (sparse 14.9%-coverage
  glyph in upper-left quadrant); AC-V-04 captured PNG fully transparent.
  Followups for ui-critic were specific (per-axis predictions). **E003
  holistic luma sampling honored** at the 22-region floor, with explicit
  block-averaging rationale documented when single-pixel sample looked
  like a false-positive (text density vs. chrome bleed). Cycle-2 expanded
  to 17 named regions for AC-V-06 — methodology delta is structurally
  robust now.
- **ui-critic (cycle-2 only):** PASS 25/30 with concrete axis subscores
  and per-scenario notes naming exact y-coordinates. Identified the
  T-020 baseline residual mismatch as borderline AC-D-06 PASS (filed
  T-022 P2 rather than reopen T-020) — correct triage. Filed T-021 P2
  for scenario-07 strip placement; both tickets target M14. Cycle-1 ui-
  critic skipped per PROTOCOL.md after tester REJECT — protocol worked
  as designed; no wasted work.

## Did E001 + E002 + E003 still hold?

**All three settled.**
- **E001 (perf gates):** capture-all wallclock 2.41–3.23s vs 30s budget;
  WL-B byte-stable short-circuit reduces rerun cost (`0 captured /
  14 unchanged in 2.51s`).
- **E002 (swift-testing convention):** All +26 new tests use `@Suite` /
  `@Test` / `#expect`. Zero XCTest creep across the diff.
- **E003 (holistic luma probe ≥8 named regions):** Tester used 22-region
  / 17-region / 30-region samples across cycles, max luma always ≪ 0.3.
  M05/M06 P0 white-bleed condition NOT recurred. **Settled after one
  milestone of confirmation.**

## Watch-list carry-forward summary

6 items (2 P2 design tickets to M14: T-021 + T-022; 1 workflow-ergonomics:
capture-all `--out` CWD-relative bug; 1 dual-source-of-truth: SVG↔Canvas
icon mirror; 1 schema-doc: AC-F-15 closure verification; 1 flake-closure
verification: AC-V-06 next milestone). 2 evolution candidates listed for
watch-list (E005, E006); both single-occurrence; promote at M08+ if
recurrence observed.
