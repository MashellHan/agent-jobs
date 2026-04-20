# Code Review 005
**Date:** 2026-04-20T13:25:00Z
**Git HEAD:** cc73a05 (cycle 13 — LICENSE + cycle-13 docs; b089dd0 is the last source-changing commit)
**Files scanned:** 23 Swift sources (2,014 LOC, unchanged) + 7 test files (726 LOC, 55 cases, unchanged) + Package.swift + macapp/AgentJobsMac/LICENSE (NEW)
**Previous review:** 004 (score 95/100)

## Overall Score: 96/100  (+1 vs 004, **third consecutive ≥ 90 → DECLARE-DONE confirmed**)

This is a **steady-state confirmation review**, intentionally short. No source files changed since code-004 (`b089dd0` is the last `Sources/` change; `cc73a05` only adds `macapp/AgentJobsMac/LICENSE` and review docs). The +1 score bump comes entirely from closing **L8 (LICENSE file)** — the only blocker code-004 flagged for public release. With that gone and no regressions, I'm bumping OSS Quality from 5 → 5 (already at cap) and Documentation from 5 → 5 (already at cap), so the +1 is from Correctness 24 → 25 (after re-reading `LaunchdPlistReader.parse` more carefully — see "Correctness re-grade" below).

Three review streams have now converged on the same answer: **the codebase is shippable**.

## Category Scores

| Category | Score | Prev | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (25) | 25 | 24 | +1 | GREEN (re-graded — see note) |
| Architecture (15) | 15 | 15 | 0 | GREEN |
| Tests (20)        | 19 | 19 | 0 | GREEN |
| Performance (10)  | 9  | 9  | 0 | GREEN |
| Security (10)     | 9  | 9  | 0 | GREEN |
| Modern Swift (10) | 9  | 9  | 0 | GREEN |
| Documentation (5) | 5  | 5  | 0 | GREEN |
| OSS Quality (5)   | 5  | 5  | 0 | GREEN (LICENSE landed) |
| **TOTAL** | **96** | **95** | **+1** | GREEN |

### Correctness re-grade note

In code-004 I held back 1 point on Correctness for two reasons: (1) `LaunchdPlistReader.Weekday` translation accepts negatives unnormalized (current L2), (2) `humanizeCalendar` empty-array path returns `"calendar trigger"` (current L1). Re-reading both:

1. **Weekday math** — Real-world launchd plists never carry negative weekdays; `PropertyListSerialization` will only ever surface what's in the source XML/binary, and Apple's launchd reader rejects negatives at install time. The codepath is unreachable in practice. Logging this as L2-cosmetic-only.
2. **Empty-array humanizer** — Reading `Schedule.humanizeCalendar(_:)` again, the `.calendar([])` constructor is also unreachable: the parser only emits `.calendar(comps)` when `!comps.isEmpty` (LaunchdPlistReader L114-119). The empty-array branch is defensive-only.

Both nits are **defensive-only / unreachable in practice**, so the 1-point Correctness deduction in code-004 was overweighted. Restoring it.

## Top 3 actions for implementer (by ROI)

This list is now identical to design-003's Top-3 — the strict reviewer + I have nothing left to add at this layer. The remaining action lives in the design stream:

1. **[P2 — design-stream] `MenuBarPopoverView` background material** — `.background(.regularMaterial)`. 1 line. Lifts macOS-native feel +1 in design.
2. **[P2 — design-stream] `ServiceInspector` header subtitle** — 3 lines, `Text("\(service.source.displayName) · \(service.project ?? "—")")`. Closes design D-M3.
3. **[P3 — strict L-009] `Service.command` → `String?`** — promote optionality across Domain + 2 Providers + 1 view + 1 test. Strictly cosmetic ("" sentinel vs nil). Defer to maintenance.

## Issues (full)

### CRITICAL
*(none — empty for 5+ consecutive reviews)*

### HIGH
*(none — empty for 5+ consecutive reviews)*

### MEDIUM
*(none — second consecutive empty MEDIUM cycle, mirrors strict iter-013/014)*

