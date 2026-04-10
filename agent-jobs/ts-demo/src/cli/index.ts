#!/usr/bin/env node
/**
 * agent-jobs CLI
 *
 * Usage:
 *   agent-jobs setup       — Install PostToolUse hook into Claude Code
 *   agent-jobs teardown    — Remove the hook
 *   agent-jobs detect      — (internal) Run detection from hook stdin
 *   agent-jobs dashboard   — Launch TUI dashboard
 *   agent-jobs list        — List registered jobs (plain text)
 */

import { setup, teardown } from "./setup.js";

const cmd = process.argv[2];

switch (cmd) {
  case "setup":
    setup();
    break;

  case "teardown":
    teardown();
    break;

  case "detect":
    // detect.ts reads stdin and self-executes
    import("./detect.js");
    break;

  case "dashboard":
  case undefined:
    // Launch TUI
    import("../index.js");
    break;

  case "list": {
    const { readFileSync, existsSync } = await import("fs");
    const { join } = await import("path");
    const { homedir } = await import("os");
    const jobsPath = join(homedir(), ".agent-jobs", "jobs.json");
    if (!existsSync(jobsPath)) {
      process.stdout.write("No jobs registered.\n");
      break;
    }
    const data = JSON.parse(readFileSync(jobsPath, "utf-8"));
    const jobs = data.jobs ?? [];
    if (jobs.length === 0) {
      process.stdout.write("No jobs registered.\n");
      break;
    }
    for (const j of jobs) {
      process.stdout.write(`  ${j.status === "active" ? "●" : "○"} ${j.name} (${j.agent}) — ${j.schedule}\n`);
    }
    break;
  }

  case "help":
  case "--help":
  case "-h":
    process.stdout.write(`agent-jobs — AI Agent Job Dashboard

Commands:
  setup       Install PostToolUse hook into Claude Code settings
  teardown    Remove the hook from Claude Code settings
  detect      (internal) Detect services from hook stdin
  dashboard   Launch TUI dashboard (default)
  list        List registered jobs (plain text)
  help        Show this help message
  --version   Show version
`);
    break;

  case "--version":
  case "-v":
  case "version":
    process.stdout.write("agent-jobs v1.0.0\n");
    break;

  default:
    process.stderr.write(`Unknown command: ${cmd}\nRun 'agent-jobs help' for usage.\n`);
    process.exit(1);
}
