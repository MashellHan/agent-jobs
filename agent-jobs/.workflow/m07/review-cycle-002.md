# M07 Review Report — Cycle 2

**Reviewer:** reviewer
**Date:** 2026-04-27T13:45:00Z
**Build commit under review:** e981530
**Verdict:** **PASS 93/100**

---

## Summary

Cycle-2 implementation closes both tester REJECT FAILs (AC-V-01 + AC-V-04)
and resolves the F1 resources warning. Build is clean (0 warnings),
358/358 tests pass, capture-all is 14/14 byte-stable on rerun, and the
new `MenuBarIconOnlyView` Canvas branch is contained to the harness +
gated to dark scheme only — production light path is verbatim
unchanged. M02–M06 baselines are untouched in cycle-2.

---

## Quality gates

| Gate | Result |
|---|---|
| `swift build` | `Build complete! (0.29s)` — zero warnings, zero errors |
| F1 resources warning | **GONE** — `Sources/AgentJobsCore/Resources/` directory removed |
| `swift test` | **358/358 pass** (no count delta from cycle-1; cycle-2 is fix-cycle) |
| `swift run capture-all` rerun | run-1 fresh empty out-dir = 14 captured; run-2 = `0 captured, 14 unchanged in 2.52s` — **14/14 byte-stable** |
| Baseline byte-equality vs fresh capture | 14/14 PNG byte-identical (verified `diff -q` on 01 + 13; rest match via diff -rq with only `.json` sidecars unique to critique) |
| M02/M03/M04/M05/M06 baseline diff vs commit `5b857e6` (cycle-1 tester boundary) | `0 insertions(+), 0 deletions(-)` across 30 byte-identical-but-mtime-touched files (no pixel-meaningful change) |
| WL-A `forceDarkAppearance` rename + dark-only precondition | Holds (`Snapshot.swift:236`, precondition at :245) |
| WL-C dead-code grep (`ServiceRowCompact\|activeServices\|upcomingServices`) | 0 matches in `Sources/` |

---

## AC re-verification (cycle-2 deltas)

### AC-V-01 — `01-menubar-icon-idle-light.png` central 8×8 luma < 0.2

Independently sampled the committed cycle-2 baseline PNG (alpha-composited
over white before luma calc — the actual measurement an AppKit menubar
would make):

```
01-menubar-icon-idle-light.png: central 8×8 luma = 0.186  (want < 0.2)
```

**PASS.** The new "service tray" glyph (filled 14×14 rounded body
centered in the 22×22 frame, with slits at glyph y=3 / y=12 deliberately
outside the central 8×8 sample window) clears the spec target. Margin
to threshold is tight (0.014) — see Finding F1 below.

Implementer's report claims luma 0.000 — that's measuring the raw RGB
plane *without* alpha compositing (the glyph pixels are RGB(0,0,0) with
alpha=255). My number (0.186) is the alpha-over-white composite that
matches what a sighted user / production renderer sees, and is also
the correct measurement to compare to the spec wording. Both numbers
confirm PASS, but the headline number in the spec context is 0.186.

### AC-V-04 — `13-menubar-icon-idle-dark.png` central 8×8 luma > 0.7

```
13-menubar-icon-idle-dark.png: central 8×8 luma = 0.968  (want > 0.7)
```

**PASS** (huge margin). Scenario 13 PNG now shows a clearly visible
white-on-dark glyph; cycle-1 fully-transparent capture is fixed.

### F1 resources warning

`Sources/AgentJobsCore/Resources/` deleted. `swift build 2>&1 | grep
warning` returns empty.

**RESOLVED.**

---

## `MenuBarIconOnlyView` design audit

The new view is the load-bearing change of cycle-2. Audit:

**Containment.** Lives entirely inside `HarnessScenes` as a
`private struct` — not exported, not reachable from production app
code. Production `MenuBarLabel` callsites in `MenuBarController.swift`
unchanged.

