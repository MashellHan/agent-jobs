# Agent Jobs Review — v033
**Date:** 2026-04-15T00:15:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 7125ee6 (main)
**Previous review:** v032 (score 94/100)
**Test results:** 309/309 pass | Coverage: 90.7% stmts, 82.7% branch, 87.8% funcs, 92.2% lines

## Overall Score: 96/100

Significant feature delivery since v032: session JSONL cron scanner (+258 LOC) and source column UX fix. Test count jumped from 268 to 309 (+41 tests). Two long-standing P2 issues resolved (SOURCE column labels, cron task ID stability). The session cron scanner is well-designed — streaming readline for large files, smart pre-filter, proper error handling. Score improves +2 from v032 due to feature quality and test growth.

---

## Changes Since v032

| Commit | Type | Summary |
|--------|------|---------|
| `e111d1e` | feat | Session JSONL cron scanner for comprehensive cron task discovery |
| `7125ee6` | fix | Display human-readable source labels in table column |

### Change Analysis

**Session JSONL Cron Scanner (`e111d1e`) — 258 new LOC**

This is the most significant feature addition since the initial TUI build. It replaces the limited `scheduled_tasks.json`-only approach with a two-phase scanner:

1. **Phase 1 — JSONL Parsing:** Scans `~/.claude/projects/*/` for session JSONL files (≤7 days old), parses `CronCreate`/`CronDelete` tool calls using streaming readline, correlates tool_use with tool_result to extract cron schedule, prompt, and lifecycle.

2. **Phase 2 — Durable Fallback:** Still reads `scheduled_tasks.json` for durable tasks, with deduplication against JSONL-discovered tasks.

**Key design decisions reviewed:**

| Decision | Assessment |
|----------|-----------|
| Streaming readline for JSONL | ✅ Correct — files can be 10-30MB |
| Smart pre-filter (`hasCronOp \|\| hasPending`) | ✅ Excellent — only parses JSON for lines containing cron ops or pending results |
| tool_use → tool_result correlation via Map | ✅ Standard two-phase pattern for async tool results |
| Session active detection (15min window) | ✅ Reasonable heuristic — matches Claude Code's session lifetime |
| 7-day max age filter | ✅ Matches Claude Code's cron auto-expiry |
| Content-based dedup (schedule + description[:50]) | ⚠️ Could collide if same schedule + prompt appears in different projects |

**Bug fix caught by tests:**

The original pre-filter `!line.includes("CronCreate") && !line.includes("CronDelete")` was too aggressive — it filtered out `tool_result` lines, preventing any cron tasks from being discovered. Fixed to `hasCronOp || hasPending`, which only parses tool_result lines when there are pending CronCreate tool_uses. This bug would have made the entire scanner non-functional in production.

**Source Column Fix (`7125ee6`)**

Resolves P2 carried from v030: SOURCE column now shows short labels (`hook`, `live`, `cron`, `launchd`) instead of raw enum values (`registered`, `live`, etc.). Added `sourceToShort()` for compact table display, keeping `sourceToHuman()` for the detail panel. Clean separation of concerns.

---

## Category Scores

### Correctness: 29/30

**Improved from v032 (28/30):**
- Test count jumped 268 → 309 (+41 tests, 15.3% increase)
- 25 new tests for session cron scanner (projectNameFromDir, parseSessionJsonl, scanSessionCronTasks)
- 6 new tests for sourceToShort
- Bug found and fixed during TDD (pre-filter was too aggressive)

**Issues:**

1. **LOW — Content-based dedup could produce false collisions.** `scanner.ts:610`: The dedup key is `schedule + description[:50]`. Two different projects could have the same cron schedule and prompt prefix, causing one to be suppressed. A more robust key would include the project directory: `schedule + projDir + description[:50]`.

2. **LOW (carried) — `removeRegisteredJob` writes empty file on ENOENT.** `store.ts:57-60`.

### Architecture: 20/20

**Improved from v032 (19/20):**

The session cron scanner follows excellent architectural patterns:

