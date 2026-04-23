---
description: Apply pending PROPOSED evolutions from EVOLUTION.md to agent prompts. Use --auto to skip confirmation.
allowed-tools: Read, Edit, Write, Bash
argument-hint: [--auto]
---

Process workflow evolution proposals.

1. Read `.workflow/EVOLUTION.md`.
2. Find all entries with `Status: PROPOSED`.
3. For each proposal:
   - Show the rationale and diff to the user.
   - If `$ARGUMENTS` contains `--auto`: apply without asking.
   - Otherwise: ask user (one at a time): "Apply E{NNN}? (y/n/skip)"
   - On apply:
     - Edit the target `.claude/agents/{name}.md` with the diff
     - Update EVOLUTION.md entry: `Status: APPLIED` + add `Applied at: <ISO8601>`
4. Commit applied changes:
   ```
   evolve: applied E{NNN1}, E{NNN2}, ...

   - {agent}: {one-line of change}
   ```
5. Print summary: N applied, M skipped, K still pending.

## When to run

- After every 3 milestones (rough cadence)
- When retros pile up uncommitted evolutions (≥ 5 PROPOSED)
- Manually after a notable failure that yielded a clear lesson
