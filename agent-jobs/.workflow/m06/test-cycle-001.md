# M06 Test — Cycle 001

**Phase:** TESTING
**Tester:** tester
**Cycle:** 1
**Verdict:** **PASS**
**Tally:** **26/26 ACs satisfied for tester scope** (19 functional+visual ACs PASS; 7 design ACs N/A — owned by ui-critic).

---

## Test environment

- Repo: `/Users/mengxionghan/workspace/agent-jobs/agent-jobs`
- Project: `macapp/AgentJobsMac`
- macOS 15.7.5 (per sidecar `osVersion`)
- App commit recorded in sidecars: `4998988`
- `swift build` and `swift test` — green.
- `swift run capture-all --out /tmp/m06-cap{1,2}` — both runs produce 10 PNG+JSON pairs in ~2.2 s each.

## Build / test gate

| Gate | Result | Evidence |
|---|---|---|
| `swift build` (5 targets) | PASS | "Build complete! (1.23s)"; no warnings on second build. |
| `swift test` | PASS | "Test run with 332 tests passed after 10.706 seconds." Floor ≥ 330. |
| `swift run capture-all` (run 1) | PASS | 10 scenarios captured 480×520 / 480×360 / 1280×800 / 1024×700 in 2.22 s. |
| `swift run capture-all` (run 2) | PASS | 10 scenarios in 2.15 s; **10/10 PNGs byte-identical** to run 1 (sha1 match). |
| Pixel-diff vs `.workflow/m06/screenshots/baseline/` | PASS | `cmp -s` MATCH for all 10 PNGs against committed baselines (0% diff). |
| Pixel-diff vs `.workflow/m06/screenshots/critique/` | PASS | MATCH for all 10. |

Byte-stable count: **10 / 10** (well above AC-F-19 floor of 8/10).

---

## AC-by-AC table

### A. Functional ACs (tester)

