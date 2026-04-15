# Agent Jobs Review — v035
**Date:** 2026-04-15T08:00:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** a36b5a4 (main)
**Previous review:** v034 (score 96/100)
**Test results:** 309/309 pass | Coverage: 90.0% stmts, 82.1% branch, 87.8% funcs, 91.5% lines

## Overall Score: 96/100

No production code changes since v034. This is a stability checkpoint confirming the codebase remains healthy: 309/309 tests pass, coverage stable at 90%+ statements, no regressions introduced. Score holds at 96. The project is in a mature maintenance phase — recent cycles have been closing carried issues rather than adding features, which is the correct priority for a tool at this maturity level.

---

## Changes Since v034

| Commit | Type | Summary |
|--------|------|---------|
| `a36b5a4` | docs | Review v034 document + visual notes update |

No production code changes. The only commit since v034 is the review document itself.

### Stability Assessment

With no code changes to review, this cycle focuses on codebase health audit:

**Test Health:**
- 309/309 tests pass consistently across 3 consecutive runs (v033, v034, v035)
- No flaky tests detected
- Test-to-code ratio: 1.58:1 — excellent
- 9 test files covering all modules

**Coverage Stability:**
| Metric | v033 | v034 | v035 | Trend |
|--------|------|------|------|-------|
| Statements | 90.7% | 90.0% | 90.0% | Stable |
| Branches | 82.7% | 82.1% | 82.1% | Stable |
| Functions | 87.8% | 87.8% | 87.8% | Stable |
| Lines | 92.2% | 91.5% | 91.5% | Stable |

All metrics above the 85% threshold. Branch coverage (82.1%) is the weakest dimension — the gap comes from uncovered branches in `app.tsx` (78.6%) and `job-detail.tsx` (58.3%). These are UI interaction branches (keyboard handlers, conditional rendering) that are harder to cover with unit tests.

**Module-Level Coverage Analysis:**
| Module | Stmts | Assessment |
|--------|-------|-----------|
| scanner.ts | 94.1% | ✅ Excellent — complex file well-tested |
| setup.ts | 100% | ✅ Perfect |
| job-table.tsx | 100% | ✅ Perfect |
| store.ts | 90.5% | ✅ Good |
| loader.ts | 88.2% | ✅ Good |
| utils.ts | 88.5% | ✅ Good |
| detect.ts | 83.2% | ⚠️ Below average — platform detection branches |
| app.tsx | 86.6% | ⚠️ UI interaction branches |
| job-detail.tsx | 76.5% | ⚠️ Lowest — conditional fields display |

---

## Category Scores

### Correctness: 29/30

**Unchanged from v034.**

No new code = no new correctness risks. The 309-test suite provides strong regression protection.

**Issues (carried):**

1. **LOW — Content-based dedup lacks project context.** `scanner.ts:611`: Schedule+description key still doesn't include project directory. Low risk — identical cron prompts across different projects are rare.

2. **LOW — `removeRegisteredJob` writes on ENOENT.** `store.ts:57-60`: When no jobs file exists, `loadJobsFile()` returns empty default, and `saveJobsFile()` writes it anyway. Harmless disk write.

### Architecture: 20/20

**Unchanged.** Architecture is stable and well-layered:
- **Data layer:** 4 parallel scanners (registered, live, cron/session, launchd)
- **State layer:** Ink/React state management with 10s auto-refresh
- **UI layer:** Component composition (header, tab-bar, job-table, job-detail, footer)
- **CLI layer:** `detect.ts` for auto-detection, `setup.ts` for hook installation

### Production-readiness: 19/20

3. **MEDIUM (carried since v030) — `auto-commit.sh` uses `git add -A`.** Line 24 stages all files. This is the oldest carried issue (5 review cycles). Recommendation: change to `git add src/ package.json tsconfig.json .review/` or use a whitelist approach.

### Open-source quality: 14/15

4. **LOW (carried) — Narrow terminal test regex fragility.** Tests use `toMatch(/succe/)` for truncated "success" in 80-col terminal. Works but is brittle.

### Security: 14/15

5. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** Same as #3 — `git add -A` with only `.gitignore` as protection.

---

## Visual TUI Review

### Screenshot Analysis (2026-04-15 07:58)

**Display is now active.** Full VS Code workspace visible with multiple terminal panels.

