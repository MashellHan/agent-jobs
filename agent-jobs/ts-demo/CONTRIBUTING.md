# Contributing to agent-jobs

## Development Setup

```bash
git clone https://github.com/MashellHan/agent-jobs.git
cd agent-jobs
npm install
npm run dev
```

## Project Structure

```
src/
  cli/
    index.ts      — CLI entry (setup/teardown/detect/dashboard/list)
    detect.ts     — PostToolUse hook detector
    setup.ts      — Hook injection/removal
  components/
    header.tsx    — Dashboard header
    tab-bar.tsx   — Tab filter bar
    job-table.tsx — Table rows
    job-detail.tsx — Inline detail view
    footer.tsx    — Key hints
  app.tsx         — Main App component
  index.tsx       — Ink render entry
  loader.ts       — Job loading + file watching
  scanner.ts      — Live process + Claude task scanning
  types.ts        — TypeScript types
  utils.ts        — Formatting helpers
```

## Pull Requests

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run `npm run build` to verify
5. Submit a PR

## Reporting Issues

Use [GitHub Issues](https://github.com/MashellHan/agent-jobs/issues).
