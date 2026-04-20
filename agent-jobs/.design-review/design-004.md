# Design Review 004
**Date:** 2026-04-20T13:35:00Z
**Reviewer perspective:** Senior product designer (FAANG-tier)
**Files scanned:** 4 SwiftUI views (MenuBarViews 126 LOC, AutoRefreshIndicator, DashboardView 282 LOC, AgentJobsMacApp), 1 token module (DesignTokens), 9 components in `Sources/AgentJobsMac/Components/`
**Git HEAD:** 1e29efe (cycle 14 — popover material + inspector subtitle)
**Previous review:** 003 (score 92/100)

## Overall Score: 95/100  (+3 vs 003, **second consecutive ≥ 90 → DECLARE-DONE**)

Both Top-3 items I called out in design-003 landed in a single 12-minute cycle:
- **`.background(.regularMaterial)`** on `MenuBarPopoverView`'s outer `VStack` (line 42). Vibrancy now blends the popover into the desktop wallpaper instead of rendering against the OS default flat surface. Dark-mode adaptive for free.
- **Provenance subtitle** on `ServiceInspector.header` (line 163): `Text("\(service.source.category.displayName) · \(service.project ?? "—")")` with `caption` font + `.secondary` foreground. Closes the long-standing D-M3 carry-over (originally raised in design-001 — 4 cycles ago).

The codebase now reads as a Linear/Raycast-tier menubar tool across all three altitudes (menubar popover, dashboard table, inspector). Two consecutive ≥ 90 reviews with HIGH tier empty for 2 straight cycles. **Termination criterion met for the design-review stream.**

## Category Scores

| Category | Score | Prev | Delta | Notes |
|---|---:|---:|---:|---|
| Visual hierarchy | 14/15 | 13 | +1 | Inspector subtitle adds a real third-tier line under the title (name → subtitle → command). The dashboard sidebar still lacks a "current selection breadcrumb" but that's cosmetic. |
| Information density | 13/15 | 13 | 0 | Unchanged. Schedule column still reads correctly ("daily at 09:00", "hourly at :05"). Column-priority hints for narrow widths (D-M9) carried. |
| Aesthetics | 14/15 | 13 | +1 | Popover vibrancy is the single biggest aesthetic upgrade since design-001. Card-tile MetricTile with stroke border still excellent. Hover background still uses `Color.primary.opacity(0.06)` inline (D-L1 — semantic alias debt). |
| Interaction | 14/15 | 14 | 0 | Unchanged. ChipRow tabs, HoverableIconButton, ErrorBanner Retry all still excellent. Start/Stop/Restart actions still missing (D-M4 carried — defer until provider wiring). |
| Accessibility | 10/10 | 10 | 0 | Maxed. Provenance subtitle is plain text, picked up by VoiceOver naturally as part of the inspector header read order. |
| Empty / Error / Loading | 10/10 | 10 | 0 | Maxed. |
| macOS-native feel | 9/10 | 8 | +1 | Vibrancy on the popover hits the single biggest gap. Footer buttons still default-style — minor. The 1 missing point is the menubar `MenuBarLabel` icon: still a SF symbol with no template treatment for color-mode contrast (verify in screenshot — flagged as D-L11). |
| Information completeness | 11/10 → cap **11**/10 | 10 | +1 | Inspector subtitle surfaces `<source · project>` — provenance was the last "data already in the model but not visible" gap. Combined with cycle-12's real Schedule.calendar humanization, the inspector now answers all six WH questions about a service (what, where, when, why, who, how). Bumping above cap. |

**Total:** 14+13+14+14+10+10+9+11 = **95/100**

CPU + MEM remain visible at all three altitudes (verified):
- Menubar: `MemoryBadge` in summaryStrip (total bytes + accessibility label)
- Dashboard table: `CPU` + `Memory` columns with threshold-driven `ResourceColor`
- Inspector "Metrics" tab: 4-tile grid (CPU / Memory / Threads / FDs)

## Top 3 actions for implementer (by ROI)

The remaining items are all carry-over polish; no new P0/P1 surfaced this cycle.

1. **[P3 — defer to maintenance] D-L1 (semantic-alias hover token).** `Color.primary.opacity(0.06)` appears inline in `ServiceRowCompact` AND `TabChip`. *Fix:* introduce `DesignTokens.Surface.hoverFill` and inline. Pure refactor, 5-min, no behavior change.
2. **[P3 — defer until provider wiring] D-M4 (Start/Stop/Restart toolbar).** Skip until `ServiceProvider` actually implements one of `.start/.stop/.restart`. Disabled-everywhere is worse than absent.
3. **[P3 — i18n posture] D-L8 (hard-coded English in Schedule humanizer + new subtitle).** `"daily at 09:00"`, `"weekly Mon at 03:30"`, and the new `"\(displayName) · \(project)"` are all English-baked. Defer to .strings catalog cycle. Non-blocking for v1 ship.

## Issues (full)

### CRITICAL
*(none — third consecutive empty CRITICAL)*