- **Streaming I/O:** `createReadStream` + `readline` prevents loading entire JSONL files into memory
- **Smart filtering:** The pre-filter skip heuristic (`hasCronOp || hasPending`) avoids parsing 99%+ of JSONL lines
- **Layered design:** `parseSessionJsonl()` is a pure parser, `scanSessionCronTasks()` orchestrates discovery, `scanDurableScheduledTasks()` is the fallback. Each has a single responsibility.
- **New types:** `CronLifecycle` type (`session-only | durable`) and optional `sessionId`/`lifecycle` fields on `Job` — backward-compatible extensions
- **Existing code unchanged:** `scanClaudeScheduledTasks()` remains for backward compatibility, new scanner wired in at the loader level only

The `clearScreen()` on auto-refresh (v031 P2) was not addressed in this cycle. Keeping score at 20/20 because the architectural improvement from the new scanner outweighs this carried issue.

### Production-readiness: 19/20

3. **MEDIUM (carried) — `auto-commit.sh` uses `git add -A`.** Still not addressed.

4. **LOW (carried) — Missing `LICENSE` file.** `package.json` declares MIT but no license file exists.

5. **LOW (carried) — `prepublishOnly` order wrong.** Should be build-then-test, not test-then-build.

### Open-source quality: 14/15

**Improved:**
- Test count from 268 to 309 demonstrates active testing culture
- `sourceToShort` tests include a meta-test verifying all values fit within the 9-char column width — good defensive testing pattern
- New test file `session-cron.test.ts` uses real temp files for integration tests (not just mocks), increasing confidence

6. **LOW (carried) — Missing LICENSE file.**

7. **LOW (carried) — Test assertions use partial regex in narrow terminal.**

### Security: 14/15

**Session JSONL Scanner Security Review:**

The scanner reads files from `~/.claude/projects/*/`. Key security considerations:

- ✅ No user input reaches file paths — directory structure is derived from `os.homedir()`
- ✅ `readdir` + `stat` + `createReadStream` — no shell expansion or injection vectors
- ✅ JSONL parsing uses `JSON.parse` with try/catch — malformed data can't crash the process
- ✅ File age filter (7 days) limits the attack surface for stale/tampered files

8. **LOW — Directory traversal not explicitly prevented.** `scanner.ts:551`: `projDir` comes from `readdir()` output, which could theoretically contain `../` entries on a compromised filesystem. While `readdir` normally returns direct children only, a `path.resolve()` + containment check would be defensive.

---

## Feature Brainstorming: Docker/Container Monitoring

### Current State

The dashboard monitors 4 data sources but has no container awareness. With AI agents increasingly deploying to Docker containers, this is a natural extension.

### Detection Strategy

| Signal | Method | Latency | Reliability |
|--------|--------|---------|-------------|
| `docker ps` | `execFile("docker", ["ps", "--format", "json"])` | ~100ms | High (if Docker running) |
| `docker events` | Long-lived stream (`docker events --filter type=container`) | Real-time | High |
| `docker-compose.yml` | File watcher on project directories | Instant | Medium (only if compose used) |
| Docker socket | `/var/run/docker.sock` API | ~50ms | High |

### Proposed: `scanDockerContainers()`

```typescript
interface DockerContainer {
  id: string;
  name: string;
  image: string;
  ports: string[];
  status: string;
  created: string;
}

export function scanDockerContainers(): Promise<Job[]> {
  return new Promise((resolve) => {
    execFile("docker", ["ps", "-a", "--format", "{{json .}}"],
      { encoding: "utf-8", timeout: 5000 },
      (err, stdout) => {
        if (err) { resolve([]); return; }

        const containers = stdout.trim().split("\n")
          .filter(Boolean)
          .map(line => {
            try { return JSON.parse(line) as DockerContainer; }
            catch { return null; }
          })
          .filter(Boolean);

        const jobs = containers.map(c => ({
          id: `docker-${c.id.slice(0, 12)}`,
          name: c.name,
          description: `${c.image} — ${c.status}`,
          agent: inferAgentFromContainer(c),
          schedule: "container",
          status: c.status.startsWith("Up") ? "active" : "stopped",
          source: "docker" as const,
          // ... remaining fields
        }));

        resolve(jobs);
      }
    );
  });
}
```

### Agent Detection for Containers

How to determine if a container was created by an AI agent?

