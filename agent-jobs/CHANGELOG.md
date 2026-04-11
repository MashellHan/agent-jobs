# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0 (2026-04-11)

Initial public release.

### Features

- **TUI Dashboard**: Interactive terminal UI built with Ink (React for CLI)
  - Tab-based navigation (Dashboard, Settings)
  - Keyboard shortcuts: arrow keys, Enter to expand, q to quit
  - Inline detail panel with job metadata
- **Auto-Detection**: PostToolUse hook captures 14 service patterns
  - pm2, nohup, docker run, systemctl, launchctl, docker-compose
  - flask, uvicorn, gunicorn, next dev, vite dev, and more
- **Live Process Scanner**: Discovers running services via lsof
  - Port extraction, friendly names, framework detection
- **Cron Task Scanner**: Reads Claude Code scheduled tasks
- **Agent Support**: Claude Code, Cursor, GitHub Copilot, OpenClaw
- **Human-Readable Display**: cronToHuman schedules, relative time AGE column
- **CLI Commands**: `agent-jobs` (TUI), `agent-jobs list` (JSON), `agent-jobs setup`/`teardown`
- **Zero-Config Install**: postinstall hook auto-registers the PostToolUse hook
- **Atomic Writes**: temp-file-then-rename for jobs.json and settings.json
