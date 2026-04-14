# Agent Jobs Review — v032
**Date:** 2026-04-14T23:45:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 0094b2a (main)
**Previous review:** v031 (score 94/100)
**Test results:** 268/268 pass | Coverage: 91.7% stmts, 85.1% branch, 88.6% funcs, 92.5% lines

## Overall Score: 94/100

No source code changes since v031. This review is a deep architectural stability audit of the entire codebase (5,226 total LOC — 2,432 production, 2,794 test). The architecture is clean, well-modularized, and follows project coding standards. All carried-forward issues from v030/v031 remain unaddressed. Brainstorming this round focuses on **Editor HUD/statusline integration**.

---

## Changes Since v031

No agent-jobs source code changes. The most recent 5 commits on `main` are for a separate project (EyesHealth). The agent-jobs codebase is stable at commit `0094b2a`.

---

## Deep Code Review

### Architecture Stability Audit

The codebase has a clean 3-tier architecture:

```
Data Layer          →  Business Logic   →  Presentation
──────────────────     ───────────────     ─────────────
scanner.ts (413L)      loader.ts (71L)    app.tsx (302L)
cli/detect.ts (394L)   store.ts (89L)     components/ (5 files, 285L)
                       utils.ts (197L)    index.tsx (24L)
                       types.ts (48L)
```

**File size compliance** (max 800L per rules):
- ✅ All production files under 420L
- ✅ All test files under 660L
- ✅ Average production file: 167L (well within 200-400L typical range)

**Module responsibilities are cleanly separated:**

| Module | Single Responsibility | Clean? |
|--------|----------------------|--------|
| `types.ts` | Data model + constants | ✅ 48L, pure types |
| `scanner.ts` | 4 data source scanners (lsof, claude cron, launchd, live) | ✅ Each scanner is an independent function |
| `cli/detect.ts` | PostToolUse hook pattern matching + registration | ✅ 17 patterns, file locking, atomic writes |
| `cli/setup.ts` | Hook injection/removal in settings.json | ✅ Two functions: setup/teardown |
| `cli/index.ts` | CLI router | ✅ Pure routing, no logic |
| `loader.ts` | Data loading orchestration + file watchers | ✅ Aggregates 4 scanners, manages watchers |
| `store.ts` | Persistence (jobs.json, hidden.json) | ✅ CRUD operations with atomic writes |
| `utils.ts` | Pure formatting functions | ✅ Stateless, well-tested |
| `app.tsx` | State management + keyboard handling + layout | ⚠️ 302L — approaches upper bound for a single component. Could extract `useKeyboardHandler()` hook. |
| `components/*` | 5 small, focused UI components | ✅ Largest is job-table.tsx at 100L |

### Correctness: 28/30

**Strengths:**
- All 268 tests pass consistently
- Coverage exceeds 85% on all dimensions (91.7% stmts, 85.1% branch, 88.6% funcs, 92.5% lines)
- Error boundaries are comprehensive — every scanner, loader, and store function catches and gracefully degrades
- File lock in `detect.ts` includes stale-lock detection (process.kill(0) probe)
- Atomic writes (temp + rename) prevent data corruption

**Issues found during deep review:**

1. **LOW (carried from v030) — `removeRegisteredJob` writes empty file on ENOENT.** `store.ts:57-60`: If `jobs.json` doesn't exist, `loadJobsFile()` returns `{ version: "1.0", jobs: [] }`, then `saveJobsFile()` writes this empty payload. The `filter()` removes nothing. Net effect: creates an empty jobs.json when none existed. Harmless but wasteful.

2. **LOW — `scanClaudeScheduledTasks` uses index-based IDs (`cron-0`, `cron-1`).** `scanner.ts:189`: If tasks are reordered in `scheduled_tasks.json`, job IDs change, breaking hidden-ID persistence. A content-hash ID (e.g., `cron-${hash(prompt+cron)}`) would be more stable.

3. **LOW — `parseLsofOutput` casts command to lowercase for `RELEVANT_CMDS` check.** `scanner.ts:43`: The Set contains lowercase entries like `"node"`, `"python3"`, and the check does `cmd.toLowerCase()`. This is correct but undocumented — if someone adds `"Node"` to the Set, it silently fails to match.

