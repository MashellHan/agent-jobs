---
description: Show current workflow state — milestone, phase, owner, recent activity, blockers.
allowed-tools: Read, Bash, Glob
---

Print a concise status report:

1. Read `.workflow/CURRENT.md` frontmatter — show milestone, phase, cycle, owner, lock state.
2. Run `git log --oneline -10` and show last 5 commits matching the current milestone.
3. List most recent artifact in current m{N}/ directory (newest spec/architecture/impl/review/test file).
4. Check for STUCK files: `find .workflow -name "STUCK.md"` — surface any.
5. Show last EVOLUTION.md entry summary.

Output format (markdown, terse):

```
## Workflow status

**Milestone:** M{N} ({theme})
**Phase:** {phase}
**Cycle:** {cycle}
**Owner:** {owner or "free"}
**Lock:** {expires_at or "none"}

### Last 5 commits (M{N})
- ...

### Latest artifact
{file} ({mtime})

### Blockers
{none / STUCK files / open BASELINE_REVIEW}

### Last evolution
{E{NNN} — date — agent — status}
```
