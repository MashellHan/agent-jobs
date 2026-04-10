# Agent Jobs Review — v001
**Date:** 2026-04-11T00:30:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (Initial commit — everything is uncommitted)
**Files scanned:** 33

## Overall Score: 28/100

This is an early-stage prototype with 3 demo implementations (Go, Python, TypeScript) and a partially-implemented TypeScript version that is being developed into the real product. The demos should be removed. The core hook + scanner + TUI pipeline exists but has significant gaps in architecture, distribution, testing, and open-source readiness.

---

## Category Scores

| Category | Score | Status | Notes |
|----------|-------|--------|-------|
| A. Architecture & Design | 4/10 | 🔴 | Multi-language demos pollute project, no build step, bin points to .ts |
| B. Functionality Completeness | 3/10 | 🔴 | No LaunchAgent scanner, no log viewer, no start/stop, no status command |
| C. Code Quality | 5/10 | 🟡 | TypeScript types decent, but detect.ts has unsafe patterns, no tests |
| D. UI/UX | 5/10 | 🟡 | Tab bar + detail view good, but separator hardcoded 120 chars, no scrolling |
| E. Performance | 6/10 | 🟡 | Hook detect is sync/fast, but lsof scanner blocks main thread |
| F. Stability & Error Handling | 4/10 | 🔴 | No validation of hook stdin size, no lock on registry writes |
| G. Installation & Distribution | 2/10 | 🔴 | bin points to .ts file, no build, no postinstall, needs tsx at runtime |
| H. Git & Open Source Readiness | 1/10 | 🔴 | No .gitignore, README, LICENSE, CONTRIBUTING, compiled binary in tree |
| I. Feature Brainstorm | -/10 | — | See proposals below |

---

## Critical Issues (must fix)

### C1. `bin` in package.json points to raw `.ts` file
**File:** `ts-demo/package.json:8`
```json
"bin": { "agent-jobs": "./src/cli/index.ts" }
```
npm will install this as-is. Users running `agent-jobs` will get a syntax error unless they have `tsx` globally installed. This is a **broken install for every user**.

**Fix:** Add a build step (`tsc` or `tsup`), point `bin` to `dist/cli/index.ts`, or use a shim that calls `npx tsx`.

### C2. Compiled Go binary checked into source
**File:** `agent-jobs/agent-jobs` (14MB+ compiled binary)
This binary file will be committed to git. It should never be in source control.

### C3. No `.gitignore` — entire project is untracked
No `.gitignore` exists at any level. `node_modules/`, `.venv/`, compiled binaries, `.review/`, and OS files will all be committed.

### C4. `detect.ts` does NOT echo stdin back to stdout
**File:** `ts-demo/src/cli/detect.ts:258-284`
The `main()` function reads stdin, processes it, but **never writes stdin back to stdout**. This violates the PostToolUse hook contract. Every Claude Code hook MUST echo the original JSON to stdout. Without this, Claude Code will receive empty output and may malfunction.

**Fix:** Add `process.stdout.write(raw)` before `process.exit(0)` in every exit path, or at the end of `main()`.

### C5. No `postinstall` / `preuninstall` scripts
**File:** `ts-demo/package.json`
The setup/teardown of hooks is not automated. Users must manually run `agent-jobs setup`. This defeats the "zero config" goal.

### C6. Package name is `agent-job-dashboard`, not `agent-jobs`
**File:** `ts-demo/package.json:2`
The npm package name doesn't match the CLI binary name. Confusing for users.

---

## High Priority (should fix)

### H1. Three demo implementations should be deleted
`go-demo/`, `python-demo/`, `agent-jobs/` (Go version) are prototype explorations. They:
- Add 1400+ lines of code that won't be maintained
- Confuse contributors about which is the "real" implementation
- Contain hardcoded `../shared/jobs.json` paths
- The Go version has its own `go.mod` with a `github.com/MashellHan/agent-jobs` module path

**Fix:** Delete `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/`. Promote `ts-demo/` to project root.

### H2. No LaunchAgent scanner
The design discussion identified LaunchAgent scanning as the most important data source (since Claude Code creates plist files via Write + launchctl load). But `scanner.ts` only has `scanLiveProcesses()` (lsof) and `scanClaudeScheduledTasks()`. No plist parsing, no `launchctl list` integration.

### H3. `setup.ts` uses `npx tsx` as the hook command
**File:** `ts-demo/src/cli/setup.ts:19`
```typescript
return `npx tsx "${detectScript}"`;
```
Problems:
- `npx tsx` takes ~500ms to boot — too slow for a PostToolUse hook
- Points to source `.ts` file path which may not exist after npm global install
- `npx` may resolve to a different version of `tsx`

**Fix:** After build, the hook command should be `node /path/to/dist/cli/detect.js`. No `npx`, no `tsx` at runtime.

### H4. No tests — 0% coverage
Zero test files found. The `detect.ts` pattern matching logic is the most critical code (if it misdetects, services are silently lost) and has zero test coverage.

