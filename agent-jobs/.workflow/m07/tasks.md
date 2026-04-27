# M07 Tasks

**Owner agent:** architect → implementer
**Filed:** 2026-04-27
**Cycle:** 1
**Inputs:** `m07/architecture.md`, `m07/spec.md`, `m07/acceptance.md`.

> Five tasks, ordered. Task 1 is gating (per spec §"Risks" #1 — without the
> asset catalog every popover/dashboard baseline is stale). Tasks 2-3 establish
> the token substrate. Task 4 extends capture-all to capture the new identity.
> Task 5 folds in the M06 watch-list. Each task ends with a `swift build &&
> swift test` checkpoint and a single commit.

---

## Task 1 — Asset catalog + .icns master pipeline (T-001 P0, GATING)

**Files created:**
- `Sources/AgentJobsMacApp/Resources/Assets.xcassets/Contents.json`
- `Sources/AgentJobsMacApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `Sources/AgentJobsMacApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_{16,32,128,256,512}{,@2x}.png` (10 PNGs)
- `Sources/AgentJobsMacApp/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json`
- `Sources/AgentJobsMacApp/Resources/Assets.xcassets/MenuBarIcon.imageset/menubar-glyph{,@2x,@3x}.png` (3 PNGs)
- `Sources/AgentJobsMacApp/Resources/Identity/menubar-glyph.svg`
- `Sources/AgentJobsMacApp/Resources/Identity/app-icon.svg`
- `Sources/AgentJobsMacApp/Resources/Identity/README.md`
- `scripts/build-icns.sh` (executable)

**Files edited:**
- `Package.swift` — add `.process("Resources")` to the `AgentJobsMacApp` target's `resources:` list (or `[.copy("Resources/Assets.xcassets"), .copy("Resources/Identity")]` if `.process` misbehaves on `.svg`).
- `Sources/AgentJobsMacUI/Components/MenuBarLabel.swift` — swap SF Symbol for `Image("MenuBarIcon", bundle: .main).renderingMode(.template)`; add private `BadgeOverlay` struct with three branches (0 / 1..9 / "9+").

**Tests added:** (in `Tests/AgentJobsCoreTests/Visual/MenuBarIconAssetTests.swift`, new file)
- `MenuBarIconAssetTests.testAppIconAssetPresent` (AC-F-04, AC-F-05)
- `MenuBarIconAssetTests.testMenuBarIconAssetIsTemplate` (AC-F-04, AC-F-06)
- `BadgeOverlayTests.testZeroCountRendersNothing` (AC-F-07)
- `BadgeOverlayTests.testSingleDigitRendersLiteral` (AC-F-07)
- `BadgeOverlayTests.testTenPlusRendersNinePlus` (AC-F-07)

**Acceptance gates closed:** AC-F-04, AC-F-05, AC-F-06, AC-F-07.

**Done-when checkpoint:** `swift build && swift test` green; `bash scripts/build-icns.sh` runs idempotently (re-running produces no `git diff`).

**Commit:** `feat(M07): T-001 — asset catalog, custom menubar template glyph, count badge`

---

## Task 2 — Design-token namespace (T-T01 + T-T02 + T-T03)

**Files created:**
- `Sources/AgentJobsCore/Design/Tokens.swift` — `DesignTokens.SemanticColor`, `DesignTokens.SourceColor`, additive entries to existing `Typography` (`display`) and `Spacing` (`sm`, `md`, `lg` aliases).
- `Sources/AgentJobsCore/Design/AssetColor.swift` — `enum AssetColor { static func color(_ name: String, bundle: Bundle = .module) -> Color }` with system-color fallback.
- `Sources/AgentJobsCore/Resources/Assets.xcassets/Contents.json`
- `Sources/AgentJobsCore/Resources/Assets.xcassets/{StatusRunning,StatusScheduled,StatusFailed,StatusIdle}.colorset/Contents.json` (4 status color sets, each with light + dark appearance variants)
- `Sources/AgentJobsCore/Resources/Assets.xcassets/{SourceRegistered,SourceClaudeSched,SourceClaudeLoop,SourceLaunchd,SourceLiveProc}.colorset/Contents.json` (5 source color sets)

**Files edited:**
- `Package.swift` — add `resources: [.process("Resources")]` to the `AgentJobsCore` target.
- `Sources/AgentJobsCore/Design/DesignTokens.swift` — `StatusColor.running` etc. forward to `SemanticColor.statusRunning`; mark the old surface `@available(*, deprecated, renamed: ...)`.

**Tests added:** (in `Tests/AgentJobsCoreTests/Design/TokensTests.swift`, new file)
- `TokensTests.testSemanticColorNamespaceShape` — asserts all 4 status-color names resolve and produce non-clear `Color` (AC-F-08).
- `TokensTests.testSourceColorNamespaceShape` — asserts all 5 source-color names resolve (AC-F-08).
- `TokensTests.testTypographyNamespaceShape` — asserts all 5 font tokens (`display/title/body/caption/mono`) exist (AC-F-09).
- `TokensTests.testSpacingNamespaceShape` — asserts all 5 spacing tokens (`xs/sm/md/lg/xl`) map to (4/8/12/16/24) (AC-F-10).

**Acceptance gates closed:** AC-F-08, AC-F-09, AC-F-10 (namespace shape only; wiring AC closed in Task 3).

**Done-when checkpoint:** `swift build && swift test` green; new namespaces resolve from both `AgentJobsCore` (tests) and `AgentJobsMacApp` (compiles).

**Commit:** `feat(M07): T-T01..T03 — design-token namespaces (color/typography/spacing) backed by asset-catalog color sets`

---

## Task 3 — Wire tokens into visible surfaces + close T-019 + T-020

**Files edited:**
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarRowViews.swift` — popover row primary title font → `DesignTokens.Typography.body`; status pill → `DesignTokens.SemanticColor.status<X>`.
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift` —
  - **T-019**: Name column gets `.width(min: 210, ideal: 280)`; "Last Run" column gets `min:` width sized for full header text.
  - **T-020**: SidebarFiltersHeader band heightens with `.frame(minHeight: 40)` so its top edge aligns with the bucket-strip's top edge (architect chose option (b) per architecture §1.3).
  - Inspector header font → `DesignTokens.Typography.title`; metadata grid labels → `DesignTokens.Typography.caption`; padding magic numbers → `DesignTokens.Spacing.sm/md/lg`.
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketChip.swift` — chip background → `DesignTokens.SourceColor.<bucket>`.
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketStrip.swift` — strip total label → `DesignTokens.Typography.caption`.
- `Sources/AgentJobsMacUI/Components/StatusBadge.swift` — color literals → `DesignTokens.SemanticColor.status<X>`.

**Tests added:**
- `Tests/AgentJobsCoreTests/Layout/NameColumnWidthTests.swift` — at 1280×800 with default split widths (220 / 360), asserts list pane = 700pt and Name column min ≥ 210pt (AC-F-11).
- `Tests/AgentJobsCoreTests/Layout/BucketStripChromeAlignmentTests.swift` — snapshot (or render-tree) assertion: sidebar `Filters` header top edge and bucket-strip top edge differ by ≤ 2pt (AC-F-12).
- `Tests/AgentJobsCoreTests/Design/TokenAdoptionTests.swift` — `grep`-style source scan asserting `DesignTokens.SemanticColor` is referenced in ≥3 visible-surface files (AC-F-09 adoption clause).

**Acceptance gates closed:** AC-F-11, AC-F-12, AC-F-09 (adoption), AC-F-08 (adoption), AC-F-10 (adoption).

**Done-when checkpoint:** `swift build && swift test` green; visual smoke (manual `swift run AgentJobsMacApp`) shows new colors in popover + dashboard.

**Commit:** `feat(M07): T-019/T-020 + token wiring — Name col ≥30%, sidebar header aligns bucket strip, tokens applied to popover/dashboard/inspector`

---

## Task 4 — capture-all extension: 4 new scenarios + tokens swatch

**Files created:**
- `Sources/AgentJobsMacUI/Features/Tokens/TokensSwatchView.swift` — `internal struct TokensSwatchView: View` rendering 9-color swatch grid + 5-row type-scale specimen + 5-step spacing ruler at 800×600.

**Files edited:**
- `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` — extend `HarnessScenes` with `IconState` enum and two new factories: `menuBarIconOnly(state:)`, `tokensSwatch(size:)`.
- `Sources/CaptureAll/Scenarios.swift` —
  - Renumber existing scenarios per architecture §3.1 (old 01 popover-light → new 02; old 04 dashboard-populated-light → new 05; etc.).
  - Drop old `10-menubar-popover-with-failure-light` (failure variant covered implicitly by populated scenarios).
  - Add 4 new scenario rows (11/12/13/14) per architecture §3.1 table.

**Tests added:**
- `Tests/AgentJobsCoreTests/Visual/SwatchSnapshotTests.swift` — renders `TokensSwatchView` at 800×600 and asserts non-empty render (≥1 distinct color in the grid region).
- `Tests/AgentJobsCoreTests/Visual/MenuBarIconScenarioTests.swift` — renders scenarios 01/11/12/13 and asserts: scenario 01 central 8×8 luma < 0.2 (light bg, dark glyph); scenario 13 central 8×8 luma > 0.7 (dark bg, light glyph); scenario 12 badge bbox contains "9+" with non-zero pixel coverage.

**Acceptance gates closed:** AC-F-18 (scenario count = 14); supports AC-V-01..04 (visual diff still owned by tester via committed baselines, regen happens during TESTING).

**Done-when checkpoint:** `swift build && swift test` green; `swift run capture-all --out /tmp/m07-cap` emits exactly 14 PNG + 14 JSON pairs.

**Commit:** `feat(M07): capture-all — 4 menubar-icon scenarios + tokens swatch (14 total)`

---

## Task 5 — Watch-list cleanup (WL-A through WL-E)

**Files edited:**
- `Sources/AgentJobsVisualHarness/Snapshot.swift` — **WL-A**: rename `forceAppearance(_:on:)` → `forceDarkAppearance(_:on:)`; insert `precondition(appearance?.name == .darkAqua, "forceDarkAppearance is dark-only")` at function entry. Update the call site (line 143) accordingly.
- `Sources/CaptureAll/main.swift` — **WL-B**: before writing PNG, read existing bytes at `pngURL` if present; if equal to fresh `Data` returned from `Snapshot.write`, skip both PNG + sidecar writes. Print `"unchanged: <name>"` instead of `"captured: <name>"`. (Note: needs minor refactor — call `Snapshot.capture` to get Data first, then conditionally `Snapshot.write` or just `data.write(to:)`.)
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift` — **WL-C**: delete `activeServices` (line 166), `upcomingServices` (line 170), `section(title:services:emptyMessage:)` (line 178). Confirm no remaining callers via `grep`.
- `Sources/AgentJobsMacUI/Components/ServiceRowCompact.swift` — **WL-C**: **DELETE** the entire file. Confirm no references via `grep ServiceRowCompact Sources/`.
- `.workflow/DESIGN.md` — **WL-D**: append a single line under §"Public CLI" canonicalizing the impl-side sidecar schema (`scenarioName`, `appCommit`, `colorScheme`, `viewportWidth/Height` are the spec-blessed names; spec-side `scenario`/`commit`/`scheme`/`width`/`height` were proposal-only and are NOT adopted).