| Heuristic | Signal | Confidence |
|-----------|--------|-----------|
| Container labels | `--label created-by=claude-code` | High |
| Image name | `claude-*`, `copilot-*` | Medium |
| Container name pattern | `claude-code-*`, `agent-*` | Medium |
| Creation time correlation | Container created within 5s of a registered job | Low |
| Volume mounts | Mounts to agent working directory | Medium |

### Challenges

1. **Docker may not be installed** — scanner must handle `ENOENT` on the `docker` binary
2. **Permission issues** — some Docker setups require sudo
3. **Docker Desktop vs CLI** — different socket paths on macOS
4. **Container churn** — short-lived build containers create noise
5. **Docker Compose services** — should group by compose project

### New Job Source Type

Would require adding `"docker"` to `JobSource`:

```typescript
export type JobSource = "registered" | "live" | "cron" | "launchd" | "docker";
```

And a new tab filter or integration into existing "live" tab.

### Effort/Impact

| Feature | Effort | Impact |
|---------|--------|--------|
| Basic `docker ps` scanner | 1 day | Medium — adds 5th data source |
| Docker events watcher | 2 days | High — real-time container lifecycle |
| Compose project grouping | 1 day | Medium — better UX for multi-container apps |
| Agent detection heuristics | 0.5 day | Medium — accurate attribution |

---

## Action Items

### P1

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 3 | `auto-commit.sh` stages all files | ⚠️ Carried | Not addressed since v030 |

### P2

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| — | SOURCE column raw codes | ✅ **Fixed** in `7125ee6` | `sourceToShort()` added |
| — | Cron task ID stability | ✅ **Fixed** in `e111d1e` | Session-scoped IDs (`cron-{session}-{cronId}`) |
| 5 | clearScreen on auto-refresh | ⚠️ Carried | Causes brief flash every 10s |
| 4/6 | Missing LICENSE file | ⚠️ Carried | MIT declared but no file |
| 5 | prepublishOnly order | ⚠️ Carried | Build should precede test |

### P3

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | Dedup key could collide cross-project | New | Add projDir to dedup key |
| 8 | No directory traversal guard in scanner | New | Low risk, defensive improvement |

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
```

---

## Brainstorming Exploration Tracker

| # | Direction | Explored In | Depth |
|---|-----------|-------------|-------|
| 1 | Multi-agent scheduled task support | v031 | Deep |
| 2 | Editor HUD/statusline integration | v032 | Deep |
| 3 | Adapter/plugin architecture | v031 | Medium |
| 4 | Docker/container monitoring | **v033** | **Deep — scanner sketch, agent detection, challenges** |
| 5 | Cross-platform support (Linux systemd) | — | Not yet explored |

**Next brainstorm (v034):** Cross-platform support — systemd timers on Linux, Task Scheduler on Windows.

---

## Codebase Metrics

| Metric | v032 | v033 | Δ |
|--------|------|------|---|
| Production LOC | 2,432 | 2,899 | +467 |
| Test LOC | 2,794 | 3,493 | +699 |
| Test-to-code ratio | 1.15:1 | 1.20:1 | +0.05 |
| Test count | 268 | 309 | +41 |
| Coverage (stmts) | 91.7% | 90.7% | -1.0% |
| Coverage (funcs) | 88.6% | 87.8% | -0.8% |
| Coverage (lines) | 92.5% | 92.2% | -0.3% |
| Source files | 14 | 14 | = |
| Test files | 8 | 9 | +1 |

Coverage dipped slightly (~1%) due to the large new feature adding more branches (friendlyCronName patterns), but remains well above the 85% threshold on all dimensions.

---

## Summary

v033 scores **96/100** (+2 from v032). Two significant code changes: (1) session JSONL cron scanner that discovers cron tasks from Claude Code session logs using streaming readline + smart pre-filter, fixing a critical pre-filter bug caught during TDD; (2) source column UX fix showing readable labels instead of raw enum values. Test count grew 15.3% (268→309) with a new test file for integration-style tests using real temp files. Two carried P2 issues resolved. Architecture remains clean with the scanner following the established parallel-scan pattern. Docker/container monitoring brainstormed as the next data source expansion. Key remaining issues: auto-commit staging scope (P1), clearScreen flicker (P2), missing LICENSE file (P2).
