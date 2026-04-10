# Agent Jobs Review — v002
**Date:** 2026-04-11T00:40:00Z
**Reviewer:** Claude Code (Automated)
**Git HEAD:** 9bfbab6 (still only initial commit — all new work is uncommitted)
**Files scanned:** 33
**Previous review:** v001 (2026-04-11T00:30:00Z, score 28/100)

## Overall Score: 30/100

+2 from v001. The critical `detect.ts` stdin echo bug (C4 in v001) has been fixed — `process.stdout.write(raw)` is now at line 271. `tsup` was added to devDependencies. No other changes observed. All other critical and high-priority issues from v001 remain open.

---

## Category Scores

| Category | Score | v001 | Delta | Status |
|----------|-------|------|-------|--------|
| A. Architecture & Design | 4/10 | 4/10 | — | 🔴 |
| B. Functionality Completeness | 3/10 | 3/10 | — | 🔴 |
| C. Code Quality | 5/10 | 5/10 | — | 🟡 |
| D. UI/UX | 5/10 | 5/10 | — | 🟡 |
| E. Performance | 6/10 | 6/10 | — | 🟡 |
| F. Stability & Error Handling | 5/10 | 4/10 | +1 | 🟡 |
| G. Installation & Distribution | 2/10 | 2/10 | — | 🔴 |
| H. Git & Open Source Readiness | 1/10 | 1/10 | — | 🔴 |
| I. Feature Brainstorm | — | — | — | — |

---

## Diff Since Last Review (v001)

### Fixed
- **C4 (CRITICAL): `detect.ts` now echoes stdin to stdout** — `process.stdout.write(raw)` added at line 271, before JSON parsing. This is correct placement: even if JSON parse fails, stdout is echoed. Hook contract is now satisfied.
- **`tsup` added to devDependencies** — `package.json:24` now has `"tsup": "^8.5.1"`. Build tooling is available but not yet wired up.

### Not Fixed (carried from v001)
- C1: `bin` still points to raw `.ts` file
- C2: Go binary still in tree (4.9MB)
- C3: No `.gitignore`
- C5: No `postinstall`/`preuninstall`
- C6: Package name still `agent-job-dashboard`
- H1-H7: All high priority items open
- M1-M8: All medium priority items open

---

## Critical Issues (must fix)

### C1. [CARRIED] `bin` points to `.ts` — npm install is broken
**File:** `ts-demo/package.json:7-8`
```json
"bin": { "agent-jobs": "./src/cli/index.ts" }
```
`tsup` is now in devDependencies but there is no `build` script, no `tsup.config.ts`, and `bin` still points to source. Users who `npm install -g` will get a TypeScript syntax error when running `agent-jobs`.

**Fix priority:** This is the #1 blocker. Add:
```json
{
  "scripts": {
    "build": "tsup src/cli/index.ts src/cli/detect.ts src/index.tsx --format esm --dts",
    "prepublishOnly": "npm run build"
  },
  "bin": { "agent-jobs": "./dist/cli/index.js" },
  "files": ["dist"]
}
```

### C2. [CARRIED] Go binary in source (4.9MB)
**File:** `agent-jobs/agent-jobs` — Mach-O 64-bit arm64 executable
Still present. Will bloat git history permanently once committed.

### C3. [CARRIED] No `.gitignore`
Still no `.gitignore` at any level. `.DS_Store` already in the file list.

### C4. [NEW] `detect.ts` echoes stdin before parsing — timing issue
**File:** `ts-demo/src/cli/detect.ts:271`
The fix echoes stdin correctly, but there's a subtle issue: `readFileSync(0, "utf-8")` (line 261) is a synchronous blocking read of stdin. On some systems/Node versions, this can hang if stdin is a pipe and the writer hasn't closed its end yet. The current hook infra likely handles this fine, but a more robust approach would be the streaming pattern used by the existing `post-bash-command-log.js` hook:
```javascript
process.stdin.on('data', chunk => { raw += chunk })
process.stdin.on('end', () => { /* process + echo */ })
```

### C5. [CARRIED] No `postinstall`/`preuninstall` hooks
Zero-config goal is not met.

### C6. [CARRIED] Package name mismatch
`agent-job-dashboard` vs `agent-jobs` CLI binary name.

---

## High Priority (should fix)

### H1. [CARRIED] Demo directories must go
`go-demo/`, `python-demo/`, `agent-jobs/`, `shared/` are still present. 17 files and 4.9MB binary that add nothing to the shipping product.

### H2. [CARRIED] No LaunchAgent scanner
Still only `lsof` and `scheduled_tasks.json` scanners. The primary use case (Claude Code creates plist → hook captures → scanner shows status) has no scanner for the "show status" part.

Missing implementation:
```typescript
// scanLaunchdServices(registeredLabels: string[]): Service[]
// 1. For each label from registry, read plist
// 2. Parse with plutil -convert json -o - <plist> (or plist npm pkg)
// 3. Extract: ProgramArguments, StartInterval, StandardOutPath, etc.
// 4. Get live status: launchctl list <label> → pid, exit code
// 5. Map to Job model
```

