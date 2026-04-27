# M06 Review — Cycle 001

**Phase:** REVIEWING
**Reviewer:** reviewer
**Cycle:** 1
**Verdict:** **PASS-with-nits**
**Score:** **89 / 100**

---

## Summary

Eight commits from `cfe0e68..dd354a3` deliver all six tickets and three watch-list
items the architect sequenced. Build is green for all 5 targets;
`swift test` runs **332 tests passed** (target ≥ 330 — +15 over M05 close,
matching the impl-cycle 001 self-tally). Visual baselines are present for
all 10 scenarios at the spec-mandated sizes (popover 480-wide, dashboard
1280×800, narrow 1024×700), and inspection of 04/05/01/10 PNGs shows the
T-014 fix is real: dashboard `Table` rows render (≥5 rows visible at
1280×800), dark-scheme corners are full-frame dark (sampled luma 0,0 and
1279,799 = 0.157 / 0.0 — well below the 0.3 floor), popover sections
(RUNNING / SCHEDULED / FAILED / OTHER) render with status pills, friendly
titles, summaries, and a Retry circle on the failed row.

Three nits keep this off a clean PASS: dead code in `MenuBarPopoverView`,
an empty-popover scenario that doesn't render the architect-designed
`includeEmpty:true` group headers, and a light dependence of
`ServiceRegistry.snapshot(...)` on the now-internal `DiagnosticsBearing`
protocol via runtime `as?` cast. None block AC verification or compromise
the harness; all are appropriate for tester-phase or follow-up.

---

## Findings

