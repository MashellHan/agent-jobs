# M07 — Visual Identity

**Owner agent (SPEC):** pm
**Filed:** 2026-04-27
**Cycle:** 1
**Mode:** ui-critic ENFORCING (M06+ standard; threshold 24/30)

## Goal (one paragraph)

Give the app a recognizable visual identity at the two surfaces a user actually sees: the 16pt menu-bar glyph and the 1024 system app icon. Pair the icon with a small, disciplined design-token layer (status palette, source colors, type scale, spacing) so future milestones paint on a stable substrate instead of magic numbers. Close T-001 (P0) plus the two P2 layout carry-forwards from M06 (T-019 Name column width, T-020 bucket-strip header alignment). Visual harness gains four new icon-variant scenarios and one token-swatch scenario so ui-critic can score the identity work against committed baselines, not vibes.

## Why now

M06 locked information architecture. With layout no longer churning, this is the right milestone to invest in identity — the icon, the color/type tokens, the spacing — before M08 starts moving functional code (hook migration) or M10 introduces a second top-level page (Sessions). If we ship M08 with placeholder visual identity, the Sessions page will need re-skinning later.

## In scope

### Primary tickets
- **T-001  P0  menu-bar-icon** — Custom `agent-jobs.icns` glyph that reads as "background services watcher" at 16pt; running-count badge variant (0 / N states). **GATING — first task.** Without this, AC-V-01..03 baselines are moot.
- **T-019  P2  dashboard-list** — Name column claims ≥30% of list pane width at 1280pt default; "Last Run" header reads in full; lower-priority columns demotable.
- **T-020  P2  dashboard-chrome** — Bucket-strip header either spans full window width OR sidebar "Filters" header band heightens to align with the strip's top edge. Architect picks one.

### New M07 design-token tickets (filed by this spec)
- **T-T01  P1  tokens-color** — Centralize status palette (`running` / `scheduled` / `failed` / `idle`) and source-bucket palette (`registered` / `claude-sched` / `claude-loop` / `launchd` / `live-proc`) as a single `DesignTokens.Color` namespace replacing scattered `Color(.systemX)` literals.
- **T-T02  P1  tokens-type** — Typography scale: `display` / `title` / `body` / `caption` / `mono`. SwiftUI `Font` extensions; replace ad-hoc `.font(.system(size: 13))` calls in popover + dashboard.
- **T-T03  P2  tokens-spacing** — Spacing scale: `xs / sm / md / lg / xl` (4 / 8 / 12 / 16 / 24). Apply to popover row internals + dashboard padding; do not boil the ocean — incremental adoption is fine.

### M06 watch-list cleanup (folded in, non-blocking)
- **WL-A** Rename `Snapshot.forceAppearance` → `forceDarkAppearance` OR add `assert(appearance.name == .darkAqua)` at the top. Reviewer cycle-2 F3.
- **WL-B** Capture-all skips JSON sidecar rewrite when PNG bytes match prior. Reviewer cycle-2 F4.
- **WL-C** Delete dead helpers in `MenuBarPopoverView` (`activeServices`, `upcomingServices`, `section(...)` from M05) and the latent `ServiceRowCompact.swift`. Reviewer F1, F5 from cycle-1.
- **WL-D** AC-F-15 sidecar schema delta: either rename impl fields (`scenarioName` → `scenario`, `metadata.viewportWidth/Height` → `width/height`, `colorScheme` → `scheme`, `appCommit` → `commit`) OR document the delta as the canonical schema in M07 spec. Architect picks; if rename, regen all 10 m06 sidecars + update tests.
- **WL-E** AC-V-06 menubar-icon flake — directly relevant since T-001 rewrites the menubar icon. Replace the flaky environmental assertion with a deterministic asset-catalog presence check + offscreen render of the template image.

## Out of scope (explicit cut)