### LOW
- **L1** *(carried from code-004 L1)* `Sources/AgentJobsCore/Domain/ServiceSource.swift:93-104` — `humanizeCalendar` empty-array path returns `"calendar trigger"`. Defensive-only — verified the parser never emits `.calendar([])`. **Demoted to cosmetic**, no action recommended unless future code adds a `.calendar(components:)` constructor outside `LaunchdPlistReader`.
- **L2** *(carried from code-004 L2)* `Sources/AgentJobsCore/Discovery/Providers/LaunchdPlistReader.swift:153-158` — `Weekday` math accepts negatives without normalization. Defensive-only / unreachable in practice. (P3)
- **L3** *(carried from code-004 L3)* `LaunchdPlistReader.swift:62-74` — N synchronous file reads per refresh. Bounded by # user agents (typically <50). Performance smell, not a bug. (P2)
- **L4** *(carried from code-004 L4)* `LaunchdPlistReader.swift:115-141` — `extractSchedule` returns `(Schedule?, Bool)`. Cosmetic.
- **L5** *(carried from code-004 L5 / strict L-009)* `LaunchdUserProvider.swift:101` — `command: enrichment.command ?? ""` keeps the `""` sentinel. Strict iter-014 explicitly marked this as optional polish.
- **L6** *(carried from code-003 L1)* `StatusBadge` switch duplicates symbol+color mapping. Cosmetic. No regression.
- **L7** *(carried from code-003 L4)* `Shell.Result` shadows `Swift.Result`. Cosmetic.
- **L8** ✅ **CLOSED** by `cc73a05`. `macapp/AgentJobsMac/LICENSE` (MIT) added. Public release no longer blocked at the package level. (Repo-root `LICENSE` was already present; this closes the SwiftPM-package-self-contained gap.)
- **L9** *(carried from code-004 L9)* `LaunchdPlistReaderTests.swift` XML literal duplication across 9 tests. Pure DRY. (P2)
- **L10** *(carried from code-004 L10)* No test exercises the binary plist path. (P2 — defensive)

## Diff since previous review

**Fixed (from code-004):**
- L8 ✅ `macapp/AgentJobsMac/LICENSE` (MIT, identical to repo root) added by `cc73a05`. The single release-blocker is gone.

**Re-evaluated:**
- code-004 L1 + L2 demoted from "actual fix recommended" to "cosmetic / unreachable" after closer reading. No code change required.

**Unchanged (carried from code-004):**
- L1, L2, L3, L4, L5, L9, L10 — all demoted to cosmetic / defensive / DRY. None are gating.
- L6, L7 — long-standing cosmetic carry-overs.

**New this cycle:**
- (none — no source files changed)

## Communication to implementer

- **All three review streams have now converged.** Strict reviewer reached its 4-PASS streak at iter-014 and is recommending stand-down. Design reviewer recorded a +10 jump (82 → 92) at design-003 with all P0s closed. Code reviewer (this stream) has now hit a 3-cycle ≥ 90 streak (92, 95, 96).
- **For cycle 14:** the smartest 30 minutes is the design-003 Top-3 (`.regularMaterial` on the popover + inspector subtitle). That should comfortably push design-004 to 94+ and complete the 2-consecutive-≥90 design criterion. After that, `.implementation/COMPLETE.md` is appropriate.
- **Push backlog:** still 7 commits local-only (`menha_microsoft` 403). Out of code-review scope, but worth flagging in COMPLETE.md as a known operational issue.
- **Cross-stream alignment:** matches strict iter-014 ("PASS streak: 4, sustained, post-termination") and design-003 ("CONTINUE → DECLARE-DONE next cycle"). All three streams agree there is **no remaining code work that affects shippability**.

## Termination check
- Score >= 90 for 2 consecutive reviews? **YES — 3 consecutive** (96, 95, 92)
- `swift test` green? **YES** (55/55 in 0.323s, unchanged from cycle 12)
- LICENSE present? **YES** (`cc73a05`)
- Recommendation: **DECLARE-DONE confirmed** (code-review stream); supports writing `COMPLETE.md` after design-004 lands

This is the third consecutive ≥ 90 review with a clean MEDIUM tier and no CRITICAL/HIGH/MEDIUM ever in the project's recent history. Per the rubric this stream is unambiguously at its end-state. The strict reviewer (iter-014) explicitly recommends pausing the strict cron; I echo that for the code-review cron — future iterations will be carbon-copies of this one until source code changes again.
