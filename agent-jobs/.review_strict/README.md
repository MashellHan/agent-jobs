# Strict Code Review — agent-jobs → Mac App rewrite

## Purpose

隔壁 agent team 正在把 `agent-jobs` 从 Go/TUI 改写为原生 macOS app（位于 `macapp/AgentJobsMac/`）。
本目录存放严格的、连续迭代的 review 报告，每 30 分钟一次。

## Scope

每次 review 必须覆盖：

1. **UX / Design**
   - 是否符合 macOS Human Interface Guidelines (HIG)
   - 信息层级、导航模式（NavigationSplitView vs Tab）
   - 状态可见性（4 个 source 同时刷新时如何呈现）
   - Inline detail expansion（继承自 TUI 偏好，见 MEMORY: feedback_tui_design）
   - 可见的 auto-refresh 指示（见 MEMORY: feedback_tui_design）
   - Created_at 在表格 / 友好 history 在 detail（见 MEMORY: feedback_tui_history）

2. **架构 / 后端 Code Design**
   - 4 数据源聚合的并发模型（Swift Concurrency / actor / Combine？）
   - 与原 Go 项目的数据契约一致性（registered/live/cron/launchd）
   - PostToolUse hook 仍是 Node — Swift 端如何消费 `~/.claude/...` 数据
   - `lsof`、`launchctl`、`plutil` 调用是否安全（沙盒、权限、超时、parsing）
   - 错误传播、取消、重试
   - Schedule 显示按真实频率（见 MEMORY: feedback_schedule_display）

3. **Quality Gates**
   - 测试覆盖（单元 / 集成 / UI）≥ 80%
   - 无硬编码 secret、无 force-unwrap、无主线程阻塞
   - 文件 < 800 行、函数 < 50 行
   - 无新增依赖未经评估

4. **进度 vs 上一轮**
   - 检查上一轮 CRITICAL / HIGH 是否已修复
   - 标记新引入的 regression
   - 累积未解决问题清单

## File naming

`YYYY-MM-DD-HHMM-iter-NNN.md` — 时间戳 + 迭代号

## Severity

| Level | 含义 | 行动 |
|-------|------|------|
| CRITICAL | 安全漏洞、数据丢失、架构走偏 | BLOCK |
| HIGH | bug、明显走偏 HIG、违反 MEMORY 偏好 | WARN |
| MEDIUM | 可维护性、风格 | INFO |
| LOW | nit | NOTE |

## Cross-iteration tracking

`_open_issues.md` — 跨迭代的未解决问题登记册，每轮 review 末尾更新。
