# Competitive Analysis — M01

> Theme: Discovery audit + gap fill (parity with the legacy TS scanner).
> Focus: how comparable open-source macOS menu-bar apps **discover** and **refresh** the things they monitor — process listeners, launchd jobs, AI-agent state.
> All data fetched 2026-04-23 via `gh api` and WebFetch.

## Products surveyed

| Product | URL | License | Stars | Last push | Relevance to M01 |
|---|---|---|---|---|---|
| Stats (exelban) | https://github.com/exelban/stats | MIT | 38,231 | 2026-04-22 | Reference for menu-bar density, popover pattern, multi-source aggregation discipline. Not direct competitor (system metrics, not jobs). |
| Ports (ChaosCoder) | https://github.com/ChaosCoder/Ports | MIT | 11 | 2022-08-27 | Direct overlap with our **live process** source: `lsof`-style listening-port discovery + per-row kill. Stale repo but pattern is solid. |
| MacPorts (KevLehman) | https://github.com/KevLehman/MacPorts | MIT | 1 | 2026-03-30 | Recent, tiny. Same "open ports → menu-bar list → kill" pattern. Confirms the niche is too narrow on its own — agent-jobs unifies more sources. |
| pylaunchd (glowinthedark) | https://github.com/glowinthedark/pylaunchd | Apache-2.0 | 74 | 2024-11-23 | Reference for launchd discovery surface (user/system/GUI domains, properties shown). Python, not Swift, but the data model is reusable. |
| spotlightishere/launchcontrol | https://github.com/spotlightishere/launchcontrol | MIT | 13 | 2022-05-07 | Native launchd GUI experiment in Swift — abandoned. Confirms there is **no** mature OSS Swift launchd manager; we are not duplicating prior art. |
| Claude-Usage-Tracker (hamed-elfayome) | https://github.com/hamed-elfayome/Claude-Usage-Tracker | MIT | 2,227 | 2026-04-21 | Closest "AI-agent menu-bar" peer in Swift/SwiftUI. Refresh + popover patterns are directly applicable. Does **not** parse `~/.claude` JSONL — uses API. |
| SwiftBar | https://github.com/swiftbar/SwiftBar | MIT | 4,004 | 2026-04-04 | Plugin host. Reference for menu-bar item lifecycle on modern macOS. Not a feature competitor. |
| LangSmith / Helicone (web tools) | https://www.langchain.com/langsmith/observability , https://www.helicone.ai/ | proprietary SaaS | n/a | n/a | Proves there is demand for AI-agent observability, but cloud-side. They do **not** see locally-spawned dev processes — that gap is exactly our wedge. |

## Feature matrix

Legend: ✓ = present, · = absent, ~ = partial, ? = unknown.

| Feature | Stats | Ports | pylaunchd | Claude-Usage-Tracker | We have today | Plan for M01? |
|---|---|---|---|---|---|---|
| Menu-bar entry + popover | ✓ | ✓ | · | ✓ | ✓ | n/a (UI not in scope) |
| Discover registered jobs from JSON file | · | · | · | · | ✓ (`AgentJobsJsonProvider`) | Hardening only |
| Live process scan via `lsof` | · | ✓ | · | · | **·** | **✓ add `LsofProcessProvider`** |
| Per-listener port + PID + command | · | ✓ | · | · | · (Service has fields, no provider populates them) | ✓ via lsof provider |
| Read `launchctl list` (user domain) | · | · | ✓ | · | ✓ (`LaunchdUserProvider`) | Already adequate |
| Enrich launchd from on-disk plist | · | · | ✓ | · | ✓ (`LaunchdPlistReader`) | Add file-mtime as `createdAt` |
| Read Claude `scheduled_tasks.json` | · | · | · | ~ (uses API instead) | **·** | **✓ add `ClaudeScheduledTasksProvider`** |
| Parse Claude session JSONL for cron | · | · | · | · | · | Out of scope (M01) — defer |
| Auto-refresh on interval | ✓ | ? | ? | ✓ (5–300s configurable) | partial (UI-driven) | Out of scope (M05 owns this) |
| `fs.watch` on source files | · | · | · | · | · | Out of scope (M05) |
| Per-row kill / unload | · | ✓ | · | · | · | Out of scope (M04) |
| Concurrent provider fan-out | n/a | n/a | n/a | n/a | ✓ (TaskGroup in `ServiceRegistry`) | Maintain |
| Per-provider failure isolation | ? | ? | ? | ? | ✓ | Maintain |
| Subprocess timeout/kill | ? | ? | ? | ? | ✓ (`Shell.run` 5s default) | Reuse for new providers |

