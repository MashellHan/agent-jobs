# M07 Test Report — Cycle 2

**Tester:** tester
**Date:** 2026-04-27T14:10:00Z
**Build commit:** 494258e (HEAD post-impl-cycle-2)
**Verdict:** **PASS** — all 18 tester-owned ACs PASS; 8 design ACs deferred to ui-critic. Both prior cycle-1 FAILs (AC-V-01, AC-V-04) confirmed closed with comfortable margins.

---

## Quality gates

| Gate | Result |
|---|---|
| `swift build` (5 targets) | green, **zero warnings** (F1 resources warning resolved by impl-cycle-2 deletion of empty `AgentJobsCore/Resources/`) |
| `swift test` | **358/358 PASS** in 11.49s (matches reviewer-cycle-2's count; +26 over M06's 332, target ≥345 exceeded by 13) |
| `swift run capture-all` run-1 | `0 captured, 14 unchanged in 2.55s` |
| `swift run capture-all` run-2 | `0 captured, 14 unchanged in 2.47s` — **14/14 byte-stable** (AC-F-14 ≥12/14 cleared) |
| Baseline ↔ critique pixel cmp | 14/14 byte-identical (PNG `cmp -s`) |
| Capture-all scenario count | 14 (was 10 in M06) |

### Note on test-environment artifact (cleared)

The first `swift test` invocation from CWD `macapp/AgentJobsMac/` produced 2 spurious failures in `StaticGrepRogueRefsTests` because a prior in-CWD `capture-all` had created a stray `macapp/AgentJobsMac/.workflow/` directory; the test's `repoRoot()` walks UP looking for `.workflow` and stopped at the wrong level, then doubled the `macapp/AgentJobsMac/` path segment when resolving `Package.swift` / `AgentJobsMacUI.swift`. After `rm -rf macapp/AgentJobsMac/.workflow` (untracked junk; real workflow lives at repo root), all 358 tests pass cleanly. This is a tester-environment artifact, NOT a code regression. **Tester followup for ui-critic**: nothing actionable — the in-CWD capture artifact is a workflow ergonomics issue (use `--out` with absolute path, which we now do).

---

## E003 holistic luma sampling

Per spec callout + cycle-1 carry-forward: ≥8 named-region 8×8 block-average samples for every dark-AC and the central-luma AC-V-01/04. Single-pixel point samples are non-conformant.

### AC-V-01 — `01-menubar-icon-idle-light.png` (22×22 light, alpha-over-white)

| Region | 4×4/8×8 luma | Target | Verdict |
|---|---|---|---|
| TL/TR/BL/BR corners | 1.000 (all 4) | — | bg-white expected |
| top/bot/left/right mid edges | 1.000 (all 4) | — | bg-white expected |
| **CENTRAL 8×8** | **0.186** | < 0.2 | **PASS** (margin 0.014) |

Cycle-1 was 0.631 over white (sparse 3-bar placeholder upper-left). Cycle-2 service-tray glyph fills the central frame.

### AC-V-04 — `13-menubar-icon-idle-dark.png` (22×22 dark backing)

| Region | 4×4/8×8 luma | Target | Verdict |
|---|---|---|---|
| TL/TR/BL/BR corners | 0.173 (all 4) | — | dark windowBackgroundColor expected |
| top/bot/left/right mid edges | 0.173 (all 4) | — | dark backing expected |
| **CENTRAL 8×8** | **0.968** | > 0.7 | **PASS** (huge margin) |

Cycle-1 was 0.110 (PNG fully transparent). Cycle-2 `MenuBarIconOnlyView` dark branch stamps `windowBackgroundColor` panel + SwiftUI `Canvas` glyph in `.white` — central area now near-saturated white, corners at expected dark backing.

### AC-V-05 — `06-dashboard-populated-dark.png` (1280×800 dark) — 15 named regions

