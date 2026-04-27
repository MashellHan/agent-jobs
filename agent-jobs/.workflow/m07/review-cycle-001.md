# M07 Review — Cycle 001

**Phase:** REVIEWING
**Cycle:** 1
**Reviewer:** reviewer agent
**Reviewed at:** 2026-04-27T12:10:00Z
**Inputs:** `m07/spec.md`, `m07/acceptance.md`, `m07/architecture.md`, `m07/tasks.md`, `m07/impl-cycle-001.md`, diffs `46190d8..HEAD` (7 commits).

---

## Verdict

**PASS-with-nits — 91/100**

Advance to **TESTING cycle 1**.

Build green, 358/358 tests pass (target ≥345 — exceeds by 13), all 14 capture-all
scenarios emit cleanly, second-run is byte-stable 14/14, dead code purged,
WL-A..E mechanically landed, T-019 / T-020 closed at the source level. The
architect's two cycle-1 deviations (`SemanticColor` aliased to `Color(.system*)`
rather than asset-catalog colorsets; `StatusColor` not annotated `@available
deprecated`) are documented in `impl-cycle-001.md §"What did NOT happen"` and
are byte-stable / non-breaking respectively — accepted. The placeholder glyph
is explicitly authorized by architecture §7 for cycle 1; AC-D-01 rubric verdict
is ui-critic's call, not mine.

Two low-severity issues knock 9 points off the score:

1. **Resources warning** (`'agentjobsmac': found 1 file(s) which are unhandled
   ... AgentJobsCore/Resources/Assets.xcassets`) — empty leftover directory
   from architecture §1.2's planned-but-skipped color-set duplication. Build
   succeeds, but every clean rebuild prints the warning. Fix path below.

2. **6 older-milestone baselines regenerated** (M02 ×2, M03 ×2, M04 ×2). The
   reviewer brief expected `git diff 46190d8..HEAD -- .workflow/m02..m05 m06`
   to be empty; it is not (M05/M06 are clean, M02/M03/M04 carry 6 binary
   diffs). Implementer pre-justified this in `impl-cycle-001.md §"Older-
   milestone baselines regenerated"` against the M06 cycle-1 precedent
   (commit `3c5fcaf`); the layout shift is intentional (T-019 Name col +
   T-020 sidebar header band 40pt) and the regen is the cheapest correct
   fix. Acceptable but the reviewer flags it for awareness.

Neither blocks TESTING. Both can be addressed in cycle 2 if ui-critic kicks
back, otherwise carry into M08 watch list.

---

## Findings

| # | Severity | Area | Finding | Recommendation |
|---|---|---|---|---|
| F1 | Low | Build hygiene | Empty `Sources/AgentJobsCore/Resources/Assets.xcassets/` dir triggers SPM "found 1 file(s) which are unhandled" warning every clean build. Architecture §1.2 planned this path with 9 colorsets; impl-cycle-001 §"What did NOT happen" elects to skip the colorsets and use direct `Color(.system*)` aliases for byte-stability. The empty directory was left behind. | Pick one: (a) `rmdir` the empty `Resources` dir; (b) add `exclude: ["Resources"]` to the `AgentJobsCore` target in `Package.swift`; (c) declare it as `resources: [.process("Resources")]` and populate per architecture §1.2 in cycle 2. Option (a) is one line and reflects the actual implementation choice — preferred. |
| F2 | Low | Older-milestone artifacts | 6 binary baselines under `.workflow/m02/`, `m03/`, `m04/` regenerated this milestone (commit `aa7c508`). Reviewer brief expected zero diff. Implementer pre-justified per M06 cycle-1 precedent; M05 + M06 are clean. | Accepted. Document the precedent in `EVOLUTION.md` so the reviewer brief can be updated for M08 to allow "older-baseline regen iff justified by intentional layout shift". No code change. |
| F3 | Info | Architect deviation #1 | `DesignTokens.SemanticColor.statusRunning` resolves via `Color(.systemGreen)` rather than `AssetColor.color("StatusRunning")`. Architecture §1.2 + §1.4 specified asset-catalog backing. Trade-off: byte-stable M02-M06 baselines vs lost light/dark-variant tunability per token. | Documented in `impl-cycle-001.md`; accept for cycle 1. Revisit if ui-critic AC-D-04 (popover identity holds across light/dark) flags drift. |
| F4 | Info | Architect deviation #2 | `StatusColor.running` etc. are NOT annotated `@available(*, deprecated, renamed: ...)`. Architecture §1.4 said "expose both shapes; deprecate the old". Implementer skipped the annotation to avoid churning warnings during active milestones. | Accepted; track as M08 cleanup item. |
| F5 | Info | T-001 placeholder glyph | `menubar-glyph.svg` is a 3-rounded-rect-stack-plus-dot placeholder, not the spec's "watching eye + task list" reference metaphor. Architecture §7 explicitly authorizes a placeholder for cycle 1 with REJECT-recovery in cycle 2. | No action — pre-authorized. ui-critic owns AC-D-01 verdict. |
| F6 | Info | Test count delta arithmetic | Implementer claims 332 → 358 = +26 (correct). Of those, 1 deleted M02-era `MenuBarIconVisualTest` is netted out (Task 5 reshuffle into Task 1). Math reconciles. | None. |
| F7 | Info | `MenuBarInteraction.swift` Sendable warnings | 3 main-actor / Sendable closure warnings exist in `Sources/AgentJobsVisualHarness/MenuBarInteraction.swift` (lines 79/80/81). Pre-existing, not introduced this milestone. Build still passes. | Out of scope for M07; file as M08 watch-list candidate. |