### H5. `loader.ts` mixes sync and async patterns
**File:** `ts-demo/src/loader.ts:9-17`
```typescript
export function loadAllJobs(): Promise<Job[]> {
  return new Promise((resolve) => {
    loadRegisteredJobs().then((registered) => {
      const live = scanLiveProcesses();      // SYNC - blocks event loop
      const cron = scanClaudeScheduledTasks(); // SYNC
```
`scanLiveProcesses()` calls `execFileSync("lsof")` which blocks the Node event loop. In the TUI, this freezes rendering for the duration of the lsof scan (can be 100ms+).

**Fix:** Use `execFile` (async) or `child_process.spawn` with promise wrapper.

### H6. Registry write race condition
**File:** `ts-demo/src/cli/detect.ts:156-182`
`registerJob()` does read-modify-write on `jobs.json` without any file locking. If two Claude Code tool calls fire concurrently, both hooks will read the old state and one write will be lost.

**Fix:** Use `fs-ext` flock, atomic rename (`writeFileSync` to temp + `renameSync`), or use append-only JSONL.

### H7. `detect.ts` pattern for node/python scripts is too broad
**File:** `ts-demo/src/cli/detect.ts:74-88`
Any `node script.js` or `python script.py` command matches. Most of these are one-off scripts, not servers. The `isBackground` and `hasServerOutput` guards help, but `tool_result` (output) is not always present in PostToolUse hooks — need to verify what CC actually sends.

---

## Medium Priority (nice to have)

### M1. Hardcoded separator width
**File:** `ts-demo/src/components/job-table.tsx:30`
```tsx
<Text dimColor>{"─".repeat(120)}</Text>
```
Doesn't respond to terminal width. Will look broken in narrow terminals or overflow in wide ones.

### M2. `loadAllJobs` called every 10 seconds with full lsof scan
**File:** `ts-demo/src/app.tsx:70`
The comment says "15 seconds" but the code says `10_000`. The lsof scan is expensive. Should be separate intervals: registry (on fs.watch change), lsof (every 15-30s), cron (on fs.watch change).

### M3. Tab filter "live" includes "cron" — confusing semantics
**File:** `ts-demo/src/app.tsx:19`
```typescript
case "live":
  return jobs.filter((j) => j.source === "live" || j.source === "cron");
```
CronCreate tasks are scheduled, not "live". They should be a separate tab or in "registered".

### M4. `utils.ts` `statusIcon` takes `string` instead of `JobStatus`
**File:** `ts-demo/src/utils.ts:20`
```typescript
export function statusIcon(status: string): { icon: string; color: string }
```
Should accept `JobStatus` type for type safety.

### M5. No empty state design
When no jobs exist (fresh install), the dashboard shows "No jobs in this category" but no onboarding hint (how to register a job, how to trigger detection).

### M6. `detect.ts` `JobsFile` interface duplicated from `types.ts`
**File:** `ts-demo/src/cli/detect.ts:112-115`
Different definition than `types.ts:23-26` — `jobs` is `Array<Record<string, unknown>>` vs `Array<Omit<Job, "source">>`. Should share one type.

### M7. `watchJobsFile` only watches `jobs.json`, not `scheduled_tasks.json`
**File:** `ts-demo/src/loader.ts:41-58`
Changes to Claude's `scheduled_tasks.json` won't trigger a refresh. Need a second watcher.

### M8. Index.tsx still uses old monolithic pattern
**File:** `ts-demo/src/index.tsx`
```typescript
render(React.createElement(App));
```
Should be in `cli/index.ts` as the `dashboard` command, not a separate entry point.

---

## Low Priority (polish)

### L1. Color scheme uses only magenta — monotone
Everything is magenta. Consider a richer palette: different colors for different sources (cyan for live, green for active, yellow for cron).

### L2. Footer keys could have separator
Currently keys are space-separated. A `│` separator between them would improve readability (the Go version does this).

### L3. Detail view doesn't show log file paths
LaunchAgent plist files specify `StandardOutPath` / `StandardErrorPath`. These should appear in the detail view with a "press l to view" option.

### L4. No version display in CLI
`agent-jobs --version` is not handled.

### L5. `shared/jobs.json` has hardcoded user paths (`~/projects/...`)
These will appear in the git history of an open-source project.

---

## Feature Proposals

### Proposal 1: LaunchAgent Scanner with plist parsing
**Value:** Core feature — most services created by Claude Code on macOS are LaunchAgents
**Effort:** Medium (1-2 days)
**Design sketch:**
```typescript
// 1. Read registry.json for labels created by hooks
// 2. For each label, read plist from ~/Library/LaunchAgents/<label>.plist
// 3. Parse plist XML (use plist npm package or child_process plutil -convert json)
// 4. Get runtime status from: launchctl list | grep <label>
// 5. Extract: schedule (StartInterval/StartCalendarInterval), logs, command, keepalive
// 6. Map to Service model with source: "launchd"
```

