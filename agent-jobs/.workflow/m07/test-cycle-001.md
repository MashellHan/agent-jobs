# M07 Test Report — Cycle 1

**Tester:** tester
**Date:** 2026-04-27T12:55:00Z
**Build commit:** 5b857e6
**Verdict:** **REJECT** (24/26 PASS, 2 FAIL — both AC-V on the menubar icon glyph; placeholder asset gap, not a build/code regression)

---

## Quality gates

| Gate | Result |
|---|---|
| `swift build` (5 targets) | green (clean, with one pre-existing F1 resources warning re: empty `AgentJobsCore/Resources/Assets.xcassets`) |
| `swift test` | **358/358 pass** (target ≥345; +26 vs M06 baseline of 332) |
| `swift run capture-all` run-1 | `14 captured, 0 unchanged in 3.15s` |
| `swift run capture-all` run-2 | `0 captured, 14 unchanged in 2.42s` — **14/14 byte-stable** |
| capture-all scenario count | 14 (was 10 in M06) |
| Older-milestone baselines | M02/M03/M04 (6 + 7 + 17 byte-deltas) match reviewer-accepted impl-cycle-1 regeneration set (commit aa7c508) — diff stat shows zero pixel-meaningful change |

Baselines copied from `critique/` → `baseline/` (14 PNGs) per architecture §6 risk #5 (tester regens wholesale). `.workflow/m07/screenshots/baseline/` and `…/critique/` both committed-pending.

---

## E003 holistic luma sampling (per spec callout)

For every dark-AC, used 8x8-pixel **block averages** at named regions instead of single-pixel point samples. Single-pixel sampling in M06 cycle-1 had falsely flagged text-glyph hits as bleed; block averaging is the correct measurement of band fill.

### AC-V-05 `06-dashboard-populated-dark.png` — 12 named regions
| Region | 8x8 avg luma | < 0.3? |
|---|---|---|
| TL corner | 0.141 | ✓ |
| TR corner | 0.173 | ✓ |
| BL corner | 0.141 | ✓ |
| BR corner | 0.173 | ✓ |
| sidebar interior upper | 0.141 | ✓ |
| sidebar interior lower | 0.141 | ✓ |
| top header band L (avoiding text) | 0.141 | ✓ |
| top header band C | 0.177 | ✓ |
| inspector header band | 0.173 | ✓ |
| inspector body upper | 0.173 | ✓ |
| inspector body lower | 0.173 | ✓ |
| list pane interior | 0.180 | ✓ |

**Max 0.180 — well below 0.3 threshold. No white bleed.**

### AC-V-06 `09-dashboard-inspector-dark.png` — 10 named regions
| Region | 8x8 avg luma | < 0.3? |
|---|---|---|
| TL/TR/BL/BR corners | 0.141..0.173 | ✓ |
| sidebar interior | 0.141 | ✓ |
| top header band L | 0.141 | ✓ |
| top header band C | 0.177 | ✓ |
| inspector header band | 0.173 | ✓ |
| inspector metadata cell area 1 | 0.204 | ✓ |
| inspector metadata cell area 2 | 0.247 | ✓ |

**Max 0.247 — under 0.3. Inspector header recurrence (M05/M06 P0) NOT observed.**

> Side note for ui-critic: a single-pixel probe at (400, 20) on scenario 06 measured luma 0.784 — this is the column-header text glyph rendering, not chrome bleed. Block averaging across the same 8x8 region resolves to 0.141. Total bright pixels (luma > 0.5) in top 40 rows = 1.93% — text content density, not background fill. This is the kind of false positive E003 retro flagged when corner-only sampling was the norm; band averaging is the correct evolution.

---

## AC table

### A. Functional ACs (tester)

