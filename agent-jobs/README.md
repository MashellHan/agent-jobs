# agent-jobs

TUI dashboard to monitor and manage background services created by AI coding agents (Claude Code, Cursor, Copilot, OpenClaw).

## Features

- **Auto-detection** — PostToolUse hook automatically registers services when Claude Code creates them
- **Live process scanning** — discovers running services via `lsof`
- **Claude Code cron tasks** — reads `~/.claude/scheduled_tasks.json`
- **Tab-based filtering** — All / Registered / Live / Active / Error
- **Inline detail view** — expand any job to see full details
- **File watching** — reactive updates when `jobs.json` changes
- **Zero config** — `npm install` auto-installs the hook

## Install

```bash
npm install -g agent-jobs
```

The `postinstall` script automatically injects a PostToolUse hook into `~/.claude/settings.json`.

## Usage

```bash
# Launch TUI dashboard
agent-jobs

# List registered jobs
agent-jobs list

# Manually install/remove hook
agent-jobs setup
agent-jobs teardown

# Show help
agent-jobs help
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `q` | Quit |
| `r` | Refresh |
| `d` / `Enter` | Toggle detail view |
| `Esc` | Close detail |
| `Up` / `Down` | Navigate jobs |
| `Left` / `Right` | Switch tabs |

## How it works

```
Claude Code creates a service (Write .plist, Bash pm2 start, etc.)
        |
        v
PostToolUse hook fires → agent-jobs detect
        |
        v
Pattern matching (launchctl, pm2, docker, node, python, etc.)
        |
        v
Registers to ~/.agent-jobs/jobs.json
        |
        v
TUI dashboard auto-refreshes (fs.watch)
```

### Detected patterns

| Pattern | Trigger |
|---------|---------|
| `launchctl load/bootstrap` | Bash command |
| `pm2 start` | Bash command |
| `systemctl enable/start` | Bash command |
| `docker run -d` | Bash command |
| `docker-compose up -d` | Bash command |
| `uvicorn` / `gunicorn` / `flask run` | Bash command |
| `nohup ... &` | Bash command |
| `node script.js` (with server output) | Bash command |
| `*.plist` file creation | Write/Edit |
| `docker-compose.yml` creation | Write/Edit |
| `*.service` file creation | Write/Edit |

## Development

```bash
git clone https://github.com/MashellHan/agent-jobs.git
cd agent-jobs
npm install
npm run dev    # Watch mode
npm run build  # Production build
npm test       # Run tests
```

## Testing

```bash
npm test              # Run tests
npm run test:watch    # Watch mode
npm run test:coverage # Coverage report (threshold: 70%)
```

## License

MIT
