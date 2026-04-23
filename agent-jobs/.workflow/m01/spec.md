# M01 — Discovery audit + gap fill

## Goal (one sentence)

Bring the Swift Discovery layer to behavioral parity with the legacy TypeScript scanner's four data sources — registered jobs, live listeners, Claude scheduled tasks, and launchd — so that everything the existing TUI can see, the Mac app can see, with the same level of failure isolation and bounded latency.

## User value (why now)

Today the Swift app only sees two of the four sources the TUI sees. A user who launches the menu-bar app and expects to see their `next dev`, their Claude `/cron` task, or their `npm start` background server gets an incomplete list, which silently undermines the app's reason to exist. M01 is the smallest milestone that closes this trust gap. Every later milestone (detail panel, actions, hooks, packaging) assumes Discovery is complete; specifying anything else first risks reworking it.

## Scope (in)

1. **New provider: `LsofProcessProvider`** — Swift port of `scanLiveProcesses` from `src/scanner.ts`.
   - Spawn `/usr/sbin/lsof -i -P -n -sTCP:LISTEN` via `Shell.run` with a 5 s default timeout.
   - Parse the multi-column output. Filter to the same set of relevant commands the TS scanner uses (`node`, `python`, `python3`, `go`, `ruby`, `java`, `deno`, `bun`, `uvicorn`, `gunicorn`, `tsx`).
   - Deduplicate on PID (same TS behavior).
   - For each surviving entry, resolve a "full command" string — the TS scanner does this with `ps -p <pid> -o args=`. Cap concurrency (see Constraints) so we don't fork-bomb a system with hundreds of listeners.
   - Map to `Service` with `source = .process(matched: <commandName>)`, `kind = .interactive`, `status = .running`, `pid`, and a friendly name derived from script filename / framework / agent (parity with `friendlyLiveName`).
   - Emit `ServiceOrigin.agent` when an agent can be inferred from the full command (parity with `inferAgent`: `claude-code`, `cursor`, `github-copilot`, `openclaw`).

2. **New provider: `ClaudeScheduledTasksProvider`** — Swift port of `scanClaudeScheduledTasks`.
   - Read `~/.claude/scheduled_tasks.json` using the same timeout-guarded read pattern `AgentJobsJsonProvider` already uses (`readWithTimeout`).
   - File missing or unreadable → return `[]`, do not throw (parity with TS).
   - File present but malformed JSON → log + return `[]`, do not throw (parity with TS).
   - File present with a non-array root → return `[]` (parity with TS).
   - For each entry, map `prompt` and `cron` strings to a `Service` with `source = .claudeScheduledTask(durable: true)`, `kind = .scheduled`, `status = .scheduled`, `schedule = .cron(<expr>)`, `owner = .agent(.claude)`, `name` derived from the prompt (cron-friendly truncation, ~6 words / 40 chars; pick a stable rule and document it).

3. **Wire both new providers** into `ServiceRegistry.defaultRegistry()` so they participate in the existing concurrent fan-out and failure-isolation. No changes to the `ServiceProvider` protocol or to the registry's public API are required (or permitted).

4. **Provenance fix on `LaunchdUserProvider`** — populate `Service.createdAt` from the plist file's `mtime` (matches TS `getFileMtime`). When the plist isn't found on disk, leave `createdAt = nil` (current behavior). This is a small enrichment, not a redesign of the provider.

5. **Tests** — see Acceptance for the binding list. Each new provider gets a unit-test file with at least: empty input, happy-path parse, malformed input, dedup behavior (lsof only), and timeout behavior (lsof only — invoke via injected `Runner`). All tests must run without touching the real filesystem or spawning real subprocesses (use the existing injection seams).

## Out of scope (explicit non-goals)

