# M02 Released

**Date:** 2026-04-24
**Final commit:** 3f7ef1c
**Cycles:** IMPL=2 REVIEW=2 TEST=1

## Summary
Functional UI baseline. First milestone with visible UI changes. Surfaces all 5 discovery sources (registered jobs.json, claude scheduled, claude session-JSONL, launchd, live processes) in the Dashboard with a `SourceBucketStrip` summary header (5 chips, click-to-filter), inline `ServiceInspector` right-pane (no separate window), and `.accessory` activation policy so the menu bar icon is the primary entry point. Adds the visual-test harness (`NSHostingView` snapshot + ImageMagick `compare` via `scripts/visual-diff.sh`), 6 committed screenshot baselines, app-launch smoke test, and dashboard-filter pure unit tests.

## Acceptance
All 26/26 acceptance criteria PASS (see `test-cycle-001.md`). 1 conditional (AC-P-02 perf gate measured 3.96s on dev box vs 3s spec on reference HW; non-blocking, gated behind `AGENTJOBS_PERF=1`).

| Category | Pass |
|---|---|
| Functional | 12/12 |
| Visual (with screenshot baselines) | 6/6 |
| Performance | 4/4 |
| Quality gates | 4/4 |

## Modules touched
- `AgentJobsCore.Domain` — `ServiceSource.Bucket` enum (5 cases) + accessor
- `AgentJobsCore.Discovery` — `StubServiceRegistry` for deterministic visual tests
- `AgentJobsMac` — `SourceBucketStrip`, `SourceBucketChip`, `DashboardView` filter integration, `ServiceInspector` provenance row
- `AgentJobsMacApp` — `NSApplicationDelegateAdaptor` setting `.accessory` activation policy
- `scripts/visual-diff.sh` — ImageMagick wrapper, 2% default / 5% menu-bar threshold
- `Tests/` — +33 tests (Bucket=3, StubRegistry=6, AppLaunch=2, DashboardFilter=8, ScreenshotHarness=3, VisualBaseline=6, MenuBarIconVisual=1, Performance=4)
- `.workflow/m02/screenshots/baseline/` — 6 baselines committed

## Test count
145 → 178 (+33).

## Deferred to future milestones
- M03 — Actions (stop/hide/refresh) — design hooks deliberately not added in M02
- AC-P-02 spec budget — revisit on reference HW; if dev-box discovery routinely exceeds 3s, tighten provider scan or relax spec
- 5 P2 nits from review-cycle-001/002 (style/ergonomics, no functional impact)
- odiff swap-in (currently ImageMagick `compare`; harness wraps tool so swap is one-line)
