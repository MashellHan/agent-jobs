# agent-jobs

TUI dashboard to monitor and manage background services created by AI coding agents.

Designed for developers who use AI coding assistants (Claude Code, Cursor, Copilot, OpenClaw) — these tools frequently spin up background processes, cron tasks, and system services that are easy to lose track of. `agent-jobs` provides a single pane of glass to see everything running, where it came from, and control it.

## Features

### Data Sources

`agent-jobs` aggregates services from 4 concurrent data sources:

| Source | What it captures | How |
|--------|-----------------|-----|
| **Registered** | Services created during AI coding sessions | PostToolUse hook auto-detects service creation patterns |
| **Live** | Currently running processes listening on ports | `lsof -i -P -n -sTCP:LISTEN` scanning |
| **Cron** | Claude Code scheduled tasks | Reads `~/.claude/scheduled_tasks.json` |
| **Launchd** | macOS launch agents | Scans `~/Library/LaunchAgents/*.plist` via `plutil` |

### Detection Patterns

The PostToolUse hook detects **17 patterns** across two tool categories:

**Bash commands:**

| Pattern | Example |
|---------|---------|
| `launchctl load/bootstrap` | `launchctl load ~/Library/LaunchAgents/com.app.plist` |
| `pm2 start` | `pm2 start server.js` |
| `systemctl enable/start` | `systemctl start my-service` |
| `docker run -d` | `docker run -d --name api nginx` |
| `docker-compose up -d` | `docker-compose up -d` |
| `uvicorn` / `gunicorn` | `uvicorn app:main --port 8000` |
| `flask run` | `flask run --port 5000` |
| `npx serve/http-server` | `npx serve ./dist` |
| `next/nuxt/vite dev/start` | `next dev --port 3000` |
| `nohup ... &` | `nohup node worker.js &` |
| `node script.js` | `node server.js` (with server output) |
| `python script.py` | `python api.py` (with server output) |
| `deno run` / `bun run` | `deno run --allow-net server.ts` |

**File creation (Write/Edit):**

| Pattern | Example |
|---------|---------|
| `*.plist` | Creating a launchd plist file |
| `docker-compose.yml` | Writing a compose file |
| `*.service` | Creating a systemd unit file |

### Dashboard

- **Tab-based filtering** — All / Registered / Live / Active / Errors, with live counts
- **9-column table** — Status, Service, Agent, Source, Schedule, Last Run, Result, Created
- **Inline detail view** — expand any row to see full command, project, port, PID, schedule details, and run history
- **Auto-refresh** — file watching (debounced 300ms) on `jobs.json`, `hidden.json`, `scheduled_tasks.json`; live process re-scan every 10 seconds
- **Fullscreen alternate screen** — clean TUI canvas, restores terminal on exit (like `htop`)

### Actions

| Key | Action | Scope |
|-----|--------|-------|
| `s` | **Stop** (with y/n confirmation) | Registered: sets status to stopped; Live: sends SIGTERM; Launchd: `launchctl stop` |
| `x` | **Hide** from dashboard | Adds to `~/.agent-jobs/hidden.json`; registered jobs also removed from `jobs.json` |

### Agent Support

Automatically infers which AI tool created a service:

| Agent | Detection |
|-------|-----------|
| Claude Code | Command contains "claude" |
| Cursor | Command contains "cursor" |
| GitHub Copilot | Command contains "copilot" |
| OpenClaw | Command contains "openclaw" or "claw" |
| Manual | Fallback for unrecognized sources |

## Install

```bash
npm install -g agent-jobs
```

The `postinstall` script automatically injects a PostToolUse hook into `~/.claude/settings.json`. On uninstall, `preuninstall` cleans it up.

### Requirements

- Node.js >= 18
- macOS (for launchd scanning; other features work cross-platform)

## Usage

```bash
# Launch TUI dashboard (default command)
agent-jobs

# List registered jobs (plain text, non-interactive)
agent-jobs list

# Manually install/remove the PostToolUse hook
agent-jobs setup
agent-jobs teardown

# Show version
agent-jobs --version

# Show help
agent-jobs help
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `q` | Quit |
| `r` | Manual refresh |
| `d` / `Enter` | Toggle detail view |
| `Esc` | Close detail view |
| `s` | Stop service (with confirmation) |
| `x` | Hide service from dashboard |
| `Up` / `Down` | Navigate jobs |
| `Left` / `Right` | Switch tabs |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  CLI Entry (cli/index.ts)                               │
│  setup | teardown | detect | dashboard | list | help    │
└───────────┬─────────────────────────┬───────────────────┘
            │                         │
   ┌────────▼────────┐      ┌────────▼────────┐
   │  PostToolUse     │      │  TUI Dashboard   │
   │  Hook Pipeline   │      │  (Ink + React)   │
   │                  │      │                  │
   │  detect.ts       │      │  app.tsx         │
   │  17 patterns     │      │  components/     │
   │  atomic write    │      │    header        │
   │  file lock       │      │    tab-bar       │
   └────────┬─────────┘      │    job-table     │
            │                │    job-detail    │
            │                │    footer        │
   ┌────────▼─────────┐      └────────┬─────────┘
   │ ~/.agent-jobs/    │               │
   │   jobs.json       │◄──────────────┤ fs.watch
   │   hidden.json     │               │
   └──────────────────┘      ┌────────▼─────────┐
                             │  Data Loader      │
                             │  loader.ts        │
                             │                   │
                             │  4 parallel scans: │
                             │  ├ registered     │
                             │  ├ live (lsof)    │
                             │  ├ cron (claude)  │
                             │  └ launchd (plist)│
                             └───────────────────┘
```