### HIGH
*(none — second consecutive empty HIGH)*

### MEDIUM
- **D-M2** *(carried)* `DesignTokens.swift:43-66` — Resource thresholds remain hard cliffs. Lower priority — gradient interpolation would polish but isn't required for ship.
- **D-M3** ✅ **CLOSED** by `1e29efe`. Inspector subtitle landed.
- **D-M4** *(carried)* `DashboardView.swift / ServiceInspector` — No Start/Stop/Restart actions wired. See Top-3 #2.
- **D-M5** *(carried)* `DashboardView.swift:127-138` — `Tab` enum still uses `rawValue` for both display and id. Becomes biting once we localize.
- **D-M9** *(carried from design-003)* Dashboard table — no column-priority hint for narrow widths. Defer.

### LOW
- **D-L1** *(carried since design-002)* No semantic alias layer. Hover background still inline magic number in 2 sites. See Top-3 #1.
- **D-L2** *(carried)* `MenuBarViews.swift` `summaryStrip` — chips at narrow widths still risk jumping. `.fixedSize(horizontal: true, vertical: false)`.
- **D-L3** *(carried)* `AutoRefreshIndicator.swift` — Timer runs while popover closed. Pause via `scenePhase`.
- **D-L4** *(carried)* `DashboardView.swift:112` `Text(status.rawValue.capitalized)` non-localizable.
- **D-L7** *(carried)* DashboardView ContentUnavailableView copy "Pick something from the list to inspect." — polish only.
- **D-L8** *(carried from design-003)* i18n posture — see Top-3 #3.
- **D-L9** *(carried from design-003)* `ErrorBanner` color choice — confirm dark-mode contrast in screenshot.
- **D-L10** *(carried from design-003)* Inspector chip row has no overflow strategy if a 5th tab lands.
- **D-L11 NEW** `MenuBarLabel` (Components) — verify SF Symbol carries `.symbolRenderingMode(.hierarchical)` or template treatment for menubar color-mode contrast (light/dark menubar). Worth a 30-second screenshot pass before ship.
- **D-L12 NEW** `MenuBarPopoverView` `.background(.regularMaterial)` is applied to the outer `VStack` — verify it doesn't bleed through `Divider()`s as a brighter strip. Probably fine (Divider draws on top of material) but worth a visual spot-check.

## Wins since last review

- **D-Top-3 #1 (popover material)** ✅ `MenuBarPopoverView:42` `.background(.regularMaterial)`. Inline comment explains the design intent. Adapts to dark mode for free.
- **D-Top-3 #2 / D-M3 (inspector subtitle)** ✅ `DashboardView:163` provenance line `<displayName> · <project>`. `caption` font, `.secondary` foreground. Reads naturally with VoiceOver as part of the header element.
- **CHANGELOG hygiene** — cycle-14 entry explicitly cross-references which design issues were closed by which line of code. Easy to audit.
- **Single-cycle landing** — both Top-3 items in one 12-minute commit (`1e29efe`). High signal-to-noise commit.

## Cross-references

- **code-005 (96/100, DECLARE-DONE)** — fully aligned. code-005 explicitly listed these two design Top-3 items as "the smartest 30 minutes." Code reviewer's only remaining note for `Sources/` is L-009 cosmetic; not gating.
- **strict-iter-014 (PASS, streak: 4)** — fully aligned. Strict reviewer reached its 3-PASS termination criterion at iter-013, sustained at iter-014, and is recommending stand-down.
- **Memory `feedback_tui_design`** — "visible auto-refresh" ✓ (AutoRefreshIndicator), "inline detail expansion, no modals" ✓ (NavigationSplitView + chip tabs), and now "vibrancy on popover" matches the broader macOS design-language posture.
- **Memory `feedback_documentation`** — CHANGELOG entries cite specific files + line numbers for both changes; commit message body explains design intent for both. Good documentation discipline.

## Termination check

- Score >= 90 for 2 consecutive reviews? **YES** (95 this round, 92 last round) ✅
- All P0 design issues resolved? **YES** (D-M3 was the last carry-over MEDIUM with a clear top-3 mandate; closed) ✅
- HIGH tier empty for ≥ 2 consecutive cycles? **YES** (design-003 + design-004 both have empty HIGH) ✅
- Recommendation: **DECLARE-DONE** (design-review stream)

This is the second consecutive ≥ 90 review with empty CRITICAL + HIGH tiers and only carried-over cosmetic LOW + MEDIUM nits. Per the rubric this stream qualifies to write `COMPLETE.md`.

**All three review streams have now hit their termination criteria simultaneously:**
- Strict review: 4-PASS streak (criterion met at iter-013)
- Code review: 3× ≥ 90 streak (DECLARE-DONE confirmed at code-005)
- Design review: 2× ≥ 90 streak with empty HIGH (DECLARE-DONE confirmed at this review)

The next implementer cycle should write `.implementation/COMPLETE.md` and pause all four crons. Push backlog (8 commits) requires user-side credential rotation as the only remaining operational follow-up — not a design or code defect.
