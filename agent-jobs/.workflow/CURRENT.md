---
milestone: M02
phase: SPECCING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T01:35:00Z
last_actor: human
---

# Current Workflow State

**Milestone:** M02 — Functional UI baseline
**Phase:** SPECCING
**Cycle:** 1
**Owner:** none — pm pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)

## M02 priorities (PM should respect)
- This is the FIRST milestone with visible UI changes — visual ACs MANDATORY (screenshot baselines)
- Surface ALL 5 data sources (registered, live, claude scheduled, claude session, launchd) with a summary header showing counts
- Per-row detail panel (no separate window — inline expand or side panel)
- App must launch without crash, menu bar icon visible, list scrolls smoothly
- Tester WILL launch the app via `swift run` and verify with screenshot regression

## Next
- pm: short competitive scan (Stats, SwiftBar, Bartender for menu-bar UX patterns), then spec