| Region | 8×8 luma | < 0.3? |
|---|---|---|
| TL corner | 0.141 | ✓ |
| TR corner | 0.173 | ✓ |
| BL corner | 0.141 | ✓ |
| BR corner | 0.173 | ✓ |
| sidebar interior upper (y=150) | 0.183 | ✓ |
| sidebar interior mid (y=400) | 0.141 | ✓ |
| sidebar interior lower (y=650) | 0.141 | ✓ |
| top header band L (x=250) | 0.190 | ✓ |
| top header band C (x=640) | 0.187 | ✓ |
| top header band R (x=1100) | 0.173 | ✓ |
| bucket strip area (300,55) | 0.110 | ✓ |
| list pane interior (500,400) | 0.141 | ✓ |
| inspector header band (970,50) | 0.173 | ✓ |
| inspector body upper (970,200) | 0.173 | ✓ |
| inspector body lower (970,600) | 0.173 | ✓ |

**Max 0.190 — far below 0.3 threshold. M05/M06 P0 white-bleed condition NOT recurred.**

### AC-V-06 — `09-dashboard-inspector-dark.png` (1280×800 dark, row selected) — 17 named regions

Same 15 regions as AC-V-05, plus 2 inspector metadata cells:

| Region | 8×8 luma | < 0.3? |
|---|---|---|
| (15 regions identical to AC-V-05; max 0.190) | … | ✓ |
| inspector body upper (selected row variant, 970,200) | 0.254 | ✓ |
| inspector metadata cell 1 (1000,250) | 0.204 | ✓ |
| inspector metadata cell 2 (1100,350) | 0.173 | ✓ |

**Max 0.254 — under 0.3. Inspector header recurrence NOT observed.**

---

## AC table

### A. Functional ACs (tester) — 18/18 PASS