### Data Flow

1. **Hook registration**: When Claude Code runs a tool (Bash/Write/Edit), the PostToolUse hook (`detect.ts`) receives the tool input/output via stdin, pattern-matches against 17 service signatures, and appends detected services to `~/.agent-jobs/jobs.json` with file-level locking and atomic writes.

2. **Dashboard loading**: On startup (and every 10s), the dashboard runs 4 parallel scans — registered jobs from `jobs.json`, live TCP listeners via `lsof`, Claude scheduled tasks from `~/.claude/scheduled_tasks.json`, and launchd agents from `~/Library/LaunchAgents/*.plist`.

3. **Reactive updates**: `fs.watch` monitors `jobs.json`, `hidden.json`, and `scheduled_tasks.json` with 300ms debounce, triggering a full refresh on any change.

### Key Design Decisions

- **Atomic writes** — All JSON mutations use write-to-temp-then-rename to prevent corruption on concurrent access.
- **File locking** — The detection hook uses an exclusive lock file (`jobs.lock`) with stale lock detection to prevent race conditions between multiple hook invocations.
- **Alternate screen buffer** — The TUI enters `\x1b[?1049h` on start and restores on exit/SIGINT/SIGTERM for a clean terminal experience.
- **Graceful degradation** — Each scanner resolves to `[]` on error rather than crashing the dashboard.
- **No external dependencies at runtime** — Only `ink` and `react`; all scanning uses Node.js built-ins and system commands.

## Project Structure

```
agent-jobs/
├── src/
│   ├── cli/
│   │   ├── index.ts          CLI router (setup/teardown/detect/dashboard/list/help)
│   │   ├── detect.ts         PostToolUse hook: pattern matching + job registration
│   │   ├── setup.ts          Hook injection into ~/.claude/settings.json
│   │   └── setup.test.ts     Setup/teardown tests
│   ├── components/
│   │   ├── header.tsx        Dashboard header with status counts
│   │   ├── tab-bar.tsx       Tab filter bar (All/Registered/Live/Active/Errors)
│   │   ├── job-table.tsx     Table header + job rows
│   │   ├── job-detail.tsx    Expandable inline detail panel
│   │   └── footer.tsx        Keyboard shortcut hints
│   ├── app.tsx               Main App component (state, keyboard handling, layout)
│   ├── app.test.tsx          App component tests
│   ├── index.tsx             Ink render entry + alternate screen setup
│   ├── ink-instance.ts       Shared Ink instance reference
│   ├── loader.ts             Data loading + fs.watch file watchers
│   ├── loader.test.ts        Loader tests
│   ├── scanner.ts            Live process / Claude cron / launchd scanners
│   ├── scanner.test.ts       Scanner tests
│   ├── store.ts              Atomic persistence (jobs.json, hidden.json)
│   ├── store.test.ts         Store tests
│   ├── types.ts              TypeScript types and constants
│   ├── utils.ts              Formatting helpers (time, cron, names, icons)
│   ├── utils.test.ts         Utils tests
│   ├── fixtures.ts           Shared test fixtures
│   └── job-table.test.tsx    JobTable component tests
├── package.json
├── tsconfig.json             Strict TypeScript (ES2022, NodeNext)
├── tsup.config.ts            Dual build: CLI (with shebang) + TUI entry
├── vitest.config.ts          Test config (85% coverage threshold)
├── CHANGELOG.md
└── CONTRIBUTING.md
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Runtime** | Node.js >= 18, ES modules |
| **Language** | TypeScript (strict mode, no `any`) |
| **UI Framework** | [Ink](https://github.com/vadimdemedes/ink) 5 (React for terminals) |
| **React** | React 18 (functional components, hooks) |
| **Build** | [tsup](https://github.com/egoist/tsup) (ESM, sourcemaps, declarations) |
| **Test** | [Vitest](https://vitest.dev/) + [ink-testing-library](https://github.com/vadimdemedes/ink-testing-library) |
| **Coverage** | v8 provider, 85% statements/lines/functions, 75% branches |

## Development

```bash
git clone https://github.com/MashellHan/agent-jobs.git
cd agent-jobs
npm install

npm run dev            # Watch mode with tsx
npm run build          # Production build via tsup
npm test               # Run tests
npm run test:watch     # Watch mode
npm run test:coverage  # Coverage report
```

### Build Output

`tsup` produces two build targets:

1. **`dist/cli/index.js`** + **`dist/cli/detect.js`** — CLI entry points with `#!/usr/bin/env node` shebang
2. **`dist/index.js`** — TUI entry point (no shebang, imported by CLI router)

## Data Storage

All data lives in `~/.agent-jobs/`:

| File | Purpose |
|------|---------|
| `jobs.json` | Registered jobs (from PostToolUse hook detection) |
| `hidden.json` | IDs of jobs hidden by the user |
| `jobs.lock` | Exclusive lock file for concurrent hook access |

## License

MIT
