---
description: Begin a new milestone. Sets phase to SPECCING and dispatches PM agent.
allowed-tools: Read, Edit, Write, Bash, Task
---

Start the next milestone (or M01 if currently in BOOTSTRAPPING).

1. Read `.workflow/CURRENT.md`.
2. Verify phase is one of: `BOOTSTRAPPING`, `RETROSPECTIVE` (just finished), or fresh start. Refuse if there is an active milestone in any other phase (instruct user to use /tick or /ship).
3. Determine next milestone number:
   - If BOOTSTRAPPING: M01
   - Else: previous milestone + 1
4. Create directory: `mkdir -p .workflow/m{NN}/screenshots/baseline`
5. Update `.workflow/CURRENT.md` frontmatter:
   - `milestone: M{NN}`
   - `phase: SPECCING`
   - `cycle: 1`
   - `owner: null`
   - clear lock fields
   - `last_transition: <now>`
   - `last_actor: human`
6. Commit the bump:
   ```
   chore(M{NN}): start milestone — phase SPECCING
   ```
7. Dispatch `pm` agent via Task tool with prompt: "M{NN} is starting. Read .workflow/CURRENT.md and PROTOCOL.md. Do your full SPECCING phase: audit existing code, run competitive research, write spec.md / competitive-analysis.md / acceptance.md, transition phase to ARCHITECTING."
8. Print the PM's summary.
