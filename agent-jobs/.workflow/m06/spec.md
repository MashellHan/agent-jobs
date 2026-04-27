# M06 — Information Architecture

**Owner agent (SPEC):** pm
**Filed:** 2026-04-27
**Cycle:** 1
**Mode:** ui-critic ENFORCING (first milestone where visual P0 can REJECT to IMPLEMENTING)

## Goal (one paragraph)

Reshape the popover and dashboard so a user can identify, locate, and act on background services at a glance. Make the popover information-rich at a comfortable default width, and give the dashboard a default size + 3-pane layout that earns its real estate. Pre-requisite: fix the visual harness so dashboard rows + dark scheme actually render in `capture-all` output — without this, the M06 ui-critic gate is blind to half the surface area.

## Why now

M05 delivered content fidelity (friendly titles, CPU/RSS, diagnostics) but the geometry around that content is wrong: 360pt popover, ~900x600 dashboard, vertical-stripe bucket chips, blank `Table` body in critique screenshots. M07 (visual identity / icon) presumes a stable IA to apply tokens onto; if IA shifts in M07 we re-do the icon work. M06 locks the layout so M07 can paint it.

## In scope

Tickets:
- **T-014  P0  visual-harness** — Dashboard `Table` rows + dark scheme not rendering in `capture-all`. **GATING — first task.**
- **T-002  P0  popover** — ≥480pt wide; rich rows (program-friendly title primary, status pill, 1-line summary); group by status.
- **T-003  P0  dashboard-default-size** — ≥1280x800 default; sidebar 220 / inspector 360 / list gets the rest; list min-width 480 before inspector hides.
- **T-008  P1  empty-state** — 0-count chips: hover tooltip + subtle dimming.
- **T-015  P1  source-bucket-strip** — Vertical-stripe layout fix in `DashboardView`; horizontal pills matching popover treatment; "total N" on one line.
- **T-016  P2  popover-row** — Failed-status row exposes inline "Retry" affordance in trailing slot (or arrow → opens dashboard row; architect's call).

Carry-forward watch-list (from M05 retro):
- **WL-1  Visual ↔ design AC delineation.** Spec must mark each visual AC as either `tester` (pixel-diff vs. committed baseline) or `ui-critic` (rubric quality). Tester does not score quality; ui-critic does not run pixel diffs. See `acceptance.md`.
- **WL-2  `AgentJobsMacUI.swift` 530 LOC split.** Architect to assess in ARCHITECTING; if T-002 (rich rows) + T-008 (chip dimming/tooltip) push it past ~600 LOC, split into `MenuBarPopoverView.swift` + `MenuBarRowViews.swift` + `SourceBucketStrip.swift`. Spec includes this as a non-blocking AC.
- **WL-3  `ProviderDiagnostics` public surface.** Trim widened public API surfaced in M05 review nit; keep only what `MenuBarPopoverView` + chip-tooltip plumbing needs. Non-blocking AC.

## Out of scope (explicit)

- Custom menubar icon / running-count badge (T-001) — M07.
- Color tokens, typography scale, density modes — M07.
- Motion / micro-interactions (hover transitions, list reorder animations) — M11.
- New providers, hook migration, settings — later.
- Sessions / agent observability (T-009/010/011) — M10.
- T-013 hook ring-buffer — out.

## Capture-all scenario list (regenerate baselines)

Dashboard scenarios MUST be re-captured at the new default size and the rendering fix MUST land first.

| # | Name | Surface | Size | Scheme | Notes |
|---|---|---|---|---|---|
| 01 | menubar-popover-light | popover | 480 × auto | light | new ≥480pt width (T-002) |
| 02 | menubar-popover-dark | popover | 480 × auto | dark | parity |
| 03 | menubar-popover-empty-light | popover | 480 × auto | light | 0-count chip dimming + tooltip body in metadata (T-008) |
| 04 | dashboard-populated-light | dashboard | 1280 × 800 | light | NEW DEFAULT; ≥3 rendered rows; horizontal bucket strip (T-014/T-015) |
| 05 | dashboard-populated-dark | dashboard | 1280 × 800 | dark | full dark frame, no white bleed (T-014) |
| 06 | dashboard-empty-light | dashboard | 1280 × 800 | light | empty list copy + dimmed-zero chips |
| 07 | dashboard-inspector-light | dashboard | 1280 × 800 | light | row selected; sidebar 220 / list 700 / inspector 360 |
| 08 | dashboard-inspector-dark | dashboard | 1280 × 800 | dark | full inspector grid renders (T-014) |
| 09 | dashboard-narrow-light | dashboard | 1024 × 700 | light | inspector hides at list < 480; collapse correct |
| 10 | menubar-popover-with-failure-light | popover | 480 × auto | light | failed row shows Retry affordance (T-016) |

All 10 PNG+JSON pairs land in `.workflow/m06/screenshots/critique/`. Tester commits new baselines under `.workflow/m06/screenshots/baseline/` after T-014 lands.

## Risks / callouts

1. **T-014 is gating.** If T-014 isn't fixed first, every subsequent visual baseline captured during the milestone is suspect, and ui-critic enforcement on M06 is structurally meaningless. Architect MUST sequence T-014 as task #1.
2. **Popover width change ripples.** Going 360 → ≥480 changes wrapping for every row component; visual baselines for popover scenarios (01/02/03/10) will all redline — expected, not a regression.
3. **Dashboard default size change ripples.** All dashboard baselines redline. Expected. Tester regenerates after IMPL.
4. **3-pane geometry pressure on inspector.** Inspector at 360 is already the M05 design; verify it doesn't compress at min list-width. Add narrow scenario (09) to keep us honest.
5. **Status-grouped popover changes accessibility ordering.** VoiceOver ordering must remain top-to-bottom by status group — ARCHITECTING pass.
6. **WL-2 split is not free.** If architect splits `AgentJobsMacUI.swift` mid-milestone, diff churn balloons; treat as optional.

## Links

- `.workflow/DESIGN.md` — visual harness architecture
- `.workflow/DESIGN-TICKETS.md` — T-002 / T-003 / T-008 / T-014 / T-015 / T-016
- `.workflow/m05/ui-review.md` — origin of T-014/T-015/T-016
- `.workflow/m05/RELEASED.md` — starting code state
- `.workflow/m06/acceptance.md` — ACs (functional / visual / design)
- `.workflow/m06/competitive-analysis.md` — IA scan (Activity Monitor / Things 3 / Linear)
