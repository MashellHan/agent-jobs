# COMPLETE — agent-jobs Mac App rewrite

**Status:** ✅ DECLARE-DONE
**Date:** 2026-04-20T13:40:00Z
**Final HEAD:** `1e29efe` (cycle 14 — popover material + inspector subtitle)
**Cycles run:** 14 implementation cycles + 14 strict-review iterations + 5 code reviews + 4 design reviews
**Final test count:** 55/55 passing in 0.313s
**Final source size:** 23 Swift files, 2,026 LOC; 7 test files, 726 LOC

All three review streams have simultaneously hit their termination criteria.
Per the project termination contract, this codebase is shippable.

---

## Termination criteria — all satisfied

| Stream | Criterion | Evidence |
|--------|-----------|----------|
| Strict review | 3 consecutive PASS with empty MEDIUM | iter-011, iter-012, iter-013 (criterion met), sustained at iter-014 (4-PASS streak) |
| Code review | 2 consecutive ≥ 90 | code-003: 92, code-004: 95, code-005: 96 (3-cycle streak) |
| Design review | 2 consecutive ≥ 90 with empty HIGH | design-003: 92, design-004: 95 (both have empty HIGH tier) |

---

## What shipped

### Domain (Sources/AgentJobsCore/Domain/)
- `Service` — TUI-parity model with optional `createdAt`, `pid`, `metrics`, `history`, `origin`
- `ServiceSource` — 9-case enum + `Category` taxonomy + display names + SF Symbols
- `Schedule` — `.interval`, `.cron(...)`, `.calendar(components:)`, `.eventTrigger`, `.onDemand`, `.unknown`
- `CronHumanizer` — 7 common cron patterns translated ("weekdays at 9am", "every 5 minutes")
- `Schedule.humanizeCalendar` — launchd calendar triggers as natural English ("daily at 09:00", "weekly Mon at 03:30", "monthly on day 15 at 12:00", "hourly at :05")
- `ResourceMetrics` — CPU, RSS, threads, FDs

### Discovery (Sources/AgentJobsCore/Discovery/)
- `ServiceProvider` protocol with failure-isolated `discover()` contract
- `ServiceRegistry` actor with `withTaskGroup` aggregation; `discoverAllDetailed() → DiscoverResult { services, succeededCount, totalCount, allFailed }` so the view-model can distinguish "all providers failed" from "all providers legitimately empty"
- `Shell.run(_:args:timeout:)` — argv-array subprocess wrapper with bounded SIGTERM→SIGKILL escalation, structured-concurrency cancellation
- `AgentJobsJsonProvider` — schema-versioned, timeout-bounded JSON loader with `os.Logger` for malformed input
- `LaunchdUserProvider` — parses `launchctl list` 3-column output, skips Apple system jobs, maps PID/exit-status to `.running/.scheduled/.failed`
- `LaunchdPlistReader` — reads `~/Library/LaunchAgents/<label>.plist` and `/Library/LaunchAgents`; decodes `ProgramArguments`, `Program`, `StartInterval`, `StartCalendarInterval` (single dict OR array), `WatchPaths`, `QueueDirectories`, `KeepAlive`. Tolerant of missing/malformed plists. Sendable, injection seam for tests.

### UI (Sources/AgentJobsMac/)
- `AgentJobsMacApp` — `MenuBarExtra(.window)` + `Window` for dashboard, OpenWindow-based navigation
- `MenuBarPopoverView` — 360pt popover with `.regularMaterial` vibrancy, header + summaryStrip + ErrorBanner + scrollable section list (Active Now / Scheduled Soon) + footer
- `DashboardView` — NavigationSplitView + sidebar (categorized filter with counts) + Table (`.tableStyle(.inset(alternatesRowBackgrounds: true))` with category-aware ContentUnavailableView for zero-filter) + ServiceInspector
- `ServiceInspector` — chip-row tab navigation (Overview / Logs / Config / Metrics) with provenance subtitle (`source · project`) and command preview
- `Components/` — 10 reusable atoms (StatusBadge, MetricTile, MemoryBadge, SummaryChip, ErrorBanner, HoverableIconButton, ServiceRowCompact, EmptyHintView, SkeletonRow, MenuBarLabel)
- `DesignTokens` — Spacing (xxs..xxl), Radius (s/m/l/xl), Typography (rounded), StatusColor, ResourceColor (CPU/MEM thresholds)
- `AutoRefreshIndicator` — visible "updated Xs ago • next in Ys" header badge with reduce-motion guard
- CPU + Memory visible at all three altitudes (menubar MemoryBadge → dashboard CPU/MEM columns → inspector Metrics tab)

