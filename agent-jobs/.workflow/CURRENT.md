---
milestone: M04
phase: TESTING
cycle: 1
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-24T12:18:00Z
last_actor: reviewer
---

# Current Workflow State

**Milestone:** M04 — Auto-refresh + fs.watch
**Phase:** TESTING
**Cycle:** 1
**Owner:** none — tester pick up

## Phase History (workflow-wide)
- M01 SHIPPED 2026-04-24T00:30:00Z (37/37 ACs PASS, pushed)
- M01.5 SHIPPED 2026-04-24T01:30:00Z (15/15 ACs PASS first try, pushed)
- M02 SHIPPED 2026-04-24T06:40:00Z (26/26 ACs PASS, pushed)
- M02 RETRO 2026-04-24T06:55:00Z (E001 perf-gate, E002 framework-check)
- M03 SHIPPED 2026-04-24T10:30:00Z (26/26 ACs PASS first-try, pushed)
- M03 RETRO 2026-04-24T10:45:00Z (E001 + E002 → ACCEPTED)
- M04 ARCHITECTING → IMPLEMENTING 2026-04-24T11:30:00Z (architect: 8 tasks, AC-F-15 dropped, AC-V-05 kept)
- M04 IMPLEMENTING → REVIEWING 2026-04-24T12:05:00Z (T01..T08 done, 266 tests, 1 pre-existing M01 flake)
- M04 REVIEWING → TESTING 2026-04-24T12:18:00Z (cycle 1 PASS, score 88/100, 0 CRITICAL)

## M04 architect decisions
- AC-F-15 DROPPED (M03 overlay continuity covered indirectly)
- AC-V-05 KEPT (dashboard-toolbar indicator placement is new UX surface)
- RefreshScheduler is an `actor` in `AgentJobsCore/Refresh/`, hand-rolled `DispatchWorkItem` debounce (no Combine)
- VisibilityProvider protocol in Core; `AppKitVisibilityProvider` production impl in App layer
- WatchPaths injection is the test seam; static-grep enforces no real `~/` literals

## M04 implementer notes
- All 8 tasks committed individually (`impl(M04-T0X): ...`)
- 266 tests in suite (was 224 in M03 → +42 tests, target was +20/+30)
- 3 perf-gated tests intentionally skipped (AC-P-01, AC-P-02, AC-P-03 — gated behind AGENTJOBS_PERF=1 per E001)
- 1 pre-existing M01 flake (`AC-P-02: parse 10,000-line synthetic JSONL in < 500 ms`) NOT in M04 scope; documented in `.workflow/m04/impl-notes.md` as Workaround #1; passes solo (~177 ms) but slow under suite contention (~600-700 ms)
- 7 visual baselines recorded under `.workflow/m04/screenshots/baseline/` (idle light/dark, refreshing, error, popover-with-indicator, dashboard-toolbar-with-indicator, selection-preserved)
- See `.workflow/m04/impl-cycle-001.md` for full summary

## M04 reviewer notes (cycle 1)
- Build PASS; tests PASS 266/266 (M01 flake did not surface this run)
- Score 88/100, 0 CRITICAL, 0 HIGH, 2 MEDIUM (M1: visibility-task self capture; M2: dir-watcher path prefix check), 4 LOW
- AC-P-04 (16 ms main-thread non-block) NOTED missing — implementer honestly deferred per E001 (no relaxed assertion written). Tester should decide whether to add the strict test in TESTING phase OR carry to retro.
- AC-Q-02 (≥80% coverage on changed lines) untracked — tester to run `swift test --enable-code-coverage` and report
- See `.workflow/m04/review-cycle-001.md` for full review

## Next
- tester: read `.workflow/m04/review-cycle-001.md` + `acceptance.md`. Run full strict-mode `AGENTJOBS_PERF=1 swift test`, run `scripts/visual-diff.sh`, measure coverage, verify each AC against the "Acceptance criteria status" table. Report PASS/FAIL per AC. Decide AC-P-04 disposition (write test now, or retro item).