4. **LOW — `acquireLock` busy-waits with CPU spin.** `detect.ts:165-166`: The retry loop uses a `while (Date.now() - start < LOCK_RETRY_MS)` spin lock. This is acceptable for a hook with 50ms retry and 5s timeout, but `setTimeout` would be more CPU-friendly. Since this runs in a short-lived PostToolUse hook process, the impact is minimal.

### Architecture: 19/20

**Strengths:**
- 4-source parallel loading (`Promise.all` in `loader.ts:12-17`) — elegant
- Watcher factory pattern (`createWatcher` in `loader.ts:43-59`) — DRY
- Immutable state updates throughout (React hooks, `map()` in store, spread operator)
- Zero `any` types in production code — verified via grep
- Zero `console.log` in production code — verified via grep
- Component composition follows React best practices (props-only, no side effects in render)

**Issues:**

5. **LOW — `clearScreen()` called on every 10s auto-refresh.** `app.tsx:70`: The `refresh()` callback calls `clearScreen()` unconditionally. This runs every 10 seconds via `setInterval`. The screen clear is only needed when UI height changes (expand/collapse/tab switch/hide/stop). Consider:
   ```typescript
   // Option A: Don't clearScreen in refresh
   const refresh = useCallback((clear = false) => {
     if (clear) clearScreen();
     loadAllJobs().then(...);
   }, []);

   // Option B: Use a ref to track if height changed
   ```

6. **LOW — `app.tsx` has 10 useState hooks.** While each is necessary, this approaches "state management complexity" threshold. Consider extracting a `useJobsDashboard()` custom hook to encapsulate `allJobs`, `hiddenIds`, `cursor`, `expanded`, `tab`, `lastRefresh`, `loading`, `error`, `confirmAction`, `statusMsg`.

### Production-readiness: 18/20

**Strengths:**
- `postinstall` / `preuninstall` lifecycle scripts for zero-config installation
- TTY guard on `clearScreen()` (`process.stdout.isTTY`)
- Alternate screen buffer for clean fullscreen TUI
- SIGINT/SIGTERM signal handlers for graceful cleanup
- Debounced file watchers (300ms) prevent thrashing

**Issues:**

7. **MEDIUM (carried from v030) — `auto-commit.sh` uses `git add -A`.** Still stages all files including potential secrets. Not yet addressed.

8. **LOW — No `LICENSE` file.** `package.json` declares `"license": "MIT"` but no actual `LICENSE` file exists in the repository. Required for open-source compliance.

9. **LOW — `prepublishOnly` runs tests then build.** `package.json:20`: If tests pass but build fails, a partial npm publish could occur. Should be `"prepublishOnly": "npm run build && npm test"` (build first).

### Open-source quality: 14/15

**Strengths:**
- README is comprehensive (architecture, patterns, project structure, tech stack)
- CHANGELOG exists with detailed v0.1.0 entry
- CONTRIBUTING.md exists with project structure and PR workflow
- Test fixtures are realistic and well-documented (JSDoc comments on each)
- Code has meaningful JSDoc comments on complex functions

**Issues:**