**Files created:**
- `Tests/AgentJobsCoreTests/Visual/MenuBarIconAssetTests.swift` — already created in Task 1, but Task 5 adds **WL-E**: `testMenuBarIconRendersDarkOnDarkMenubar` — load `MenuBarIcon` from bundle, render at 22×22 dark, assert central 8×8 luma > 0.7 (AC-F-17).

**Files deleted (or rewritten):**
- Whatever existing test in `Tests/AgentJobsCoreTests/Visual/` performs the M02-era wallpaper-sampling check (search for `wallpaper` or `AC-V-06` in test names). Delete or rewrite to call the new deterministic asset-catalog check.

**Tests added:**
- `Tests/AgentJobsCoreTests/Visual/SnapshotForceDarkAppearanceTests.swift` — calls `Snapshot.forceDarkAppearance` with `.aqua` and asserts trap (using `withCheckedContinuation` + `Task` + `signal` trap pattern, OR — simpler — wraps in `#if DEBUG` and confirms `precondition` fires under debug build) (AC-F-13).
- `Tests/AgentJobsCoreTests/Visual/CaptureAllByteStableTests.swift` — runs `capture-all` twice via `Process()`, sha256 each output, asserts ≥ 12/14 byte-identical (AC-F-14).
- `Tests/AgentJobsCoreTests/Hygiene/DeadCodeTests.swift` — `grep`-asserts `activeServices`, `upcomingServices`, `ServiceRowCompact` produce 0 matches in `Sources/` (AC-F-15).
- `Tests/AgentJobsCoreTests/Hygiene/SidecarSchemaDocTests.swift` — reads `.workflow/DESIGN.md` and asserts the canonical-schema sentence appended (AC-F-16).

