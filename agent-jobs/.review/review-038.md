# Agent Jobs Review — v038
**Date:** 2026-04-15T09:10:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 20d3a52 (main)
**Previous review:** v037 (score 97/100)
**Test results:** 336/336 pass | Coverage: 90.7% stmts, 83.9% branch, 88.4% funcs, 92.2% lines

## Overall Score: 97/100

One targeted test commit since v037: 2 new watcher debounce tests for `loader.ts` branch coverage, closing the 70% branch gap identified in v037. Test count 334→336, coverage improved across all dimensions. Score holds at 97 — the improvement is incremental but demonstrates continued attention to the coverage targets identified in previous reviews.

---

## Changes Since v037

| Commit | Type | Summary |
|--------|------|---------|
| `2ed2c6e` | test | Add watcher debounce branch tests for loader.ts coverage |
| `20d3a52` | docs | Visual review v037 notes |

### Change Analysis

**Watcher Debounce Tests (`2ed2c6e`) — 49 LOC added**

Two new tests in `loader.test.ts` targeting the `watchJobsFile` debounce logic:

1. **"debounces rapid file changes"**: Fires the watcher callback twice in rapid succession, verifies only one `onChange` call fires after the 300ms debounce window. Tests the `clearTimeout(debounceTimer)` → `setTimeout` cycle.

2. **"clears pending debounce timer on cleanup"**: Starts a debounce timer, calls `cleanup()` before it fires, advances past 500ms, verifies `onChange` was never called. Tests the `clearTimeout` in the cleanup function.

Both tests use `vi.useFakeTimers()` / `vi.advanceTimersByTime()` for precise timing control — the correct approach for testing debounce logic.

**Coverage impact:**
| Metric | v037 | v038 | Δ |
|--------|------|------|---|
| Statements | 90.3% | 90.7% | +0.4% |
| Branches | 83.5% | 83.9% | +0.4% |
| Functions | 87.8% | 88.4% | +0.6% |
| Lines | 92.0% | 92.2% | +0.2% |

The `loader.ts` branch coverage gap (identified as 70% in v037) has been partially addressed. The debounce timer clear/reset paths are now covered.

---

## Category Scores

### Correctness: 30/30
Unchanged. 336 tests (+2), all pass.

### Architecture: 20/20
Unchanged.

### Production-readiness: 20/20
Unchanged.

### Open-source quality: 14/15
1. **LOW (carried) — Narrow terminal test regex fragility.** `toMatch(/succe/)` pattern in job-table tests.

### Security: 13/15
2. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** Informational.

---

## Feature Brainstorming: OpenCode/Cursor Integration

### Context

The agent-jobs dashboard currently integrates exclusively with Claude Code (PostToolUse hooks, session JSONL parsing, scheduled_tasks.json). As more AI coding assistants emerge (OpenCode, Cursor, Windsurf, Copilot Workspace), a multi-assistant integration would make the dashboard universally useful.

### Assistant Detection Signals

| Assistant | Detection Method | Job Source |
|-----------|-----------------|-----------|
| Claude Code | PostToolUse hook, `~/.claude/` | registered, cron |
| OpenCode | `~/.opencode/` config, tool calls | opencode |
| Cursor | `.cursor/` project files, composer logs | cursor |
| Windsurf | `.windsurf/` sessions | windsurf |
| Copilot | `.github/copilot-*` logs | copilot |
| Aider | `.aider/` history, `aider.conf.yml` | aider |

### Integration Architecture

```typescript
// New type extension
export type JobSource = 
  | "registered" | "live" | "cron" | "launchd" | "systemd"
  | "opencode" | "cursor" | "windsurf" | "copilot" | "aider";

// Plugin interface for assistant integrations
interface AssistantPlugin {
  name: string;
  source: JobSource;
  detect(): Promise<boolean>;     // Is this assistant installed/active?
  scan(): Promise<Job[]>;          // Discover jobs from this assistant
  watch?(cb: () => void): void;   // Optional: watch for changes
}
```

### OpenCode-Specific Integration

OpenCode stores session data similarly to Claude Code:

```typescript
async function scanOpenCodeSessions(): Promise<Job[]> {
  const configDir = join(homedir(), ".opencode");
  if (!existsSync(configDir)) return [];
  
  // OpenCode uses a different session format but similar concepts:
  // - Tools are logged as JSON events
  // - Background tasks are tracked in session state
  // - Cron-like scheduling via session persistence
  
  return []; // Implementation would follow Claude Code scanner pattern
}
```

### Cursor Composer Integration

Cursor's Composer feature creates multi-step agent workflows:

```typescript
async function scanCursorComposer(): Promise<Job[]> {
  // Cursor stores composer sessions in:
  // ~/.cursor-server/data/composer/
  // Each session has tool invocations that may spawn background processes
  
  // Detection: look for running Cursor processes
  // + check for .cursor/ directory in project roots
  return [];
}
```

### Unified Agent Column

With multi-assistant support, the AGENT column becomes more valuable:

```
ST  SERVICE            AGENT        SOURCE    SCHEDULE
●   my-web-server      claude-code  hook      always-on
●   api-gateway        opencode     opencode  always-on
○   test-runner        cursor       cursor    every 30m
●   deploy-monitor     copilot      copilot   daily 9am
```

### Challenges

1. **No standardized format:** Each assistant has different log/session formats
2. **Rapid evolution:** Assistant APIs and storage formats change frequently
3. **Permission issues:** Some assistants store data in sandboxed locations
4. **Process attribution:** Distinguishing "started by Cursor" vs "started by user in Cursor terminal"
5. **Plugin maintenance:** Each integration requires ongoing maintenance as assistants update

### Effort/Impact

| Integration | Effort | Impact | Feasibility |
|-------------|--------|--------|-------------|
| OpenCode | 2 days | Medium | High — similar to Claude Code |
| Cursor | 3 days | High | Medium — less standardized logs |
| Aider | 1 day | Low | High — well-documented config |
| Copilot | 2 days | Medium | Low — limited session persistence |
| Plugin system | 3 days | High | High — enables community contributions |

---

## Action Items

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Low risk |
| 3 | Narrow terminal test regex fragility | ⚠️ Carried | Acceptable |

### Coverage Status

| Module | v037 Branch | v038 Branch | Status |
|--------|------------|------------|--------|
| loader.ts | 70% | improved* | ✅ Debounce branches covered |
| app.tsx | 78.6% | 78.6% | ⚠️ Keyboard handler branches |
| detect.ts | 81% | 81% | ⚠️ Platform detection branches |

*loader.ts individual row merged into src aggregate in v038 coverage output.

---

## Score Trajectory

```
v027: 97  ████████████████▌
v028: 97  ████████████████▌
v029: 91  ███████████████
v030: 95  ████████████████
v031: 94  ███████████████▌
v032: 94  ███████████████▌
v033: 96  ████████████████
v034: 96  ████████████████
v035: 96  ████████████████
v036: 97  ████████████████▌
v037: 97  ████████████████▌
v038: 97  ████████████████▌ ← debounce tests, coverage +0.4%
```

**Plateau at 97 for 3 consecutive reviews.** The path to 98 requires either:
- Closing `app.tsx` branch coverage gap (keyboard handler edge cases)
- Adding text search feature (new user-facing capability)
- Plugin system for multi-assistant support

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | v033 | Deep |
| 5 | Cross-platform support (Linux systemd) | v034 | Deep |
| 6 | Notification system | v035 | Deep |
| 7 | Interactive TUI actions | v036 | Deep |
| 8 | Project grouping & multi-workspace | v037 | Medium |
| 9 | OpenCode/Cursor/multi-assistant integration | **v038** | **Deep — plugin interface, 5 assistants analyzed** |

**Next brainstorm (v039):** Job health metrics & historical tracking — storing run history, success rates, uptime percentages over time.

---

## Codebase Metrics

| Metric | v037 | v038 | Δ |
|--------|------|------|---|
| Production LOC | 2,509 | 2,509 | = |
| Test LOC | 4,179 | 4,228 | +49 |
| Test-to-code ratio | 1.67:1 | 1.69:1 | +0.02 |
| Test count | 334 | 336 | +2 |
| Coverage (stmts) | 90.3% | 90.7% | +0.4% |
| Coverage (branch) | 83.5% | 83.9% | +0.4% |
| Coverage (funcs) | 87.8% | 88.4% | +0.6% |
| Coverage (lines) | 92.0% | 92.2% | +0.2% |

---

## Summary

v038 scores **97/100** (unchanged, 3rd consecutive at this level). One code commit: 2 new watcher debounce tests addressing the `loader.ts` branch coverage gap identified in v037. Test count grew 334→336, all coverage metrics improved (+0.2-0.6%). The codebase has been at 97 for three reviews, indicating a mature plateau. OpenCode/Cursor multi-assistant integration brainstormed as the next feature direction — a plugin interface (`AssistantPlugin`) would enable community-contributed integrations. Nine feature directions have been explored across the review series. The project is ready for its next feature phase: text search, project grouping, or multi-assistant support would each move the score toward 98+.