| AC | Verdict | Evidence |
|---|---|---|
| AC-F-01 build green 5 targets | PASS | `swift build` Build complete, 0 errors. F1 resources warning is non-blocking (reviewer-accepted). |
| AC-F-02 tests ≥ 345 | PASS | 358/358 pass (+26 over M06; target +13 exceeded by 13). |
| AC-F-03 launch + custom glyph + popover | PASS-degraded | Build + harness scenes render the glyph (asset present, MenuBarIcon image set populated). Interactive launch deferred (CI mode); per reviewer-cycle-1 deferral. AC-F-03 marked PASS on the basis of harness-rendered scenarios 02/03/04 showing popover with ≥1 row + `MenuBarLabel` swap to `IdentityImage.menuBarTemplate()` verified in source (`MenuBarLabel.swift`). |
| AC-F-04 asset catalog completeness | PASS | `Sources/AgentJobsMacUI/Resources/Assets.xcassets/AppIcon.appiconset/` ships icon_16/32/128/256/512 @1x+@2x (10 PNGs); `MenuBarIcon.imageset/` ships @1x/@2x/@3x; SVG source at `Resources/Identity/menubar-glyph.svg`. (Architect moved from MacApp → MacUI; reviewer accepted.) |
| AC-F-05 .icns build path documented | PASS | `scripts/build-icns.sh` + `Resources/Identity/README.md` present. `.icns` not pre-built in repo (build-on-demand); doc trail valid per AC's "OR is produced by an iconutil/asset-catalog step Tester can run" branch. |
| AC-F-06 menubar Image isTemplate=true | PASS | `IdentityImage.menuBarTemplate()` wraps NSImage with `isTemplate = true`; verified in tests `MenuBarIconAssetTests`. |
| AC-F-07 count-badge contract (0 / 1..9 / ≥10→"9+") | PASS | Three branches covered by `BadgeOverlay` tests (visible in `SwatchAndIconScenarioTests` + dedicated unit tests in test suite). |
| AC-F-08 DesignTokens.SemanticColor + SourceColor namespaces | PASS | `Sources/AgentJobsCore/Design/Tokens.swift` exposes `statusRunning/Scheduled/Failed/Idle` + `sourceRegistered/ClaudeSched/ClaudeLoop/Launchd/LiveProc`. Adopted in StatusBadge, MenuBarRowViews, SourceBucketChip, MenuBarLabel (>3 visible-surface files). |
| AC-F-09 DesignTokens.Typography (display/title/body/caption/mono) ≥3 callsites | PASS | Adoption found in 13 non-Tokens files (popover, dashboard rows, inspector, components). |
| AC-F-10 DesignTokens.Spacing (xs/sm/md/lg/xl = 4/8/12/16/24) ≥2 callsites | PASS | Defined in `Tokens.swift`; adopted in TokensSwatchView + multiple components. |
| AC-F-11 T-019 Name column ≥30% of list pane | PASS | `DashboardWindowConfig.nameColumnMinWidth = 210` (210/700 = 30.0%). Width applied via `.width(min:)` in DashboardView:251. "Last Run" header reads in full at this width per scenario 05 visual inspection. |
| AC-F-12 T-020 chrome alignment (option b 40pt) | PASS | Architect picked option (b) sidebar header heightens to 40pt; verified in source via `header:` closure with `.frame(minHeight:)`. Visual confirmation in scenarios 05/10. |
| AC-F-13 WL-A rename forceAppearance→forceDarkAppearance + dark-only assert | PASS | `Snapshot.swift:242` defines `forceDarkAppearance`; line 245 `precondition(appearance.name == .darkAqua, ...)` enforces dark-only. All callsites renamed. |
| AC-F-14 capture-all byte-stable rerun ≥12/14 | PASS | 14/14 unchanged on rerun (exceeds threshold by 2). |
| AC-F-15 WL-C dead helpers deleted | PASS | `grep -rn 'ServiceRowCompact\|activeServices\|upcomingServices' Sources/` returns 0 matches. `ServiceRowCompact.swift` does not exist on disk. |
| AC-F-16 WL-D sidecar schema resolution | PASS | `.workflow/DESIGN.md:84` documents canonical schema sentence (`scenarioName`, `appCommit`, `colorScheme`, `viewportWidth/Height` are authoritative; short forms NOT adopted). M07 sidecars match this canonical schema (verified in `01-...json`). |
| AC-F-17 WL-E deterministic asset+template-render luma test | PASS | `MenuBarIconAssetTests.swift` present with asset-catalog presence + offscreen render assertions; replaces M02-era wallpaper-sampling AC-V-06. Test passes in suite. |
| AC-F-18 14 PNG+JSON pairs in critique/ + canonical schema | PASS | 28 files (14 PNG + 14 JSON) under `critique/`; sidecars conform to WL-D schema. |

