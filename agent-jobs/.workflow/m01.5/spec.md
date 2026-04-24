# M01.5 Spec — Claude session-JSONL cron parser

## Goal
Port the legacy TS `scanSessionCronTasks` (src/scanner.ts:417–622) to Swift as a
new `ClaudeSessionCronProvider` that streams Claude session JSONL files,
computes the live `CronCreate − CronDelete` net set, and dedups against
`ClaudeScheduledTasksProvider`.

## TS source reference
- `src/scanner.ts:417-622` (`SessionCronTask`, `parseSessionJsonl`,
  `scanSessionCronTasks`, `scanDurableScheduledTasks`, `projectNameFromDir`,
  constants `JSONL_MAX_AGE_MS`, `SESSION_ACTIVE_WINDOW_MS`).

## Behavior to preserve
1. Walk `~/.claude/projects/*/<sessionId>.jsonl`; ignore directory-traversal entries.
2. Skip JSONL files whose mtime is older than 7 days (`JSONL_MAX_AGE_MS`).
3. Parse line-by-line (streaming, no full file load) — fast pre-filter on
   substring `CronCreate` / `CronDelete` / pending `tool_result`.
4. Match `CronCreate` `tool_use` → its `tool_result` by `tool_use_id`; record
   net `creates` map keyed by the result's `id` (the cron job id).
5. Add to `deletes` set on every `CronDelete` `tool_use` (input.id).
6. Emit a `Service` per `(create − delete)` pair with `status = .running`
   when session is active (mtime within 15 min) else `.idle`; cron schedule;
   project derived from `cwd` (last 2 path segments) or
   `projectNameFromDir(projDir)` fallback.
7. Dedup: drop session-derived services whose `(cron, prompt-prefix-50)`
   matches a `ClaudeScheduledTasksProvider` durable entry already in scope.
   The de-dup runs *inside* this provider — we read `scheduled_tasks.json`
   ourselves to compute the dedup key, but we **do not emit** durable
   services (those stay owned by `ClaudeScheduledTasksProvider`).
8. All filesystem / parse failures degrade silently to `[]`-or-skip; only
   timeouts on the durable read raise (parity with sibling provider).

## Out of scope
- Reconstructing run history from JSONL events (M02+).
- Live FS watching (M04 watchers slot).
- Reading non-Claude session formats.
- Modifying `ClaudeScheduledTasksProvider` itself.

## Open risks
- Very large JSONL files (10–30MB documented). Streaming via
  `FileHandle.bytes.lines` keeps memory bounded but still reads the whole
  file once. Acceptable: the 7-day window caps total scanned bytes.
- Dedup key collision: `(cron, prompt[..50])` could over-merge two real
  distinct tasks that share both. TS does the same thing; preserved.
- `Bundle.module` resource path inside nested `Fixtures/sessions/` —
  `FixtureLoader` already falls back to flat lookup; we'll verify.