- **Density modes (compact / comfortable).** ROADMAP M07 listed this; **deferred to M14 (Visual polish + accessibility)**. Rationale: density is most valuable when paired with Dynamic Type + VoiceOver work, which M14 already owns. Doing density now means a second sweep in M14 anyway. Keep M07 focused on identity primitives + the two P2 layout fixes; revisit if M14 finds it isn't enough lead time.
- Motion / micro-interactions (SF Symbol effects, hover transitions) — M11.
- New providers, hook migration, settings — later.
- Sessions / agent observability (T-009/T-010/T-011) — M10.
- T-013 hook ring-buffer — out.
- NavigationSplitView capture-path refactor (M06 watch-list item #3). No new pane structure planned in M07; the 4-stage dark fix in `Snapshot.swift` stays in place. Keep the 8-point luma sample standing per E003. Refactor only if recurrence is observed.

## Capture-all scenario list (regenerate baselines)

T-001 lands first; popover-1/2/3 menubar variants only become meaningful after the new asset catalog is wired. Tokens land after T-001 so swatch scenario reflects the canonical names.

| # | Name | Surface | Size | Scheme | Notes |
|---|---|---|---|---|---|
| 01 | menubar-icon-idle-light | menubar template | 22 × 22 (rendered at 16pt logical) | light | NEW. Idle glyph (no badge), light wallpaper sampler. T-001. |
| 02 | menubar-popover-light | popover | 480 × auto | light | regen after icon swap (popover header re-renders icon). |
| 03 | menubar-popover-dark | popover | 480 × auto | dark | parity. |
| 04 | menubar-popover-empty-light | popover | 480 × auto | light | unchanged from M06; regen for token-color drift. |
| 05 | dashboard-populated-light | dashboard | 1280 × 800 | light | T-019 Name column ≥30% applied; T-020 chrome alignment applied. |
| 06 | dashboard-populated-dark | dashboard | 1280 × 800 | dark | parity. |
| 07 | dashboard-empty-light | dashboard | 1280 × 800 | light | empty list copy + dimmed-zero chips with new tokens. |
| 08 | dashboard-inspector-light | dashboard | 1280 × 800 | light | row selected; verify type scale on inspector header / metadata grid. |
| 09 | dashboard-inspector-dark | dashboard | 1280 × 800 | dark | parity. |
| 10 | dashboard-narrow-light | dashboard | 1024 × 700 | light | inspector hides at list < 480; verify bucket-strip chrome (T-020) holds at narrow. |
| 11 | menubar-icon-count-1-light | menubar template | 22 × 22 | light | NEW. Single running task, badge variant. T-001. |
| 12 | menubar-icon-count-N-light | menubar template | 22 × 22 | light | NEW. N ≥ 9 (test 2-digit badge layout). T-001. |
| 13 | menubar-icon-idle-dark | menubar template | 22 × 22 | dark | NEW. Idle glyph against dark menubar. T-001. |
| 14 | tokens-swatches-light | composite swatch view | 800 × 600 | light | NEW. Renders the full palette + type-scale specimen + spacing-scale rule. Paired with `14-tokens-swatches-dark.png`? Architect's call — single light swatch is sufficient for this milestone. T-T01/T02/T03. |

All 14 PNG+JSON pairs land in `.workflow/m07/screenshots/critique/`. Tester commits new baselines under `.workflow/m07/screenshots/baseline/` after T-001 + tokens land.

Note: scenario count grows 10 → 14 (icon variants ×3 + tokens swatch ×1). M06 had 10. The 4 new scenarios are intentionally ≤2s additional capture wallclock budget per E001 (4 lightweight 22×22 captures + one 800×600 swatch ≈ 200ms total).

## Risks / callouts

1. **T-001 is gating.** Until the new asset catalog ships, popover scenarios re-render with the placeholder icon and any committed baseline becomes stale. Architect MUST sequence T-001 as task #1 (asset catalog + Image source + template-image plumbing).
2. **`.icns` master pipeline is one-time work.** Need a 1024 master + iconset compilation step (`iconutil` or AppIcon asset catalog with all required sizes). Document the source-of-truth (likely a single SVG / vector asset committed under `Resources/Identity/`). Do NOT check in only the rendered `.icns` without the source.
3. **Menubar template-image rules are strict.** macOS strips color from `isTemplate = true` images and tints by appearance. The glyph must be designed for that constraint (single-layer black-on-clear at 1x/2x/3x). Color comes only from the badge overlay, which is *not* a template — count-badge requires a separate compositing path.
4. **Count-badge legibility at 16pt.** A "9+" or "12" digit pair at 16pt is on the edge of native-app legibility (Stats and iStat Menus both use a chip with 1-2 digits maxed). Spec the contract: badge shows `count` for 1..9, `9+` for ≥10, hidden for 0. Document under T-001 done-when.
5. **Token rollout discipline.** Replacing every `Color(.systemX)` literal at once will produce a huge diff. Architect should scope T-T01/T02/T03 to the *visible* surfaces (popover row, dashboard chrome, inspector header) — not to every test fixture. Reviewer can confirm via `git diff --stat`.
6. **AC-V-06 was a known menubar-icon flake.** T-001 changes the icon entirely. Re-design AC-V-06 (now `AC-V-01` in the new numbering) to be a deterministic asset-catalog + template-render check, not a wallpaper-sampling visual diff. Resolves the M02-era flake.
7. **E003 holistic luma bake-in.** All AC wording for "full-frame X" / "no white bleed" must specify the named regions to sample (corners + sidebar interior + top header band + inspector header) and the minimum point count (≥8). Tester cannot regress to corner-only.
8. **Threshold stays at 24/30.** M06 PASS was 27/30. We do not raise the bar in M07 — identity work is risk-prone (subjective rubric on Identity axis especially), and we're folding in 7 watch-list items already.

## Links

- `.workflow/DESIGN.md` — visual harness architecture
- `.workflow/DESIGN-TICKETS.md` — T-001, T-019, T-020 (open); T-T01/T-T02/T-T03 (filed by this spec — to be appended)
- `.workflow/m06/RELEASED.md` — starting code state
- `.workflow/m06/retrospective.md` — watch-list items WL-A..E folded in here
- `.workflow/EVOLUTION.md` — E003 (proposed) holistic luma sampling — baked into AC verification language here
- `.workflow/m07/acceptance.md` — ACs (functional / visual / design)
- `.workflow/m07/competitive-analysis.md` — Stats / Bartender / iStat Menus icon strategy + .icns pipeline
