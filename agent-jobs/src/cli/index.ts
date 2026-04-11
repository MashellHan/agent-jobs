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

  case "detect": {
    const { main } = await import("./detect.js");
    main();
    break;
  }

  case "dashboard":
  case undefined:
    // Launch TUI
    import("../index.js");
    break;

  case "list": {
    const { loadAllJobs } = await import("../loader.js");
    const jobs = await loadAllJobs();
    if (jobs.length === 0) {
      process.stdout.write("No jobs found.\n");
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
  case "version": {
    const { createRequire } = await import("module");
    const require = createRequire(import.meta.url);
    const { version } = require("../../package.json");
    process.stdout.write(`agent-jobs v${version}\n`);
    break;
  }

  default:
    process.stderr.write(`Unknown command: ${cmd}\nRun 'agent-jobs help' for usage.\n`);
    process.exit(1);
}
