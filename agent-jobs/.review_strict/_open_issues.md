# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL
*(none — HEAD `838ba93`, build green, 38/38 tests)*

### HIGH
*(none)*

### MEDIUM
*(none — first empty MEDIUM table since project start; iter-012 cleanest cycle)*

### LOW

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| L-005 | 004 | `Shell.onCancel` 用 `DispatchQueue.global().asyncAfter` 做 SIGKILL，跳出 structured concurrency | `Shell.swift:107-117` | OPEN (nit) |
| L-006 | 004 | `AgentJobsJsonProvider.readWithTimeout` 内仍是 sync `Data(contentsOf:)` | `AgentJobsJsonProvider.swift:64-67` | OPEN (acceptable) |
| L-009 | 007 | `command: ""` 应为 `nil` 或哨兵值 | `LaunchdUserProvider.swift:91` | OPEN (nit) |

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
| H-004 | 007 | 008 | LaunchdUserProvider + 7 tests + ServiceRegistry/AgentJobsMacApp 修改全部未提交 — cycle-9 (`297aafb`) 作为单一 coherent commit 提交 |
| M-007 | 007 | 008 | `"No providers responded"` error 误报 — cycle-10 (`c67de9c`) 引入 `discoverAllDetailed() → DiscoverResult { allFailed }`，refresh() 仅在 `allFailed` 时翻 `.error` |
| M-005 | 006 | 010 | Commit-gate 未实装 — 经 4 轮挂账后 reviewer 在 iter-010 直接实装：`scripts/pre-commit-gate.sh` + `.claude/settings.json` PreToolUse `Bash(git commit:*)` hook，含"无 macapp 改动则跳过"优化 |
| M-006 | 007 | 011 | `LaunchdUserProvider` 合成 `Date()` createdAt — cycle-11 把 `Service.createdAt` 改为 `Date?`，launchd 传 `nil`，DashboardView 显示 `—` 不再撒谎 |
| M-008 | 008 | 011 | `DiscoverResult.allFailed` 测试覆盖 — cycle-11 在 `ServiceRegistryTests.swift` 加 4 个 test 覆盖 all-fail/partial/all-empty-success/empty-registry 全四象限 |
| M-009 | 010 | 011 | Implementer cron 停滞 — cycle-11 实证恢复：working tree 出现针对 M-006/M-008 的 coherent diff，build/test 38/38 |
| M-010 | 011 | 012 | Working-tree 未提交 — implementer cycle-11 提交 `838ba93`，pre-commit gate 首次实战触发并通过（swift build 1.55s + test 38/38） |
| L-007 | 007 | 012 | Launchd schedule 占位 `.onDemand` — cycle-12 引入 `LaunchdPlistReader` 解析 `~/Library/LaunchAgents/*.plist` 的 `StartInterval`/`StartCalendarInterval`，UI 现显示真实频率（"daily at 09:00"、"hourly at :05"…） |
| L-008 | 007 | 012 | `kind` 仅靠 PID — cycle-12 当 plist 含触发器（StartInterval/Calendar/WatchPaths）时强制 `.scheduled`，与 L-007 同 commit 修复 |
