---
milestone: M00
phase: BOOTSTRAPPING
cycle: 0
owner: null
lock_acquired_at: null
lock_expires_at: null
last_transition: 2026-04-23T18:30:00Z
last_actor: human
---

# Current Workflow State

**Milestone:** M00 — Bootstrap
**Phase:** BOOTSTRAPPING (one-time)
**Cycle:** 0
**Owner:** none

## What "BOOTSTRAPPING" means

The workflow itself was just installed. The legacy `.review/`, `.review_strict/`, `.review-prompts/`, `.implementation/`, `.design-review/` directories from the previous TUI iteration remain on disk as historical reference but are no longer the active workflow.

Existing Swift code at `macapp/AgentJobsMac/` is partial — it has menu bar + dashboard scaffolding + Discovery layer. The new workflow must inherit this state (do not start from zero).

## To start the new workflow

Run: `/milestone-start`

This will:
1. Invoke `pm` agent to write ROADMAP entries (audit existing macapp/, identify what's done, plan next milestones)
2. PM picks M01 and writes its spec
3. Phase transitions to ARCHITECTING

## Next Allowed Transitions

From BOOTSTRAPPING:
- → SPECCING (when `/milestone-start` is invoked)
