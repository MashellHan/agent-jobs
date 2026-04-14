# Agent Jobs Review — v034
**Date:** 2026-04-15T05:52:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 80aaf72 (main)
**Previous review:** v033 (score 96/100)
**Test results:** 309/309 pass | Coverage: 90.0% stmts, 82.1% branch, 87.8% funcs, 91.5% lines

## Overall Score: 96/100

Maintenance cycle addressing v033 action items. Two defensive fixes: directory traversal guard in scanner, dedup key separator improvement, prepublishOnly order correction. The `friendlyCronName` firstLine extraction is a meaningful robustness improvement — multi-line prompts were causing false matches deeper in the regex chain. No new features, no test count change (309), no architectural shifts. Score holds at 96 — these are exactly the kind of targeted fixes that maintain code health without introducing risk.

---

## Changes Since v033

| Commit | Type | Summary |
|--------|------|---------|
| `80aaf72` | fix | Address review-033 action items (prepublishOnly, traversal guard, dedup separator) |
| `9c24388` | fix | Use firstLine for friendlyCronName pattern matching |

### Change Analysis

**Review-033 Action Items (`80aaf72`) — 3 fixes in 1 commit**

1. **prepublishOnly order** (`package.json`): Changed from `"npm test && npm run build"` to `"npm run build && npm test"`. This ensures the build artifact exists before tests run against it. Resolves P2 #5 carried since v032.

2. **Directory traversal guard** (`scanner.ts:551-552`): Added `if (projDir.includes("..") || projDir.includes("/")) continue;` before constructing `projPath = join(projectsDir, projDir)`. Defensive against compromised filesystem returning `../` entries from `readdir()`. Resolves P3 #8 from v033.

3. **Dedup key separator** (`scanner.ts:611-616`): Changed from `j.schedule + j.description.slice(0, 50)` to `j.schedule + "|" + j.description.slice(0, 50)`. The pipe separator prevents ambiguous key boundaries where a schedule suffix could bleed into the description prefix (e.g., `"*/5 * * * *" + "check..."` vs `"*/5 * * * *|check..."`). Minor but correct.

**firstLine pattern matching (`9c24388`) — 43 lines changed in utils.ts**

All 17+ regex patterns in `friendlyCronName()` now operate on `firstLine` instead of the full `trimmed` prompt. This is a significant robustness fix:

- **Problem:** Multi-line cron prompts contain implementation details, examples, and markdown that triggered false matches in later regex patterns.
- **Solution:** Extract `const firstLine = trimmed.split(/\n/)[0]!.trim()` and use it for all pattern matching.
- **Design insight:** Cron prompt intent is always stated in the first line — implementation details follow.

Additional improvements in this commit:
- Role match regex broadened: `(?:[\w ]+ )?` → `(?:.+?\s+)?` to handle compound roles like "Tech Lead + PM"
- New `checkPathMatch` pattern for direct path references: `Check the /path/to/project/.review/`
- `checkDirMatch` expanded: now handles "Check for new/updated files in BOTH directories"
- All fallback paths use `firstLine` instead of `trimmed`

---

## Category Scores

### Correctness: 29/30

**Unchanged from v033:**
- Test count: 309 (no new tests needed — these were defensive fixes to existing code)
- All 309 tests pass
- Coverage stable: 90.0% stmts (was 90.7%), 91.5% lines (was 92.2%)

**Issues:**

1. **LOW (carried) — Content-based dedup could produce false collisions.** `scanner.ts:611`: The separator fix (`|`) helps but the key still lacks project context. Two different projects with the same schedule and prompt prefix would collide. Low risk in practice since different projects rarely share identical cron prompts.

2. **LOW (carried) — `removeRegisteredJob` writes to disk even on ENOENT.** `store.ts:57-60`: When `loadJobsFile()` returns the default empty object (no file exists), `saveJobsFile()` still writes it. Harmless but wasteful. Could add `if (file.jobs.length === 0 && !existsSync(JOBS_PATH)) return;`.

### Architecture: 20/20

**Unchanged from v033.**

The `firstLine` extraction in `friendlyCronName` is architecturally sound — it follows the principle of "parse the minimum necessary input." The function now has a clear data flow:
1. Trim → extract firstLine → match against patterns → fallback
2. Full prompt body is never consulted for name extraction

No structural changes to module boundaries, types, or scan pipeline.

### Production-readiness: 19/20

3. **MEDIUM (carried) — `auto-commit.sh` uses `git add -A`.** Line 24: `git add -A` stages ALL files including potential secrets, build artifacts, or large binaries that happen to be in the working tree. Should use explicit file paths or at minimum respect `.gitignore` patterns more carefully. The `--no-gpg-sign` on line 28 also bypasses commit signing, which may be intentional for automation but should be documented.

