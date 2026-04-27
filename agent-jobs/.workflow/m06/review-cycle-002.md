# M06 REVIEW Cycle 2 — T-017 P0 + T-018 P1 fixes

**Reviewer:** reviewer
**Filed:** 2026-04-27
**Cycle:** 2 (after ui-critic cycle-1 REJECT 20/30)
**Scope:** Cycle-2 deltas only (commit 330a2fd over cb31392)

---

## Verdict: PASS — 94 / 100

Both P0 (T-017 dark dashboard chrome) and P1 (T-018 empty popover scaffolding) close cleanly. Dark-only gating is rigorous: every cycle-2 fix sits behind an explicit `if isDark` (Snapshot.swift) or `colorScheme == .dark` (DashboardView.swift) branch, with the light path returning the prior behavior verbatim. All 6 light-mode M06 visual baselines remain pixel-identical to cycle-1, and M02/M03/M04 baseline directories show **zero diff** since milestone start. Tests 332/332 green. No regressions.

Score breakdown:
- Functional correctness (T-017 + T-018 both closed): 30/30
- Dark-only gating discipline: 25/25
- Light-mode byte-stability (M02/M03/M04 + M06 light): 20/20
- Code quality (well-commented, single-purpose helpers, no scope creep): 14/15
- Test/baseline hygiene (332 pass, baselines + critique sets in lock-step): 5/10  — see N1

---

## Verification

| Check | Result |
|---|---|
| `swift build` | green (warnings only, none new) |
| `swift test` | **332 / 332 pass** (0 failures, 0 regressions) |
| Baseline count: `.workflow/m06/screenshots/baseline/*.png` | 10/10 present |
| Critique count: `.workflow/m06/screenshots/critique/*.png` | 10/10 present (in lock-step with baselines) |
| Light M06 baselines (01, 04, 06, 07, 09, 10) pixel-identical to cb31392 | YES (PIL byte-compare on RGBA: zero pixels differ for all 6) |
| Dark M06 baselines (02, 05, 08) changed | YES (intentional T-017 fix; bytes differ ~57–63%) |
| Empty M06 baseline (03) changed | YES (intentional T-018 fix; ~1.7% bytes differ → group headers + microcopy added) |
| `git diff cb31392..HEAD -- .workflow/m02 .workflow/m03 .workflow/m04` | **EMPTY (no diff)** — older milestone baselines untouched |
| Dark-frame chrome luma sample (10 points across scenarios 02/05/08) | all luma 31–46 / 255 (≈ 0.12–0.18 normalized) — well under the 0.3 dark-frame rubric threshold; covers corners + interior + top header band + inspector pane |

---

## Findings

| # | Severity | Area | Finding |
|---|---|---|---|
| F1 | NIT | `MenuBarPopoverView.swift` (carry-forward) | Dead helpers from M05 still linger: `section(title:services:emptyMessage:)`, `activeServices`, `upcomingServices`. Cycle-1 reviewer flagged this; cycle-2 implementer correctly chose not to touch them (out of scope for T-017/T-018). Re-flagging as M07 cleanup. |
| F2 | NIT | `Snapshot.swift` | Three `RunLoop.current.run(until: ...0.05)` settles + `forceAppearance` recursion + `invalidateLayers` recursion add ~150 ms per dark capture. Acceptable; flag for M07 if dark capture wall-clock budget tightens. |
| F3 | NIT | `Snapshot.swift` `forceAppearance` | The function unconditionally re-stamps `NSScrollView.backgroundColor = .windowBackgroundColor` and `drawsBackground = true` on every scroll view in the subtree. This is dark-only by virtue of the call-site `if isDark` gate, but the function itself is not internally guarded. If a future caller invokes `forceAppearance` from a light path, light-mode baselines could shift silently. Consider asserting or renaming to `forceDarkAppearance` in M07. |
| F4 | NIT | Baseline timestamps | All 10 baseline + 10 critique JSON sidecars regenerated → `appCommit` advanced from `4998988` → `cb31392` and `capturedAt` advanced. The 6 light-mode PNGs are pixel-identical, so the JSON refresh is harmless metadata churn but produces a noisy diff. Future capture-all could skip JSON rewrite when PNG is byte-stable. |

No HIGH or MEDIUM findings. No P0/P1 blockers. None of the above is exit-criteria-blocking.

---

## Confirmation: light-mode older milestones untouched

```
$ git diff cb31392..HEAD -- .workflow/m02 .workflow/m03 .workflow/m04
(empty — no diff)
```

M02/M03/M04 baseline PNGs and JSON sidecars are byte-stable since milestone start. Light-mode rendering for older milestones verified by `swift test` running every M02/M03/M04 visual baseline test green (e.g. `M02 AC-V-01..05`, `M03 AC-V-01..05`, `M04 AC-V-01..V-05`).

---

## Cycle-2 verifiable observations against ui-critic cycle-1 tickets

- **T-017 (P0) — closed.** Snapshot.swift implements all 4 documented dark-only mitigations (NSApp.appearance pin, resolved opaque window bg, ordered-front offscreen, forceAppearance walk + layer invalidation). DashboardView.swift adds dark-only `paneBackground` on content + inspector panes. Luma sampling at 10 points across scenarios 02/05/08 (corners + interior + top band + inspector) returns 31–46/255 — full-frame dark, no white bleed. The M05 P0 condition does not recur.
- **T-018 (P1) — closed.** MenuBarPopoverView empty branch now `ForEach`'s `emptyGroupedServices` (groupByStatus with `includeEmpty: true`, `.other` filtered out), rendering `PopoverGroupHeader` with 0 count and per-group `EmptyHintView` microcopy ("No services running right now." / "Nothing scheduled in the next hour." / "Nothing has failed recently."). Matches architecture §3.2 information-architecture parity rule. Scenario 03 baseline PNG bytes diverge from cb31392 (16115 → 22803 bytes, ~1.7% pixel diff) reflecting the new scaffolding.
- **T-019 (P2) / T-020 (P2)** — correctly deferred to M07 per ticket triage.

---

## Recommendation

Advance to **TESTING cycle 2**. Tester should re-run capture-all twice for byte-stability confirmation, re-execute the dark-frame luma rubric on scenarios 02/05/08 (sampling more than just 4 corners — include top header band y≈30 and inspector mid-pane), and re-evaluate AC-D-07. AC-F-15 sidecar schema delta from cycle-1 still flagged as borderline; ui-critic gate on cycle-2 will confirm whether the empty-popover scaffolding satisfies the cycle-1 ui-critic Empty/Error 2/5 score regression.