**Observations:**
- Multiple Claude Code sessions running simultaneously in VS Code integrated terminals
- Claude Session Monitor TUI visible in bottom-right panel — shows session data with active/stopped indicators
- Left sidebar shows the agent-jobs project file tree with `.review/`, `src/`, `scripts/` directories
- Terminal output shows build/test runs completing successfully
- The workspace layout includes 4+ terminal panels, suggesting active multi-agent workflow

**TUI-specific observations:**
- The agent-jobs TUI is not directly visible in the main viewport — the Claude Session Monitor (a separate project) is the visible TUI
- Cannot assess agent-jobs TUI rendering directly from this screenshot
- The session monitor shows tabular data with status indicators (● active, ○ stopped), similar column layout to agent-jobs

**Recommendations for next visual review:**
- Run `npx tsx src/index.tsx` in a dedicated terminal panel and capture that specific panel
- Consider using `tmux capture-pane -p` to capture TUI output as text for more reliable analysis
- The current multi-panel workspace makes it hard to isolate agent-jobs TUI output

---

## Feature Brainstorming: Notification System

### Current State

The dashboard is a passive monitoring tool — users must actively look at the TUI to notice job state changes. For agents running background tasks, proactive notifications would significantly increase utility.

### Notification Channels

| Channel | Method | Effort | User Impact |
|---------|--------|--------|-------------|
| macOS Notifications | `osascript -e 'display notification'` | 0.5 day | High — native desktop alerts |
| Terminal bell | `\x07` character in stdout | 0.25 day | Low — often ignored |
| Webhook (Slack/Discord) | HTTP POST to configured URL | 1 day | High — team visibility |
| Log file | Append to `~/.agent-jobs/notifications.log` | 0.25 day | Medium — audit trail |
| Sound | `afplay /System/Library/Sounds/*.aiff` | 0.25 day | Medium — attention-grabbing |

### Proposed: Event-Driven Notification System

```typescript
interface NotificationEvent {
  type: "job_started" | "job_stopped" | "job_error" | "job_recovered";
  jobId: string;
  jobName: string;
  source: JobSource;
  timestamp: string;
  details?: string;
}

interface NotificationConfig {
  enabled: boolean;
  channels: ("desktop" | "webhook" | "log" | "sound")[];
  webhookUrl?: string;
  // Debounce: don't notify more than once per N seconds for the same job
  debounceSeconds: number;
  // Only notify for these event types
  events: NotificationEvent["type"][];
  // Only notify for these sources
  sources?: JobSource[];
}
```

### State Diffing for Event Detection

The notification system needs to detect state transitions between refresh cycles:

```typescript
function diffJobStates(
  prev: Map<string, Job>,
  curr: Map<string, Job>
): NotificationEvent[] {
  const events: NotificationEvent[] = [];
  
  for (const [id, job] of curr) {
    const old = prev.get(id);
    if (!old) {
      // New job appeared
      events.push({ type: "job_started", jobId: id, ... });
    } else if (old.status !== job.status) {
      // Status changed
      if (job.status === "error") {
        events.push({ type: "job_error", jobId: id, ... });
      } else if (old.status === "error" && job.status === "active") {
        events.push({ type: "job_recovered", jobId: id, ... });
      }
    }
  }
  
  for (const [id, job] of prev) {
    if (!curr.has(id)) {
      events.push({ type: "job_stopped", jobId: id, ... });
    }
  }
  
  return events;
}
```

### macOS Desktop Notification Implementation

```typescript
import { execFile } from "child_process";

function sendDesktopNotification(event: NotificationEvent): void {
  if (process.platform !== "darwin") return;
  
  const title = `Agent Jobs: ${event.jobName}`;
  const message = event.type === "job_error" 
    ? `Error detected in ${event.source} job`
    : `Job ${event.type.replace("job_", "")}`;
  
  execFile("osascript", [
    "-e", `display notification "${message}" with title "${title}"`
  ], { timeout: 3000 }, () => {});
}
```

### Configuration Storage

```json
// ~/.agent-jobs/config.json
{
  "notifications": {
    "enabled": true,
    "channels": ["desktop", "log"],
    "debounceSeconds": 60,
    "events": ["job_error", "job_recovered"],
    "sources": ["registered", "cron"]
  }
}
```