### H3. [CARRIED] Hook command uses `npx tsx`
`setup.ts:19` still generates `npx tsx "/path/to/detect.ts"` as the hook command. This is ~500ms startup overhead per hook invocation, and breaks if the source path changes.

### H4. [CARRIED] Zero tests
No test files found anywhere.

### H5. [CARRIED] `loader.ts` sync lsof blocks event loop
`scanLiveProcesses()` uses `execFileSync` which freezes the TUI.

### H6. [CARRIED] Registry write race condition
No file locking on `jobs.json` read-modify-write.

### H7. [CARRIED] `detect.ts` node/python patterns too broad
The backgrounded/server-output guards help but may miss cases where `tool_result` is absent.

### H8. [NEW] No `tsup` configuration or build script
`tsup` was added as a dependency but there's no:
- `tsup.config.ts`
- `"build"` script in package.json
- Any `dist/` output
- `"prepublishOnly"` hook

It's a dangling dependency that does nothing yet.

### H9. [NEW] `detect.ts` uses `readFileSync(0)` instead of stream
Unlike the existing hooks in `~/.claude/scripts/hooks/post-bash-command-log.js` (which reads stdin via `process.stdin.on('data'/'end')`), `detect.ts` uses `readFileSync(0, "utf-8")`. This works but is the less standard pattern for Node.js stdin and could cause issues with large payloads or unusual pipe semantics.

---

## Medium Priority (nice to have)

### M1. [CARRIED] Hardcoded separator width (120 chars)
### M2. [CARRIED] 10s refresh comment says 15s
### M3. [CARRIED] Tab "live" includes "cron" — confusing
### M4. [CARRIED] `utils.ts` functions accept `string` not typed unions
### M5. [CARRIED] No onboarding empty state
### M6. [CARRIED] `JobsFile` type duplicated between `detect.ts` and `types.ts`
### M7. [CARRIED] Only watches `jobs.json`, not `scheduled_tasks.json`
### M8. [CARRIED] Redundant `index.tsx` entry point

### M9. [NEW] `detect.ts` dedup uses `name` not `id`
**File:** `ts-demo/src/cli/detect.ts:159`
```typescript
if (file.jobs.some((j) => j.name === label)) return false;
```
If a user creates two different plist files that resolve to the same label (e.g., two `com.pew.sync.plist` in different paths), only the first is registered. Should dedup by a richer key like `source + file_path` or `label + project`.

### M10. [NEW] `registerJob` hardcodes `agent: "claude-code"`
**File:** `ts-demo/src/cli/detect.ts:168`
Since this runs as a PostToolUse hook in Claude Code, this is technically correct. But for future multi-agent support, the agent should be detected from hook environment variables or passed as context.

### M11. [NEW] No `--version` command
No version display anywhere. Should read from `package.json`.

---

## Low Priority (polish)

### L1. [CARRIED] Monotone magenta color scheme
### L2. [CARRIED] Footer separator missing
### L3. [CARRIED] Detail view doesn't show log paths
### L4. [CARRIED] No `--version`
### L5. [CARRIED] `shared/jobs.json` has hardcoded user paths

### L6. [NEW] `cli/index.ts` uses top-level `await import()` for `list` command
**File:** `ts-demo/src/cli/index.ts:38`
```typescript
case "list": {
  const { readFileSync, existsSync } = await import("fs");
```
Top-level await requires Node 14.8+ and ESM. Should be fine for the target audience but worth noting in engine requirements.

### L7. [NEW] `cli/index.ts` list command reimplements job loading
**File:** `ts-demo/src/cli/index.ts:37-56`
This inlines its own `readFileSync` + `JSON.parse` logic instead of reusing `loader.ts`. Duplication.

---

## Feature Proposals

### Proposal 1: Build Pipeline (blocking everything else)
**Value:** Critical — without this, nothing else matters
**Effort:** 30 minutes
**Design sketch:**
```bash
# tsup.config.ts
export default {
  entry: ['src/cli/index.ts', 'src/cli/detect.ts', 'src/index.tsx'],
  format: ['esm'],
  target: 'node18',
  clean: true,
  dts: true,
  external: ['ink', 'react'],
  banner: { js: '#!/usr/bin/env node' }  // for CLI entry
}
```
```json
// package.json additions
{
  "bin": { "agent-jobs": "./dist/cli/index.js" },
  "files": ["dist"],
  "scripts": {
    "build": "tsup",
    "prepublishOnly": "npm run build",
    "postinstall": "node dist/cli/index.js setup",
    "preuninstall": "node dist/cli/index.js teardown"
  }
}
```

### Proposal 2: Project Restructure
**Value:** High — makes this look like a real npm package, not a dump of experiments
**Effort:** 15 minutes
**Design sketch:**
```
agent-jobs/                  # repo root
├── src/                     # move ts-demo/src/ here
│   ├── cli/
│   ├── components/
│   ├── scanners/            # new: one file per scanner
│   │   ├── launchd.ts
│   │   ├── live.ts
│   │   ├── cron.ts
│   │   └── index.ts         # orchestrator
│   ├── app.tsx
│   ├── types.ts
│   └── ...
├── tests/                   # new
│   ├── detect.test.ts
│   ├── scanner.test.ts
│   └── ...
├── package.json
├── tsconfig.json
├── tsup.config.ts
├── .gitignore
├── README.md
├── LICENSE
├── CONTRIBUTING.md
└── CHANGELOG.md
```
Delete: `go-demo/`, `python-demo/`, `agent-jobs/`, `shared/`, `ts-demo/` wrapper