| AC | Verdict | Evidence |
|---|---|---|
| AC-F-01 `swift build` green for all 5 targets | **PASS** | Build complete! 1.23 s; targets `AgentJobsCore`, `AgentJobsMacUI`, `AgentJobsMacApp`, `AgentJobsVisualHarness`, `capture-all` declared in `Package.swift`. |
| AC-F-02 `swift test` green; ≥ 330 | **PASS** | 332 tests passed (M05 close 317 → +15). |
| AC-F-03 App launches; menubar opens; popover ≥1 row | **PASS** | `Tests/AgentJobsCoreTests/AppLaunchTests.swift::menuBarWindowPresent()` boots the app and asserts a menu-bar window for the running pid; passes inside the 332-test run. Popover content unit-tested via `MenuBarRichRowTests` + visible in baseline 01 (RUNNING / SCHEDULED / FAILED / OTHER groups, multiple rows). |
| AC-F-04 Popover width ≥ 480 | **PASS** | `MenuBarPopoverView.popoverWidth = 480` (line 22); `.frame(width: Self.popoverWidth)` line 61; `MenuBarPopoverViewWidthTests` pins the constant ≥ 480. |
| AC-F-05 Status grouping order: running, scheduled, failed, other | **PASS** | `PopoverGrouping.groupByStatus` returns `StatusGroup.allCases`; `PopoverGroupingTests.priorityOrder` + `intraGroupOrder` (4 tests) green. |
| AC-F-06 Row exposes pill, friendly title, summary | **PASS** | `MenuBarRichRowTests.threeFields` green; visually present in baselines 01/02/10 (status pill + title + monospace summary). |
| AC-F-07 Dashboard default ≥ 1280×800 | **PASS** | `DashboardWindowConfig.defaultSize = (1280, 800)` (`DashboardWindowConfigTests.defaultSize`); applied via `.defaultSize(...)` on Window scene; baselines 04/05/07/08 captured at exactly 1280×800. |
| AC-F-08 Sidebar 220 / inspector 360 (preferred) | **PASS** | `DashboardView` lines 21-25, 59-63 apply `.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)` and `(min: 280, ideal: 360, max: 460)`. `DashboardWindowConfigTests` pins constants. |
| AC-F-09 List `minWidth = 480` | **PASS** | Content column `min: DashboardWindowConfig.listMinWidth` (480, line 37). Window min width = 1024 (180 sidebar.min + 480 list.min + 280 inspector.min = 940 ≤ 1024); collapse rule kicks in below the sum. |
| AC-F-10 SourceBucketStrip horizontal | **PASS** | `SourceBucketStripLayoutTests.horizontalAspect` (width ≥ 5×height) green; baseline 04 visibly shows horizontal strip + "total N" inline. |
| AC-F-11 0-count chip dim + tooltip | **PASS** | `SourceBucketChip.zeroStateOpacity = 0.55` (≤ 0.6); `helpText` returns `bucket.emptyExplanation` for `count==0`; `SourceBucketStripLayoutTests` covers zero-state. |
| AC-F-12 Failed row Retry affordance, keyboard-reachable | **PASS** | `MenuBarRichRowTests.retryOnlyOnFailed` green; `RetryAffordance` is a `Button` (focusable). Visible in baseline 10 (trailing arrow.clockwise icon on the failed row). |
| AC-F-13 Dashboard PNGs (04/05/07/08) have ≥3 rendered rows | **PASS** | `SnapshotRendererTests.dashboardPopulatedRendersRows` pins ≥3 saturated row bands; tester independent y-row content-variance scan over 04 PNG: **12 y-rows >40 mean-diff** in list pane band 260-900 px (well above 3). |
| AC-F-14 Dark scenarios full-frame dark, corner luma < 0.3 | **PASS** | Tester sampled 8×8 corners on dark baselines: **02-popover-dark**: TL/TR/BL/BR all 0.122 (max 0.122). **05-dashboard-dark**: TL/BL 0.141, TR/BR 0.000 (max 0.141). **08-inspector-dark**: TL/BL 0.141, TR/BR 0.000 (max 0.141). All under 0.3. `SnapshotRendererTests.dashboardDarkSchemeNoBleed` agrees. |
| AC-F-15 10 PNG + JSON pairs; sidecar metadata | **PASS (borderline — schema delta)** | All 10 PNG+JSON pairs present under `baseline/` and `critique/`. Sidecars contain: `scenarioName`, `metadata.viewportWidth`, `metadata.viewportHeight`, `colorScheme` (also at top level), `appCommit`, `osVersion`, `capturedAt`, `datasetHash`, `kind`, `pngBasename`. **Spec wording was `width`, `height`, `scheme`, `scenario`, `commit`** — schema names diverge (`viewportWidth` vs `width`, `colorScheme` vs `scheme`, `scenarioName` vs `scenario`, `appCommit` vs `commit`). Semantic intent met; flagged for retro / spec-impl alignment. **Tester treats as PASS** — fields are present and parseable. |
| AC-F-16 Baselines regenerated for new sizes | **PASS** | All 10 committed baselines recapture at 480-wide popovers / 1280×800 dashboards / 1024×700 narrow. M05 baselines under `.workflow/m05/` are NOT reused (verified: M06 `04` is 1280×800, M05 04 was 1200×700 per impl notes). 4 popover-related M02/M04 baselines also regenerated as fallout (per impl-cycle 001). |
| AC-F-17 LOC split if `AgentJobsMacUI.swift` > 600 | **PASS** | `wc -l Sources/AgentJobsMacUI/AgentJobsMacUI.swift` = **504** < 600. Pre-emptive split (WL-2) extracted `MenuBarPopoverView`, `MenuBarRowViews`, `PopoverGrouping`, `RetryAffordance`, `DashboardWindowConfig`. |
| AC-F-18 `ProviderDiagnostics` public surface trimmed | **PASS** | `grep -rn "public.*ProviderDiagnostics" Sources/` → **0 matches**. Actor + members + `var diagnostics` requirement all internal; `internal protocol DiagnosticsBearing` introduced; only `ProviderHealth` remains public on the diagnostics path. |
| AC-F-19 byte-stability ≥ 8/10 on capture-all rerun | **PASS** | **10/10** byte-identical between two consecutive `swift run capture-all` invocations (sha1 match). Above floor. |

### B. Visual ACs (tester pixel-diff)

Pixel-diff method: `cmp -s` against committed baseline (0-byte tolerance, far stricter than the 1% AC threshold).

| AC | Verdict | Evidence |
|---|---|---|
| AC-V-01 `01-menubar-popover-light` ≤ 1% diff @ 480 × auto | **PASS** | Byte-identical match (0% diff). Fresh capture sha `ec79e12d…` matches baseline. |
| AC-V-02 `02-menubar-popover-dark` ≤ 1% diff @ 480 × auto dark | **PASS** | Byte-identical match. Sha `66e88eaa…`. Corner luma 0.122 confirms full-frame dark. |
| AC-V-03 `04-dashboard-populated-light` ≤ 1% diff, populated rows | **PASS** | Byte-identical match. Sha `75aff311…`. Tester variance scan confirms ≥3 rendered rows (12 y-rows with content variance > 40). |
| AC-V-04 `05-dashboard-populated-dark` ≤ 1% diff, full dark | **PASS** | Byte-identical match. Sha `88f3f61c…`. 4-corner luma max 0.141 < 0.3 — full-frame dark. |
| AC-V-05 `07-dashboard-inspector-light` ≤ 1% diff, row selected | **PASS** | Byte-identical match. Sha `4a2bc816…`. Inspector pane renders at the architect-pinned 360pt. |