4. **LOW — Resolved: LICENSE file now exists.** MIT license file present at project root. ✅

5. **LOW — Resolved: prepublishOnly order fixed.** `"npm run build && npm test"` is correct. ✅

### Open-source quality: 14/15

**Unchanged from v033.**
- LICENSE file now present ✅
- Test-to-code ratio improved: 1.58:1 (3,958 test LOC / 2,505 production LOC)
- All tests pass, coverage well above thresholds

6. **LOW (carried) — Test assertions use partial regex in narrow terminal.** `job-table.test.tsx` uses `toMatch(/succe/)` for "success" due to word-wrap in 80-col test terminal. Acceptable but fragile — a terminal width change could break these assertions.

### Security: 14/15

**Improved:**
- Directory traversal guard added in scanner ✅
- `projDir.includes("..") || projDir.includes("/")` prevents path escape

7. **LOW (carried) — `auto-commit.sh` could stage sensitive files.** `git add -A` on line 24 will stage any file in the working tree, including `.env` files or credentials that might be temporarily present. The `.gitignore` is the only protection, and it may not cover all cases.

---

## Visual Review

**Status:** Screen capture returned black image — display appears to be asleep/locked. Unable to perform visual TUI analysis this cycle.

**Previous visual observations (v033):**
- TUI renders correctly without stacking issues
- SOURCE column displays readable labels (hook/live/cron/launchd)
- Column widths appropriate for terminal width
- Tab counts updating correctly
- No visible flicker from auto-refresh

**Next visual review:** Will attempt screenshot at next cron trigger. If display remains unavailable, will verify TUI via test snapshots and `ink-testing-library` render output instead.

---

## Feature Brainstorming: Cross-Platform Support (Linux systemd)

### Current State

The dashboard currently supports macOS-only service detection via `launchctl`/launchd plist scanning. Linux systems use systemd timers and services, which represent a large untapped user base.

### systemd Detection Strategy

| Signal | Method | Reliability |
|--------|--------|-------------|
| `systemctl list-units` | `execFile("systemctl", ["list-units", "--type=service", "--output=json"])` | High |
| `systemctl list-timers` | `execFile("systemctl", ["list-timers", "--output=json"])` | High |
| User units | `~/.config/systemd/user/` directory scan | Medium |
| Journal logs | `journalctl -u <service> --since "1 hour ago"` | High |

### Proposed: `scanSystemdServices()`

```typescript
interface SystemdUnit {
  unit: string;
  load: string;
  active: string;
  sub: string;
  description: string;
}

export async function scanSystemdServices(): Promise<Job[]> {
  // Skip on non-Linux
  if (process.platform !== "linux") return [];
  
  return new Promise((resolve) => {
    execFile("systemctl", [
      "list-units", "--type=service",
      "--user", "--output=json", "--no-pager"
    ], { encoding: "utf-8", timeout: 5000 }, (err, stdout) => {
      if (err) { resolve([]); return; }
      
      try {
        const units = JSON.parse(stdout) as SystemdUnit[];
        const jobs = units
          .filter(u => isAgentUnit(u))
          .map(u => ({
            id: `systemd-${u.unit}`,
            name: u.unit.replace(".service", ""),
            description: u.description,
            agent: inferAgentFromUnit(u),
            schedule: "always-on",
            status: u.active === "active" ? "active" : "stopped",
            source: "systemd" as const,
          }));
        resolve(jobs);
      } catch { resolve([]); }
    });
  });
}
```

### systemd Timer → Cron Mapping

systemd timers are the Linux equivalent of cron jobs and launchd calendar intervals:

```ini
# ~/.config/systemd/user/agent-review.timer
[Timer]
OnCalendar=*:0/30    # Every 30 minutes
Persistent=true

[Install]
WantedBy=timers.target
```

Mapping to `Job.schedule`:
- `OnCalendar=*:0/30` → `"every 30 min"`
- `OnCalendar=daily` → `"daily"`
- `OnCalendar=Mon..Fri *-*-* 09:00:00` → `"weekdays 9am"`
- `OnBootSec=5m` → `"5min after boot"`

### Agent Detection for systemd

| Heuristic | Signal | Confidence |
|-----------|--------|-----------|
| Unit file path | `~/.config/systemd/user/claude-*` | High |
| Unit description | Contains "claude", "agent", "ai" | Medium |
| ExecStart command | Runs `claude`, `npx agent-jobs` | High |
| Environment | `ANTHROPIC_API_KEY` in unit file | High |

