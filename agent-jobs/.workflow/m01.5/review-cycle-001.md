# M01.5 Review Cycle 001

**Reviewer:** reviewer agent
**Date:** 2026-04-23
**Range:** `724ccce..HEAD` on `main` (commits a0b1bdf, fe538cb, a93f8cc, b92d405)
**Verdict:** **PASS** — score **94 / 100**
**Next phase:** TESTING (cycle 1)

## Build / test gates

- `swift build` — green (0.86s)
- `swift test` — green, **145/145** (was 111 pre-cycle)
- New tests: 10 (parser) + 7 (deduper) + 11 (provider behavioral) +
  1 (perf AC-P-02) + 4 (project-name helpers) + 2 (integration) ≈ 35 added
  (impl log claims 34 — close enough; not a defect).
- Coverage on new files (per impl-cycle-001 + spot-checked): all ≥ 80% AC-Q-03.

## Rubric (100 pts)

| Bucket | Max | Score | Notes |
|---|---|---|---|
| Spec / acceptance fidelity | 25 | 24 | All 15 ACs mapped to tests; behavior parity with TS |
| Architecture conformance | 20 | 19 | All planned files exist with stated roles; deduper signature matches arch.md exactly |
| Streaming correctness (AC-P-01) | 10 | 9 | `URL.lines` used in production reader; parser is `AsyncSequence`-based; no `Data(contentsOf:)` on JSONL files in prod path |
| Dedup correctness (AC-I-02) | 10 | 10 | Provider strips collisions, never emits durable copies; integration test proves single-emission |
| Concurrency / resource safety | 10 | 9 | `AsyncSemaphore(value: 8)` reused; TaskGroup fan-out bounded; small smell on `defer { Task { ... signal() } }` (see issue 1) |
| Test quality + coverage | 15 | 14 | Coverage healthy; one test is partly aspirational (issue 2) |
| Code hygiene (no Process/print/force-unwrap, file/func size, logging via os.Logger) | 10 | 9 | Clean. Minor perf nit on per-call `ISO8601DateFormatter` (issue 3) |
| **Total** | **100** | **94** | PASS threshold = 80 |

## Top issues (all NON-BLOCKING)

1. **Semaphore release inside `defer { Task { await semaphore.signal() } }`** in
   `ClaudeSessionCronProvider.parseAll` (line 162). Spawning a child Task from
   `defer` to issue `signal()` is correct (signal must be async), but the
   release is decoupled from the per-file Task's completion ordering. With
   only 8 in-flight slots and small file counts this is harmless, but a
   future reviewer may want to convert to a structured pattern (e.g.
   `await semaphore.signal()` immediately before `return`, removing `defer`).
   No test exercises a starvation scenario today. **Tester need not gate on this.**

2. **`traversalEntryIgnored` test is aspirational** — the inline comment admits
   FileManager won't surface `..` or `/` entries, so the guard at
   `ClaudeSessionCronProvider.swift:129` cannot be exercised end-to-end. The
   guard itself is fine (belt-and-suspenders, parity with TS). Consider
   either deleting the test or replacing it with a unit test on the guard
   logic in a follow-up — not blocking.

3. **`ISO8601DateFormatter` allocated per call** in `parseTimestamp`. With
   typical JSONL volumes this is fine; if profiling later shows hotness,
   cache a pair of formatters. Not blocking.

## Focus-area verification

- **Streaming (AC-P-01):** `defaultLineReader` wraps `url.lines` (Foundation
  `AsyncLineSequence`, macOS 14+) inside an `AsyncStream` continuation; no
  full-file load. `parse(lines:)` uses `for try await` over the sequence.
  Synchronous test helper `parse(text:)` does load a string but is
  test-only. ✓
- **Dedup precedence:** `discover()` builds `sessionTasks`, then calls
  `CronTaskDeduper.dedup(sessionCreates:durable:)` which **filters out** any
  session task whose `(cron, prompt[..<50])` matches a durable key. The
  durable list is read separately and never emitted by this provider —
  `ClaudeScheduledTasksProvider` retains ownership. Integration test
  `dedupAcrossProviders` confirms registry sees exactly one service. ✓
- **Concurrency cap:** `AsyncSemaphore(value: 8)` matches M01 pattern.
  TaskGroup of `ParsedFile?` collects bounded results. ✓
- **Coverage:** 90.83 / 100.00 / 96.50 — all ≥ 80%. ✓

## Decision

**PASS.** Transition to TESTING cycle 1. No re-implementation needed.
The 3 minor items above are tracked here for future cleanup; tester
should focus on AC verification per `acceptance.md`.