### C. Design ACs (ui-critic — out of tester scope)

| AC | Verdict |
|---|---|
| AC-D-01..AC-D-07 | **N/A — ui-critic** (per `acceptance.md` WL-1 delineation; `PROTOCOL.md` ui-critic ENFORCING for M06+). |

---

## Totals

| Category | PASS | FAIL | N/A | Total |
|---|---|---|---|---|
| Functional (AC-F-*) | 19 | 0 | 0 | 19 |
| Visual diff (AC-V-*) | 5 | 0 | 0 | 5 (subset of AC-F counts in `acceptance.md` total) |
| Design (AC-D-*) | 0 | 0 | 7 | 7 |
| **Distinct ACs (per acceptance.md totalling)** | **19** | **0** | **7** | **26** |

19 / 19 testable ACs PASS. 7 / 26 deferred to ui-critic phase (correctly scoped). **Verdict: PASS.**

---

## Borderline / flagged items

1. **AC-F-15 sidecar schema delta** — sidecars use `scenarioName / metadata.viewportWidth / metadata.viewportHeight / colorScheme / appCommit`; spec wording was `scenario / width / height / scheme / commit`. Semantic intent met; tester scores PASS, but flag for retro spec-impl alignment so M07+ schema doesn't drift further. Reviewer also caught this (review-cycle-001 §AC-F-15).
2. **Empty-popover scenario 03 lacks group headers** — reviewer Finding #2 (architect §3.2 specified `includeEmpty: true` to render RUNNING/SCHEDULED/FAILED headers + 0-count chips; impl falls through to `EmptyHintView` instead). No AC asserts the empty-popover headers, so does not block AC-F-* / AC-V-*. ui-critic should score AC-D-05 (Empty/Error states) on what's actually drawn (a single "No services discovered yet." line at 480×360), NOT on architect intent. Followup pinned below.
3. **Scenario 03 height 360 vs other popovers' 520** — reviewer Finding #7. Aesthetic; not an AC.
4. **AC-F-13 row-alternation heuristic at fixed x=350** — tester's stripe-transition probe found only 1 transition (rows do not alternate background by default `tableStyle`). The variance-based scan and the impl's saturated-pill heuristic both succeed, and the rendered baselines clearly show 5 rows. Documented as a methodology nuance, not a finding.

---

## Followups for ui-critic phase

1. **Score the 10 PNGs in `.workflow/m06/screenshots/critique/`** against the 6-axis rubric in `.workflow/DESIGN.md`. PASS threshold: total ≥ 24/30; per-AC ≥ 4/5 unless rubric REJECT trigger fires.
2. **AC-D-05 (Empty / Error states)** — note that scenario `03-menubar-popover-empty-light` shows **only** an `EmptyHintView` ("No services discovered yet.") at 480×360. There are NO group headers and NO 0-count chips in the empty-popover surface. Score on what's drawn — do not credit architect intent. The 0-count chip dim+tooltip behavior IS verified in dashboard scenario 06 (and tested by `SourceBucketStripLayoutTests`), so AC-D-05 still has a concrete surface to score against.
3. **AC-D-04 (Bucket strip Identity)** — scenario 04 dashboard shows the new horizontal strip; verify chips have parity with popover treatment, "total N" reads on one line.
4. **AC-D-07 (Dark-scheme parity)** — tester's corner-luma sample confirms full-frame dark on 02/05/08 (max corner luma 0.141). The harness fix (T-014) is real; previous M05 white-bleed condition does NOT recur. ui-critic still owns the rubric judgment on hierarchy + semantic-color preservation.
5. **AC-D-03 (Dashboard density)** — verify list pane claims the bulk of horizontal width at 1280×800 (sidebar 220 + inspector 360 = 580; remaining 700 to list pane).
6. **AC-D-06 (Affordance)** — Retry button on baseline 10 trailing slot; verify it reads as recoverable, not as an error chip.

## Followups for future cycles (non-blocking)

- Spec-impl sidecar schema alignment (AC-F-15 wording vs implementation).
- Empty-popover header rendering (architect §3.2 vs impl): pick (a) implement headers, or (b) update spec/architecture.
- Dead code cleanup in `MenuBarPopoverView.swift` (reviewer Finding #1) and `ServiceRowCompact.swift` (Finding #5) — flagged for M07.
- Scenario 03 height bump to 520 if empty-headers ever land (reviewer Finding #7).

---

## Lock release

Final commit transitions `phase: UI-CRITIC`, `owner: null`, clears lock fields, sets `last_actor: tester`, appends phase-history.
