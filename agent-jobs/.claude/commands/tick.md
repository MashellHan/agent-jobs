---
description: Inspect every tick — read CURRENT.md, dispatch the right agent for the current phase. Idempotent. Safe to run on /loop.
allowed-tools: Read, Bash, Task
---

You are running the workflow tick dispatcher.

## Procedure

1. Read `.workflow/CURRENT.md`.
2. Parse the YAML frontmatter to extract: `phase`, `owner`, `lock_expires_at`, `milestone`.
3. Decide what to do based on the phase + lock state:

| State | Action |
|---|---|
| `phase: BOOTSTRAPPING` | Print message: "Run /milestone-start to begin" and exit. |
| `owner != null` AND `lock_expires_at > now` | Print: "Lock held by {owner} until {expires}, waiting." Exit. |
| `owner != null` AND `lock_expires_at <= now` | Print: "Stale lock from {owner}. Will dispatch new agent." Continue to phase dispatch. |
| `phase: STUCK` | Print: "Workflow STUCK. See `.workflow/m{N}/STUCK.md`. Manual intervention required." Exit. |
| `phase: ACCEPTED` | Print: "M{N} accepted. Run /ship to release + start retrospective." Exit. |
| `phase: BASELINE_REVIEW` | Print: "Visual baselines need human approval. See `.workflow/m{N}/screenshots/`." Exit. |
| `phase: SPECCING` | Dispatch `pm` agent via Task tool. |
| `phase: ARCHITECTING` | Dispatch `architect`. |
| `phase: IMPLEMENTING` | Dispatch `implementer`. |
| `phase: REVIEWING` | Dispatch `reviewer`. |
| `phase: TESTING` | Dispatch `tester`. |
| `phase: RETROSPECTIVE` | Dispatch `retrospective`. |

4. When dispatching: launch the sub-agent via the Task tool with `subagent_type: "{agent-name}"`. The agent prompt has been pre-written; just give it the task: `"Tick: phase is {phase}, milestone is {milestone}. Read .workflow/CURRENT.md and PROTOCOL.md, do your one cycle, transition state, commit."`

5. After the sub-agent returns, briefly summarize what it did (one sentence) and exit. Do NOT dispatch another agent in the same tick — that's the next tick's job. This keeps each tick simple and observable.

## Examples

```
$ /tick
[CURRENT.md] phase=IMPLEMENTING owner=null milestone=M03 cycle=2
Dispatching implementer...
[implementer returned] Completed task T05 — added LiveProcessProvider; tests green; transitioned phase to IMPLEMENTING (1 task remaining).
```

```
$ /tick
[CURRENT.md] phase=ACCEPTED owner=null milestone=M02
M02 accepted. Run /ship to release + start retrospective.
```

## Anti-patterns

- Do NOT skip the lock check.
- Do NOT call multiple agents per tick.
- Do NOT modify CURRENT.md yourself — only the dispatched agent does.