**Functional subtotal: 18/18 PASS** (AC-F-03 with documented degraded-but-passing note).

### B. Visual ACs (tester — pixel diff against fresh baseline + E003 luma)

| AC | Verdict | Evidence |
|---|---|---|
| AC-V-01 `01-menubar-icon-idle-light.png` 22×22 light, central 8×8 luma < 0.2 | **FAIL** | PNG byte-stable vs fresh baseline (0% pixel diff trivially), but the **central 8×8 luma over white = 0.631** (want <0.2). Glyph (3 monoline rectangles + dot per architecture §7 cycle-1 placeholder authorization) occupies only 14.9% of the 22×22 frame and is positioned in the upper-left quadrant; the central 8×8 catches mostly background, not glyph. **Root cause: placeholder glyph design — sparsity + off-center placement.** Not a render-pipeline bug. Pre-authorized by architect for cycle 1; expected to be replaced by the real glyph in REJECT-recovery cycle 2 per architecture §7. |
| AC-V-02 `11-menubar-icon-count-1-light.png` badge non-zero coverage | PASS | Badge bbox (right side of 44×22 frame) has visible "1" digit pixels (alpha-map confirms 25+ opaque pixels in the badge area). Byte-stable. |
| AC-V-03 `12-menubar-icon-count-N-light.png` → "9+", bbox width ≤ glyph half-width | PASS | Badge renders "9" + "+" digits at right side of 56×22 frame; badge bbox width ≈9px ≤ glyph half-width 11px. Byte-stable. |
| AC-V-04 `13-menubar-icon-idle-dark.png` central 8×8 luma > 0.7 | **FAIL** | PNG is **fully transparent** (0 opaque pixels in 22×22 frame) — capture-all renders the template-image asset directly without simulating macOS NSStatusItem inversion. Central 8×8 over dark bg = 0.110 (want > 0.7). **Root cause: harness scene `HarnessScenes.menuBarIconOnly(state: .idle)` for the dark scenario draws the template glyph as black-with-alpha; without a chrome inversion pass, dark-on-dark vanishes.** This AC fundamentally tests something the offscreen capture path cannot produce; needs either (a) a synthetic dark-menubar background rect + glyph composited as white in the harness, or (b) the AC re-scoped to "asset present + template flag set" (which AC-F-17 already covers). Implementer scenario wiring needs a fix. |
| AC-V-05 `06-dashboard-populated-dark.png` 12-region 8×8 luma all <0.3 | PASS | Max 0.180 across 12 named regions (corners + sidebar interior + top header band + inspector header + body + list pane). M05/M06 P0 white-bleed condition NOT recurred. Byte-stable vs fresh baseline. |
| AC-V-06 `09-dashboard-inspector-dark.png` 10-region 8×8 luma all <0.3 | PASS | Max 0.247 across 10 named regions including 2 inspector metadata cells. Byte-stable. |

**Visual subtotal: 4/6 PASS, 2 FAIL** (both on the menubar icon glyph asset).

### C. Design ACs — deferred to ui-critic

AC-D-01..D-08 (8 ACs) are rubric-scored, owned by `ui-critic` against the 14 PNGs in `critique/`.

---

## Score

**24/26 PASS** (functional 18/18 + visual 4/6 + 8 design deferred to ui-critic).

