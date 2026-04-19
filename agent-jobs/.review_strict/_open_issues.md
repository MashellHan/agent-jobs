# Open Issues Register — agent-jobs Mac App rewrite

> 跨迭代追踪未解决问题。每轮 review 完成后更新此文件。

## Open

### CRITICAL
*(none — build green at e53dbd6 + uncommitted feature work, 34/34 tests)*

### HIGH

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| H-004 | 007 | `LaunchdUserProvider` + 7 tests + `ServiceRegistry`/`AgentJobsMacApp` 修改全部 **未提交** — 直接证实 M-005 失效 | `git status` (working tree) | OPEN |

### MEDIUM

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| M-005 | 006 | Commit-gate 未实装 — implementer 自律修复 C-005，但下一次 stale-cache 仍会重现 iter-005 的"谎称 passing" | `.claude/settings.json` PreToolUse / implementer loop | OPEN (now demonstrably needed — H-004) |
| M-006 | 007 | `LaunchdUserProvider` 用 `Date()` 合成 `createdAt`，违反 feedback_tui_history 的"真实注册时间"偏好 | `LaunchdUserProvider.swift:84` | OPEN |
| M-007 | 007 | `"No providers responded"` error 在合法的"无服务"场景误报 — 应跟踪每个 provider 的 success/fail 而不是仅看结果是否为空 | `AgentJobsMacApp.swift:60` | OPEN |

### LOW

| ID | Iter opened | Title | File / location | Status |
|----|-------------|-------|-----------------|--------|
| L-005 | 004 | `Shell.onCancel` 用 `DispatchQueue.global().asyncAfter` 做 SIGKILL，跳出 structured concurrency | `Shell.swift:107-117` | OPEN (nit) |
| L-006 | 004 | `AgentJobsJsonProvider.readWithTimeout` 内仍是 sync `Data(contentsOf:)` | `AgentJobsJsonProvider.swift:64-67` | OPEN (acceptable) |
| L-007 | 007 | Launchd `.schedule = .onDemand` — 没解析 calendar/interval plist，违反 feedback_schedule_display | `LaunchdUserProvider.swift:88` | OPEN (defer) |
| L-008 | 007 | `kind: .daemon vs .scheduled` 仅靠 PID 判断 — 同 L-007 根因 | `LaunchdUserProvider.swift:87` | OPEN (defer) |
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
