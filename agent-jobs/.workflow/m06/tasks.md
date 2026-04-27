# M06 Tasks — Ordered

> Each task: scope, files touched, verification.
> **T-014 (Task 1) is gating** — no other visual baseline is trustworthy until it lands.
> Implementer commits after each task; reviewer/tester gates run only at end of IMPL.

---

## Task 1 — T-014: Fix `Snapshot.capture` rendering (BLOCKING, FIRST)

**Why first.** Per spec + CURRENT.md: every visual baseline produced before this fix is a lie. M06 ui-critic enforcement is structurally meaningless until the harness honestly renders dashboard rows + dark scheme.

**Scope.**
- Patch `Snapshot.capture` to host the `NSHostingView` inside a borderless `NSWindow` so AppKit promotes the hosting context (NSTableView realizes rows; window's `effectiveAppearance` propagates to SwiftUI material/background).
- Apply `appearance` to the `NSWindow`, not just the `NSHostingView`.
- Add a second short run-loop tick (0.05s) after the first `layoutSubtreeIfNeeded()` so delayed `Table`/`NSTableView` row realization completes before bitmap cache.
- Add unit-tests that PROVE rows are rendered and dark frame has no white bleed.

**Files touched.**
- `macapp/AgentJobsMac/Sources/AgentJobsVisualHarness/Snapshot.swift` (edit `capture(_:size:appearance:)`).
- `macapp/AgentJobsMac/Tests/AgentJobsMacUITests/Visual/SnapshotRendererTests.swift` (NEW).

**Verification.**
- `swift build` green.
- `swift test --filter SnapshotRendererTests` passes (≥3 row bands detected; 4-corner luminance < 0.3 on dark).
- Manual: `swift run capture-all --out /tmp/m06-t14-check/`. Open `04-dashboard-populated-light.png` — Table body must show ≥3 rows. Open `05-dashboard-populated-dark.png` — full-frame dark, no white bleed.
- Acceptance ACs covered: AC-F-13, AC-F-14.

---

## Task 2 — WL-2: Split `AgentJobsMacUI.swift` (no-behavior-change)

**Why second.** Pre-commit decision (architecture §3.7): split BEFORE adding popover code so the move shows up as a clean rename diff. Splitting after T-002 conflates "move + rewrite" and is unreviewable.

**Scope.**
- Move `MenuBarPopoverView` (currently in `Features/MenuBar/MenuBarViews.swift`) → new file `Features/MenuBar/MenuBarPopoverView.swift`. Verbatim move; zero behavior change.
- DELETE `Features/MenuBar/MenuBarViews.swift` after move (it only contained `MenuBarPopoverView`; if it has anything else, leave only the non-popover bits — at the time of writing it has only the popover view).
- Pre-create empty stubs `Features/MenuBar/MenuBarRowViews.swift`, `Features/MenuBar/PopoverGrouping.swift`, `Components/RetryAffordance.swift`, `Features/Dashboard/DashboardWindowConfig.swift` — files exist but only with import header + `// stub: filled by Task N`. Reduces noise in later commits.

**Files touched.**
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarViews.swift` (DELETE).
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift` (NEW — move target).
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarRowViews.swift` (NEW stub).
- `Sources/AgentJobsMacUI/Features/MenuBar/PopoverGrouping.swift` (NEW stub).
- `Sources/AgentJobsMacUI/Components/RetryAffordance.swift` (NEW stub).
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardWindowConfig.swift` (NEW stub).

**Verification.**
- `swift build` green.
- `swift test` passes with no test-count change (move-only).
- `git diff` shows pure relocate of `MenuBarPopoverView`. Reviewer can verify by `git log --follow` on the new path.
- Acceptance ACs covered (preliminary toward): AC-F-17 (split is in place; will tally LOC after IMPL).

---

## Task 3 — T-003: Dashboard default size + 3-pane sizing

**Scope.**
- Fill `DashboardWindowConfig.swift` with constants per architecture §2.3.
- In `AgentJobsAppScene` (`AgentJobsMacUI.swift`), change dashboard `Window` to: `.frame(minWidth: 1024, minHeight: 700)`, append `.defaultSize(CGSize(width: 1280, height: 800))` and `.windowResizability(.contentMinSize)` to the Scene.
- In `DashboardView.body`, attach `.navigationSplitViewColumnWidth(...)` modifiers to sidebar / content / detail per architecture §3.3.
- Update `HarnessScenes.dashboard(...)` default `size` parameter from 1200×700 → 1280×800.
- Update `Sources/CaptureAll/Scenarios.swift`: scenarios 04, 05, 06, 07, 08 → 1280×800; scenario 09 → 1024×700.

**Files touched.**
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardWindowConfig.swift`.
- `Sources/AgentJobsMacUI/AgentJobsMacUI.swift`.
- `Sources/AgentJobsMacUI/Features/Dashboard/DashboardView.swift`.
- `Sources/CaptureAll/Scenarios.swift`.
- `Tests/AgentJobsMacUITests/DashboardWindowConfigTests.swift` (NEW).

**Verification.**
- `swift build` green.
- New `DashboardWindowConfigTests` passes (constants pinned).
- `swift run capture-all --out /tmp/m06-t3-check/` produces dashboard PNGs at 1280×800 (verify via JSON sidecars).
- Acceptance ACs covered: AC-F-07, AC-F-08, AC-F-09, AC-F-15 (size metadata).

---

## Task 4 — T-015 + T-008: Bucket strip horizontal layout + 0-count chip dimming/tooltip

**Scope.**
- `SourceBucketChip.swift`: add `.fixedSize(horizontal: true, vertical: false)` on the chip's inner HStack; add `.opacity(0.55)` when `count == 0 && !isSelected`; extend `helpText` with bucket-specific zero-state copy via private `ServiceSource.Bucket.emptyExplanation`.
- `SourceBucketStrip.swift`: wrap the chips HStack in `ScrollView(.horizontal, showsIndicators: false) { … }` so narrow widths don't collapse chips.
- (Defensive) `SummaryChip.swift`: same `.fixedSize` invariant.

**Files touched.**
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketChip.swift`.
- `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketStrip.swift`.
- `Sources/AgentJobsMacUI/Components/SummaryChip.swift`.
- `Tests/AgentJobsMacUITests/SourceBucketChipTests.swift` (extend or NEW for zeroState).
- `Tests/AgentJobsMacUITests/SourceBucketStripLayoutTests.swift` (NEW: snapshot strip alone, assert horizontal aspect ratio).

**Verification.**
- `swift build` green.
- New tests pass.
- Visual smoke: render `06-dashboard-empty-light` via `swift run capture-all`; PNG shows 5 chips horizontally with dimmed appearance for 0-count buckets; "total 0" reads on one line.
- Acceptance ACs covered: AC-F-10, AC-F-11.

---

## Task 5 — T-002 + T-016: Popover width 480 + grouped rich rows + Retry affordance

**Scope.**
- Fill `PopoverGrouping.swift` with `enum PopoverGrouping { enum StatusGroup { running, scheduled, failed, other }; static func groupByStatus(_:includeEmpty:) -> [(StatusGroup, [Service])] }` per architecture §2.1.
- Fill `MenuBarRowViews.swift` with: `struct MenuBarRichRow: View` (status pill + title + summary + conditional trailing slot), `struct PopoverGroupHeader: View` (uppercase caption + count chip).
- Fill `RetryAffordance.swift` per architecture §2.4.
- Rewrite `MenuBarPopoverView.body`: replace the two hardcoded sections (`Active Now`, `Scheduled Soon`) with a `ForEach` over `PopoverGrouping.groupByStatus(...)`. Move `.frame(width: 480)` from `AgentJobsAppScene.MenuBarExtra` content closure into `MenuBarPopoverView` itself (and remove the 360 frame from `AgentJobsAppScene`).
- In each rendered row, set `onRetry` only when `service.status == .failed`; closure invokes `Task { await registry.refresh() }`.

**Files touched.**
- `Sources/AgentJobsMacUI/Features/MenuBar/PopoverGrouping.swift`.
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarRowViews.swift`.
- `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift`.
- `Sources/AgentJobsMacUI/Components/RetryAffordance.swift`.
- `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` (drop the 360-width frame from MenuBarExtra).
- `Tests/AgentJobsMacUITests/PopoverGroupingTests.swift` (NEW).
- `Tests/AgentJobsMacUITests/MenuBarRichRowTests.swift` (NEW).
- `Tests/AgentJobsMacUITests/MenuBarPopoverViewTests.swift` (extend for width assertion).

**Verification.**
- `swift build` green.
- New tests pass (status group order; rich-row 3-field render; retry-only-on-failed).
- Visual smoke: `swift run capture-all` produces popover PNGs at 480pt with section headers visible (`RUNNING`, `SCHEDULED`, …) and a Retry button in scenario 10.
- Acceptance ACs covered: AC-F-04, AC-F-05, AC-F-06, AC-F-12.

---

## Task 6 — Update capture-all popover scenarios to 480pt

**Scope.**
- `Sources/CaptureAll/Scenarios.swift`: scenarios 01, 02, 03, 10 → width 480 (height stays 520 / 360 / 520 — auto-grow under content).
- Confirm `HarnessScenes.menuBarPopover(...)` default width parameter is no longer applied (popover view owns its own frame); update default to `480` for callers that pass nothing.

**Files touched.**
- `Sources/CaptureAll/Scenarios.swift`.
- `Sources/AgentJobsMacUI/AgentJobsMacUI.swift` (`HarnessScenes.menuBarPopover` default width 360 → 480).

**Verification.**
- `swift run capture-all --out .workflow/m06/screenshots/critique/` produces 10 PNG + 10 JSON pairs. JSON sidecars show new sizes.
- Acceptance ACs covered: AC-F-15.

---

## Task 7 — WL-3 / AC-F-18: Trim `ProviderDiagnostics` public surface

**Scope.**
- In `Sources/AgentJobsCore/Discovery/ServiceProvider.swift`:
  - Move the `var diagnostics: ProviderDiagnostics? { get }` requirement OUT of `public protocol ServiceProvider` into a new `internal protocol DiagnosticsBearing { var diagnostics: ProviderDiagnostics? { get } }`.
  - Change `public actor ProviderDiagnostics` → `internal actor ProviderDiagnostics`. Demote its members (`public private(set) var lastError`, etc.) to `internal private(set)`.
- In each concrete provider (`ClaudeScheduledTasksProvider`, `ClaudeSessionCronProvider`):
  - Demote `public let diagnostics: ProviderDiagnostics?` → `let diagnostics: ProviderDiagnostics?` (default access, internal).
  - Add `: ServiceProvider, DiagnosticsBearing` conformance.
- `ServiceRegistry.discoverAllDetailed()` already builds `ProviderHealth`; if it consumes `provider.diagnostics` it now does so via the internal `DiagnosticsBearing` cast. Verify code path.
- The default `extension ServiceProvider { var diagnostics: ProviderDiagnostics? { nil } }` moves to `extension DiagnosticsBearing where Self: ServiceProvider`.

**Files touched.**
- `Sources/AgentJobsCore/Discovery/ServiceProvider.swift`.
- `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift`.
- `Sources/AgentJobsCore/Discovery/Providers/ClaudeScheduledTasksProvider.swift`.
- `Sources/AgentJobsCore/Discovery/Providers/ClaudeSessionCronProvider.swift`.

**Verification.**
- `swift build` green for ALL 5 targets (regression risk: `AgentJobsMacUI` could be importing the symbol — search confirms it does not).
- `swift test` green; existing `ProviderDiagnosticsTests` continues to pass (same module, internal access fine).
- `nm`/`swift symbolgraph` diff vs. M05: `ProviderDiagnostics` no longer exported.
- Acceptance ACs covered: AC-F-18.

---

## Task 8 — Regenerate visual baselines

**Scope.**
- Run `swift run capture-all --out .workflow/m06/screenshots/critique/`. Inspect every PNG against the spec scenario list (size + scheme).
- Copy critique → `baseline/`: `cp .workflow/m06/screenshots/critique/*.png .workflow/m06/screenshots/baseline/` (or whatever script the test target uses; reuse M05 conventions).
- Commit baselines.

**Files touched.**
- `.workflow/m06/screenshots/critique/01..10.{png,json}` (regenerate).
- `.workflow/m06/screenshots/baseline/01..10.{png,json}` (commit-fresh — DO NOT carry M05 baselines).

**Verification.**
- All 10 PNGs present.
- JSON sidecars carry correct width/height/scheme for each scenario.
- `swift run capture-all` re-run produces byte-stable output for ≥8/10 scenarios (AC-F-19; allow up to 2 known-flaky environmental scenarios).
- Acceptance ACs covered: AC-F-15, AC-F-16, AC-F-19.

---

## Task 9 — Final pass: tests count + LOC audit + impl-cycle notes

**Scope.**
- Confirm total `swift test` count ≥ 330 (M05 ended at 317; M06 adds ≥13 — 14 expected).
- Re-measure LOC of `AgentJobsMacUI.swift` and any candidate file. Confirm AC-F-17 (split happened; file under 600 LOC).
- Write `.workflow/m06/impl-cycle-001.md` recording: tasks done, baselines regenerated, surface-trim diff summary, any deviations from architecture.

**Files touched.**
- `.workflow/m06/impl-cycle-001.md` (NEW).

**Verification.**
- `swift build` green for 5 targets.
- `swift test` green; count ≥ 330.
- `wc -l Sources/AgentJobsMacUI/AgentJobsMacUI.swift` < 600.
- Acceptance ACs covered: AC-F-01, AC-F-02, AC-F-17.

---

## Sequencing rationale (one-page)

| # | Task | Why this slot |
|---|---|---|
| 1 | T-014 (renderer fix) | Spec + CURRENT.md mandate. All baselines depend on it. |
| 2 | WL-2 split | Move-only diff is cleanest BEFORE T-002 rewrite. |
| 3 | T-003 (dashboard size) | Independent of popover work; makes dashboard scenarios meaningful early so renderer can be sanity-checked at real sizes. |
| 4 | T-015 + T-008 (strip) | Touches files no other task touches; lowers merge friction for Task 5. |
| 5 | T-002 + T-016 (popover) | Largest behavior change; lands on top of stable bases. |
| 6 | Popover scenario sizes | Mechanical; gated on Task 5 landing. |
| 7 | WL-3 surface trim | Pure refactor in `AgentJobsCore`; isolated. Done late so it doesn't churn test fixtures during UI work. |
| 8 | Baseline regeneration | Must be last UI-affecting step. |
| 9 | Final audit | Closes AC-F-01/02/17. |

**Reviewer expectation.** Each task should commit cleanly. If a task fails its verification step, fix in-task — do not roll forward.