**Acceptance gates closed:** AC-F-13 (WL-A), AC-F-14 (WL-B), AC-F-15 (WL-C), AC-F-16 (WL-D), AC-F-17 (WL-E).

**Done-when checkpoint:** `swift build && swift test` green; `grep` for deleted symbols returns 0; running `swift run capture-all` twice in a row prints `"unchanged: ..."` for the second run on every scenario.

**Commit:** `chore(M07): WL-A..E — rename forceDarkAppearance, byte-stable sidecars, dead-code purge, sidecar schema doc, deterministic menubar-icon asset test`

---

## Out-of-task (tester's responsibility, NOT the implementer's)

- Regenerate `.workflow/m07/screenshots/critique/` (14 PNG + 14 JSON pairs) **once** after Task 5 lands.
- Commit those into `.workflow/m07/screenshots/baseline/` as the M07 baselines.
- Run AC-V-01..06 pixel-diff assertions; record in `m07/test-cycle-NNN.md`.
- Run E003 holistic luma sample (≥8 points across corners + sidebar + top header band + inspector header) on AC-V-05 and AC-V-06 dark scenarios.

Implementer must NOT regenerate baselines mid-cycle (per architecture §6 risk #5).

---

## Risk on cycle-2 re-entry

If review or test rejects, the most likely back-to-IMPL trigger is the SVG glyph
itself failing AC-D-01 (rubric REJECT — glyph reads as generic). Per architecture
§7, implementer is permitted to ship a placeholder SVG in cycle 1; cycle-2 lands
the real glyph. No re-architecture needed.