Threshold for advance to UI-CRITIC: all tester-owned ACs must PASS (gate is binary on tester side per PROTOCOL "Acceptance criteria met"). 2 visual ACs FAIL.

---

## Verdict

**REJECT — phase IMPLEMENTING cycle 2.**

Rationale:
1. AC-V-04 is a hard FAIL with empty-frame capture (capture-all dark scenario emits 0 visible pixels) — this is a clear implementer bug in scenario wiring, not a measurement quibble. The harness needs to either composite the template glyph as white over a dark bg for scenario 13, or the AC needs re-scoping (and the implementer + architect need to land that re-scoping).
2. AC-V-01 is a softer FAIL — the placeholder glyph sparsity falls below the central-8×8 dark-coverage assertion. Architect §7 explicitly anticipates this as the cycle-1 → cycle-2 REJECT-recovery path: real glyph design lands in cycle 2.
3. Both failures are concentrated in T-001 territory; the rest of the milestone (tokens, T-019, T-020, watch-list cleanup, capture-all infrastructure, dark-mode chrome) is solid.
4. Per spec risk #1 ("T-001 is gating"), failing T-001 surface ACs is exactly the case the protocol expects to round-trip back to IMPLEMENTING.

Note that the dark-mode chrome work from M06 cycle 2 is **fully holding**: AC-V-05/06 max luma 0.247 across 22 named-region 8×8 samples. The harness wiring/glyph fixes do not need to touch the snapshot dark-mode plumbing.

---

## Followups for ui-critic

1. **AC-D-01 Identity ≥ 4/5 (menubar idle glyph) — heads-up REJECT trigger likely fires.** The placeholder glyph (3 stacked rounded rectangles + dot, occupying upper-left quadrant only) is unlikely to clear "recognizable as a domain metaphor" or "2-second recognition test" rubric language. AC-V-01 already FAIL on luma; ui-critic should confirm whether to call AC-D-01 REJECT in the same cycle or hold pending cycle-2 glyph redesign.
2. **AC-D-02 Identity ≥ 4/5 (count-badge legibility).** Badge for `count == 1` renders "1" with reasonable coverage; `count == 12` renders "9+" but at 22pt source, the "+" is borderline legible (alpha map shows roughly 6×3 px footprint for the +). Worth a close read against the 16pt logical rendering target.
3. **AC-D-03 Identity ≥ 4/5 (token swatch palette coherence).** Tokens swatch (scenario 14) is 800×600 light only — ui-critic should verify status colors (running/scheduled/failed/idle) are visually distinct (ΔE76 ≥ 5) and that source colors don't collide with status colors. **Specific concern: `caption` and `mono` type-scale specimens may be hard to read at the rendered size; check readability of the 5-line type stack against scenario 14.**
4. **AC-D-08 Dark-scheme parity.** Tester confirms numerically — 22 named-region 8×8 luma samples across scenarios 02/05/06/09 max 0.247. ui-critic should spot-read the same regions for any visible bleed the numeric test missed (the M06 retro evolution lesson).
5. **Empty popover scenario 04 (AC-D-07).** Token application to dimmed-zero chips — confirm M06 cycle-2 RUNNING(0)/SCHEDULED(0)/FAILED(0) scaffolding still reads as a hierarchy after the new color tokens replace `Color(.systemX)` literals.

## Appendix — sidecar schema sample

```json
{
  "appCommit" : "5b857e6",
  "capturedAt" : "2026-04-27T09:29:51.080Z",
  "colorScheme" : "light",
  "datasetHash" : "fixtures.menubar.idle",
  "kind" : "menubar",
  "metadata" : { "colorScheme" : "light", "datasetHash" : "fixtures.menubar.idle",
                 "viewportHeight" : "22", "viewportWidth" : "22" },
  "osVersion" : "15.7.5",
  "pngBasename" : "01-menubar-icon-idle-light.png",
  "scenarioName" : "01-menubar-icon-idle-light"
}
```

Conforms to canonical schema in `.workflow/DESIGN.md:84`.
