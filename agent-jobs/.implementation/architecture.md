# Architecture Overview

## Pipeline

```
PostToolUse Hook → detect.ts → jobs.json → TUI Dashboard
                                    ↑
                          scanner.ts (live processes, cron tasks)
```

## Data Flow

1. **Hook Trigger**: Claude Code fires PostToolUse after Bash/Write/Edit tool calls
2. **Detection** (`detect.ts`): Parses hook stdin JSON, matches 14 service patterns (pm2, docker, nohup, systemctl, etc.), extracts name/port/description
3. **Registration**: Deduplicates by name, writes to `~/.agent-jobs/jobs.json` via atomic temp-file-then-rename
4. **Live Scanner** (`scanner.ts`): On TUI launch, runs `lsof -i -P -n` to discover listening processes. Enriches with `ps` for full command, infers agent from command string
5. **Cron Scanner** (`scanner.ts`): Reads `~/.claude/scheduled_tasks.json` for Claude Code cron jobs
6. **Display** (`app.tsx` → components): Merges registered + live + cron jobs, renders tabbed TUI with Ink

## Component Tree

```
App (app.tsx)
├── Header (header.tsx)
├── TabBar (tab-bar.tsx)
├── TableHeader (job-table.tsx)
├── JobRow[] (job-table.tsx)
│   └── JobDetail (job-detail.tsx)  [inline expansion]
└── Footer (footer.tsx)
```

## Key Files

| File | Purpose |
|------|---------|
| `src/cli/detect.ts` | Hook handler — stdin parsing, pattern matching, job registration |
| `src/scanner.ts` | Live process discovery (lsof/ps) and cron task reading |
| `src/utils.ts` | Pure formatting: truncate, cronToHuman, formatRelativeTime, statusIcon |
| `src/components/` | Ink React components for TUI rendering |
| `src/types.ts` | Job type definition, constants |
| `src/loader.ts` | Reads jobs.json, merges with scanner results |

## Data Format (`jobs.json`)

```json
{
  "id": "hook-<hash>",
  "name": "my-server",
  "description": "pm2 start server.js",
  "agent": "claude-code",
  "schedule": "always-on",
  "status": "active",
  "source": "registered",
  "port": 3000,
  "created_at": "2026-04-11T00:00:00.000Z",
  "last_result": "success"
}
```