### Proposal 3: Test Suite for `detect.ts` (highest ROI test)
**Value:** High — detect.ts is the most critical code, zero-tolerance for missed or false detections
**Effort:** 1-2 hours
**Design sketch:**
```typescript
// tests/detect.test.ts
import { detect } from "../src/cli/detect.js";

describe("detect", () => {
  // True positives
  it("detects launchctl load", () => {
    expect(detect({
      tool_name: "Bash",
      tool_input: { command: "launchctl load ~/Library/LaunchAgents/com.pew.sync.plist" }
    })).toBe(true);
  });

  // True negatives
  it("ignores simple node script", () => {
    expect(detect({
      tool_name: "Bash",
      tool_input: { command: "node script.js" }
    })).toBe(false);
  });

  // Edge cases
  it("handles multiline commands", () => { ... });
  it("handles missing tool_input", () => { ... });
  it("deduplicates same service", () => { ... });
});
```

### Proposal 4: LaunchAgent scanner (repeat from v001, still top priority feature)
### Proposal 5: Log viewer panel (repeat from v001)
### Proposal 6: Service control start/stop (repeat from v001)

### Proposal 7: [NEW] `agent-jobs doctor` — Self-diagnostic command
**Value:** Medium — helps users debug when things don't work
**Effort:** 1 hour
**Design sketch:**
```bash
$ agent-jobs doctor

  Checking agent-jobs installation...

  ✓ CLI installed at /usr/local/bin/agent-jobs
  ✓ Registry dir exists (~/.agent-jobs/)
  ✓ Registry file exists (3 services tracked)
  ✗ PostToolUse hook NOT installed in ~/.claude/settings.json
    → Run: agent-jobs setup
  ✓ Claude Code running (3 sessions detected)
  ⚠ scheduled_tasks.json not found (no durable cron tasks)
  ✓ Node.js v22.11.0 (>= 18 required)

  Overall: 1 issue found
```

### Proposal 8: [NEW] Configurable scanner intervals
**Value:** Low-medium — power users want to control scan frequency
**Effort:** 30 minutes
**Design sketch:**
```json
// ~/.agent-jobs/config.json
{
  "refresh": {
    "registry": "on-change",      // fs.watch, instant
    "cronTasks": "on-change",     // fs.watch, instant
    "liveProcesses": 15,          // seconds
    "launchdStatus": 30           // seconds
  },
  "notifications": false,
  "theme": "dark"
}
```

---

## Progress Tracking

| v001 Issue | Status | Notes |
|------------|--------|-------|
| C1. bin→.ts | ❌ Open | tsup added but not wired |
| C2. Go binary | ❌ Open | |
| C3. No .gitignore | ❌ Open | |
| C4. No stdin echo | ✅ Fixed | line 271 |
| C5. No postinstall | ❌ Open | |
| C6. Package name | ❌ Open | |
| H1. Demo dirs | ❌ Open | |
| H2. No launchd scanner | ❌ Open | |
| H3. npx tsx hook | ❌ Open | |
| H4. No tests | ❌ Open | |
| H5. Sync lsof | ❌ Open | |
| H6. Race condition | ❌ Open | |
| H7. Broad patterns | ❌ Open | |

**Velocity note:** 1 critical and 1 minor fix in ~10 minutes. At this rate, the critical blockers alone need another 2-3 hours. The project restructure (H1) should happen before anything else — building on top of the `ts-demo/` nested structure will create rework.

---

## Actionable Next Steps (prioritized — updated from v001)

1. **[5 min] Delete demo directories** — `rm -rf go-demo/ python-demo/ agent-jobs/ shared/` — do this first to avoid committing 4.9MB binary
2. **[5 min] Move ts-demo/ to root** — `mv ts-demo/* . && rm -rf ts-demo/`
3. **[5 min] Add .gitignore** — node_modules, dist, .review, .DS_Store, *.plist
4. **[15 min] Wire up tsup build** — create `tsup.config.ts`, add build/prepublishOnly scripts, fix bin path
5. **[5 min] Add postinstall/preuninstall** to package.json
6. **[5 min] Rename package to `agent-jobs`** in package.json
7. **[5 min] Fix hook command** in setup.ts — use compiled `node dist/cli/detect.js`
8. **[30 min] Add README.md, LICENSE (MIT), CONTRIBUTING.md**
9. **[1 hr] Add detect.ts tests** — vitest or jest
10. **[2 hr] Implement LaunchAgent scanner**
11. **[30 min] Make lsof scan async**
12. **[30 min] Add atomic write to registry**
13. **[5 min] First clean git commit** — after steps 1-8 are done
14. **[10 min] Create GitHub repo and push**
