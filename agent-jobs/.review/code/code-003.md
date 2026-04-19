# Code Review 003
**Date:** 2026-04-20T00:25:00Z
**Git HEAD:** d5764a5 (cycle 8 — extract StatusBadge/MetricTile + ServiceRegistry test coverage)
**Files scanned:** 15 Swift sources (1,556 LOC) + 5 test files (354 LOC, 27 cases) + Package.swift
**Previous review:** 002 (score 89/100)

## Overall Score: 92/100  (+3 vs 002, **first ≥ 90 round**)

Component extraction landed cleanly: `StatusBadge` and `MetricTile` are now in `Sources/AgentJobsMac/Components/`, with crisp single-responsibility files (52 + 25 LOC). DashboardView dropped from 335 → 272 LOC, well under the 400-LOC ceiling. ServiceRegistry tests grew from 3 to 5 cases, including a 10-provider stress test. Shell wrapper continues to look excellent. The `LoadPhase.error` UI branch (cycle 7) is wired but unreachable today — that and `MenuBarViews` size are the only meaningful remaining items.

## Category Scores
| Category | Score | Prev | Delta | Status |
|----------|-------|------|-------|--------|
| Correctness (25) | 23 | 22 | +1 | GREEN |
| Architecture (15) | 14 | 14 | 0  | GREEN |
| Tests (20)        | 18 | 16 | +2 | GREEN |
| Performance (10)  | 9  | 9  | 0  | GREEN |
| Security (10)     | 9  | 9  | 0  | GREEN |
| Modern Swift (10) | 9  | 9  | 0  | GREEN |
| Documentation (5) | 5  | 5  | 0  | GREEN |
| OSS Quality (5)   | 5  | 5  | 0  | GREEN |
| **TOTAL** | **92** | **89** | **+3** | GREEN |

## Top 3 actions for implementer (by ROI)

1. **[P1] `Sources/AgentJobsMac/AgentJobsMacApp.swift:51-58`** — `refresh()` never sets `LoadPhase.error`. The cycle-7 `ErrorBanner` UI branch is dead-code today because `registry.discoverAll()` returns non-throwing. *Fix:* either (a) add a `discoverAllThrowing()` actor method that surfaces "all providers failed" as `ProviderError.ioError`, or (b) document explicitly in `LoadPhase` that `.error` is reserved for future fatal-init / privilege failures and update tests to cover both branches via injected stub. Pick (a) for honesty: change `refresh()` to set `phase = .error("No providers responded")` when `discovered.isEmpty && !providers.isEmpty`.
2. **[P1] `Sources/AgentJobsMac/Features/MenuBar/MenuBarViews.swift`** — 324 LOC; growing larger than DashboardView post-extraction. `SkeletonRow`, `EmptyHintView`, `SummaryChip`, `MemoryBadge`, `HoverableIconButton`, `ErrorBanner`, `ServiceRowCompact`, `MenuBarLabel` are all reusable atoms. *Fix:* mirror the cycle-8 pattern — move each to `Sources/AgentJobsMac/Components/{SkeletonRow,SummaryChip,MemoryBadge,HoverableIconButton,ErrorBanner,ServiceRowCompact,MenuBarLabel}.swift`. MenuBarViews then keeps only `MenuBarPopoverView`.
3. **[P1] `Sources/AgentJobsCore/Discovery/`** — still ships only `AgentJobsJsonProvider`. Architecture spec promised launchd / cron / brew. Leverage the cycle-5 `Shell` wrapper to land `LaunchdUserProvider.discover()` calling `Shell.run("/bin/launchctl", ["list"])`. *Fix:* one ~80 LOC provider + one golden-file test; this also gives `ServiceRegistry.defaultRegistry()` a real second provider so the failure-isolation tests reflect production shape.

## Issues (full)

### CRITICAL
*(none)*

### HIGH
*(none)*

