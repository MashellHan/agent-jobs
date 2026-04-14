import { execFile } from "child_process";
import { readFile, readdir } from "fs";
import { createReadStream } from "fs";
import { join } from "path";
import { homedir } from "os";
import { stat } from "fs/promises";
import { createInterface } from "readline";
import type { Job, CronLifecycle } from "./types.js";
import { MAX_DESCRIPTION_LENGTH } from "./types.js";
import { friendlyCronName } from "./utils.js";

/** Parsed plist data relevant to launchd service scanning */
export interface PlistData {
  Label?: string;
  ProgramArguments?: string[];
  Program?: string;
  StartInterval?: number;
  StartCalendarInterval?: Record<string, number> | Array<Record<string, number>>;
  KeepAlive?: boolean | Record<string, unknown>;
  RunAtLoad?: boolean;
  StandardOutPath?: string;
  StandardErrorPath?: string;
  [key: string]: unknown;
}

const RELEVANT_CMDS = new Set([
  "node", "python", "python3", "go", "ruby", "java",
  "deno", "bun", "uvicorn", "gunicorn", "tsx",
]);

export interface LsofEntry {
  pid: number;
  command: string;
  port: number;
  user: string;
}

export function parseLsofOutput(output: string): LsofEntry[] {
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

export function inferAgent(fullCmd: string): string {
  const lower = fullCmd.toLowerCase();
  if (lower.includes("claude")) return "claude-code";
  if (lower.includes("cursor")) return "cursor";
  if (lower.includes("copilot")) return "github-copilot";
  if (lower.includes("openclaw") || lower.includes("claw")) return "openclaw";
  return "manual";
}

/** Generic entry point scripts that should be skipped when agent is detected */
const GENERIC_SCRIPTS = new Set(["entry.js", "index.js", "main.js", "entry.mjs", "index.mjs", "main.mjs"]);

export function friendlyLiveName(command: string, fullCmd: string, port: number, agent?: string): string {
  const parts = fullCmd.trim().split(/\s+/);

  // Try to find a script file argument (e.g. server.js, app.py)
  // Skip generic entry points (entry.js, index.js, main.js) when an agent is detected
  const scriptArg = parts.find((p) =>
    /\.(js|mjs|ts|jsx|tsx|py|rb|go)$/i.test(p) && !p.startsWith("-")
  );

  if (scriptArg) {
    const filename = scriptArg.split("/").pop()!;
    // If agent is detected and the script is generic, skip to agent-aware naming
    if (!(agent && agent !== "manual" && GENERIC_SCRIPTS.has(filename.toLowerCase()))) {
      return port > 0 ? `${filename} :${port}` : filename;
    }
  }

  // For known frameworks, use a friendly label
  const cmdLower = fullCmd.toLowerCase();
  for (const fw of ["next", "nuxt", "vite", "uvicorn", "gunicorn", "flask", "fastapi"]) {
    if (cmdLower.includes(fw)) {
      return port > 0 ? `${fw} :${port}` : fw;
    }
  }

  // Agent-aware fallback: use agent name + subcommand for readable names
  // e.g. openclaw gateway → "openclaw-gateway"
  if (agent && agent !== "manual") {
    const agentLabel = agent === "claude-code" ? "claude" : agent;
    // Look for subcommand after the agent binary/path
    const agentPattern = agent.replace(/-/g, ".");
    const subMatch = cmdLower.match(new RegExp(`${agentPattern}[\\w/.-]*\\s+(\\w+)`));
    const suffix = subMatch?.[1] ?? "";
    const name = suffix ? `${agentLabel}-${suffix}` : agentLabel;
    return port > 0 ? `${name} :${port}` : name;
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
            const agent = inferAgent(fullCmd);
            const name = friendlyLiveName(entry.command, fullCmd, entry.port, agent);

            return {
              id: `live-${entry.pid}`,
              name,
              description: fullCmd.slice(0, MAX_DESCRIPTION_LENGTH),
              agent,
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
          name: friendlyCronName(t.prompt as string ?? ""),
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

// ── Launchd Scanner ──────────────────────────────────────────────

/**
 * Derive a human-friendly schedule string from a parsed plist.
 * Handles StartInterval (seconds), StartCalendarInterval (cron-like),
 * KeepAlive/RunAtLoad (always-on), and on-demand fallback.
 */
export function deriveSchedule(parsed: PlistData): string {
  if (parsed.StartInterval) {
    const seconds = parsed.StartInterval;
    if (seconds < 60) return `every ${seconds}s`;
    if (seconds < 3600) {
      const mins = Math.round(seconds / 60);
      return mins === 1 ? "every min" : `every ${mins} min`;
    }
    if (seconds < 86400) {
      const hours = Math.round(seconds / 3600);
      return hours === 1 ? "hourly" : `every ${hours}h`;
    }
    const days = Math.round(seconds / 86400);
    return days === 1 ? "daily" : `every ${days}d`;
  }

  if (parsed.StartCalendarInterval) {
    const cal = Array.isArray(parsed.StartCalendarInterval)
      ? parsed.StartCalendarInterval[0]
      : parsed.StartCalendarInterval;

    if (cal) {
      const min = cal.Minute ?? 0;
      const hour = cal.Hour;
      const weekday = cal.Weekday;

      // Daily at specific time
      if (hour !== undefined && weekday === undefined) {
        const ampm = hour >= 12 ? "pm" : "am";
        const h12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
        return min === 0 ? `daily ${h12}${ampm}` : `daily ${h12}:${String(min).padStart(2, "0")}${ampm}`;
      }

      // Specific weekday
      if (hour !== undefined && weekday !== undefined) {
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const dayName = days[weekday] ?? `day${weekday}`;
        const ampm = hour >= 12 ? "pm" : "am";
        const h12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
        return `${dayName} ${h12}${ampm}`;
      }
    }
  }

  if (parsed.KeepAlive || (parsed.RunAtLoad && !parsed.StartInterval && !parsed.StartCalendarInterval)) {
    return "always-on";
  }

  return "on-demand";
}

/**
 * Derive a human-friendly service name from a launchd label and ProgramArguments.
 * E.g. "com.pew.sync" + ["/opt/homebrew/bin/pew", "sync"] → "pew sync"
 */
export function deriveFriendlyName(label: string, args: string[]): string {
  // Use the actual command name, not the reverse-DNS label
  if (args.length >= 2) {
    const binary = args[0]!.split("/").pop()!;
    const subcommands = args.slice(1).filter((a) =>
      !a.startsWith("-") &&     // skip flags
      !a.startsWith("/") &&     // skip absolute paths
      !/^\d+$/.test(a) &&       // skip port numbers
      !a.includes("/")          // skip relative paths with slashes
    );
    const subcommand = subcommands.slice(0, 2).join(" ");
    const name = subcommand ? `${binary} ${subcommand}` : binary;
    return name.length > 20 ? name.slice(0, 19) + "…" : name;
  }
  if (args.length === 1) {
    const name = args[0]!.split("/").pop()!;
    return name.length > 20 ? name.slice(0, 19) + "…" : name;
  }
  // Fallback: strip reverse-DNS prefix (com.pew.sync → sync, or pew.sync → sync)
  const parts = label.split(".");
  return parts.length > 2 ? parts.slice(2).join(" ") : parts[parts.length - 1] ?? label;
}

/**
 * Parse a plist file by calling plutil to convert XML/binary plist to JSON.
 * Returns null if parsing fails.
 */
function parsePlist(plistPath: string): Promise<PlistData | null> {
  return new Promise((resolve) => {
    execFile("plutil", ["-convert", "json", "-o", "-", plistPath], { encoding: "utf-8", timeout: 3000 }, (err, stdout) => {
      if (err || !stdout) {
        resolve(null);
        return;
      }
      try {
        resolve(JSON.parse(stdout) as PlistData);
      } catch {
        resolve(null);
      }
    });
  });
}

/**
 * Load all launchctl services once and return a map of label → pid.
 * More efficient than calling `launchctl list <label>` N times.
 */
function loadLaunchctlList(): Promise<Map<string, number | null>> {
  return new Promise((resolve) => {
    execFile("launchctl", ["list"], { encoding: "utf-8", timeout: 3000 }, (err, stdout) => {
      const map = new Map<string, number | null>();
      if (err || !stdout) {
        resolve(map);
        return;
      }
      // Format: PID\tStatus\tLabel  (PID is "-" when not running)
      for (const line of stdout.split("\n").slice(1)) {
        const parts = line.trim().split(/\t/);
        if (parts.length >= 3) {
          const pidStr = parts[0];
          const pid = pidStr && pidStr !== "-" ? parseInt(pidStr, 10) : null;
          map.set(parts[2]!, isNaN(pid as number) ? null : pid);
        }
      }
      resolve(map);
    });
  });
}

/**
 * Get the modification time of a file as ISO string.
 */
function getFileMtime(filePath: string): Promise<string> {
  return stat(filePath)
    .then((s) => s.mtime.toISOString())
    .catch(() => new Date().toISOString());
}

/**
 * Scan ~/Library/LaunchAgents/ for user-installed launchd services.
 * Skips com.apple.* plists. Uses plutil for native plist parsing.
 */
export function scanLaunchdServices(): Promise<Job[]> {
  const agentsDir = join(homedir(), "Library", "LaunchAgents");

  return new Promise((resolve) => {
    readdir(agentsDir, (err, files) => {
      if (err) {
        resolve([]);
        return;
      }

      const plists = files.filter((f) => f.endsWith(".plist") && !f.startsWith("com.apple."));

      if (plists.length === 0) {
        resolve([]);
        return;
      }

      // Load all launchctl services once (batch) instead of per-plist
      loadLaunchctlList().then((launchctlMap) => {
        Promise.all(
          plists.map(async (filename): Promise<Job | null> => {
            const plistPath = join(agentsDir, filename);
            const parsed = await parsePlist(plistPath);
            if (!parsed) return null;

            const label = parsed.Label ?? filename.replace(".plist", "");
            const args: string[] = parsed.ProgramArguments ?? [];
            const command = args.join(" ") || parsed.Program || "";
            const friendlyName = deriveFriendlyName(label, args);
            const schedule = deriveSchedule(parsed);
            const loaded = launchctlMap.has(label);
            const pid = launchctlMap.get(label) ?? null;
            const createdAt = await getFileMtime(plistPath);

            return {
              id: `launchd-${label}`,
              name: friendlyName,
              description: command.slice(0, MAX_DESCRIPTION_LENGTH),
              agent: inferAgent(command),
              schedule,
              status: loaded ? "active" : "stopped",
              source: "launchd",
              project: "",
              pid: pid ?? undefined,
              created_at: createdAt,
              last_run: loaded ? new Date().toISOString() : null,
              next_run: null,
              last_result: loaded ? "success" : "unknown",
              run_count: -1,
            };
          }),
        )
          .then((results) => resolve(results.filter((j): j is Job => j !== null)))
          .catch(() => resolve([]));
      }).catch(() => resolve([]));
    });
  });
}

// ── Session Cron Scanner ────────────────────────────────────────

/** Parsed cron task from a session's JSONL log */
export interface SessionCronTask {
  cronJobId: string;
  cron: string;
  prompt: string;
  recurring: boolean;
  durable: boolean;
  timestamp: string;
  sessionId: string;
  cwd: string;
  projectDir: string;
}

/** Max age for JSONL files to scan (7 days = cron auto-expiry) */
const JSONL_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

/** Session is considered active if JSONL was written within this window */
const SESSION_ACTIVE_WINDOW_MS = 15 * 60 * 1000;

/**
 * Extract a readable project name from the Claude project directory path.
 * E.g. "-Users-mengxionghan--superset-projects-Tmp" → "superset/projects/Tmp"
 */
export function projectNameFromDir(dirName: string): string {
  // Strip the home prefix pattern "-Users-<user>-" or "-Users-<user>--"
  const stripped = dirName.replace(/^-Users-[^-]+-+/, "");
  // Convert remaining dashes to slashes, collapse doubles
  return stripped.replace(/-/g, "/").replace(/\/\//g, "/");
}

/**
 * Parse a single JSONL file for CronCreate/CronDelete entries.
 * Uses readline for streaming (files can be 10-30MB).
 * Returns { creates, deletes } maps.
 */
export function parseSessionJsonl(filePath: string): Promise<{
  creates: Map<string, SessionCronTask>;
  deletes: Set<string>;
}> {
  return new Promise((resolve) => {
    const creates = new Map<string, SessionCronTask>();
    const deletes = new Set<string>();

    // Pending CronCreate tool_uses waiting for their tool_result
    const pendingToolUses = new Map<string, { cron: string; prompt: string; recurring: boolean; durable: boolean }>();

    const stream = createReadStream(filePath, { encoding: "utf-8" });
    const rl = createInterface({ input: stream, crlfDelay: Infinity });

    rl.on("line", (line) => {
      // Fast pre-filter: skip lines that can't contain cron operations
      const hasCronOp = line.includes("CronCreate") || line.includes("CronDelete");
      const hasPending = pendingToolUses.size > 0 && line.includes("tool_result");
      if (!hasCronOp && !hasPending) return;

      try {
        const obj = JSON.parse(line) as Record<string, unknown>;
        const msg = obj.message as Record<string, unknown> | undefined;
        if (!msg) return;

        const content = msg.content as Array<Record<string, unknown>> | undefined;
        if (!Array.isArray(content)) return;

        for (const block of content) {
          // CronCreate tool_use — store pending
          if (block.name === "CronCreate" && block.type === "tool_use") {
            const inp = (block.input ?? {}) as Record<string, unknown>;
            pendingToolUses.set(block.id as string, {
              cron: (inp.cron as string) ?? "",
              prompt: (inp.prompt as string) ?? "",
              recurring: (inp.recurring as boolean) ?? true,
              durable: (inp.durable as boolean) ?? false,
            });
          }

          // CronCreate tool_result — match with pending, extract cronJobId
          if (block.type === "tool_result") {
            const toolUseResult = obj.toolUseResult as Record<string, unknown> | undefined;
            if (!toolUseResult || !toolUseResult.id) continue;

            const toolUseId = block.tool_use_id as string;
            const pending = pendingToolUses.get(toolUseId);
            if (!pending) continue;

            pendingToolUses.delete(toolUseId);

            const cronJobId = toolUseResult.id as string;
            creates.set(cronJobId, {
              cronJobId,
              cron: pending.cron,
              prompt: pending.prompt,
              recurring: pending.recurring,
              durable: (toolUseResult.durable as boolean) ?? pending.durable,
              timestamp: (obj.timestamp as string) ?? new Date().toISOString(),
              sessionId: (obj.sessionId as string) ?? "",
              cwd: (obj.cwd as string) ?? "",
              projectDir: "",
            });
          }

          // CronDelete tool_use
          if (block.name === "CronDelete" && block.type === "tool_use") {
            const inp = (block.input ?? {}) as Record<string, unknown>;
            const deleteId = inp.id as string;
            if (deleteId) deletes.add(deleteId);
          }
        }
      } catch {
        // Skip malformed lines
      }
    });

    rl.on("close", () => resolve({ creates, deletes }));
    rl.on("error", () => resolve({ creates, deletes }));
    stream.on("error", () => resolve({ creates, deletes }));
  });
}

/**
 * Scan all Claude Code session JSONL files for cron tasks.
 * Discovers both session-only and durable cron tasks across all sessions.
 * Also reads ~/.claude/scheduled_tasks.json for durable tasks as fallback.
 */
export async function scanSessionCronTasks(): Promise<Job[]> {
  const projectsDir = join(homedir(), ".claude", "projects");
  const now = Date.now();
  const jobs: Job[] = [];

  // Phase 1: Scan session JSONL files
  try {
    const projectDirs = await listDir(projectsDir);

    for (const projDir of projectDirs) {
      const projPath = join(projectsDir, projDir);
      const projStat = await safeStat(projPath);
      if (!projStat || !projStat.isDirectory()) continue;

      const files = await listDir(projPath);
      const jsonlFiles = files.filter((f) => f.endsWith(".jsonl"));

      for (const jsonlFile of jsonlFiles) {
        const filePath = join(projPath, jsonlFile);
        const fileStat = await safeStat(filePath);
        if (!fileStat) continue;

        // Skip files older than 7 days (cron auto-expiry)
        const age = now - fileStat.mtimeMs;
        if (age > JSONL_MAX_AGE_MS) continue;

        const sessionActive = age < SESSION_ACTIVE_WINDOW_MS;
        const sessionId = jsonlFile.replace(".jsonl", "");

        const { creates, deletes } = await parseSessionJsonl(filePath);

        // Net active = creates - deletes
        for (const [cronId, task] of creates) {
          if (deletes.has(cronId)) continue;

          task.projectDir = projDir;
          const lifecycle: CronLifecycle = task.durable ? "durable" : "session-only";
          const projectName = task.cwd
            ? task.cwd.split("/").slice(-2).join("/")
            : projectNameFromDir(projDir);

          jobs.push({
            id: `cron-${sessionId.slice(0, 8)}-${cronId}`,
            name: friendlyCronName(task.prompt),
            description: task.prompt.slice(0, MAX_DESCRIPTION_LENGTH),
            agent: "claude-code",
            schedule: task.cron,
            status: sessionActive ? "active" : "stopped",
            source: "cron",
            project: projectName,
            created_at: task.timestamp,
            last_run: sessionActive ? new Date().toISOString() : null,
            next_run: null,
            last_result: sessionActive ? "success" : "unknown",
            run_count: -1,
            sessionId: sessionId.slice(0, 8),
            lifecycle,
          });
        }
      }
    }
  } catch {
    // If scanning fails, continue with durable tasks fallback
  }

  // Phase 2: Also read durable tasks from scheduled_tasks.json (fallback)
  const durableTasks = await scanDurableScheduledTasks();
  // Deduplicate: durable tasks from JSONL already have durable=true
  const existingIds = new Set(jobs.map((j) => j.schedule + j.description.slice(0, 50)));
  for (const dt of durableTasks) {
    const key = dt.schedule + dt.description.slice(0, 50);
    if (!existingIds.has(key)) {
      jobs.push(dt);
    }
  }

  return jobs;
}

/** Read durable tasks from ~/.claude/scheduled_tasks.json */
function scanDurableScheduledTasks(): Promise<Job[]> {
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
          id: `cron-durable-${i}`,
          name: friendlyCronName(t.prompt as string ?? ""),
          description: (t.prompt as string ?? "").slice(0, MAX_DESCRIPTION_LENGTH),
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
          lifecycle: "durable",
        }));
        resolve(jobs);
      } catch {
        resolve([]);
      }
    });
  });
}

/** List directory entries, returning [] on error */
function listDir(dirPath: string): Promise<string[]> {
  return new Promise((resolve) => {
    readdir(dirPath, (err, files) => resolve(err ? [] : files));
  });
}

/** Stat a file, returning null on error */
function safeStat(filePath: string): Promise<import("fs").Stats | null> {
  return stat(filePath).catch(() => null);
}
