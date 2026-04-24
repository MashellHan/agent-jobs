# M01.5 Acceptance Criteria

## Functional (parse correctness)
- AC-F-01: A JSONL fixture with one `CronCreate` (tool_use + matching
  tool_result) yields exactly one `creates` entry keyed by the result's `id`.
- AC-F-02: A JSONL fixture with `CronCreate` followed by `CronDelete` of the
  same id yields **zero** services from that file.
- AC-F-03: A JSONL fixture mixing two creates and one unrelated delete
  yields exactly two services.
- AC-F-04: Files older than 7 days (mtime) are skipped (yield nothing).
- AC-F-05: Malformed JSON lines are skipped silently; surrounding valid
  lines still parse.
- AC-F-06: `Service.status == .running` when session mtime ≤ 15 min;
  `.idle` otherwise.
- AC-F-07: `Service.project` derives from `cwd` (last 2 path segments) when
  `cwd` is non-empty; falls back to `projectNameFromDir(projDir)`.
- AC-F-08: `Service.id` is stable across two `discover()` calls on the same
  fixture set.

## Performance
- AC-P-01: Streaming — `parseLines` is invoked with an `AsyncSequence<String>`
  and never reads more than 64KB of any single line at once (no
  `Data(contentsOf:)` on a JSONL file in production code path).
- AC-P-02: Parsing a synthetic 10,000-line JSONL (≈ 1MB) completes in
  < 500 ms on the test host.

## Quality
- AC-Q-01: `swift build` green.
- AC-Q-02: `swift test` green; ≥ 12 new test cases.
- AC-Q-03: Line coverage ≥ 80% on each new file under
  `Discovery/Providers/ClaudeSessionCron*` (measured via
  `swift test --enable-code-coverage`).
- AC-Q-04: No `Process()`, no force-unwraps (`!` in test fixtures excluded),
  no `print()` in new sources; subprocesses (none expected) would go via
  `Shell` only.
- AC-Q-05: Each new file ≤ 400 LOC, each function ≤ 50 LOC.

## Integration
- AC-I-01: `ServiceRegistry.defaultRegistry().providerCount == 5`.
- AC-I-02: An end-to-end test with both `ClaudeScheduledTasksProvider` and
  `ClaudeSessionCronProvider` in a registry, where the JSONL session fixture
  contains a durable cron whose `(cron, prompt-prefix-50)` matches a
  `scheduled_tasks.json` entry, yields the durable copy **once** (not twice).
- AC-I-03: When `~/.claude/projects/` does not exist, the provider returns
  `[]` without throwing.
