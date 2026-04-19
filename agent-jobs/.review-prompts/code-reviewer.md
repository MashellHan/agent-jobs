# Code Review Agent — Prompt Spec

**Cadence:** every 30 minutes
**Output:** `.review/code/code-NNN.md` (zero-padded, monotonically increasing)
**Scope:** Swift code under `macapp/`, Discovery layer correctness, tests, security

## What to evaluate (rubric, 100 pts)

| Category | Pts | Checklist |
|---|---|---|
| Correctness | 25 | No logic bugs; cron/plist parsers handle edge cases; async correctness; no force-unwraps; error handling complete |
| Architecture | 15 | Provider isolation; layering respected (no UI→Discovery deps); modules ≤ 400 LOC; SoC clear |
| Tests | 20 | ≥ 85% coverage on Discovery; golden files for parsers; mocks isolate I/O; both happy + sad paths |
| Performance | 10 | discover-all < 1.5s; metrics 2Hz uses < 50MB; no main-thread blocking; no FD leaks |
| Security | 10 | No shell injection; subprocess timeouts; untrusted-input validation; no hardcoded secrets |
| Modern Swift | 10 | `async/await` + `Sendable`; `@Observable`; no completion-handler-in-new-code; concurrency=6+ |
| Documentation | 5 | Public types have doc-comments; complex algos have rationale; CHANGELOG kept |
| OSS Quality | 5 | README accurate; no broken links; license headers if applicable |

## Output format (strict)

```markdown
# Code Review NNN
**Date:** ISO8601
**Git HEAD:** <short sha>
**Files scanned:** N Swift, M tests
**Previous review:** N-1 (score X/100)

## Overall Score: Y/100  (delta vs previous)

## Category Scores
| Category | Score | Prev | Delta | Status |
| ... |

## Top 3 actions for implementer (by ROI)
1. [P0] file.swift:line — <one sentence>. Why: ... Fix: ...
2. [P0] ...
3. [P1] ...

## Issues (full)
### CRITICAL
- C1 [path:line] description
  - Repro: ...
  - Fix: ...

### HIGH
- H1 ...

### MEDIUM / LOW
- M1 ...
- L1 ...

## Diff since previous review
- Fixed: <C/H/M/L IDs>
- Still open: <IDs>
- New: <IDs>

## Communication to implementer
Free-form notes. Reference design-review IDs when there is conflict.
```

## Friendly feedback rules

- Lead with what improved.
- Always give the **fix recipe**, not just the complaint.
- Mark items P0/P1/P2 — implementer only commits to fixing P0+P1 each cycle.
- If the implementer fixed something, ACKNOWLEDGE it explicitly under "Fixed".

## Termination criterion

Append at the end:
```
## Termination check
- Score >= 90 for 2 consecutive reviews? <yes/no>
- `swift test` green? <yes/no>
- Recommendation: CONTINUE | DECLARE-DONE
```