**Light path.** `else` branch returns
`MenuBarLabel(state: state).frame(width: 22, height: 22)` — byte-for-byte
identical to the cycle-1 wrapper. Scenarios 01/11/12 baseline PNGs
shifted only because the glyph SVG bytes changed; the surrounding
SwiftUI geometry is preserved (verified visually in the cycle-2 commit
diff and in the diffstat where 01/11/12 PNG sizes change but capture
geometry doesn't).

**Dark path.** A `ZStack` with:
- Backing: `Color(nsColor: .windowBackgroundColor)` (idiomatic AppKit
  dark menubar background)
- Overlay: SwiftUI `Canvas { ctx, size in ... }` painting the same
  geometry as `menubar-glyph.svg` (rounded body, two slits, status
  notch, running dot), tinted white, with backing-color "cuts" for
  slits/notch via alternate fill calls.

The Canvas geometry mirrors the SVG element coordinates exactly:
`(1,1,14,14)` rounded body, slits at y=3 / y=12, status notch at
(11.5, 8) r=1, running dot at (14, 4) r=1.5. I cross-checked the
Swift literals against `menubar-glyph.svg` — they match.

**Risk:** the dark path now has two separate glyph "sources of truth" —
the SVG (used by the asset catalog under `MenuBarIcon.imageset`) and
the Canvas literals in `MenuBarIconOnlyView`. If the SVG geometry
ever changes, the Canvas must be updated in lockstep. Implementer's
report acknowledges this (followup #2). See Finding F2.

**No production regression risk.** Light branch routes through the
production view; dark branch is the one branch the offscreen capture
exercises (real `NSStatusItem` never hits this code path — it always
takes the AppKit composition route, not SwiftUI Canvas).

---

## Findings

| ID | Severity | Area | Finding |
|---|---|---|---|
| F1 | nit | AC-V-01 margin | Central 8×8 luma 0.186 vs 0.2 threshold = 0.014 margin. Any downstream change to glyph rendering (anti-aliasing, sub-pixel positioning) could push it over. Not blocking — spec is met — but ui-critic should note the placeholder-vs-real boundary is thin. Recommend tightening glyph fill (e.g., enlarge body 14→15, or center coordinates better) in a future pass if the margin shrinks further. |
| F2 | nit | dual glyph sources | Canvas literals in `MenuBarIconOnlyView` duplicate the SVG geometry. Implementer flagged in followup #2. Acceptable for cycle-2 (SwiftUI offscreen `Image(nsImage:)` template-render bug genuinely justifies the Canvas detour); document as a known dual-source-of-truth and add to M14 watch-list. No code action required this cycle. |
| F3 | nit | light slits invisible | By design, light-scheme glyph slits fill `white` and disappear against the white capture background (only the real menubar's tinted compositor reveals them). Implementer flagged in followup #1. ui-critic should verify the dark scenario (13) is the canonical "tray with slits" reading and accept that the light captures look like a solid tray. Not a regression — same property held in cycle-1 placeholder. |
| F4 | nit | luma-measurement convention | Implementer's report and the cycle-1 tester report use slightly different luma conventions (raw RGB vs alpha-over-white composite). Both produce the same PASS verdict for AC-V-01 + AC-V-04, but the numeric values diverge (0.000 vs 0.186 for scenario 01). For consistency in future cycles, recommend tester + implementer agree on alpha-composite-over-white as the canonical method (matches what a sighted user actually sees). Doc-only fix. |

**None blocking.** All 4 are nits.

---

## Score derivation (out of 100)

| Axis | Weight | Score | Notes |
|---|---|---|---|
| Build/test green + warning-free | 20 | 20 | Clean build, 358/358, no warnings |
| AC-V-01 + AC-V-04 closure | 30 | 28 | Both PASS; -2 for the 0.014 margin on AC-V-01 (F1) |
| New code soundness (`MenuBarIconOnlyView`) | 20 | 18 | Dark Canvas branch is well-contained + scheme-gated; -2 for the dual glyph source (F2) |
| Capture-all byte-stability + baselines | 15 | 15 | 14/14 byte-stable; baseline PNGs match fresh capture |
| M02–M06 regression check | 10 | 10 | Zero pixel-meaningful diffs vs cycle-1 boundary |
| Cycle-1 reviewer findings carry-forward | 5 | 2 | F1 (resources warning) closed; F2-F7 from cycle-1 not regressed but also not actively addressed (the cycle-2 scope was AC-V FAILs only) |

**Total: 93/100.**

Threshold for PASS in REVIEWING phase per PROTOCOL: build/tests green +
all reviewer-owned ACs verifiable PASS. Both met. Findings are nits.

---

## Verdict

**PASS — phase advances to TESTING cycle 2.**

Tester picks up M07 TESTING cycle 2 with the cycle-2 baselines.
Expected to re-run the same E003 holistic luma sweep that passed in
cycle-1 + re-verify AC-V-01 + AC-V-04 numerically (this reviewer's
spot-check confirms both PASS at the spec thresholds), then advance to
ui-critic for AC-D-01..D-08 design rubric. Architect §7 noted cycle-2
as the expected glyph-redesign path; that prediction held — both
target ACs are now numerically clear of their thresholds with comfortable
margin on AC-V-04 and acceptable margin on AC-V-01.