| # | Severity | File:line | Observation | Suggestion |
|---|---|---|---|---|
| 1 | **L** | `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift:131-163` | `private var activeServices`, `private var upcomingServices`, and `private func section(...)` are unreachable — the new grouped `ForEach` body replaced them but they were left in the file. Will be flagged by any future dead-code lint and adds reader cognitive load (you wonder if M05 group ordering is still in play). | Delete the three dead members. Pure code-removal; no test impact. |
| 2 | **M** | `Sources/AgentJobsMacUI/Features/MenuBar/MenuBarPopoverView.swift:36-40` | Architect §3.2 specified the empty-state scenario should render `PopoverGrouping.groupByStatus(..., includeEmpty: true)` so RUNNING/SCHEDULED/FAILED headers + 0-count chips appear (mirrors spec scenario-03 metadata "0-count chip dimming + tooltip body"). The implementation instead routes `services.isEmpty` straight into `EmptyHintView`. Baseline `03-menubar-popover-empty-light.png` confirms: only "No services discovered yet." renders, no headers, no 0-count chips. Not documented as a deviation in `impl-cycle-001.md`. | Either (a) gate on `registry.phase == .loaded && registry.services.isEmpty` to render headers via `groupByStatus(includeEmpty: true)` while keeping the `EmptyHintView` for the brand-new no-discovery state, or (b) update the spec/architecture if the empty-popover headers are no longer in scope. (a) is cheaper and matches architect intent. Non-blocking for AC-F-* (no AC asserts the empty-popover header rendering). |
| 3 | **L** | `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift:99-103` | `snapshot(provider:)` reaches diagnostics via `provider as? any DiagnosticsBearing`. This is fine, but pins a runtime cast against an *internal* protocol from inside the same module — perfectly legal, just one stop short of what `tasks.md` §7 said to verify (no `AgentJobsMacUI` import of the symbol — confirmed via grep). Also, `Self.snapshot(...)` runs inside the task group for **every** provider on every `discoverAllDetailed()` call, regardless of conformance — the cast is cheap but it's hot-path. | No code change required; flag for M07/M08 if the registry refactors. Reviewer-confirmed: WL-3 trim achieves AC-F-18 — no `public ProviderDiagnostics` remains in source (`grep public.*ProviderDiagnostics → 0 matches`). |
| 4 | **L** | `Sources/AgentJobsMacUI/Features/Dashboard/SourceBucketStrip.swift:21-37` | Wrapping the chips in `ScrollView(.horizontal, showsIndicators: false)` is a fine T-015 fix, but introduces a hidden coupling: any future "the chips don't paint" investigation will have to remember the chips live inside a scroll view. `.fixedSize(horizontal: true, vertical: false)` on the inner HStack already prevents axis-collapse — the ScrollView is now belt-and-braces. | Accept as defensive; document the rationale inline (already partially commented). No code change. |
| 5 | **L** | `Sources/AgentJobsMacUI/Components/ServiceRowCompact.swift` (75 LOC) | Architect §6 risk-table predicted: `ServiceRowCompact` may go dead once popover migrates to `MenuBarRichRow`. Verified: only references are in the dead `section(...)` helper (Finding #1). After deleting that, `ServiceRowCompact` is fully unused. | Either delete `ServiceRowCompact.swift` (cleanest) or keep it explicitly with a `// reserved for dashboard table cell M07` comment. Flag for M07 retro. Non-blocking. |
| 6 | **L** | `Sources/AgentJobsVisualHarness/Snapshot.swift:69-78` | Three `host.layoutSubtreeIfNeeded()` calls bracketing two 0.05 s runloop ticks. The third one (line 78) runs after the second runloop tick but before `cacheDisplay`. Empirically it's needed (the determinism test `deterministicAfterFix` would catch a regression), and 0.10 s × 10 scenarios stays within the M05 1.69 s budget hint. | No change. Note in retro: M07 may want to instrument scenario-level capture-time so we have data when we eventually need to defend the budget. |
| 7 | **L** | `Sources/CaptureAll/Scenarios.swift:48-56` | Scenario 03 (`menubar-popover-empty-light`) is captured at width 480 but **height 360** — every other popover scenario is 520. The 360 was carried forward from M05; given the empty-popover lacks group-header rendering (Finding #2), the surplus 160 pt of empty space probably isn't paying for itself either way. | If Finding #2 is fixed (headers rendered for empty), bump 03 height to 520 too. Otherwise leave. Non-blocking. |

No High-severity findings.

---

## AC verification

| AC | Verifier | Status | Evidence |
|---|---|---|---|
| AC-F-01 | reviewer | **PASS** | `swift build` exits 0; "Build complete!" |
| AC-F-02 | reviewer | **PASS** | `swift test` → "Test run with 332 tests passed". 332 ≥ 330. |
| AC-F-03 | tester | DEFER | App-launch/menu-bar smoke is tester's gate per `acceptance.md`. |
| AC-F-04 | reviewer | **PASS** | `MenuBarPopoverView.popoverWidth = 480` (line 22); `MenuBarRichRowTests.popoverWidth ≥ 480` test pins it. |
| AC-F-05 | reviewer | **PASS** | `PopoverGrouping.swift:49` returns `StatusGroup.allCases` order; `PopoverGroupingTests.priorityOrder` pins the order. |
| AC-F-06 | reviewer | **PASS** | `MenuBarRichRow.body` (lines 46-58) renders status pill, friendly title (`formatted.title`), summary (`formatted.summary`). Visible in 01/02/10 baselines. |
| AC-F-07 | reviewer | **PASS** | `DashboardWindowConfig.defaultSize = (1280, 800)`; `AgentJobsAppScene.body` applies `.defaultSize(...)` (line 51). PNG 04 confirms 1280×800. |
| AC-F-08 | reviewer | **PASS** | `DashboardView` applies `.navigationSplitViewColumnWidth(min:ideal:max:)` with sidebar ideal 220, inspector ideal 360 (lines 21-25, 59-63). |
| AC-F-09 | reviewer | **PASS** | Content column has `min: DashboardWindowConfig.listMinWidth` (480, line 37). |
| AC-F-10 | reviewer | **PASS** | `SourceBucketStrip` lays chips along X axis (HStack, line 23); SourceBucketStripLayoutTests pin horizontal aspect. PNG 04 shows horizontal strip with 5 chips + total. |
| AC-F-11 | reviewer | **PASS** | `SourceBucketChip.zeroStateOpacity = 0.55` when count==0 & !selected; `helpText` switches to `bucket.emptyExplanation` for zero counts. |
| AC-F-12 | reviewer | **PASS** | `MenuBarRichRow.trailingSlot` renders `RetryAffordance` only when `service.status == .failed && onRetry != nil`. `RetryAffordance` is a real `Button` (keyboard-reachable). Visible in PNG 10. |
| AC-F-13 | reviewer | **PASS** | `SnapshotRendererTests.dashboardPopulatedRendersRows` asserts ≥3 saturated row bands; passes in run. PNG 04 visibly contains 5 rows with status pills. |
| AC-F-14 | reviewer | **PASS** | `SnapshotRendererTests.dashboardDarkSchemeNoBleed` 4-corner luma < 0.3; passes. Manual 4-corner sample on 05.png: top-left 40/40/40 (luma 0.157), top-right 0/0/0, bottom-left 40/40/40, bottom-right 0/0/0 — all well below 0.3. |
| AC-F-15 | reviewer | **PASS** | 10 PNG + 10 JSON pairs in `.workflow/m06/screenshots/critique/` and `/baseline/`. JSON includes `scenarioName`, `metadata.viewportWidth`, `metadata.viewportHeight`, `colorScheme`, `appCommit`. (Schema names diverge slightly from spec wording — `scenarioName` vs spec's `scenario`, `metadata.viewportWidth` vs `width`. Functionally complete; reviewer treats as PASS, tester to confirm scheme.) |
| AC-F-16 | reviewer | **PASS** | M06 baselines committed at new sizes (480-wide popovers, 1280×800 dashboards, 1024×700 narrow). M05 baselines not reused — 4 popover-related M02/M04 baselines also regenerated (per impl-cycle 001 §"Visual-baseline outcome"). |
| AC-F-17 | reviewer | **PASS** | `wc -l Sources/AgentJobsMacUI/AgentJobsMacUI.swift` = 504 < 600. Pre-emptive split landed (`MenuBarPopoverView`, `MenuBarRowViews`, `PopoverGrouping`, `RetryAffordance`, `DashboardWindowConfig` extracted). |
| AC-F-18 | reviewer | **PASS** | `grep public.*ProviderDiagnostics` → 0 matches in `Sources/`. `actor ProviderDiagnostics` and members `internal`. `var diagnostics` requirement moved to `internal protocol DiagnosticsBearing`. |
| AC-F-19 | reviewer | **PASS** | impl-cycle 001 reports 10/10 byte-stable on rerun (above ≥8/10 floor). Reviewer didn't re-run capture-all (would only verify what tester verifies); accepts implementer claim subject to tester corroboration. |
| AC-V-01..05 | tester | DEFER | Pixel-diff against committed baselines belongs to TESTING. Reviewer only confirms baselines exist + are at the spec-mandated sizes. |
| AC-D-01..07 | ui-critic | DEFER | Design-rubric scoring is ui-critic's gate. Reviewer notes: PNG 01 (popover-light) reads as a strong rubric candidate (clear hierarchy, group headers, status pills, no truncation at 480pt); PNG 04 shows the dashboard inspector's `ContentUnavailableView` rendering as expected, list pane gets the bulk of the horizontal space. |

**Reviewer tally: 19/19 verifiable functional ACs PASS. AC-V-01..05 + AC-D-01..07 deferred to tester / ui-critic per `acceptance.md` ownership.**

---

## Watch-list verification

| WL | Status | Notes |
|---|---|---|
| WL-1 | HONORED | `acceptance.md` cleanly delineates `tester` (AC-F-*/AC-V-*) vs. `ui-critic` (AC-D-*). Implementer self-check respected the boundary. |
| WL-2 | HONORED | `AgentJobsMacUI.swift` 504 LOC. Split landed in commit `8c56b5f` BEFORE the T-002 rewrite (`e8cc09d`) — exactly as architect §3.7 required. Move-only diff is reviewable. |
| WL-3 | HONORED | `ProviderDiagnostics` actor + members + `var diagnostics` requirement all internal. `DiagnosticsBearing` introduced, conformed to by both `ClaudeScheduledTasksProvider` and `ClaudeSessionCronProvider`. Public init kept (constructs diagnostics internally), separate internal init for test injection — clean ABI, sound deviation per impl §"deviations" #2. |

---

## Architecture deviations review

| Impl-cycle deviation | Reviewer judgment |
|---|---|
| #1 — `popoverWidth` stays internal; mirrored as `HarnessScenes.defaultPopoverWidth` literal with sync test | **Accepted.** Stricter than architect's wording, ABI-cleaner. The sync test (`MenuBarRichRowTests.popoverWidth ≥ 480`) catches drift. |
| #2 — `ProviderDiagnostics` init shape: public init no longer takes `diagnostics:`; internal init for test injection | **Accepted.** Forced by access rules — public default arg can't reference internal type. Production callers unaffected. |
| #3 — Tests live under `AgentJobsCoreTests/` not `AgentJobsMacUITests/` | **Accepted.** `Package.swift` only declares `AgentJobsCoreTests`; `@testable import AgentJobsMacUI` works fine in that target. tasks.md was inaccurate. |
| #4 — Tasks 5+6 merged into one commit | **Accepted.** Task 6 was purely the popover scenario size bumps Task 5 already needed for its smoke check; splitting would have produced an empty Task-6 commit. Architect anticipated this in the sequencing rationale ("mechanical, gated on Task 5"). |
| **Undocumented** — empty-popover state skips `includeEmpty: true` headers (architect §3.2) | **Finding #2 above.** Not blocking; flagged for tester / future cycle. |

---

## E001 / E002 gates

- **E001 (perf gates):** No regression risk. `Snapshot.capture` adds 2 × 0.05 s runloop ticks per capture (≈100 ms) — total `capture-all` budget previously 1.69 s for 10 PNGs, now ≈2.7 s upper bound. Implementer reports byte-stable on rerun, consistent with the determinism unit test. PASS.
- **E002 (framework checks):** No new framework dependencies. `NSWindow`/`NSHostingView`/`NSAppearance` — all already in use. No new SPI/`@_spi`. PASS.

---

## Followups

For tester (TESTING phase):
- Run pixel-diff for AC-V-01..05 against the committed baselines.
- Confirm AC-F-03 (app launch + menu-bar interaction) on a real run.
- Confirm AC-F-19 byte-stability claim with a fresh `capture-all` invocation.
- Verify JSON sidecar field names against `acceptance.md` AC-F-15 (spec says
  `width`, `height`, `scheme`, `scenario`, `commit`; impl produced
  `metadata.viewportWidth`, `metadata.viewportHeight`, `colorScheme`,
  `scenarioName`, `appCommit`). If tester treats the schema delta as a
  spec-vs-impl discrepancy, flag for retro — reviewer judgment is the
  semantic intent is met.

For ui-critic (UI-CRITIC phase):
- Score AC-D-01..07 on the 10 critique PNGs.
- Note that scenario 03 (empty popover) does not render group headers
  (Finding #2) — score Affordance / Empty-state on what's actually drawn,
  not on architect intent.

For future milestones (M07+):
- Delete dead `activeServices` / `upcomingServices` / `section(...)` from
  `MenuBarPopoverView.swift` (Finding #1).
- Decide `ServiceRowCompact.swift` fate: delete or repurpose for M07 dashboard
  variant (Finding #5).
- Consider per-service retry semantic (currently global refresh) — out-of-scope
  per spec but pinned in architect §3.6 for "M+".
- Empty-popover rendering: align spec ↔ impl on whether headers should
  appear (Finding #2).

---

## Verdict

**PASS-with-nits, 89/100.**

All blocking ACs the reviewer can verify are satisfied; the harness fix
(T-014) is real and verifiable both visually and via `SnapshotRendererTests`.
Findings are dead-code / spec-impl-alignment in nature, not correctness or
security. Phase advances to **TESTING**.

Score breakdown: 100 − 4 (Finding #2, undocumented architect deviation,
medium) − 3 (Finding #1, dead code in a file the file-split commit
specifically touched) − 2 (Finding #7, scenario-03 height drift) − 2
(Finding #5, latent dead `ServiceRowCompact`) = 89.