## Gaps we should fill (this milestone)

1. **Live process scan (`lsof -i -P -n -sTCP:LISTEN`).** This is the source that gives the app its "what is actually running on my machine right now" value. The TS scanner has it (`scanLiveProcesses`), the Swift app does not. Without it we surface only declared/scheduled jobs and miss dev servers, agent loops, etc.
2. **Claude `~/.claude/scheduled_tasks.json` reader.** Smallest of the four sources but mandatory: every Claude Code user with durable cron tasks has this file. The TS scanner reads it (`scanClaudeScheduledTasks` / `scanDurableScheduledTasks`); the Swift app does not.
3. **Provider registration of the two new sources in `ServiceRegistry.defaultRegistry()`** so the existing aggregation/failure-isolation contract automatically covers them.
4. **`createdAt` provenance for launchd jobs** via the plist file's `mtime` (TS scanner does this in `getFileMtime`; the Swift `LaunchdUserProvider` currently passes `nil` and the UI shows "—").

## Patterns worth borrowing

- **Stats**: keep menu-bar widgets narrow, push detail into the popover. (Not directly M01 work, but informs how Discovery latency budgets are framed: discovery must finish fast enough that opening the popover never blocks.)
- **Claude-Usage-Tracker**: configurable refresh interval with sane default (5s–120s), debounced wake-from-sleep refresh, and a usage cache that renders instantly while the next refresh runs in the background. We should design Discovery so it's safe to call concurrently and cheap enough for short intervals — even though M05 owns the auto-refresh wiring.
- **Ports / MacPorts**: the canonical command for listener discovery is `lsof -i -P -n -sTCP:LISTEN`. The TS scanner already uses this exact form; the Swift port should match it byte-for-byte to preserve behavior.
- **pylaunchd**: surfaces user/system/GUI domains separately. We deliberately scope to user-domain only (matches TS scanner and the actual user need — agent jobs are user-level), but the separation pattern is good if we ever expand.
- **`ServiceRegistry` + `Shell` already implement** the right pattern for a provider plug-in: argv-only subprocess, timeout, and isolated per-provider failure. New providers in M01 must reuse `Shell.run` and not call `Process` directly.

## Anti-patterns observed (avoid)

- **`spotlightishere/launchcontrol`** stalled at 13 stars and 4 years untouched. Its README explicitly says "Hardly any functionality comparable to launchctl is implemented." Lesson: do not build a generic launchd UI; build a focused job/agent surface that happens to read launchd.
- **Stats** mentions "the most inefficient modules are Sensors and Bluetooth … up to 50%" CPU. Lesson: every refresh must be cheap. Avoid spawning subprocesses inside an inner loop. The TS scanner makes this mistake (`getFullCommand` calls `ps -p <pid>` once **per `lsof` row**); the Swift port should batch where reasonable, or at minimum cap concurrency.
- **Claude-Usage-Tracker** chose to *not* parse local JSONL and instead authenticate to Claude's API. We are doing the opposite: we read what's on disk. Lesson: deferring the JSONL parser to a later milestone is defensible — it's the most complex parsing surface (15-min active window, durable vs session-only, dedup against `scheduled_tasks.json`) and warrants its own milestone.
- The TS `loader.ts` watches **three** files (`jobs.json`, `hidden.json`, `~/.claude/scheduled_tasks.json`) with debounced `fs.watch`. M01 must not implement this — auto-refresh is M05 — but the M01 spec should ensure the new providers expose a stable enough seam that M05 can wrap them without reshaping the registry.
