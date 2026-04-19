# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL
*(none)*

### HIGH
*(none)*

### MEDIUM
*(none)*

### LOW
*(none)*

---

## Resolved

| ID | Opened | Resolved | Title |
|----|--------|----------|-------|
| C-001 | 001 | 002 | Mac app 目录为空 — scaffold 完成 |
| C-002 | 001 | 002 | 缺设计文档 — `.implementation/macapp-architecture.md`、`sandbox-decision.md` 已建 |
| C-003 | 002 | 003 | `swift test` 0 测试 — 22/22 passing |
| C-004 | 002 | 003 | `ServiceRegistryViewModel.refresh()` stub — wired `ServiceRegistry` actor |
| H-001 | 002 | 003 | `Schedule.cron` not human readable — `CronHumanizer` 7 patterns |
| H-002 | 002 | 003 | Inspector Logs/Config dead-end — `ContentUnavailableView` |
| H-003 | 002 | 003 | Build warning Fixtures — 当前 build 无 warning |
| M-001 | 002 | 003 | README 5 行 — 重写 106 行 |
| M-002 | 002 | 003 | 缺 `MenuBarSummary` 测试 — 3 cases |
| M-004 | 002 | 003 | MenuBar sections 不对称 — symmetric `prefix(8)` |
| L-001 | 002 | 003 | sidebar "All" 项无 count |
| L-002 | 002 | 003 | `DesignTokens.ResourceColor` 阈值无注释 |
| M-003 | 002 | 004 | `AgentJobsJsonProvider` 同步 IO 无超时 — `readWithTimeout()` race + 5s cap |
| L-003 | 003 | 004 | `CronHumanizer.dayName` 8-element off-by-one — comment explaining cron 0/7 = Sunday |
| L-004 | 003 | 004 | `swift-tools-version: 5.9` — bumped to 6.0 |
