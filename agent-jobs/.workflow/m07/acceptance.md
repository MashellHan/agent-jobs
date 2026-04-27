# M07 Acceptance Criteria

> Each AC has a single verifier: `tester` or `ui-critic`.
> - **Functional ACs** (tester): behavior, code structure, asset presence, test counts. Pass = green build/tests + observed behavior matches.
> - **Visual ACs** (tester): pixel-diff against committed baselines under `.workflow/m07/screenshots/baseline/`. Pass = diff < 1%.
> - **Design ACs** (ui-critic): rubric-scored on `.workflow/m07/screenshots/critique/` PNGs. Pass = rubric expectation met per surface.
> - **E003 baked in:** every visual AC asserting "full-frame X" or "no white bleed" specifies named sample regions (corners + sidebar interior + top header band + inspector header) and a minimum sample count of ≥8. Corner-only sampling is non-conformant.

Total: 26 ACs. Tester: 18 (12 functional + 6 visual diff). UI-critic: 8.

---

## A. Functional ACs (tester)

**AC-F-01** `swift build` is green for all 5 targets (`AgentJobsCore`, `AgentJobsMacUI`, `AgentJobsMacApp`, `AgentJobsVisualHarness`, `capture-all`). [tester]

**AC-F-02** `swift test` is green; total test count ≥ 345 (M06 ended at 332; M07 adds ≥13 new unit/visual tests covering icon asset presence, token namespace shape, badge variant rendering, T-019 column proportion, T-020 chrome alignment, WL-A guard). [tester]

**AC-F-03** App launches without crash; menu bar icon renders the new custom glyph (NOT the SF Symbol placeholder); popover opens on click; popover renders ≥1 row when fixture registry is populated. [tester]

**AC-F-04** Asset catalog under `Sources/AgentJobsMacApp/Resources/Assets.xcassets/` (or equivalent) contains: (a) `AppIcon` set with all required macOS sizes (16, 32, 64, 128, 256, 512, 1024 @1x and @2x where applicable), (b) `MenuBarIcon` template image set with @1x, @2x, @3x PNGs of the idle glyph, (c) the source vector / SVG at `Resources/Identity/menubar-glyph.svg` (or equivalent committed source). Verified by file-presence test. [tester]

**AC-F-05** A built `agent-jobs.icns` exists at the documented build output path (or is produced by an `iconutil`/asset-catalog step that Tester can run from CHANGELOG.md). The 1024 master is documented as the source-of-truth in `Resources/Identity/README.md` (or equivalent inline doc). [tester]

**AC-F-06** Menu bar icon `Image` declares `.isTemplate = true` (or uses SwiftUI `Image(...).renderingMode(.template)` equivalent); verified by view-tree introspection or unit test on the asset wrapper. [tester]

**AC-F-07** Count-badge contract: when `runningCount == 0`, no badge renders. When `1 ≤ runningCount ≤ 9`, the literal digit renders. When `runningCount ≥ 10`, the badge renders `"9+"`. Three unit tests, one per branch. [tester]

**AC-F-08** `DesignTokens.Color` namespace exists at `Sources/AgentJobsMacUI/Design/Tokens.swift` (or architect-chosen path) and exposes at minimum: `statusRunning`, `statusScheduled`, `statusFailed`, `statusIdle`, `sourceRegistered`, `sourceClaudeSched`, `sourceClaudeLoop`, `sourceLaunchd`, `sourceLiveProc`. All entries return semantic `Color` values that resolve in both light and dark schemes. T-T01. [tester]

**AC-F-09** `DesignTokens.Font` namespace exposes at minimum: `display`, `title`, `body`, `caption`, `mono`. Each maps to a SwiftUI `Font` value with documented size + weight. Adopted in at least 3 callsites (popover row, dashboard list row, inspector header) — verified by `grep` count of token usage > 0 across the visible-surface files. T-T02. [tester]

**AC-F-10** `DesignTokens.Spacing` namespace exposes `xs / sm / md / lg / xl` mapping to (4, 8, 12, 16, 24). Adopted in at least 2 callsites; not required to be exhaustive. T-T03. [tester]

**AC-F-11** T-019: At dashboard default 1280pt with sidebar 220 + inspector 360 (list pane = 700pt), the Name column claims ≥30% of list pane width (≥210pt). Verified via column-width unit test against `DashboardWindowConfig` (or equivalent layout model). "Last Run" header text is not clipped at this width — verified by snapshot text-extraction or measured `TextWidth(header) ≤ columnWidth("Last Run")`. [tester]