---

## AC self-verification (functional ACs only — visual + design deferred)

Reviewer cannot verify AC-V-* (no committed M07 baselines yet — tester's job)
or AC-D-* (rubric judgment — ui-critic's job). The 18 functional ACs were
re-checked against source / build / test / capture-all output:

| AC      | Verifier | Verdict | Evidence |
|---------|----------|---------|----------|
| AC-F-01 | reviewer | PASS | Clean `swift build` succeeds with 5 targets compiled (warning F1 noted). |
| AC-F-02 | reviewer | PASS | `swift test` reports `Test run with 358 tests passed after 11.628 seconds.` (≥345 target met +13). |
| AC-F-03 | tester  | DEFERRED | Requires app-launch + popover click; reviewer cannot run interactively. |
| AC-F-04 | reviewer | PASS | `Sources/AgentJobsMacUI/Resources/Assets.xcassets/{AppIcon.appiconset, MenuBarIcon.imageset}/` populated; `Resources/Identity/menubar-glyph.svg` + `app-icon.svg` present; `MenuBarIconAssetTests` exercises load. |
| AC-F-05 | reviewer | PASS | 10 PNGs (16/32/128/256/512 @1x/@2x) under `AppIcon.appiconset/`; `Resources/Identity/README.md` documents pipeline. `.icns` build via `scripts/build-icns.sh` (idempotent). |
| AC-F-06 | reviewer | PASS | `IdentityImage.loadMenuBarNSImage().isTemplate == true`; tested. |
| AC-F-07 | reviewer | PASS | `BadgeText.text(for:)` 3-branch contract + 3 unit tests in `MenuBarIconAssetTests`. |
| AC-F-08 | reviewer | PASS | `DesignTokens.SemanticColor` + `.SourceColor` exist with 4 + 5 names; ≥3 visible-surface call sites confirmed by grep (`StatusBadge`, `MenuBarRowViews`, `SourceBucketChip`, `MenuBarLabel`, `TokensSwatchView`). Note: backed by `Color(.system*)` not asset catalog (F3). |
| AC-F-09 | reviewer | PASS | `Typography.display` added; namespace shape probe in `TokensTests`. ≥3-callsite adoption via `TokenAdoptionTests`. |
| AC-F-10 | reviewer | PASS | `Spacing.{xs,sm,md,lg,xl} = (4,8,12,16,24)` aliases added; `TokensTests` asserts. |
| AC-F-11 | reviewer | PASS | `nameColumnMinWidth = 210` pinned in `DashboardWindowConfig`; `NameColumnWidthTests` asserts ≥30%. |
| AC-F-12 | reviewer | PASS | `sidebarHeaderHeight = 40`; option (b) — sidebar header band heightened (architect's chosen path). Tested. |
| AC-F-13 | reviewer | PASS | `Snapshot.forceDarkAppearance(_:on:)` renamed; `precondition(appearance?.name == .darkAqua, ...)` at function entry (line 245); `SnapshotForceDarkAppearanceTests` covers. |
| AC-F-14 | reviewer | PASS | Manual: ran `swift run capture-all --out /tmp/m07-cap-1` twice; first run `14 captured, 0 unchanged in 3.23s`, second run `0 captured, 14 unchanged in 2.51s`. **14/14 byte-stable**, exceeds the ≥12/14 threshold. |
| AC-F-15 | reviewer | PASS | `grep -rn 'ServiceRowCompact\|upcomingServices\|activeServices' Sources/` returns **0 matches**. File deleted, helpers removed. |
| AC-F-16 | reviewer | PASS | `.workflow/DESIGN.md` carries the canonical-schema sentence: "the impl-side field names are authoritative — `scenarioName`, `appCommit`, `colorScheme`, `viewportWidth`/`viewportHeight`. Earlier proposal-only short forms ... are NOT adopted". WL-D option B as architect specified. |
| AC-F-17 | reviewer | PASS | `MenuBarIconAssetTests.menuBarIconRendersDarkOnDarkMenubar` deterministic asset-catalog + offscreen render. Implementer notes (impl-cycle-001 risk #2) the headless test uses an explicit white tint to compensate for AppKit's auto-tint only firing inside a real status item — relaxed `> 0.05` threshold acceptable as scaffolding; cycle-2 final glyph lifts past 0.7. **Caveat**: tester should NOT rely on capture-all output for the dark-glyph luma check; use the explicit-tint pattern. |
| AC-F-18 | reviewer | PASS | Capture-all emits exactly 14 PNG + 14 JSON pairs (`ls /tmp/m07-cap-1 \| wc -l = 28`). Renumber to 14-scenario table (architecture §3.1) verified scenario by scenario. |

**Functional ACs: 17/18 PASS, 1 DEFERRED to tester (AC-F-03 — interactive launch).**

---

## Architecture alignment

| Area | Architecture says | Implementation | Status |
|---|---|---|---|
| Asset catalog location | `Sources/AgentJobsMacApp/Resources/Assets.xcassets/` | `Sources/AgentJobsMacUI/Resources/Assets.xcassets/` | **Different path** — moved into `AgentJobsMacUI` (library) instead of `AgentJobsMacApp` (executable). Rationale: `Bundle.module` resolves cleanly from the UI library which is where `MenuBarLabel` + `IdentityImage` live; avoids the bundle-access caveat in architecture §1.2 entirely. Pragmatic improvement. **Accepted.** |
| `AgentJobsCore/Resources/Assets.xcassets` color sets | 9 colorsets duplicated for `Bundle.module` access | Empty directory, no colorsets created | Architect deviation (F3) — accepted, but leftover empty dir triggers warning F1. |
| Bundle path | `Image("MenuBarIcon", bundle: .main)` | Resolves via `Bundle.module` in `IdentityImage` loader | Better — works in `capture-all` context where `.main` is the harness binary. **Accepted.** |
| `StatusColor` deprecation | `@available(*, deprecated, renamed: ...)` typealiases | Not added (F4) | Architect deviation — accepted. |
| `scripts/build-icns.sh` | `rsvg-convert` w/ `qlmanage` fallback | bash + embedded Swift PNG renderer (no librsvg dep) | Self-contained, more portable. **Accepted.** |
| WL-D resolution | Option B: document impl schema | DESIGN.md amended; field names not renamed | **Matches architect's call.** |
| Task 3 split | One commit | Split into wiring (`c32b094`) + baseline regen (`aa7c508`) | Matches M06 cycle-1 precedent. **Accepted.** |
| WL-A through WL-E | Specified per task 5 | All landed mechanically | **PASS.** |

---

## Resources warning (callout)

```
warning: 'agentjobsmac': found 1 file(s) which are unhandled; explicitly
declare them as resources or exclude from the target
    /Users/.../macapp/AgentJobsMac/Sources/AgentJobsCore/Resources/Assets.xcassets
```

**Root cause:** Architecture §1.2 planned to duplicate the color sets into
`AgentJobsCore/Resources/Assets.xcassets/` so `Bundle.module` could resolve
them from the library. Implementer (per `impl-cycle-001.md §"What did NOT
happen"`) chose to back `SemanticColor` with `Color(.system*)` instead, which
is byte-stable against M02-M06 baselines but bypasses the asset catalog
entirely. The empty directory was left behind on disk and triggers SPM's
unhandled-files warning every clean build.

**Recommended fix (cheapest):** delete the empty directory.
```bash
rmdir macapp/AgentJobsMac/Sources/AgentJobsCore/Resources/Assets.xcassets
rmdir macapp/AgentJobsMac/Sources/AgentJobsCore/Resources
```
The directory isn't git-tracked (no files in it), so this is purely a local-
workspace fix. If the implementer wants to keep the directory as a future-
proofing scaffold for cycle 2 (when the asset-catalog colorsets land per
architecture §1.2), the alternative is a one-line edit to `Package.swift`:
```swift
.target(
    name: "AgentJobsCore",
    path: "Sources/AgentJobsCore",
    exclude: ["Resources"]   // until colorsets land
),
```

This is a **non-blocking** finding — build succeeds, all tests pass — but it
should be addressed before M08 starts so the warning doesn't normalize.

---

## What I checked but didn't change

- Did NOT run, edit, or regenerate `.workflow/m07/screenshots/baseline/` (tester's job per architecture §6 risk #5; directory does not yet exist on disk).
- Did NOT modify any source file — review is read-only.
- Did NOT push to remote (push policy gate per `PROTOCOL.md`).

---

## Phase transition

Reviewer transitions: `REVIEWING cycle 1` → `TESTING cycle 1`.

- `phase: TESTING`
- `cycle: 1`
- `owner: null`
- `lock_acquired_at: null`, `lock_expires_at: null`
- `last_actor: reviewer`