### Platform Abstraction

To support both macOS and Linux cleanly:

```typescript
// scanner.ts — platform-aware service scanning
export async function scanPlatformServices(): Promise<Job[]> {
  switch (process.platform) {
    case "darwin": return scanLaunchdServices();
    case "linux":  return scanSystemdServices();
    default:       return []; // Windows: future work
  }
}
```

The `JobSource` type would need extension:
```typescript
export type JobSource = "registered" | "live" | "cron" | "launchd" | "systemd";
```

### Challenges

1. **systemd JSON output varies by version** — older versions don't support `--output=json`
2. **User vs system units** — agent services are typically user-scoped (`--user` flag)
3. **Journal access** — reading logs may require `adm` group membership
4. **WSL complication** — Windows Subsystem for Linux has systemd but it behaves differently
5. **Timer accuracy** — systemd timers have `AccuracySec` randomization (similar to Claude Code's cron jitter)

### Effort/Impact

| Feature | Effort | Impact |
|---------|--------|--------|
| Basic `systemctl` scanner | 1 day | High — opens Linux market |
| Timer parsing | 0.5 day | Medium — schedule display |
| Journal log integration | 1 day | High — lastRun/lastResult from logs |
| Platform abstraction layer | 0.5 day | Medium — clean architecture |

---

## Action Items

### P1

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 3 | `auto-commit.sh` stages all files | ⚠️ Carried | `git add -A` on line 24 — not addressed since v030 |

### P2

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 5 | clearScreen on auto-refresh | ⚠️ Carried | Causes brief flash every 10s |

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key lacks project context | ⚠️ Carried | Separator added but projDir still missing |
| 2 | removeRegisteredJob writes on ENOENT | ⚠️ Carried | Harmless but wasteful |
| 6 | Narrow terminal test regex fragility | ⚠️ Carried | `toMatch(/succe/)` pattern |

### Resolved This Cycle

| # | Issue | Resolution |
|---|-------|------------|
| P2 #4/6 | Missing LICENSE file | ✅ LICENSE file now exists at project root |
| P2 #5 | prepublishOnly order wrong | ✅ Fixed to `build && test` in `80aaf72` |
| P3 #8 | No directory traversal guard | ✅ Guard added in `80aaf72` |
| — | friendlyCronName multi-line false matches | ✅ firstLine extraction in `9c24388` |

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
v033: 96  ████████████████  ← session cron scanner + source labels (309 tests!)
v034: 96  ████████████████  ← defensive fixes, firstLine robustness, 3 P2/P3 resolved
```

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | v033 | Deep |
| 5 | Cross-platform support (Linux systemd) | **v034** | **Deep — scanner sketch, timer mapping, platform abstraction** |

**Next brainstorm (v035):** Windows Task Scheduler support, or notification system (desktop/Slack/webhook alerts on job state changes).

---

## Codebase Metrics

| Metric | v033 | v034 | Δ |
|--------|------|------|---|
| Production LOC | 2,899 | 2,505 | -394* |
| Test LOC | 3,493 | 3,958 | +465* |
| Test-to-code ratio | 1.20:1 | 1.58:1 | +0.38 |
| Test count | 309 | 309 | = |
| Coverage (stmts) | 90.7% | 90.0% | -0.7% |
| Coverage (funcs) | 87.8% | 87.8% | = |
| Coverage (lines) | 92.2% | 91.5% | -0.7% |
| Source files | 14 | 15 | +1 |
| Test files | 9 | 10 | +1 |

*Note: LOC shift reflects measurement methodology change (v034 counts exclude `test-loader.ts` from production, include `fixtures.ts` in test LOC). Actual code changes were minimal (+11 lines scanner, +43 lines utils net).

Coverage dipped marginally (~0.7%) due to new code paths in `friendlyCronName` (checkPathMatch pattern) without corresponding test additions. Remains well above the 85% threshold.

---

## Summary

v034 scores **96/100** (unchanged from v033). This is a healthy maintenance cycle: 2 commits addressing 4 carried issues from previous reviews. The directory traversal guard and dedup separator are defensive improvements in the scanner. The `friendlyCronName` firstLine extraction is the most impactful change — it prevents multi-line prompt bodies from triggering false regex matches, a bug class that would have been hard to diagnose in production. Three P2/P3 items resolved (LICENSE, prepublishOnly, traversal guard). The `auto-commit.sh` staging scope (P1) remains the oldest carried issue. Cross-platform systemd support brainstormed as the next expansion direction, with a platform abstraction layer design that cleanly separates macOS and Linux service scanning.