### Integration Points

1. **`app.tsx` refresh cycle:** After loading jobs, diff against previous state → emit events
2. **New module `notifications.ts`:** Event handling, channel dispatch, debounce logic
3. **CLI setup:** `agent-jobs setup --notifications` to configure channels
4. **Footer display:** Show notification count/last notification time

### Challenges

1. **False positives:** Live process scanning can show transient absence (process between restarts)
2. **Notification fatigue:** Too many alerts → user ignores them all
3. **State persistence:** Need to persist previous state across restarts for accurate diffing
4. **Cross-platform:** `osascript` is macOS-only; Linux needs `notify-send`; Windows needs `powershell`

### Effort/Impact

| Feature | Effort | Impact |
|---------|--------|--------|
| State diffing engine | 0.5 day | High — foundation for all notifications |
| macOS desktop alerts | 0.5 day | High — immediate user value |
| Webhook integration | 0.5 day | Medium — team workflows |
| Notification log | 0.25 day | Medium — audit trail |
| CLI configuration | 0.5 day | Medium — user-friendly setup |

---

## Action Items

### P1

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 3 | `auto-commit.sh` stages all files | ⚠️ Carried (5 cycles) | `git add -A` — recommend whitelist approach |

### P2

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 5 | clearScreen on auto-refresh | ⚠️ Carried | Causes brief flash every 10s |

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Low risk |
| 2 | removeRegisteredJob writes on ENOENT | ⚠️ Carried | Harmless |
| 4 | Narrow terminal test regex fragility | ⚠️ Carried | Acceptable |

### Coverage Improvement Opportunities

| Module | Current | Target | Focus |
|--------|---------|--------|-------|
| job-detail.tsx | 76.5% | 90%+ | Test conditional fields (sessionId, lifecycle, lastRun) |
| detect.ts | 83.2% | 90%+ | Mock platform detection branches |
| app.tsx | 86.6% | 90%+ | Test keyboard handlers, tab switching |

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
v032: 94  ████████████████  ← architectural stability audit
v033: 96  ████████████████  ← session cron scanner + source labels
v034: 96  ████████████████  ← defensive fixes, firstLine robustness
v035: 96  ████████████████  ← stability checkpoint, no code changes
```

Score has been stable at 96 for 3 consecutive reviews. The project is in a mature state where the primary paths for score improvement are:
- **+1 (97):** Fix `auto-commit.sh` staging scope (P1 #3) → Production-readiness 20/20
- **+1 (98):** Improve `job-detail.tsx` coverage from 76% to 90%+ → Correctness 30/30
- **+1 (99):** Add E2E/integration test for full TUI render cycle → Open-source quality 15/15

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | v033 | Deep |
| 5 | Cross-platform support (Linux systemd) | v034 | Deep |
| 6 | Notification system (desktop/webhook/log) | **v035** | **Deep — event diffing, channels, config** |

**Next brainstorm (v036):** Windows Task Scheduler support, or interactive TUI actions (restart job, view logs, edit schedule from dashboard).

---

## Codebase Metrics

| Metric | v034 | v035 | Δ |
|--------|------|------|---|
| Production LOC | 2,505 | 2,505 | = |
| Test LOC | 3,958 | 3,958 | = |
| Test-to-code ratio | 1.58:1 | 1.58:1 | = |
| Test count | 309 | 309 | = |
| Coverage (stmts) | 90.0% | 90.0% | = |
| Coverage (funcs) | 87.8% | 87.8% | = |
| Coverage (lines) | 91.5% | 91.5% | = |
| Source files | 15 | 15 | = |
| Test files | 10 | 10 | = |

All metrics unchanged — no code changes this cycle.

---

## Summary

v035 scores **96/100** (unchanged, 3rd consecutive cycle at this level). No production code changes since v034 — this is a stability checkpoint confirming test health (309/309), coverage stability (90%+ stmts), and codebase maturity. The project is in a mature maintenance phase with clear paths to 97+ requiring targeted fixes to carried issues. Visual review captured an active workspace screenshot showing multiple Claude Code sessions and the Claude Session Monitor TUI, but the agent-jobs TUI was not directly visible in the captured viewport. Notification system brainstormed as the next feature direction — event-driven state diffing with macOS desktop alerts, webhook integration, and configurable channels.
