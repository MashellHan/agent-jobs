# M01.5 Architecture (light)

Streamlined arch decisions; bigger context lives in M01 architecture.md.

## New files

| Path | Role |
|---|---|
| `Sources/AgentJobsCore/Discovery/Providers/SessionJSONLParser.swift` | Pure: take an `AsyncSequence<String>` of lines → `(creates, deletes)` |
| `Sources/AgentJobsCore/Discovery/Providers/CronTaskDeduper.swift` | Pure: merge session creates with durable list; drop dups |
| `Sources/AgentJobsCore/Discovery/Providers/ClaudeSessionCronProvider.swift` | `ServiceProvider` conformance; FS walk + streaming + emit |
| `Tests/AgentJobsCoreTests/SessionJSONLParserTests.swift` | T01 |
| `Tests/AgentJobsCoreTests/CronTaskDeduperTests.swift` | T02 |
| `Tests/AgentJobsCoreTests/ClaudeSessionCronProviderTests.swift` | T03 |
| `Tests/AgentJobsCoreTests/Fixtures/sessions/single-create.jsonl` | T01 fixture |
| `Tests/AgentJobsCoreTests/Fixtures/sessions/create-then-delete.jsonl` | T01 fixture |
| `Tests/AgentJobsCoreTests/Fixtures/sessions/mixed.jsonl` | T01 fixture |

## Modify
- `Sources/AgentJobsCore/Discovery/ServiceRegistry.swift` —
  `defaultRegistry()` adds `ClaudeSessionCronProvider()`.
- `Tests/AgentJobsCoreTests/ServiceRegistryTests.swift` —
  `providerCount == 5`.

## Decisions

1. **Streaming.** Use `URL.lines` (Foundation `AsyncLineSequence` on macOS 14+)
   so memory stays bounded. The parser takes any
   `AsyncSequence where Element == String` for testability.
2. **Concurrency.** Reuse the existing `AsyncSemaphore(value: 8)`. The
   provider walks projects sequentially but fans out per-file `parse` jobs
   inside a `TaskGroup` capped at 8 in-flight to bound disk pressure on
   large `~/.claude/projects/` trees.
3. **Dedup helper signature:**
   `CronTaskDeduper.dedup(sessionCreates:[SessionCronTask], durable:[(cron:String,prompt:String)]) -> [SessionCronTask]`
   Returns the session creates **minus** any that collide with a durable
   entry on `(cron, prompt[..<50])`.
4. **Owner.** Provider does NOT own emitting durable scheduled tasks —
   `ClaudeScheduledTasksProvider` keeps that. M01.5 only emits *session-derived*
   services after dedup. The dedup-source list is read directly off
   `~/.claude/scheduled_tasks.json` (same path constant) so the two providers
   can run independently in `defaultRegistry()`.
5. **No `Process()`, no `print()`.** Logging via `os.Logger`.
6. **Service.source.** Use `.claudeLoop(sessionId:)` — closest existing
   variant; the session id is meaningful here.
   `Service.kind == .scheduled`. `owner == .agent(.claude)`.
   `origin == ServiceOrigin(agent: .claude, sessionId:, toolName: "CronCreate")`.
7. **ID scheme.** `claude.session-cron:<sessionPrefix8>:<cronJobId>` —
   stable across calls (matches TS `cron-<sessionId8>-<cronId>` shape).

## Concurrency model recap
```
discover()
  ├─ list ~/.claude/projects/*  (FileManager)
  ├─ for each project: list *.jsonl, filter by mtime
  ├─ TaskGroup ⨯ AsyncSemaphore(8)
  │     └─ per-file: URL.lines → SessionJSONLParser.parse → [SessionCronTask]
  ├─ flatten
  ├─ read scheduled_tasks.json (best-effort) → [(cron, prompt)]
  ├─ CronTaskDeduper.dedup(...)
  └─ map → Service[]
```
