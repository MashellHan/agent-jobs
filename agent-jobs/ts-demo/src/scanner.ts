import { execFile } from "child_process";
import { readFile } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { Job } from "./types.js";
import { MAX_DESCRIPTION_LENGTH } from "./types.js";

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

function getFullCommand(pid: number): Promise<string> {
  return new Promise((resolve) => {
    execFile("ps", ["-p", String(pid), "-o", "args="], { encoding: "utf-8", timeout: 3000 }, (err, stdout) => {
      resolve(err ? "" : stdout.trim());
    });
  });
}

function inferAgent(fullCmd: string): string {
  const lower = fullCmd.toLowerCase();
  if (lower.includes("claude")) return "claude-code";
  if (lower.includes("cursor")) return "cursor";
  if (lower.includes("copilot")) return "github-copilot";
  return "manual";
}

function friendlyLiveName(command: string, fullCmd: string, port: number): string {
  const parts = fullCmd.trim().split(/\s+/);

  // Try to find a script file argument (e.g. server.js, app.py)
  const scriptArg = parts.find((p) =>
    /\.(js|mjs|ts|jsx|tsx|py|rb|go)$/i.test(p) && !p.startsWith("-")
  );

  if (scriptArg) {
    const filename = scriptArg.split("/").pop()!;
    return port > 0 ? `${filename} :${port}` : filename;
  }

  // For known frameworks, use a friendly label
  const cmdLower = fullCmd.toLowerCase();
  for (const fw of ["next", "nuxt", "vite", "uvicorn", "gunicorn", "flask", "fastapi"]) {
    if (cmdLower.includes(fw)) {
      return port > 0 ? `${fw} :${port}` : fw;
    }
  }

  // Fallback: command + port
  return port > 0 ? `${command} :${port}` : command;
}

export function scanLiveProcesses(): Promise<Job[]> {
  return new Promise((resolve) => {
    execFile("lsof", ["-i", "-P", "-n", "-sTCP:LISTEN"], { encoding: "utf-8", timeout: 5000 }, async (err, stdout) => {
      const output = stdout || (err as { stdout?: string } | null)?.stdout || "";
      if (!output.includes("COMMAND")) {
        resolve([]);
        return;
      }

      try {
        const entries = parseLsofOutput(output);
        const now = new Date().toISOString();

        const jobs = await Promise.all(
          entries.map(async (entry): Promise<Job> => {
            const fullCmd = await getFullCommand(entry.pid);
            const name = friendlyLiveName(entry.command, fullCmd, entry.port);

            return {
              id: `live-${entry.pid}`,
              name,
              description: fullCmd.slice(0, MAX_DESCRIPTION_LENGTH),
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
          }),
        );
        resolve(jobs);
      } catch {
        resolve([]);
      }
    });
  });
}

export function scanClaudeScheduledTasks(): Promise<Job[]> {
  const tasksPath = join(homedir(), ".claude", "scheduled_tasks.json");

  return new Promise((resolve) => {
    readFile(tasksPath, "utf-8", (err, data) => {
      if (err) {
        resolve([]);
        return;
      }
      try {
        const raw = JSON.parse(data);
        if (!Array.isArray(raw)) {
          resolve([]);
          return;
        }

        const jobs = raw.map((t: Record<string, unknown>, i: number): Job => ({
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
        resolve(jobs);
      } catch {
        resolve([]);
      }
    });
  });
}
