# Agent-Jobs Workflow

> Multi-agent autonomous development pipeline for the agent-jobs Mac app rewrite.

## Quick start

```
/status                # see where we are
/milestone-start       # begin M01 (only run once at bootstrap)
/tick                  # advance one phase
```

For autonomous mode: `/loop 15m /tick`

## Architecture

5 specialist agents + 1 meta agent, coordinated by a single state file:

| Agent | Phase | Role |
|---|---|---|
| `pm` | SPECCING | Competitive research, spec, acceptance criteria |
| `architect` | ARCHITECTING | Module design, task breakdown |
| `implementer` | IMPLEMENTING | Swift code, one commit per task |
| `reviewer` | REVIEWING | Hard gate: code quality + acceptance coverage |
| `tester` | TESTING | Hard gate: runs the actual app, screenshots, visual regression |
| `retrospective` | RETROSPECTIVE | Learns from each milestone, proposes prompt evolutions |

Phase machine: `SPECCING → ARCHITECTING → IMPLEMENTING ⇄ REVIEWING → TESTING ⇄ IMPLEMENTING → ACCEPTED → RETROSPECTIVE → next`

State lives in `.workflow/CURRENT.md`. Protocol details in `.workflow/PROTOCOL.md`.

## Commands

| Command | What |
|---|---|
| `/tick` | Read CURRENT.md, dispatch the right agent for the current phase. Idempotent. The main loop primitive. |
| `/status` | Show current milestone, phase, recent activity, blockers |
| `/milestone-start` | Bump to next milestone, set phase=SPECCING, dispatch PM |
| `/ship` | When phase=ACCEPTED: write RELEASED.md, dispatch retrospective |
| `/evolve` [--auto] | Apply PROPOSED prompt changes from EVOLUTION.md |
| `/unlock` | Force-release a stale lock (use when an agent crashed) |

## Why this design

This workflow combines two patterns we evaluated:

- **eye-guard pattern** (PM/Lead/Dev/Tester per version): good for greenfield, has clear termination, but waterfall and single-Lead bottleneck.
- **Old agent-jobs `.review-prompts/` pattern** (3 parallel review streams + module rotation): great evaluation depth but no PM and no termination — leading to the "13 post-DONE idle ticks" pathology in the previous iteration.

The new design takes:
- Milestones + acceptance gates from eye-guard (so the loop can actually stop)
- Multi-perspective evaluation from old agent-jobs (reviewer + tester are independent)
- A real PM with mandatory competitive research (so direction comes from product reality, not engineering preference)
- A real Tester that **runs the app** (not just static review) — addressing the gap that TUI-era reviews never caught actual UX bugs
- A retrospective + evolution mechanism so prompts improve from observed failures (not from human guesswork)

## Phase A → Phase B

This workflow is for **Phase A** (rewrite to v1.0). After M10 (v1.0 ship), we'll switch to **Phase B** continuous mode — likely a parallel multi-stream review (per the old `.review-prompts/`) but with PM still in the loop. The Phase B design will be authored during M10's retrospective.

## Legacy artifacts

The following directories from the previous TUI iteration are kept for reference but are no longer driven by this workflow:

- `.review/` — old code reviews
- `.review_strict/` — old strict reviews
- `.review-prompts/` — old prompt specs (source material for this workflow's design)
- `.implementation/` — old impl logs
- `.design-review/` — old design reviews
- `.brainstorm/` — old planning notes

Do not modify these. They are historical context for retrospectives.