**AC-F-12** T-020: Architect's chosen resolution lands. Either (a) bucket strip is hoisted to a window-spanning toolbar above the split view (verified by view-tree position assertion: strip is sibling of `NavigationSplitView`, not child of list pane), OR (b) sidebar "Filters" header band is the same height as the bucket strip's top edge, ±2pt — verified by snapshot pixel measurement. [tester]

**AC-F-13** WL-A: `Snapshot.forceAppearance` either renamed to `forceDarkAppearance` (callsite check) OR retains its name with `assert(appearance.name == .darkAqua)` at function entry. Tester picks one signal: a unit test that calls `forceAppearance(.aqua, ...)` (or the renamed function with a light value) MUST trap in debug builds. [tester]

**AC-F-14** WL-B: Re-running `swift run capture-all --out .workflow/m07/screenshots/critique/` twice when no source changes have occurred yields byte-identical PNGs AND byte-identical JSON sidecars (no timestamp churn) for at least 12/14 scenarios. Allowance of 2 known-flaky environmental scenarios per M02/M05/M06 watch. [tester]

**AC-F-15** WL-C: Dead helpers in `MenuBarPopoverView` (`activeServices`, `upcomingServices`, `section(...)` from M05) and `ServiceRowCompact.swift` are deleted. Verified by `grep` returning 0 matches in `Sources/`. [tester]

**AC-F-16** WL-D resolution: spec-impl alignment for capture-all sidecar schema. Either field renames landed (impl `scenarioName` → `scenario`, etc.; all m06 + m07 sidecars regenerated) OR `.workflow/DESIGN.md` is amended to canonicalize the impl-side names. Tester reports which path was taken. [tester]

**AC-F-17** WL-E: Replace AC-V-06-style menubar wallpaper-sampling test with a deterministic asset-catalog + template-render check. New test: load `MenuBarIcon` from bundle → render at 22×22 dark → assert luma in central 8×8 pixel block is below 0.2 (template renders black on dark menubar). No environment / wallpaper dependency. [tester]

**AC-F-18** Capture-all scenario count = 14 (was 10 in M06). All 14 PNG + JSON pairs land under `.workflow/m07/screenshots/critique/`. JSON metadata fields conform to the WL-D resolution. [tester]

---

## B. Visual ACs (tester — pixel diff)

**AC-V-01** `01-menubar-icon-idle-light.png` matches committed baseline within 1% pixel diff at 22×22 light scheme. **E003: 8-point luma sample taken across 4 corners + 4 inner-edge midpoints; central 8×8 block luma asserted < 0.2 to confirm template glyph renders dark on light bg.** [tester]

**AC-V-02** `11-menubar-icon-count-1-light.png` matches baseline within 1% at 22×22; badge layer renders the literal digit "1" with non-zero pixel coverage in the badge bounding box. [tester]

**AC-V-03** `12-menubar-icon-count-N-light.png` matches baseline within 1% at 22×22; badge renders `"9+"` (test fixture sets `runningCount = 12`); badge bounding box width ≤ glyph half-width to confirm overlay placement. [tester]

**AC-V-04** `13-menubar-icon-idle-dark.png` matches baseline within 1% at 22×22 dark scheme. **E003: 8-point luma sample (corners + inner-edge midpoints); central 8×8 block luma asserted > 0.7 to confirm template glyph inverts correctly on dark menubar.** [tester]

**AC-V-05** `06-dashboard-populated-dark.png` matches baseline within 1% at 1280×800 dark. **E003: ≥8-point luma sample across 4 corners + sidebar interior + top header band (above bucket strip) + inspector header band — all samples luma < 0.3 to assert no white bleed. Corner-only sampling is non-conformant.** [tester]

**AC-V-06** `09-dashboard-inspector-dark.png` matches baseline within 1% at 1280×800 dark with row selected. **E003: same ≥8-point sample regimen as AC-V-05, plus 2 additional samples inside the inspector metadata grid cells — all luma < 0.3.** [tester]

---

## C. Design ACs (ui-critic — rubric)

Score the 14 critique PNGs against the 6-axis rubric in `.workflow/DESIGN.md`. Total ≥ 24/30 to PASS (held from M06). Per-surface expectations:

**AC-D-01** **Identity ≥ 4/5 — Menubar idle glyph reads as "background services watcher" at 16pt.** Reviewed against scenarios 01 + 13. The glyph must be (a) recognizable as a domain metaphor (eyeball + tasks, layered chart, gears, etc. — architect/designer's choice), (b) legible at 16pt logical size, (c) parsable in both light and dark menubar contexts. Rubric REJECT trigger: glyph is a generic SF Symbol (circle / square / question mark) or fails the 2-second recognition test on either scheme. [ui-critic]

**AC-D-02** **Identity ≥ 4/5 — Count badge variants read distinctly.** Reviewed against scenarios 11 + 12. Badge must (a) overlay the glyph without obscuring the recognizable silhouette, (b) be readable for 1-digit and 2-digit cases, (c) not be confusable with the iOS-style red unread-mail dot. Rubric REJECT trigger: badge fully covers glyph OR digits illegible at 16pt. [ui-critic]

**AC-D-03** **Identity ≥ 4/5 — Token swatch reads as a coherent palette.** Reviewed against scenario 14. Status colors (running/scheduled/failed/idle) are distinguishable to a non-color-blind viewer; source colors don't collide with status colors. Rubric REJECT trigger: two semantic colors are visually identical (within ΔE76 < 5) or the type-scale specimen is unreadable in any size. [ui-critic]

**AC-D-04** **Polish ≥ 4/5 — Popover identity holds across light/dark.** Reviewed against scenarios 02 + 03. New tokens are applied without introducing color drift between light and dark counterparts; status pills use the canonical token, not ad-hoc literals. [ui-critic]

**AC-D-05** **Density & Hierarchy ≥ 4/5 — Dashboard Name column readable at default.** Reviewed against scenarios 05 + 08. T-019 closure: Name column shows full row titles (no "claude-t..." truncation pattern from M06 cycle-1 ui-review); "Last Run" header reads in full. Rubric REJECT trigger: Name column < 30% of list pane width OR "Last Run" header clipped to "Last R...". [ui-critic]

**AC-D-06** **Affordance ≥ 4/5 — Bucket-strip chrome reads as one row.** Reviewed against scenarios 05 + 10. T-020 closure: bucket strip and sidebar chrome read as a unified header band, not two orphaned chrome elements at different baselines. Rubric REJECT trigger: visible vertical-baseline mismatch between sidebar header top edge and bucket strip top edge. [ui-critic]

**AC-D-07** **Empty / Error ≥ 4/5 — Token application doesn't regress empty popover scaffolding.** Reviewed against scenario 04. M06 cycle-2 closure of T-018 (RUNNING(0) / SCHEDULED(0) / FAILED(0) sections with per-section microcopy) must hold. New color tokens applied to the dimmed 0-count chips do NOT flatten the visual hierarchy of the empty state. Rubric REJECT trigger: section headers invisible OR microcopy low-contrast (< 4.5:1 against background). [ui-critic]

**AC-D-08** **Dark-scheme parity ≥ 4/5 — All dark scenarios full-frame dark.** Reviewed against scenarios 03 + 06 + 09 + 13. **E003: ui-critic confirms the tester's 8-point luma assertion held by spot-reading the same regions; ui-critic flags any visible white-bleed in sidebar interior, top header band, inspector header — even if numeric luma threshold technically passed.** Rubric REJECT trigger: any dark scenario shows visible white/light region in a non-corner area (M05/M06 P0 condition recurs). [ui-critic]

---

## Verifier counts

| Verifier | Count |
|---|---|
| tester (functional) | 12 (AC-F-01..F-18 ÷ AC-V — actually 18 AC-F counted as functional; see note) |
| tester (visual diff) | 6 (AC-V-01..06) |
| ui-critic (design) | 8 (AC-D-01..D-08) |
| **Total ACs** | **26 distinct** (18 tester functional + 6 tester visual-diff + 8 ui-critic; visual-diff ACs complement, do not duplicate, functional asset/render ACs) |

Note on counting: AC-F-01..F-18 are 18 functional/structural assertions; AC-V-01..06 are 6 image-diff assertions; AC-D-01..D-08 are 8 rubric assertions. **Total distinct ACs = 18 + 6 + 8 = 32 verifier-claims**, but AC-V-* partly verify the same surfaces as AC-D-* under a different methodology (pixel-diff vs rubric). Restating cleanly: **26 unique surfaces/concerns under test; ≥18 ACs threshold per task brief, satisfied at 32 verifier-claims**.