- **Session JSONL cron parsing** (`scanSessionCronTasks` in TS). It's the most complex source — streaming JSONL, 7-day age filter, 15-min active-session heuristic, dedup against `scheduled_tasks.json`. Defer to a follow-up (propose **M01.5 Session-cron parser** or fold into M02). The TS implementation in `src/scanner.ts:454-622` is the reference when that milestone lands. Not gating M01 on it preserves the milestone's "1–3 day equivalent" size.
- **Auto-refresh, `fs.watch`, debouncing.** Owned by M05. M01 must not introduce timers, polling, or file watches.
- **UI changes.** No SwiftUI files should be touched in M01. The new providers feed into the existing `ServiceRegistry`; the existing dashboard/menu-bar already render whatever the registry returns.
- **Actions (stop/kill/unload/hide).** Owned by M04. New providers must throw `ProviderError.unsupported` from `control(_:on:)` — the default implementation already does this; do not override.
- **Performance optimization beyond "good enough."** No caching layer, no incremental updates, no diffing. Discovery is one-shot.
- **Cron humanization changes.** `CronHumanizer` already exists; new providers should pass cron strings through unchanged and let the existing humanizer handle them.
- **`hidden.json` filtering.** The Mac app does not yet implement hide; deferred until M04.

## Constraints (tech, time, dependencies)

- **No new third-party dependencies.** Use Foundation + the existing `AgentJobsCore` types only. Stick with `swift-testing` for new tests (already in `Package.swift`).
- **Reuse `Shell.run`** for every subprocess; no direct `Process` use. Bounded by `Shell.defaultTimeoutSeconds = 5`.
- **`ps` fan-out concurrency cap.** When resolving full commands per lsof PID, cap to ≤ 8 concurrent `Shell.run` invocations (use a `TaskGroup` with a semaphore-style throttle). Prevents the TS scanner's worst-case "spawn one `ps` per listener" pathology on dev machines with hundreds of open ports.
- **No blocking on the main actor.** Providers are called from the `ServiceRegistry` actor and must remain `async`-safe; do not introduce any `DispatchQueue.main.sync` or `RunLoop.main.run` calls.
- **Failure isolation contract.** Throwing from a provider must continue to be caught and isolated by the registry (see `ServiceRegistry.discoverAllDetailed`). Do not change that behavior; do verify it still holds with the two new providers.
- **Schema parity with TS where it matters for users.** Field-level mapping (`source`, `status`, `schedule`, `agent` inference, friendly-name rules) must match the TS scanner's observable output for the same input. Where the Swift `Service` model has richer types (e.g. `.claudeScheduledTask(durable:)` vs the TS `source: "cron"` string), prefer the richer Swift form but ensure no observable regression in the existing UI.
- **Time bound.** Roughly a 1–2 day equivalent. If implementation exceeds two impl cycles without convergence, escalate per PROTOCOL.md.

## Open questions for architect

1. **Where do the two new files live?** The existing `Discovery/Providers/` layout suggests `LsofProcessProvider.swift` and `ClaudeScheduledTasksProvider.swift` siblings to the others. Confirm or propose an alternative.
2. **`ps` concurrency throttle pattern.** TaskGroup + counter, an `AsyncSemaphore` helper, or batching. Architect picks one and applies it consistently — the `Shell.run` API doesn't currently have a built-in throttle.
3. **Friendly-name truncation rule for Claude scheduled tasks.** Pick a stable, documented rule (the TS scanner uses `friendlyCronName`; we don't need to port that exactly, but we must commit to a deterministic rule the tests can pin).
4. **Should `LsofProcessProvider` populate `Service.metrics` (CPU/mem) or leave it `nil`?** TS does not. M01 default is `nil` to keep scope minimal; flag if the architect believes the cost of one extra `ps -o rss,%cpu` per surviving PID is justified.
5. **`createdAt` for `ClaudeScheduledTasksProvider` entries.** The JSON has no per-task timestamp. Options: (a) `nil`, (b) the file's `mtime`. TS uses `new Date().toISOString()` (lies about provenance). Recommend `nil` for honesty, but architect may prefer file `mtime` for sortability — pick one and apply consistently.
6. **Provider id naming.** Suggest `lsof.process` and `claude.scheduled-tasks` to match the existing dotted-namespace style (`agent-jobs.json`, `launchd.user`). Confirm in architecture doc.
7. **Test fixture management.** New providers need fixture files (sample `lsof` output, sample `scheduled_tasks.json`). Existing tests place fixtures inline; architect should confirm whether a `Tests/AgentJobsCoreTests/Fixtures/` directory with shared loader helpers is preferred for these larger payloads.