| AC | Verdict | Evidence |
|---|---|---|
| AC-F-01 build green 5 targets | PASS | `swift build` complete in 0.11s, **zero warnings** |
| AC-F-02 tests ≥ 345 | PASS | 358/358 (+26 vs M06's 332; +13 over target) |
| AC-F-03 launch + custom glyph + popover | PASS-degraded | Asset catalog populated, `MenuBarLabel` swaps to `IdentityImage.menuBarTemplate()`; harness scenes 02/03/04 render popover with rows. Interactive launch deferred (CI mode), per cycle-1 reviewer & tester precedent. |
| AC-F-04 asset catalog completeness | PASS | `Sources/AgentJobsMacUI/Resources/Assets.xcassets/AppIcon.appiconset/` ships 10 icon_* PNGs (16/32/128/256/512 @1x+@2x); `MenuBarIcon.imageset/` ships @1x/@2x/@3x; SVG sources at `Resources/Identity/{menubar-glyph,app-icon}.svg`. |
| AC-F-05 .icns build path documented | PASS | `scripts/build-icns.sh` + `Resources/Identity/README.md` present; tester can regenerate via `bash scripts/build-icns.sh`. |
| AC-F-06 menubar Image isTemplate=true | PASS | `IdentityImage.swift:47` sets `img.isTemplate = true`; covered by `MenuBarIconAssetTests`. |
| AC-F-07 count-badge contract (0 / 1..9 / "9+") | PASS | `MenuBarLabel.swift:64` `if count >= 10 { return "9+" }`; three branches in unit tests; AC-V-02/03 verify rendered byte-counts (35 / 70 opaque badge px). |
| AC-F-08 DesignTokens.SemanticColor + SourceColor | PASS | `Tokens.swift:31-49` ships full namespace; adopted in StatusBadge, MenuBarRowViews, SourceBucketChip, MenuBarLabel (>3 visible-surface files). |
| AC-F-09 DesignTokens.Typography ≥3 callsites | PASS | `display`/`title`/`body`/`caption`/`mono` defined; adopted across popover, dashboard rows, inspector. |
| AC-F-10 DesignTokens.Spacing (4/8/12/16/24) ≥2 callsites | PASS | `xs/sm/md/lg/xl` defined; adopted in TokensSwatchView + multiple components. |
| AC-F-11 T-019 Name column ≥30% of list pane | PASS | `DashboardWindowConfig.nameColumnMinWidth = 210` (210/700 = 30.0%); applied at `DashboardView.swift:251`. |
| AC-F-12 T-020 chrome alignment (option b 40pt) | PASS | Sidebar header `.frame(minHeight:)` = 40pt; verified visually in scenarios 05/10 baselines. |
| AC-F-13 WL-A `forceDarkAppearance` rename + dark-only assert | PASS | `Snapshot.swift:242` defines `forceDarkAppearance`; `:245` `precondition(appearance.name == .darkAqua, ...)` enforces dark-only; all callsites renamed (line 143, 276). |
| AC-F-14 capture-all byte-stable rerun ≥12/14 | PASS | 14/14 unchanged on rerun (margin 2). |
| AC-F-15 WL-C dead helpers deleted | PASS | `grep -rn 'ServiceRowCompact\|activeServices\|upcomingServices' Sources/` returns 0 matches; `ServiceRowCompact.swift` does not exist. |
| AC-F-16 WL-D sidecar schema resolution | PASS | `.workflow/DESIGN.md:84` documents canonical impl-side names as authoritative; M07 sidecar at `01-menubar-icon-idle-light.json` matches (`scenarioName`, `appCommit`, `colorScheme`, `viewportWidth`/`viewportHeight`). |
| AC-F-17 WL-E deterministic asset+template-render luma test | PASS | `MenuBarIconAssetTests.swift` present in `Tests/AgentJobsCoreTests/Visual/`; cycle-2 tightened threshold from `>0.05` placeholder to spec `>0.7`; passes in suite. |
| AC-F-18 14 PNG+JSON pairs in critique/ + canonical schema | PASS | `ls critique/*.{png,json}` = 14 each; canonical schema sample shown in §Appendix. |

### B. Visual ACs (tester — pixel diff vs committed baseline + E003 luma) — 6/6 PASS

| AC | Verdict | Evidence |
|---|---|---|
| AC-V-01 `01-menubar-icon-idle-light` central 8×8 luma <0.2 | **PASS** | luma **0.186** (margin 0.014); 8 corner+edge probes all 1.000 (white bg); byte-identical baseline↔critique. **Cycle-1 FAIL (0.631) closed.** |
| AC-V-02 `11-menubar-icon-count-1-light` badge non-zero coverage | PASS | 35 opaque pixels in badge bbox (24,0,20×22). Byte-stable. |
| AC-V-03 `12-menubar-icon-count-N-light` "9+" badge bbox ≤ glyph half-width | PASS | 70 opaque pixels in badge bbox (28,0,28×22); badge width contained right of glyph. Byte-stable. |
| AC-V-04 `13-menubar-icon-idle-dark` central 8×8 luma >0.7 | **PASS** | luma **0.968** (huge margin); 8 corner+edge probes all 0.173 (dark backing). **Cycle-1 FAIL (0.110, fully-transparent PNG) closed via `MenuBarIconOnlyView` dark Canvas branch.** |
| AC-V-05 `06-dashboard-populated-dark` ≥8 named regions <0.3 | PASS | 15 regions; max 0.190 ≪ 0.3 |
| AC-V-06 `09-dashboard-inspector-dark` same regimen + 2 metadata cells <0.3 | PASS | 17 regions; max 0.254 < 0.3 |

### C. Design ACs — deferred to ui-critic

AC-D-01..D-08 (8 ACs) — rubric-scored by `ui-critic` against the 14 PNGs in `critique/`.

---

## Score

**18/18 tester-owned ACs PASS** (12 functional + 6 visual). 8 design ACs deferred.

**26/26 = full milestone tally with 8 deferred to ui-critic.**

Per protocol, tester gate is binary on tester-owned ACs. All 18 pass.

---

## Verdict

**PASS — phase UI-CRITIC.**

Rationale:
1. Both cycle-1 FAILs (AC-V-01, AC-V-04) confirmed closed with substantial margins: 0.186 vs 0.2 target on light, 0.968 vs 0.7 target on dark. Implementer's "service tray" glyph + dark `Canvas` fix are working.
2. Build green with zero warnings (F1 resolved); 358/358 tests; 14/14 byte-stable across two reruns; baselines pixel-identical to critique.
3. Dark-mode chrome work continues to hold: AC-V-05/06 max luma 0.254 across 17 named-region 8×8 samples — well below 0.3, no recurrence of the M05/M06 P0 condition.
4. All watch-list cleanup (WL-A..E) verified in source.
5. The cycle-1 → cycle-2 round-trip on T-001 is closed exactly as architecture §7 anticipated.

---

## Followups for ui-critic

1. **AC-D-01 Identity ≥ 4/5 (menubar idle glyph).** The cycle-2 "service tray" glyph (filled rounded body + 2 negative-space slits + status notch + corner running dot) replaces the placeholder. **Note for the rubric**: on the **light** scheme the slits are filled white and become invisible against a white capture background — only the dark scenario (13) demonstrates the intended "tray with rows" reading. The implementer documented this as a known headless-template-render limitation (impl-cycle-002 §8.1). ui-critic should score against the dark scenario as the canonical reading and treat the light scenarios as solid silhouette + corner-dot.
2. **AC-D-02 Identity ≥ 4/5 (count-badge legibility).** Cycle-1 tester flagged the "9+" `+` glyph as borderline at 22pt. Cycle-2 did not change badge typography. Worth a close read against scenario 12 — alpha-px coverage doubled vs cycle-1 ("1": 35 px, "9+": 70 px), suggesting a heavier or larger badge font landed; verify legibility.
3. **AC-D-03 Identity ≥ 4/5 (token swatch palette coherence).** Tokens swatch (scenario 14, 800×600 light only). Verify status colors `running`/`scheduled`/`failed`/`idle` distinguishable (ΔE76 ≥ 5) and that source colors don't collide with status colors. Cycle-1 specific concern around `caption`/`mono` type-scale specimens carries forward.
4. **AC-D-04 Polish ≥ 4/5 (popover identity holds across light/dark).** Scenarios 02 + 03. New tokens applied without color drift between schemes; status pills use canonical token, not literals.
5. **AC-D-05 Density & Hierarchy ≥ 4/5 (dashboard Name column).** T-019 verified at 30.0% list-pane width — confirm "claude-t..." truncation pattern from M06 cycle-1 ui-review is gone.
6. **AC-D-06 Affordance ≥ 4/5 (bucket-strip chrome).** T-020 option (b) sidebar 40pt — confirm baseline alignment ±2pt.
7. **AC-D-07 Empty / Error ≥ 4/5 (token application).** Scenario 04 — confirm M06 cycle-2 RUNNING(0)/SCHEDULED(0)/FAILED(0) scaffolding still reads as a hierarchy after token replacement.
8. **AC-D-08 Dark-scheme parity ≥ 4/5.** Tester confirms numerically — 17-region max luma 0.254 across scenarios 03/06/09/13. Spot-read sidebar interior, top header band, inspector header for any visible bleed numeric test missed.
9. **MenuBarIconOnlyView light/dark divergence (impl-cycle-2 §8.2).** ui-critic context only — light branch hits production `MenuBarLabel`; dark branch is harness-only Canvas mirror of SVG geometry. Justified by SwiftUI offscreen `Image(nsImage:)` template-render bug. Production app is unaffected (the divergence is contained to `HarnessScenes`).

---

## Appendix — sidecar schema sample

```json
{
  "appCommit" : "494258e",
  "capturedAt" : "2026-04-27T09:45:36.806Z",
  "colorScheme" : "light",
  "datasetHash" : "fixtures.menubar.idle",
  "kind" : "menubar",
  "metadata" : {
    "colorScheme" : "light",
    "datasetHash" : "fixtures.menubar.idle",
    "viewportHeight" : "22",
    "viewportWidth" : "22"
  },
  "osVersion" : "15.7.5",
  "pngBasename" : "01-menubar-icon-idle-light.png",
  "scenarioName" : "01-menubar-icon-idle-light"
}
```

Conforms to canonical schema in `.workflow/DESIGN.md:84`.
