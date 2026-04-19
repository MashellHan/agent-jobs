# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|

### HIGH

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| H-003 | 002 | Build warning: stale `Invalid Resource 'Fixtures'` (already removed from Package.swift; cache may need `swift package clean`) | `.build/` cache | OPEN (cache only) |

### MEDIUM

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| M-001 | 002 | 顶层 README 5 行，缺架构概览 / 截图 / CHANGELOG | `macapp/AgentJobsMac/README.md` | OPEN |
| M-003 | 002 | `AgentJobsJsonProvider` 同步 IO 包在 async — 无超时/取消 | `AgentJobsJsonProvider.swift:24-29` | OPEN |
| M-004 | 002 | MenuBarPopoverView "Active Now" 无上限、"Scheduled Soon" prefix(5) 不对称 | `MenuBarViews.swift:80-90` | OPEN |

### LOW

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| L-002 | 002 | `DesignTokens.ResourceColor.cpu` 阈值缺注释 | `DesignTokens.swift` | OPEN |

---

## Resolved

| ID | Opened | Resolved | Title |
|----|--------|----------|-------|
| C-001 | 001 | 002 | Mac app 目录为空 — scaffold 完成（9 Swift files, 1067 SLOC） |
| C-002 | 001 | 002 | 缺设计文档 — `.implementation/macapp-architecture.md`、`sandbox-decision.md` 已建 |
| C-003 | 002 | 003 | `swift test` 0 测试可跑 — swift-testing dep added; 17/17 passing |
| C-004 | 002 | 003 | `ServiceRegistryViewModel.refresh()` stub — wired `ServiceRegistry` actor + auto-refresh loop |
| H-001 | 002 | 003 | `Schedule.cron` not human readable — `CronHumanizer.humanize()` covers 7 patterns + fallback |
| H-002 | 002 | 003 | Inspector Logs/Config dead-end — replaced with `ContentUnavailableView` |
| L-001 | 002 | 003 | sidebar "All" 项无 count — added inline count |
| M-002 | 002 | 003 | 缺 `MenuBarSummary` 单测 — 3 tests added (empty / bucketing / memory total) |
