# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL
*(none — build green at d5764a5, 27/27 tests)*

### HIGH
*(none)*

### MEDIUM

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| M-005 | 006 | Commit-gate 未实装 — implementer 自律修复 C-005，但下一次 stale-cache 仍会重现 iter-005 的"谎称 passing" | `.claude/settings.json` PreToolUse / implementer loop | OPEN |

### LOW

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| L-005 | 004 | `Shell.onCancel` 用 `DispatchQueue.global().asyncAfter` 做 SIGKILL，跳出 structured concurrency | `Shell.swift:107-117` | OPEN (nit) |
| L-006 | 004 | `AgentJobsJsonProvider.readWithTimeout` 内仍是 sync `Data(contentsOf:)` | `AgentJobsJsonProvider.swift:64-67` | OPEN (acceptable) |

---

## Resolved

| ID | Opened | Resolved | Title |
|----|--------|----------|-------|
| C-001 | 001 | 002 | Mac app 目录为空 — scaffold 完成 |
| C-002 | 001 | 002 | 缺设计文档 |
| C-003 | 002 | 003 | `swift test` 0 测试 — 25/25 passing |
| C-004 | 002 | 003 | `ServiceRegistryViewModel.refresh()` stub |
| H-001 | 002 | 003 | `Schedule.cron` not human readable |
| H-002 | 002 | 003 | Inspector dead-end |
| H-003 | 002 | 003 | Build warning Fixtures |
| M-001 | 002 | 003 | README expanded |
| M-002 | 002 | 003 | `MenuBarSummary` tests |
| M-004 | 002 | 003 | MenuBar 不对称 |
| L-001 | 002 | 003 | sidebar "All" count |
| L-002 | 002 | 003 | `ResourceColor` 阈值 doc |
| M-003 | 002 | 004 | Provider read timeout |
| L-003 | 003 | 004 | `CronHumanizer.dayName` 注释 |
| L-004 | 003 | 004 | `swift-tools-version: 6.0` |
| C-005 | 005 | 006 | `StatusBadge` 重复声明 — cycle-8 删除 `DashboardView.swift:119` 旧定义 |
| C-006 | 005 | 006 | Implementer commit 流程缺 build/test gate — 本轮 implementer 自律修复，但流程层降级为 M-005 |