### Proposal 2: Log Viewer Panel
**Value:** High — seeing why a service failed is the #1 follow-up after seeing error status
**Effort:** Medium (1-2 days)
**Design sketch:**
- Press `l` on a selected job to open log panel
- Split view: top half = job list, bottom half = log tail
- Read `StandardOutPath` / `StandardErrorPath` from plist
- Use `fs.watch` + `fs.createReadStream` for live tail
- Limit to last 50 lines to avoid memory issues
- Press `L` (shift) to open in `$EDITOR`

### Proposal 3: Service Control (start/stop/restart)
**Value:** High — users want to stop/restart services without leaving the dashboard
**Effort:** Low (half day)
**Design sketch:**
- Press `s` to stop: `launchctl unload <plist>` or `pm2 stop <name>`
- Press `S` to start: `launchctl load <plist>` or `pm2 start <name>`
- Press `R` to restart: stop + start
- Confirmation prompt before destructive action
- Status auto-updates after action

### Proposal 4: Health Check / Heartbeat
**Value:** Medium — proactively detect if a service is silently dead
**Effort:** Medium
**Design sketch:**
- For port-listening services: periodic TCP connect check
- For LaunchAgents: check `launchctl list` exit code
- For pm2: `pm2 jlist` status
- Show health indicator: 💚 healthy, 💛 degraded (high exit codes), 🔴 dead
- Optional: webhook notification on state change

### Proposal 5: Export & Reporting
**Value:** Medium — useful for teams who want to audit what agents created
**Effort:** Low (half day)
**Design sketch:**
- `agent-jobs export --format json|csv|markdown`
- Include: all registered services, current status, creation history
- `agent-jobs report` — summary with uptime statistics

### Proposal 6: Multi-Agent Support
**Value:** High — not just Claude Code, but Cursor, Copilot, Windsurf
**Effort:** Varies
**Design sketch:**
- Cursor: check `~/.cursor/` for similar task/config files
- Copilot: check `~/.config/github-copilot/`
- Each agent gets its own scanner module implementing a common interface
- Agent column in TUI shows which AI created the service
- Plugin system for community-contributed agent scanners

### Proposal 7: tmux Integration
**Value:** Medium — users who work in tmux want a status bar widget
**Effort:** Low
**Design sketch:**
- `agent-jobs status --format tmux` — outputs a tmux-compatible string
- Format: `AJ: 3● 1✗` (3 active, 1 error)
- Set in tmux.conf: `set -g status-right "#(agent-jobs status --format tmux)"`
- Refreshes on tmux status-interval

### Proposal 8: Desktop Notifications
**Value:** Medium — alert when a service crashes
**Effort:** Low
**Design sketch:**
- Use `node-notifier` or macOS `osascript -e 'display notification'`
- Trigger on: status change from active→error, exit code change
- Configurable in `~/.agent-jobs/config.json`: `{ "notifications": true }`
- Rate limit: max 1 notification per service per 5 minutes

---

## Diff Since Last Review

This is the first review. No previous review exists.

**Key observations:**
- Project started as 3 parallel demos (Go, Python, TypeScript) reading static JSON
- The TypeScript version (ts-demo/) is being evolved into the real product
- New files added since initial commit: `cli/detect.ts`, `cli/setup.ts`, `cli/index.ts`, `scanner.ts`, `loader.ts`, `types.ts`, `utils.ts`, `components/*.tsx`
- Architecture is heading in the right direction (hook detection + scanner + TUI)
- But critical distribution issues (no build step, bin→.ts) make it uninstallable

---

## Actionable Next Steps (prioritized)

1. **[BLOCKER] Fix detect.ts: add `process.stdout.write(raw)` to echo stdin** — without this, the hook breaks Claude Code
2. **[BLOCKER] Add build step** — `tsup` or `tsc`, point `bin` to compiled JS, remove `tsx` runtime dependency
3. **[BLOCKER] Add postinstall/preuninstall** — auto-setup/teardown hooks on npm install
4. **Delete demo directories** — remove `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/`. Move `ts-demo/` to root
5. **Add .gitignore** — node_modules, dist, .review, *.plist, compiled binaries
6. **Add README.md** — install instructions, screenshot/gif, feature list, contributing guide
7. **Add LICENSE** — MIT recommended for maximum adoption
8. **Add tests for detect.ts** — this is the most critical code path, needs 90%+ coverage
9. **Implement LaunchAgent scanner** — parse plist + launchctl list
10. **Fix hook command** — use compiled `node dist/cli/detect.js` instead of `npx tsx`
11. **Async lsof scan** — don't block the TUI event loop
12. **Add log viewer** (next major feature after the above are done)
13. **Rename package** — `agent-jobs` not `agent-job-dashboard`
14. **Fix registry write race** — atomic write or file lock
15. **Add tmux status output** — `agent-jobs status --format tmux`
