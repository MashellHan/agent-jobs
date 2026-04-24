---
milestone: M02
phase: IMPLEMENTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T02:05:00Z
last_actor: architect
---

# Current Workflow State

**Milestone:** M02 — Functional UI baseline
**Phase:** IMPLEMENTING
**Cycle:** 1
**Owner:** none — implementer pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 ARCHITECTING done 2026-04-24T02:05:00Z (9 tasks planned, 26/26 ACs covered)

## M02 priorities (PM should respect)
- This is the FIRST milestone with visible UI changes — visual ACs MANDATORY (screenshot baselines)
- Surface ALL 5 data sources (registered, live, claude scheduled, claude session, launchd) with a summary header showing counts
- Per-row detail panel (no separate window — inline expand or side panel)
- App must launch without crash, menu bar icon visible, list scrolls smoothly
- Tester WILL launch the app via `swift run` and verify with screenshot regression

## Architect decisions (resolves PM open questions)
1. Screenshot capture: in-process `NSHostingView` + `bitmapImageRepForCachingDisplay` (NOT XCUITest). AC-V-06 menu-bar icon uses `CGWindowListCreateImage` against the launched binary.
2. Source-bucket grouping: YES, new `ServiceSource.Bucket` enum + accessor (orthogonal to `Category`).
3. Image diff tool: ImageMagick `compare` (already installed), wrapped in `scripts/visual-diff.sh` with 2% threshold (5% for menu-bar AC-V-06).

## Next
- implementer: read .workflow/m02/{architecture,tasks}.md; execute T01..T09 in order, one commit per task.
