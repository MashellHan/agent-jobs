# Workflow Protocol

> Single source of truth for how agents coordinate. Every agent reads this on start.

## Phase State Machine

```
SPECCING ─▶ ARCHITECTING ─▶ IMPLEMENTING ─▶ REVIEWING ─▶ TESTING ─▶ ACCEPTED
   │             │               ▲              │            │          │
   │             │               └──────────────┘            │          │
   │             │            (review found issues)          │          │
   │             │                                            │          │
   │             │                                            ▼          │
   │             └────────── (arch needs revision) ─── back to ARCH       │
   │                                                                      │
   └────── (PM milestone change) ────────────────────────────────────────▶│
                                                                          ▼
                                                              RETROSPECTIVE
                                                                          │
                                                                          ▼
                                                                NEXT MILESTONE
                                                                  (or PAUSED)
```

## Agent ↔ Phase Mapping

| Phase | Owner agent | Reads | Writes |
|---|---|---|---|
| SPECCING | `pm` | ROADMAP, prior milestone retro, web (competitive) | `m{N}/spec.md`, `m{N}/competitive-analysis.md`, `m{N}/acceptance.md` |
| ARCHITECTING | `architect` | spec, existing code | `m{N}/architecture.md`, `m{N}/tasks.md` |
| IMPLEMENTING | `implementer` | tasks, prior review feedback | code + `m{N}/impl-cycle-NNN.md` |
| REVIEWING | `reviewer` | diff since milestone start, architecture, tasks | `m{N}/review-cycle-NNN.md` |
| TESTING | `tester` | acceptance criteria, built app | `m{N}/test-cycle-NNN.md` + screenshots/baselines |
| ACCEPTED | (none — `/ship` command) | all of m{N} | `m{N}/RELEASED.md`, ROADMAP update |
| RETROSPECTIVE | `retrospective` | all of m{N} artifacts | `m{N}/retro.md`, `EVOLUTION.md` proposals |

## Coordination Rules

1. **CURRENT.md is the only source of truth for state.** Agents must not infer phase from filesystem.
2. **One owner at a time.** Lock is set in CURRENT.md frontmatter. TTL = 30 min default. Expired locks may be stolen with a recorded reason.
3. **Wrong phase = silent exit.** If an agent runs but the current phase doesn't match its role, it logs one line and exits. No work. No commits.
4. **Phase transitions are atomic.** Owner agent's last action is to update CURRENT.md frontmatter (phase + owner=null + lock cleared) in the same tool call as its final artifact write where possible.
5. **Cycle counter increments on re-entry.** REVIEWING cycle 002 means second time entering REVIEW for this milestone (because IMPL had to redo).
6. **Agents do NOT modify other agents' artifacts.** Reviewer doesn't edit code. Implementer doesn't edit reviews.
7. **Tester is a hard gate.** Implementer cannot self-declare TESTING done. Only `tester` can transition TESTING → ACCEPTED.

## Lock Format (CURRENT.md frontmatter)

```yaml
---
milestone: M04
phase: REVIEWING
cycle: 002
owner: reviewer
lock_acquired_at: 2026-04-23T18:30:00Z
lock_expires_at: 2026-04-23T19:00:00Z
last_transition: 2026-04-23T18:25:00Z
last_actor: implementer
---
```

When `owner: null` and `lock_expires_at < now`, the next legal agent for that phase may take over.

## Escalation

- If REVIEWING → IMPLEMENTING happens **3 times in a row** without progress (review keeps re-rejecting), escalate: write `m{N}/STUCK.md` with diagnosis, set `phase: STUCK`, owner=null. Human or PM agent must intervene.
- If TESTING fails **3 times in a row**, same: `phase: STUCK`.
- STUCK milestones must be resolved before any other milestone proceeds.

## Evolution

- After every milestone ACCEPTED, `retrospective` agent runs automatically.
- After every 3 milestones, `/evolve` may be invoked. It reads all retros and proposes diffs to `.claude/agents/*.md`. Diffs are written to `EVOLUTION.md` as proposals; human applies (or auto-apply with `--auto` flag if desired).
- Prompt changes are versioned in `EVOLUTION.md` with rationale + measured effect.

## Quality Gates (binding)

| Gate | Owner | Failure mode |
|---|---|---|
| `swift build` green | implementer (during IMPL), tester (verify) | block commit |
| `swift test` green | implementer, tester (verify) | block commit |
| Architecture conformance | reviewer | back to IMPLEMENTING |
| Acceptance criteria met | tester | back to IMPLEMENTING |
| Visual regression < 1% pixel diff | tester | back to IMPLEMENTING |
| App launches without crash | tester | back to IMPLEMENTING (CRITICAL) |
| Menu bar interaction works | tester | back to IMPLEMENTING |

## Push Policy (CRITICAL)

**No `git push` until BOTH reviewer AND tester have produced PASS for the latest implementation in the current milestone.**

- Implementer commits locally during IMPLEMENTING — never pushes.
- Reviewer/Tester commit their report files locally — never push.
- `/ship` command (or its inline equivalent in autonomous mode) is the **only** trigger that pushes. It runs only after `phase: ACCEPTED` is reached, which requires the most recent test-cycle to be PASS, which in turn requires the most recent review-cycle to be PASS.
- Push pushes ALL accumulated local commits for the milestone in one go (`git push origin main`).
- If a milestone is in STUCK: never push. Resolve first.

This protects the remote from broken or unreviewed code. The local repo can churn freely; remote stays clean.

## File Layout

```
.workflow/
├── PROTOCOL.md          # this file
├── ROADMAP.md           # PM-owned, all milestones overview
├── CURRENT.md           # state machine pointer
├── EVOLUTION.md         # prompt change log
└── m{NN}/
    ├── spec.md
    ├── competitive-analysis.md
    ├── acceptance.md
    ├── architecture.md
    ├── tasks.md
    ├── impl-cycle-NNN.md
    ├── review-cycle-NNN.md
    ├── test-cycle-NNN.md
    ├── screenshots/
    │   ├── baseline/
    │   └── cycle-NNN/
    ├── retro.md         # written after ACCEPTED
    └── RELEASED.md      # written by /ship
```
