---
description: Mark current milestone shipped, write RELEASED.md, trigger retrospective.
allowed-tools: Read, Edit, Write, Bash, Task
---

Ship the current milestone.

1. Read `.workflow/CURRENT.md`. Verify `phase: ACCEPTED`. Refuse otherwise.
2. Read `.workflow/m{N}/test-cycle-NNN.md` (latest, must be PASS).
3. Write `.workflow/m{N}/RELEASED.md`:
   ```
   # M{N} Released
   **Date:** ISO8601
   **Final commit:** <git rev-parse HEAD>
   **Cycles:** IMPL=N REVIEW=M TEST=K

   ## Summary
   {one paragraph from spec.md "Goal"}

   ## Acceptance
   All {K} acceptance criteria PASS (see test-cycle-NNN.md).

   ## Deferred to future milestones
   {any P2 items, future-fold notes from impl/review}
   ```
4. Update CHANGELOG.md (new entry under "Unreleased" or new version section). One line per significant feature, link the milestone.
5. Update `.workflow/ROADMAP.md`: mark M{N} status as DONE.
6. Update CURRENT.md: `phase: RETROSPECTIVE`, `owner: null`, `last_actor: human`. Clear lock.
7. Commit:
   ```
   ship(M{N}): released

   - {one-line of milestone goal}
   - {N} ACs verified
   - {N} commits over {N} cycles
   ```
8. **Push** (this is the only push point in the workflow):
   ```bash
   git push origin main
   ```
   If push fails (rejected, network), do NOT force. Report and stop. Human resolves.
9. Dispatch `retrospective` agent via Task tool.
10. After retro returns, summarize and prompt: "Retro complete. Run /milestone-start when ready for M{N+1}."