### MEDIUM
- **M1** `AgentJobsMacApp.swift:51-58` — `LoadPhase.error` unreachable (see Top-3 #1).
- **M2** `MenuBarViews.swift` — 324 LOC, single file holding 8 distinct view types (see Top-3 #2).
- **M3** `Sources/AgentJobsCore/Discovery/` — only 1 production provider; defaultRegistry() ships short of the architectural promise (see Top-3 #3).
- **M4** `Sources/AgentJobsCore/Discovery/Shell.swift:110-116` — `DispatchQueue.global(qos: .utility).asyncAfter` for SIGKILL escalation crosses out of structured concurrency. Strict-review iter-004 already noted this as L-005 OPEN-acceptable. *Fix (optional):* `Task.detached(priority: .utility) { try? await Task.sleep(for: .seconds(sigtermGraceSeconds)); if process.isRunning { kill(pid, SIGKILL) } }`. Behavior identical; semantics tidier.

### LOW
- **L1** `Sources/AgentJobsMac/Components/StatusBadge.swift:24-46` — switch-statement duplicates the symbol+color mapping. Consider a `ServiceStatus.presentation: (symbol: String, color: Color)` tuple in Domain (or a single switch returning a struct). Pure cleanup.
- **L2** `Sources/AgentJobsMac/Features/Dashboard/DashboardView.swift:65-74` — sidebar `List(selection:)` still uses `Optional<ServiceSource.Category>?` tagging; the suggested `enum SidebarItem { case all; case category(...) }` from code-001 still hasn't landed. Works, but tag-with-optional pattern is fragile.
- **L3** `Tests/AgentJobsCoreTests/ServiceRegistryTests.swift:65-71` — uses `Self.makeService(...)` consistently after fix; nice. But the three `Stub*Provider` types live inside the test struct. Fine for now; if a future test wants to reuse them, hoist to a `Tests/.../Helpers/StubProviders.swift`.
- **L4** `Sources/AgentJobsCore/Discovery/Shell.swift:14-25` — `Shell.Result` shadows `Swift.Result`; carried from code-002. Cosmetic.
- **L5** No `LICENSE` file at repo root or macapp/. Carried from code-002 L4. Doesn't affect score (CHANGELOG + README cover OSS Quality 5/5) but worth dropping `LICENSE` (MIT or Apache-2.0) before announcing.
- **L6** `MetricTile.swift` is now `internal` (no `public`). If `Sources/AgentJobsCore` ever wants to surface a built-in tile preview, you'll need `public init`. Defer until needed.

## Diff since previous review

**Fixed (from code-002):**
- P0 #1 (M1) ✅ `Shell.Failure.timeout(seconds:)` — dead `partialStdout` removed.
- P0 #2     ✅ `Shell` two-stage SIGTERM→SIGKILL with `sigtermGraceSeconds = 0.5`.
- P1 #3 (M2) ✅ `ServiceRegistryTests` shipped + grew to 5 cases (cycle 6 + cycle 8).
- L2         ✅ `Shell.run` precondition on absolute path.
- M3         ⏳ Partial — DashboardView now 272 LOC (was 267 + new TabChipRow → −53 net). `StatusBadge` + `MetricTile` extracted. `SidebarItem` enum still inline. `TabChipRow`/`TabChip` still inline.

**Still open from code-002:**
- M4 (Shell timeout-arm CancellationError log-noise under Swift 6 strict concurrency) — noted; behavior correct.
- L1 (`Shell.Result` shadows `Swift.Result`) — cosmetic.
- L4 (LICENSE file) — repo chore.
- L6 (`defaultRegistry()` only ships `AgentJobsJsonProvider`) — see Top-3 #3.

**New this cycle:**
- M1 (LoadPhase.error unreachable today)
- M2 (MenuBarViews 324 LOC)
- L1 (StatusBadge mapping duplication)
- L3 (StubProviders hoisting candidate)
- L6 (MetricTile internal-only)

## Communication to implementer

- Excellent cycle-7 + cycle-8 work. Component extraction is exactly the right pattern; please continue mirroring it for MenuBarViews next cycle (Top-3 #2).
- The P1 #1 (LoadPhase.error reachability) is a *correctness honesty* concern, not a urgent bug — but resolving it ensures the cycle-7 `ErrorBanner` is testable and visible to QA. Bonus: pairs naturally with a `ServiceRegistryViewModelTests` suite (LoadPhase state-machine). Add 3-4 cases (idle→loading→loaded; loading→error; error→loading→loaded retry) and you'll lock in the contract.
- Cross-stream alignment with **strict-review iter-004 (PASS, 2nd consecutive)**: my M4 above is iter-004's L-005, judged OPEN-acceptable. So this is *informational* — don't burn cycle budget on it unless cycle 11+ when the backlog is otherwise empty.
- Cross-stream alignment with **design-002**: P1 #2 (MenuBarViews extraction) doesn't touch design semantics. Safe pure refactor.
- Per repo memory `feedback_auto_commit_push`: I noticed cycle-8's commit `d5764a5` is **local-only** (push failed with 403 due to credential rotation `menha_microsoft` → `MashellHan`). The implementer agent flagged this in `impl-2026-04-20T0010.md` — the user will need to fix the credential helper (e.g. `gh auth login` or rotate PAT in keychain) before the next push will succeed. **Not a code defect**, but blocks the auto-publish promise. Including this as a process note so the strict reviewer sees it next cycle.

## Termination check
- Score >= 90 for 2 consecutive reviews? **no** (92 this round, was 89 last round; this is the **first** ≥ 90 round)
- `swift test` green? **yes** (27/27 in 0.320s)
- Recommendation: **CONTINUE**

One more cycle holding ≥ 90 (Top-3 P1s addressed → likely 94+) and this stream will DECLARE-DONE.