### Tests (Tests/AgentJobsCoreTests/)
- 7 test files, 726 LOC, **55 test cases**
- AgentJobsJsonProviderTests, MenuBarSummaryTests, ServiceRegistryTests (DiscoverResult contract), CronHumanizerTests, LaunchdUserProviderTests, LaunchdPlistReaderTests (XML parsing, weekday translation, malformed tolerance, Schedule.humanDescription calendar suite), ShellTests (timeout reap)

### Tooling
- `scripts/build-mac.sh` — single command for `swift build && swift test`
- `scripts/pre-commit-gate.sh` + `.claude/settings.json` PreToolUse hook — runs `swift build && swift test` before any commit touching `^macapp/AgentJobsMac/Sources/`
- `Package.swift` — swift-tools-version 6.0, strict concurrency

### Documentation
- `README.md` — architecture diagram, modules table, status grid, development-loop description
- `CHANGELOG.md` — Keep-a-Changelog format, cycle-by-cycle entries with line-level cross-refs to closed issues
- `LICENSE` (MIT) at repo root AND `macapp/AgentJobsMac/LICENSE` (self-contained for SwiftPM distribution)
- `.implementation/macapp-architecture.md`, `.implementation/sandbox-decision.md`
- `.review-prompts/{implementer,code-reviewer,design-reviewer}.md`
- 14 cycle-by-cycle `.implementation/impl-*.md` docs

---

## Issues resolved across the 14-cycle journey

### CRITICAL (2 resolved, 0 outstanding)
- C-001 — Mac app directory empty (resolved cycle 2)
- C-002 — Missing design documents (resolved cycle 2)

### HIGH (4 resolved, 0 outstanding)
- H-001 — `Schedule.cron` not human readable (resolved cycle 3 via CronHumanizer)
- H-002 — Inspector dead-end (resolved cycle 4 via ContentUnavailableView)
- H-003 — Build warning Fixtures (resolved cycle 3)
- H-004 — LaunchdUserProvider commit gap (resolved cycle 9)

