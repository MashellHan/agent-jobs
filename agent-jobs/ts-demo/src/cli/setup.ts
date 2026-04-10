/**
 * `agent-jobs setup` — inject PostToolUse hook into ~/.claude/settings.json
 * `agent-jobs teardown` — remove it cleanly
 */

import { readFileSync, writeFileSync, existsSync, renameSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SETTINGS_PATH = join(homedir(), ".claude", "settings.json");
const HOOK_TAG = "agent-jobs-detect";

function getDetectScript(): string {
  // After build, detect.js sits next to this file
  return join(__dirname, "detect.js");
}

function getDetectCommand(): string {
  return `node "${getDetectScript()}"`;
}

interface HookEntry {
  matcher?: string;
  hooks: Array<{
    type: string;
    command: string;
    timeout?: number;
    async?: boolean;
  }>;
}

interface Settings {
  hooks?: {
    PostToolUse?: HookEntry[];
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

function loadSettings(): Settings {
  if (!existsSync(SETTINGS_PATH)) {
    return {};
  }
  return JSON.parse(readFileSync(SETTINGS_PATH, "utf-8")) as Settings;
}

function saveSettings(settings: Settings): void {
  const tmpPath = `${SETTINGS_PATH}.${process.pid}.tmp`;
  writeFileSync(tmpPath, JSON.stringify(settings, null, 2) + "\n");
  renameSync(tmpPath, SETTINGS_PATH);
}

function isAgentJobsHook(inner: { command: string }): boolean {
  return inner.command.includes(HOOK_TAG) ||
    inner.command.includes("agent-jobs") && inner.command.includes("detect");
}

function hasHook(settings: Settings): boolean {
  const hooks = settings.hooks?.PostToolUse ?? [];
  return hooks.some((h) => h.hooks.some(isAgentJobsHook));
}

export function setup(): void {
  const settings = loadSettings();

  if (hasHook(settings)) {
    process.stdout.write("[agent-jobs] Hook already installed, skipping.\n");
    return;
  }

  if (!settings.hooks) {
    settings.hooks = {};
  }
  if (!settings.hooks.PostToolUse) {
    settings.hooks.PostToolUse = [];
  }

  const hookEntry: HookEntry = {
    matcher: "Bash|Write|Edit|MultiEdit",
    hooks: [
      {
        type: "command",
        command: getDetectCommand(),
        timeout: 5,
        async: true,
      },
    ],
  };

  settings.hooks.PostToolUse.push(hookEntry);
  saveSettings(settings);

  process.stdout.write("[agent-jobs] PostToolUse hook installed successfully.\n");
  process.stdout.write(`[agent-jobs] Hook script: ${getDetectCommand()}\n`);
}

export function teardown(): void {
  const settings = loadSettings();

  if (!settings.hooks?.PostToolUse) {
    process.stdout.write("[agent-jobs] No hooks found, nothing to remove.\n");
    return;
  }

  const before = settings.hooks.PostToolUse.length;
  settings.hooks.PostToolUse = settings.hooks.PostToolUse.filter(
    (h) => !h.hooks.some(isAgentJobsHook)
  );
  const after = settings.hooks.PostToolUse.length;

  if (before === after) {
    process.stdout.write("[agent-jobs] No agent-jobs hook found to remove.\n");
    return;
  }

  saveSettings(settings);
  process.stdout.write("[agent-jobs] Hook removed successfully.\n");
}
