# Implementation Agent — Operating Procedure

**Cadence:** every 15 minutes (autonomous loop)
**Mission:** Build the Mac app per `.implementation/macapp-architecture.md`. Each cycle: ingest reviews, fix issues, ship code, commit, push.

## Per-cycle workflow

1. **Read** the *latest* of ALL THREE review streams (only newer than last consumed):
   - `.review/code/code-NNN.md` (our internal code review)
   - `.design-review/design-NNN.md` (our internal design review)
   - `.review_strict/YYYY-MM-DD-HHMM-iter-NNN.md` (external strict review — **MANDATORY, NEVER SKIP**)
   - `.review_strict/_open_issues.md` (cross-iteration unresolved register — read every cycle)
2. Extract `Top 3 actions` from each stream → max 9 fixes/cycle.
   Strict-review CRITICAL items take absolute priority over our internal reviews.
3. **Triage**:
   - P0 → fix this cycle, no exceptions.
   - P1 → fix this cycle if time allows (≥ 10 min budget remaining).
   - P2 → defer to next cycle.
4. **Implement** with strict module boundaries (see architecture doc §2).
5. **Test**: run `swift test` (or `npm test` for the TS layer). Do NOT commit if red.
6. **Commit + push**: per `feedback_auto_commit_push.md`. Message format:
   ```
   feat(macapp): <module> <one-line summary>

   Addresses:
   - code-review NNN: <ids>
   - design-review NNN: <ids>
   - strict-review iter-NNN: <ids>
   ```
7. Update `.implementation/impl-<timestamp>.md` with what was done + what's next.
   Note which strict-review CRITICAL/HIGH items remain open and why.
8. If ALL THREE review streams report `DECLARE-DONE` (or strict-review has `_open_issues.md` empty) for 2 consecutive rounds AND tests green → write `.implementation/COMPLETE.md` and stop scheduling.

## Module ownership rotation

Each cycle, focus on ONE module to keep churn low:
- Cycle N mod 3 == 0 → Discovery layer (M2)
- Cycle N mod 3 == 1 → UI layer (M1)
- Cycle N mod 3 == 2 → Tests + polish

Override: if a P0 spans modules, fix it regardless.

## Conflict resolution

Priority order when reviews disagree:
1. **strict-review CRITICAL** (always wins)
2. **strict-review HIGH** (wins over internal reviews unless safety-critical)
3. **internal code-review P0** vs **design-review P0** → file a `Communication` block; prefer correctness over aesthetics if equal.
4. P1+ across streams — pick by ROI, document deferrals in impl doc.

Strict-review uses MEMORY-derived preferences (TUI design, history, schedule display, autonomous execution, openclaw, auto-commit). Treat those as ground truth.

## Resource budget

- Max 30 minutes wall-clock per cycle (graceful exit if over)
- Max 10 file edits per cycle (force focus)
- Always leave the build green
