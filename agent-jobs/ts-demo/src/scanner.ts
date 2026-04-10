import { execFileSync, execSync } from "child_process";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { Job } from "./types.js";

const RELEVANT_CMDS = new Set([
  "node", "python", "python3", "go", "ruby", "java",
  "deno", "bun", "uvicorn", "gunicorn", "tsx",
]);

interface LsofEntry {
  pid: number;
  command: string;
  port: number;
  user: string;
}

function parseLsofOutput(output: string): LsofEntry[] {
  const seen = new Set<number>();
  const entries: LsofEntry[] = [];

  for (const line of output.split("\n").slice(1)) {
    const fields = line.trim().split(/\s+/);
    if (fields.length < 9) continue;

    const cmd = fields[0]!.toLowerCase();
    if (!RELEVANT_CMDS.has(cmd)) continue;

    const pid = parseInt(fields[1]!, 10);
    if (isNaN(pid) || seen.has(pid)) continue;
    seen.add(pid);

    const nameField = fields[8] ?? "";
    const lastColon = nameField.lastIndexOf(":");
    const port = lastColon >= 0 ? parseInt(nameField.slice(lastColon + 1), 10) : 0;

    entries.push({
      pid,
      command: fields[0]!,
      port: isNaN(port) ? 0 : port,
      user: fields[2] ?? "",
    });
  }

  return entries;
}

function getFullCommand(pid: number): string {
  try {
    return execSync(`ps -p ${pid} -o args=`, { encoding: "utf-8" }).trim();
  } catch {
    return "";
  }
}

function inferAgent(fullCmd: string): string {
  const lower = fullCmd.toLowerCase();
  if (lower.includes("claude")) return "claude-code";
  if (lower.includes("cursor")) return "cursor";
  if (lower.includes("copilot")) return "github-copilot";
  return "manual";
}

export function scanLiveProcesses(): Job[] {
  let output: string;
  try {
    output = execFileSync("lsof", ["-i", "-P", "-n", "-sTCP:LISTEN"], {
      encoding: "utf-8",
      timeout: 5000,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch (err: unknown) {
    // lsof returns exit code 1 when it finds results but also writes to stderr,
    // or when there are no matches. Check if stdout has content.
    const e = err as { stdout?: string };
    if (e.stdout && e.stdout.includes("COMMAND")) {
      output = e.stdout;
    } else {
      return [];
    }
  }

  try {
    const entries = parseLsofOutput(output);
    const now = new Date().toISOString();

    return entries.map((entry): Job => {
      const fullCmd = getFullCommand(entry.pid);
      const name = entry.port > 0
        ? `${entry.command} (:${entry.port})`
        : entry.command;

      return {
        id: `live-${entry.pid}`,
        name,
        description: fullCmd.slice(0, 120),
        agent: inferAgent(fullCmd),
        schedule: "always-on",
        status: "active",
        source: "live",
        project: "",
        port: entry.port > 0 ? entry.port : undefined,
        pid: entry.pid,
        created_at: now,
        last_run: now,
        next_run: null,
        last_result: "success",
        run_count: -1,
      };
    });
  } catch {
    return [];
  }
}

export function scanClaudeScheduledTasks(): Job[] {
  const tasksPath = join(homedir(), ".claude", "scheduled_tasks.json");
  if (!existsSync(tasksPath)) return [];

  try {
    const raw = JSON.parse(readFileSync(tasksPath, "utf-8"));
    if (!Array.isArray(raw)) return [];

    return raw.map((t: Record<string, unknown>, i: number): Job => ({
      id: `cron-${i}`,
      name: (t.prompt as string ?? "").slice(0, 50) || `Cron task #${i}`,
      description: t.prompt as string ?? "",
      agent: "claude-code",
      schedule: t.cron as string ?? "?",
      status: "active",
      source: "cron",
      project: "",
      created_at: new Date().toISOString(),
      last_run: null,
      next_run: null,
      last_result: "unknown",
      run_count: -1,
    }));
  } catch {
    return [];
  }
}