10. **LOW — Missing `LICENSE` file.** (Same as #8)

11. **LOW — Test assertions use partial regex matches.** (Carried from v030) Multiple assertions in `job-table.test.tsx` use `/claude-co/`, `/registe/`, `/openclaw-moni/` instead of full strings. Adding `process.stdout.columns = 160` to `beforeEach` would allow full string assertions.

### Security: 15/15

**Strengths:**
- No hardcoded secrets or API keys
- No user input reaches shell commands — all `execFile` calls use programmatic arguments
- `execFile` (not `exec`) prevents shell injection
- All external process calls have timeouts (3000-5000ms)
- `killProcess` uses SIGTERM (graceful shutdown)
- File lock prevents race conditions on `jobs.json`
- Atomic writes prevent data corruption

No security issues found in this review.

---

## Feature Brainstorming: Editor HUD/Statusline Integration

### Direction: `agent-jobs status` CLI Command

**Goal:** Provide a lightweight, non-interactive output that any editor, terminal multiplexer, or status bar can consume.

### Current CLI Commands

| Command | Output | Interactive? |
|---------|--------|-------------|
| `agent-jobs` / `dashboard` | Full TUI (Ink) | ✅ Yes |
| `agent-jobs list` | Multi-line plain text | ❌ No |
| `agent-jobs help` | Help text | ❌ No |
| `agent-jobs --version` | Version string | ❌ No |

**Gap:** No single-line summary suitable for status bars.

### Proposed: `agent-jobs status`

#### Human-readable (default)

```
● 3 active  ○ 1 stopped  ✗ 1 error  │  5 total
```

#### JSON mode (`--json`)

```json
{"active":3,"stopped":1,"error":0,"total":4,"sources":{"registered":1,"live":2,"cron":1,"launchd":0}}
```

#### Minimal mode (`--minimal`)

For very narrow status bars (e.g., tmux, vim statusline):

```
⬡3 ⬢1 ✗0
```

### Implementation Sketch

```typescript
// In cli/index.ts — add new case
case "status": {
  const { loadAllJobs } = await import("../loader.js");
  const { loadHiddenIds } = await import("../store.js");
  const jobs = await loadAllJobs();
  const hidden = loadHiddenIds();
  const visible = jobs.filter(j => !hidden.has(j.id));

  const counts = {
    active: visible.filter(j => j.status === "active").length,
    stopped: visible.filter(j => j.status === "stopped").length,
    error: visible.filter(j => j.status === "error").length,
    total: visible.length,
  };

  if (process.argv.includes("--json")) {
    process.stdout.write(JSON.stringify(counts) + "\n");
  } else if (process.argv.includes("--minimal")) {
    process.stdout.write(`⬡${counts.active} ⬢${counts.stopped} ✗${counts.error}\n`);
  } else {
    const parts = [];
    if (counts.active > 0)  parts.push(`● ${counts.active} active`);
    if (counts.stopped > 0) parts.push(`○ ${counts.stopped} stopped`);
    if (counts.error > 0)   parts.push(`✗ ${counts.error} error`);
    process.stdout.write(`${parts.join("  ")}  │  ${counts.total} total\n`);
  }
  break;
}
```

**Effort:** ~30 minutes. Reuses existing `loadAllJobs()` and `loadHiddenIds()`.

### Editor Integration Points

#### 1. Claude Code — Status Line HUD

The `claude-statusline-hud` skill can invoke `agent-jobs status --minimal`:

```json
// In statusline config
{
  "component": "agent-jobs",
  "command": "agent-jobs status --minimal",
  "interval": 30
}
```

#### 2. tmux

```bash
# In ~/.tmux.conf
set -g status-right '#(agent-jobs status --minimal 2>/dev/null || echo "—")'
set -g status-interval 30
```

This would show `⬡3 ⬢1 ✗0` in the tmux status bar, refreshing every 30 seconds.

#### 3. Neovim (Lua)

```lua
-- In statusline config (e.g., lualine)
require('lualine').setup({
  sections = {
    lualine_x = {
      function()
        local handle = io.popen('agent-jobs status --minimal 2>/dev/null')
        if handle then
          local result = handle:read('*a')
          handle:close()
          return result:gsub('%s+$', '')
        end
        return ''
      end
    }
  }
})
```

**Concern:** Shelling out on every statusline render is expensive. Should cache the result for ~30 seconds.

#### 4. VS Code Extension (Future)

A VS Code extension would use the `--json` output for structured data:

```typescript
// VS Code extension
import * as vscode from 'vscode';
import { exec } from 'child_process';

class AgentJobsStatusProvider {
  private statusBarItem: vscode.StatusBarItem;

  constructor() {
    this.statusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right, 100
    );
    this.refresh();
    setInterval(() => this.refresh(), 30000);
  }

  private refresh() {
    exec('agent-jobs status --json', (err, stdout) => {
      if (err) return;
      const data = JSON.parse(stdout);
      this.statusBarItem.text = `$(eye) ${data.active}↑ ${data.error}✗`;
      this.statusBarItem.show();
    });
  }
}
```

#### 5. OpenCode Integration

OpenCode's status bar could similarly consume `agent-jobs status --json`. Need to investigate OpenCode's extension/plugin API to determine the integration mechanism.

### Performance Consideration

`agent-jobs status` currently requires:
1. Reading `jobs.json` (fast — local file)
2. Running `lsof` (slow — ~200ms)
3. Reading `scheduled_tasks.json` (fast — local file)
4. Reading `~/Library/LaunchAgents/*.plist` + `plutil` per file (medium — ~100ms)
5. Running `launchctl list` (fast — ~50ms)

**Total latency: ~400ms** — acceptable for a status bar refresh every 30s, but too slow for a statusline that renders on every keypress.

**Optimization options:**
- `agent-jobs status --cached` — read from a cache file written by the last full scan
- `agent-jobs status --registered-only` — skip lsof/launchd for instant response
- Background daemon that writes status to a Unix socket or file

### Effort/Impact Matrix

| Feature | Effort | Impact | Priority |
|---------|--------|--------|----------|
| `status` CLI command | 30 min | High — universal integration point | **P1** |
| `--json` flag | 10 min | High — programmatic consumers | **P1** |
| `--minimal` flag | 10 min | Medium — narrow status bars | **P2** |
| tmux integration doc | 15 min | Medium — tmux users | **P2** |
| VS Code extension | 3-5 days | High — large user base | **P3** |
| Caching layer | 1 day | Medium — performance optimization | **P3** |

---

## Action Items

### P1 (should fix)

| # | Issue | File | Fix | Carried |
|---|-------|------|-----|---------|
| 7 | `auto-commit.sh` stages all files via `git add -A` | `scripts/auto-commit.sh` | Replace with explicit safe paths | v030 |

### P2 (nice to fix)

| # | Issue | File | Fix | Carried |
|---|-------|------|-----|---------|
| 5 | `clearScreen()` in every auto-refresh causes flicker | `app.tsx:70` | Gate clearScreen behind a `clear` parameter | v031 |
| 11 | Test assertions use partial regex | `job-table.test.tsx` | Set `process.stdout.columns = 160` in beforeEach | v030 |
| 8/10 | Missing LICENSE file | Root | Add MIT LICENSE file | v031 |
| 9 | `prepublishOnly` order (test before build) | `package.json:20` | Change to `"npm run build && npm test"` | New |
| 6 | 10 useState hooks in App | `app.tsx` | Extract `useJobsDashboard()` custom hook | New |

### P3 (trivial / long-term)

| # | Issue | File | Fix | Carried |
|---|-------|------|-----|---------|
| 1 | `removeRegisteredJob` writes on ENOENT | `store.ts:57` | Add early return if job not found | v030 |
| 2 | Cron task IDs are index-based | `scanner.ts:189` | Use content hash for stable IDs | New |
| 3 | `RELEVANT_CMDS` lowercase convention undocumented | `scanner.ts:24` | Add JSDoc comment | New |
| 4 | Lock retry uses CPU spin | `detect.ts:165` | Acceptable for hook process | New |

---

## v031 Action Item Resolution

| Issue | Status | Notes |
|-------|--------|-------|
| clearScreen flicker on auto-refresh | ⚠️ Not addressed | Carried to P2 |
| Test count regression 272 → 268 | ⚠️ Unresolved | May have been from a git reset/squash |
| auto-commit.sh git add -A | ⚠️ Not addressed | Carried to P1 |
| Missing LICENSE file | ⚠️ Not addressed | Carried to P2 |

---

## Score Trajectory

```
v025: 90  ███████████████
v026: 95  ████████████████
v027: 97  ████████████████
v028: 97  ████████████████
v029: 91  ███████████████  ← 5-feature drop
v030: 95  ████████████████  ← v029 fixes + SOURCE column
v031: 94  ████████████████  ← clearScreen fix + README rewrite
v032: 94  ████████████████  ← architectural stability audit (no code changes)
```

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep — matrix, crontab scanner sketch, PM2 proposal |
| 2 | Editor HUD/statusline integration | **v032** | **Deep — CLI sketch, 5 editor integrations, perf analysis** |
| 3 | Adapter/plugin architecture | v031 | Medium — interface sketch, adapter directory |
| 4 | Docker/container monitoring | — | Not yet explored |
| 5 | Cross-platform support | — | Not yet explored |

**Next brainstorm (v033):** Docker/container monitoring (#4)

---

## Summary

v032 scores **94/100** (unchanged from v031). This is a deep architectural stability audit with no source code changes. The codebase is well-structured at 2,432 production LOC across 14 files, with 2,794 test LOC (1.15:1 test-to-code ratio). Zero `any` types, zero `console.log` statements, all files under 420L. Key architectural strength: clean 3-tier separation (data → logic → presentation) with 4 parallel scanners. Main concerns remain: auto-commit staging scope (P1), clearScreen flicker on auto-refresh (P2), and missing LICENSE file (P2). Brainstorming covers HUD/statusline integration via a proposed `agent-jobs status` command — a high-impact, low-effort addition that enables tmux, Neovim, VS Code, and Claude Code statusline integration.
