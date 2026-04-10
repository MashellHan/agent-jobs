/**
 * PostToolUse hook detector.
 * Reads CC hook JSON from stdin, checks if the tool call created a background service,
 * and registers it to ~/.agent-jobs/jobs.json if detected.
 *
 * Supported patterns:
 * - Bash: launchctl load/bootstrap, pm2 start, systemctl enable/start,
 *         docker run -d, node/python/deno/bun server scripts,
 *         nohup ... &, http-server, uvicorn, gunicorn, flask run, next dev/start
 * - Write/Edit: .plist files, docker-compose.yml, systemd .service files
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, renameSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";
import type { JobsFile } from "../types.js";

const JOBS_DIR = join(homedir(), ".agent-jobs");
const JOBS_PATH = join(JOBS_DIR, "jobs.json");

// ── Pattern matchers ─────────────────────────────────────────────────

const BASH_PATTERNS: Array<{ re: RegExp; label: (m: RegExpMatchArray, cmd: string) => string }> = [
  {
    re: /launchctl\s+(load|bootstrap)\s+(.+)/i,
    label: (_m, cmd) => {
      const plist = cmd.match(/(\S+\.plist)/)?.[1] ?? "launchd-service";
      return plist.split("/").pop()!.replace(".plist", "");
    },
  },
  {
    re: /pm2\s+start\s+(\S+)/i,
    label: (m) => {
      const script = m[1]!.split("/").pop()!;
      return `pm2 ${script}`;
    },
  },
  {
    re: /systemctl\s+(enable|start)\s+(\S+)/i,
    label: (m) => m[2]!,
  },
  {
    re: /docker\s+run\s+(?:.*\s)?-d\s/i,
    label: (_m, cmd) => {
      // Prefer --name flag for human-readable container name
      const nameFlag = cmd.match(/--name\s+(\S+)/);
      if (nameFlag) return nameFlag[1]!;
      // Fallback to image name (last non-flag arg)
      const img = cmd.match(/docker\s+run\s+(?:.*\s)(\S+)\s*$/)?.[1] ?? "container";
      // Strip tag suffix for readability (e.g. nginx:latest → nginx)
      const friendlyImg = img.includes("/") ? img.split("/").pop()! : img;
      return friendlyImg.split(":")[0]!;
    },
  },
  {
    re: /docker[\s-]compose\s+up\s+-d/i,
    label: () => "docker-compose",
  },
  {
    re: /\b(uvicorn|gunicorn)\s+(\S+)/i,
    label: (m) => `${m[1]} ${m[2]}`,
  },
  {
    re: /flask\s+run/i,
    label: () => "flask-server",
  },
  {
    re: /\bnpx\s+(serve|http-server|live-server|next)\b/i,
    label: (m) => m[1]!,
  },
  {
    re: /\b(next|nuxt|vite)\s+(dev|start)\b/i,
    label: (m) => `${m[1]}-${m[2]}`,
  },
  {
    re: /\bnohup\s+(.+?)\s*&/i,
    label: (m) => {
      const inner = m[1]!.trim().split(/\s+/);
      const runtime = inner[0]!.split("/").pop()!;
      // Try to find a script file in args for a readable name
      const scriptArg = inner.find((p) =>
        /\.(js|mjs|ts|py|rb|go)$/i.test(p) && !p.startsWith("-")
      );
      if (scriptArg) {
        const filename = scriptArg.split("/").pop()!;
        return `${runtime} ${filename}`;
      }
      return runtime;
    },
  },
  {
    re: /\bnode\s+(\S+\.(?:js|mjs|ts))\b/i,
    label: (m) => `node ${m[1]!.split("/").pop()!}`,
  },
  {
    re: /\b(python3?)\s+(\S+\.py)\b/i,
    label: (m) => `python ${m[2]!.split("/").pop()!}`,
  },
  {
    re: /\b(deno)\s+run\s+(\S+)/i,
    label: (m) => `deno ${m[2]!.split("/").pop()!}`,
  },
  {
    re: /\b(bun)\s+run\s+(\S+)/i,
    label: (m) => `bun ${m[2]!.split("/").pop()!}`,
  },
];

// Bash output patterns that confirm a server is actually listening
const OUTPUT_PORT_RE = /(?:listening|started|running|serving)\s+(?:on|at)\s+(?:https?:\/\/)?(?:localhost|0\.0\.0\.0|127\.0\.0\.1|\[::\])[:\s]+(\d+)/i;
const BACKGROUND_RE = /&\s*$/;

const FILE_PATTERNS: Array<{ re: RegExp; label: (path: string) => string }> = [
  {
    re: /\.plist$/i,
    label: (p) => p.split("/").pop()!.replace(".plist", ""),
  },
  {
    re: /docker-compose\.ya?ml$/i,
    label: () => "docker-compose",
  },
  {
    re: /\.service$/i,
    label: (p) => p.split("/").pop()!.replace(".service", ""),
  },
];

// ── Helpers ──────────────────────────────────────────────────────────

function loadJobs(): JobsFile {
  if (!existsSync(JOBS_PATH)) {
    return { version: "1.0", jobs: [] };
  }
  try {
    return JSON.parse(readFileSync(JOBS_PATH, "utf-8")) as JobsFile;
  } catch {
    return { version: "1.0", jobs: [] };
  }
}

function saveJobs(file: JobsFile): void {
  if (!existsSync(JOBS_DIR)) {
    mkdirSync(JOBS_DIR, { recursive: true });
  }
  // Atomic write: write to temp file, then rename
  const tmpPath = join(JOBS_DIR, `.jobs.${process.pid}.tmp`);
  writeFileSync(tmpPath, JSON.stringify(file, null, 2) + "\n");
  renameSync(tmpPath, JOBS_PATH);
}

function extractPort(cmd: string, output: string): number | undefined {
  // Check --port or -p flags in command
  const portFlag = cmd.match(/(?:--port|-p)\s+(\d+)/);
  if (portFlag) return parseInt(portFlag[1]!, 10);

  // Check PORT= env in command
  const portEnv = cmd.match(/\bPORT=(\d+)/);
  if (portEnv) return parseInt(portEnv[1]!, 10);

  // Check output for listening port
  const outputMatch = output.match(OUTPUT_PORT_RE);
  if (outputMatch) return parseInt(outputMatch[1]!, 10);

  return undefined;
}

function registerJob(label: string, opts: {
  description: string;
  port?: number;
  source: string;
}): boolean {
  const file = loadJobs();

  // Deduplicate by name
  if (file.jobs.some((j) => j.name === label)) {
    return false;
  }

  const now = new Date().toISOString();
  file.jobs.push({
    id: `hook-${Date.now()}`,
    name: label,
    description: opts.description.slice(0, 200),
    agent: "claude-code",
    schedule: "always-on",
    status: "active",
    project: process.cwd(),
    port: opts.port,
    created_at: now,
    last_run: now,
    next_run: null,
    last_result: "success",
    run_count: 0,
  });

  saveJobs(file);
  return true;
}

// ── Main detection logic ─────────────────────────────────────────────

interface HookInput {
  tool_name?: string;
  tool_input?: {
    command?: string;
    file_path?: string;
    content?: string;
    old_string?: string;
    new_string?: string;
  };
  tool_result?: string;
}

function detectBash(input: HookInput): boolean {
  const cmd = input.tool_input?.command ?? "";
  const output = input.tool_result ?? "";

  // Only match if the command runs in background or output suggests a server started
  const isBackground = BACKGROUND_RE.test(cmd) || /run_in_background/.test(JSON.stringify(input));
  const hasServerOutput = OUTPUT_PORT_RE.test(output);

  for (const { re, label } of BASH_PATTERNS) {
    const m = cmd.match(re);
    if (!m) continue;

    // For simple node/python script runs, only register if backgrounded or server output detected
    if (/^(node|python|deno|bun)\s/.test(label(m, cmd)) && !isBackground && !hasServerOutput) {
      continue;
    }

    const name = label(m, cmd);
    const port = extractPort(cmd, output);
    return registerJob(name, {
      description: cmd.slice(0, 200),
      port,
      source: "hook-bash",
    });
  }

  return false;
}

function detectFile(input: HookInput): boolean {
  const filePath = input.tool_input?.file_path ?? "";

  for (const { re, label } of FILE_PATTERNS) {
    if (re.test(filePath)) {
      return registerJob(label(filePath), {
        description: `Created ${filePath}`,
        source: "hook-file",
      });
    }
  }

  return false;
}

export function detect(input: HookInput): boolean {
  const tool = input.tool_name ?? "";

  if (tool === "Bash") {
    return detectBash(input);
  }

  if (tool === "Write" || tool === "Edit" || tool === "MultiEdit") {
    return detectFile(input);
  }

  return false;
}

// ── CLI entry ────────────────────────────────────────────────────────

function main(): void {
  let raw = "";
  try {
    raw = readFileSync(0, "utf-8");
  } catch {
    process.exit(0);
  }

  if (!raw.trim()) {
    process.exit(0);
  }

  // PostToolUse hooks MUST echo stdin to stdout
  process.stdout.write(raw);

  let input: HookInput;
  try {
    input = JSON.parse(raw) as HookInput;
  } catch {
    process.exit(0);
  }

  const detected = detect(input);
  if (detected) {
    process.stderr.write(`[agent-jobs] Service detected and registered\n`);
  }
}

// Only run main() when executed directly (not when imported as a module)
const isDirectRun =
  import.meta.url === `file://${process.argv[1]}` ||
  process.argv[1]?.endsWith("detect.js");

if (isDirectRun) {
  main();
}