### MEDIUM (10 resolved, 0 outstanding)
- M-001 — README expansion (cycle 4)
- M-002 — MenuBarSummary tests (cycle 3)
- M-003 — Provider read timeout (cycle 5)
- M-004 — MenuBar asymmetry (cycle 4)
- M-005 — Commit-gate not installed (cycle 10 — reviewer-installed pre-commit hook)
- M-006 — Synthetic createdAt (cycle 11 — `Service.createdAt: Date?`)
- M-007 — "No providers responded" false positive (cycle 10 — `DiscoverResult.allFailed`)
- M-008 — DiscoverResult test coverage (cycle 11 — 4 cases)
- M-009 — Implementer cron stall (cycle 11 — empirical recovery)
- M-010 — Working-tree uncommitted (cycle 11 — pre-commit gate's first live firing)

### LOW (7 resolved, 3 outstanding nits)
- Resolved: L-001, L-002, L-003, L-004, L-007 (launchd schedule placeholder), L-008 (kind PID-only)
- **Carry-forward (none gating release):**
  - L-005 — `Shell.onCancel` SIGKILL via `DispatchQueue` (nit, acceptable)
  - L-006 — `AgentJobsJsonProvider.readWithTimeout` sync `Data(contentsOf:)` (acceptable)
  - L-009 — `command: ""` should be `nil`/sentinel (cosmetic)

### Design issues resolved
- D-P0-1 (hover state on ServiceRowCompact) — design-002
- D-P0-2 (non-color status signal) — design-002
- D-P0-3 (loading skeleton) — design-002
- D-H1 (.thinMaterial.opacity(0) dead code) — design-002
- D-H2 (chip-row inspector tabs) — design-003
- D-H3 (refresh button hover state) — design-003
- D-H4 (reduce-motion AutoRefreshIndicator) — design-002
- D-H5 (table styling + zero-filter empty) — design-003
- D-H6 (LoadPhase.error rendering / ErrorBanner) — design-003
- D-M3 (inspector provenance subtitle) — design-004 (carried since design-001)
- D-M6 / D-M7 (VoiceOver labels on MemoryBadge + SummaryChip) — design-003
- D-M8 / D-L5 (MetricTile inner border + minHeight) — design-003
- D-popover-material — design-004

---

## Memory preferences honored

| Preference | Status | Evidence |
|------------|--------|----------|
| `feedback_tui_design` | ✅ | Visible auto-refresh badge; chip tabs (no modals); inline detail expansion via NavigationSplitView |
| `feedback_tui_history` | ✅ | `Created` column with relative + tooltip absolute; nil renders as "—" (no fake "just now") |
| `feedback_autonomous` | ✅ | Implementer cron, strict-review cron, code-review cron, design-review cron all ran without prompting user for shell commands |
| `project_agent_collaboration` | ✅ | Reviewers consume `.implementation/*.md`; implementer consumes `.review_strict/_open_issues.md` by ID; cross-stream alignment cited in every review |
| `feedback_openclaw` | ⏭ deferred | 2 of N planned providers shipped (AgentJobsJson + LaunchdUser); OpenClaw provider deferred to post-v1 |
| `feedback_schedule_display` | ✅ | `LaunchdPlistReader` surfaces real `StartInterval`/`StartCalendarInterval` → `Schedule.humanizeCalendar` renders "daily at 09:00", "hourly at :05" — replaces hard-coded "always-on" placeholder |
| `feedback_documentation` | ✅ | README, CHANGELOG, architecture spec, sandbox decision doc, 14 cycle impl docs, .review-prompts; CHANGELOG entries cite line numbers |
| `feedback_auto_commit_push` | 🟡 partial | **Commit half:** healthy — pre-commit gate installed and fired successfully on cycles 11, 12, 13, 14. **Push half:** blocked — `menha_microsoft` credential receives 403 from `MashellHan/agent-jobs`. **9 commits local-only.** Not a code defect; requires user-side credential rotation. |

---

## Operational follow-up (non-code, post-DECLARE-DONE)

1. **Push the 9 local commits to `MashellHan/agent-jobs`** — rotate the GitHub credential (`menha_microsoft` → token with write access for `MashellHan/agent-jobs`), then `git push`. Pre-commit gate will not re-fire on push.
2. **Pause all four crons** — implementer, strict-review, code-review, design-review. The strict-review cron's iter-014 doc explicitly recommends stand-down. Each cron firing now will be a carbon copy.
3. **Optional cycle-15 maintenance** — close cosmetic L-009 (`command ?? nil`), DRY test XML literals (code-005 L9), add `Surface.hoverFill` semantic alias (design-004 D-L1). All ~15-min jobs, none gating.
4. **Pre-ship visual smoke** — verify `MenuBarLabel` SF Symbol contrast against light/dark menubar backgrounds (design-004 D-L11); verify `.regularMaterial` doesn't bleed across `Divider()`s (design-004 D-L12). Both ~30-second screenshot passes.

---

## How to verify

```bash
cd /Users/mengxionghan/.superset/projects/Tmp/agent-jobs/macapp/AgentJobsMac
swift build       # → Build complete (~1.7s)
swift test        # → 55/55 passing (~0.3s)
```

Or single-command:
```bash
bash /Users/mengxionghan/.superset/projects/Tmp/agent-jobs/scripts/build-mac.sh
```

---

## Sign-off

The agent-jobs Mac app is **shippable**. CRITICAL/HIGH/MEDIUM tiers have been
empty across all three review streams for ≥ 2 consecutive cycles. The
remaining LOW nits are documented in `.review_strict/_open_issues.md` and
explicitly marked as non-gating by the strict reviewer.

This file's existence signals to the implementer cron: **stop scheduling new
cycles** per `.review-prompts/implementer.md` ("Stop scheduling if
.implementation/COMPLETE.md exists").

— closed by implementation cycle 15 on 2026-04-20T13:40:00Z
