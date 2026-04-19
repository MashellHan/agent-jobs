# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL
*(none)*

### HIGH

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| H-003 | 002 | Build warning: stale `Invalid Resource 'Fixtures'` (Package.swift fixed; cache only — needs `swift package clean`) | `.build/` cache | OPEN (cache only) |

### MEDIUM

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| M-003 | 002 | `AgentJobsJsonProvider` 同步 IO 包在 async — 无超时/取消 | `AgentJobsJsonProvider.swift:24-29` | OPEN |

### LOW
*(none)*

---

## Resolved

| ID | Opened | Resolved | Title |
|----|--------|----------|-------|
| C-001 | 001 | 002 | Mac app 目录为空 — scaffold 完成 |
| C-002 | 001 | 002 | 缺设计文档 — `.implementation/macapp-architecture.md`、`sandbox-decision.md` 已建 |
| C-003 | 002 | 003 | `swift test` 0 测试可跑 — 17/17 passing |
| C-004 | 002 | 003 | `ServiceRegistryViewModel.refresh()` stub — wired ServiceRegistry actor |
| H-001 | 002 | 003 | `Schedule.cron` not human readable — `CronHumanizer` |
| H-002 | 002 | 003 | Inspector Logs/Config dead-end — `ContentUnavailableView` |
| L-001 | 002 | 003 | sidebar "All" 项无 count — added |
| M-002 | 002 | 003 | 缺 `MenuBarSummary` 单测 — 3 tests added |
| M-001 | 002 | 004 | README expansion — architecture diagram + modules + status table |
| M-004 | 002 | 004 | MenuBar sections 不对称 — symmetric `prefix(8)` + differentiated empty copy |
| L-002 | 002 | 004 | `DesignTokens.ResourceColor` 阈值缺注释 — doc comments added |
