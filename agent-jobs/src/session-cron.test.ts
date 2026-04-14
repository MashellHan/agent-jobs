import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { writeFileSync, mkdirSync, rmSync, existsSync } from "fs";
import { join } from "path";
import { projectNameFromDir, parseSessionJsonl, scanSessionCronTasks } from "./scanner.js";

// Compute testHome before mocking os
const testHome = join("/tmp", "agent-jobs-home-" + process.pid);

// Mock os.homedir to use temp directory for scanSessionCronTasks tests
vi.mock("os", () => ({
  homedir: vi.fn(() => testHome),
}));

// ── projectNameFromDir (pure function) ──────────────────────────

describe("projectNameFromDir", () => {
  it("extracts project path from standard Claude dir format", () => {
    expect(projectNameFromDir("-Users-mengxionghan--superset-projects-Tmp")).toBe(
      "superset/projects/Tmp",
    );
  });

  it("handles single-dash after username", () => {
    expect(projectNameFromDir("-Users-john-my-project")).toBe("my/project");
  });

  it("handles double-dash after username", () => {
    expect(projectNameFromDir("-Users-alice--workspace-repo")).toBe("workspace/repo");
  });

  it("handles deeply nested project paths", () => {
    expect(projectNameFromDir("-Users-dev--home-src-github-my-app")).toBe(
      "home/src/github/my/app",
    );
  });

  it("handles simple project name", () => {
    expect(projectNameFromDir("-Users-user--project")).toBe("project");
  });

  it("handles empty string after stripping prefix", () => {
    expect(projectNameFromDir("-Users-user-")).toBe("");
  });
});

// ── parseSessionJsonl (uses temp files) ──────────────────────────

describe("parseSessionJsonl", () => {
  const testDir = join(testHome, "parseSessionJsonl-test");

  beforeEach(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  function writeJsonl(filename: string, lines: unknown[]): string {
    const filePath = join(testDir, filename);
    writeFileSync(filePath, lines.map((l) => JSON.stringify(l)).join("\n") + "\n");
    return filePath;
  }

  it("returns empty creates/deletes for file with no cron operations", async () => {
    const filePath = writeJsonl("no-cron.jsonl", [
      { message: { content: [{ type: "text", text: "Hello" }] } },
      { message: { content: [{ type: "tool_use", name: "Bash", input: { command: "ls" } }] } },
    ]);

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(0);
    expect(deletes.size).toBe(0);
  });

  it("parses CronCreate tool_use + tool_result pair", async () => {
    const toolUseId = "tu-001";
    const cronJobId = "cj-abc123";

    const filePath = writeJsonl("cron-create.jsonl", [
      // CronCreate tool_use
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: toolUseId,
              name: "CronCreate",
              input: {
                cron: "*/5 * * * *",
                prompt: "Check health endpoint",
                recurring: true,
                durable: false,
              },
            },
          ],
        },
      },
      // CronCreate tool_result
      {
        message: {
          content: [
            {
              type: "tool_result",
              tool_use_id: toolUseId,
            },
          ],
        },
        toolUseResult: { id: cronJobId, durable: false },
        timestamp: "2026-04-14T10:00:00Z",
        sessionId: "sess-001",
        cwd: "/Users/dev/project",
      },
    ]);

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(1);
    expect(deletes.size).toBe(0);

    const task = creates.get(cronJobId);
    expect(task).toBeDefined();
    expect(task!.cron).toBe("*/5 * * * *");
    expect(task!.prompt).toBe("Check health endpoint");
    expect(task!.recurring).toBe(true);
    expect(task!.durable).toBe(false);
    expect(task!.timestamp).toBe("2026-04-14T10:00:00Z");
    expect(task!.sessionId).toBe("sess-001");
    expect(task!.cwd).toBe("/Users/dev/project");
  });

  it("handles CronDelete removing a previously created cron", async () => {
    const toolUseId = "tu-002";
    const cronJobId = "cj-delete-me";

    const filePath = writeJsonl("cron-delete.jsonl", [
      // CronCreate
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: toolUseId,
              name: "CronCreate",
              input: { cron: "0 * * * *", prompt: "Hourly task", recurring: true },
            },
          ],
        },
      },
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: toolUseId }],
        },
        toolUseResult: { id: cronJobId },
        timestamp: "2026-04-14T10:00:00Z",
      },
      // CronDelete
      {
        message: {
          content: [
            {
              type: "tool_use",
              name: "CronDelete",
              input: { id: cronJobId },
            },
          ],
        },
      },
    ]);

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(1);
    expect(deletes.has(cronJobId)).toBe(true);
  });

  it("handles multiple cron creates in one session", async () => {
    const filePath = writeJsonl("multi-cron.jsonl", [
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: "tu-a",
              name: "CronCreate",
              input: { cron: "*/5 * * * *", prompt: "Task A" },
            },
          ],
        },
      },
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: "tu-a" }],
        },
        toolUseResult: { id: "cj-a" },
        timestamp: "2026-04-14T10:00:00Z",
      },
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: "tu-b",
              name: "CronCreate",
              input: { cron: "0 9 * * *", prompt: "Task B", durable: true },
            },
          ],
        },
      },
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: "tu-b" }],
        },
        toolUseResult: { id: "cj-b", durable: true },
        timestamp: "2026-04-14T10:05:00Z",
      },
    ]);

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(2);
    expect(creates.get("cj-a")!.prompt).toBe("Task A");
    expect(creates.get("cj-a")!.durable).toBe(false);
    expect(creates.get("cj-b")!.prompt).toBe("Task B");
    expect(creates.get("cj-b")!.durable).toBe(true);
    expect(deletes.size).toBe(0);
  });

  it("skips malformed JSON lines gracefully", async () => {
    const filePath = join(testDir, "malformed.jsonl");
    const content = [
      '{"message":{"content":[{"type":"tool_use","id":"tu-1","name":"CronCreate","input":{"cron":"* * * * *","prompt":"Test"}}]}}',
      "this is not valid JSON at all {{{",
      '{"message":{"content":[{"type":"tool_result","tool_use_id":"tu-1"}]},"toolUseResult":{"id":"cj-1"},"timestamp":"2026-04-14T10:00:00Z"}',
    ].join("\n");
    writeFileSync(filePath, content + "\n");

    const { creates } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(1);
    expect(creates.get("cj-1")!.prompt).toBe("Test");
  });

  it("ignores tool_result without matching pending tool_use", async () => {
    const filePath = writeJsonl("orphan-result.jsonl", [
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: "non-existent" }],
        },
        toolUseResult: { id: "cj-orphan" },
      },
    ]);

    const { creates } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(0);
  });

  it("skips lines without message field", async () => {
    const filePath = writeJsonl("no-message.jsonl", [
      { type: "CronCreate", other: "data" },
      { message: null },
    ]);

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(0);
    expect(deletes.size).toBe(0);
  });

  it("handles empty file", async () => {
    const filePath = join(testDir, "empty.jsonl");
    writeFileSync(filePath, "");

    const { creates, deletes } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(0);
    expect(deletes.size).toBe(0);
  });

  it("handles CronCreate with missing input fields gracefully", async () => {
    const filePath = writeJsonl("partial-input.jsonl", [
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: "tu-partial",
              name: "CronCreate",
              input: {},
            },
          ],
        },
      },
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: "tu-partial" }],
        },
        toolUseResult: { id: "cj-partial" },
        timestamp: "2026-04-14T10:00:00Z",
      },
    ]);

    const { creates } = await parseSessionJsonl(filePath);
    expect(creates.size).toBe(1);
    const task = creates.get("cj-partial")!;
    expect(task.cron).toBe("");
    expect(task.prompt).toBe("");
    expect(task.recurring).toBe(true); // default
    expect(task.durable).toBe(false); // default
  });

  it("durable flag from tool_result overrides tool_use", async () => {
    const filePath = writeJsonl("durable-override.jsonl", [
      {
        message: {
          content: [
            {
              type: "tool_use",
              id: "tu-dur",
              name: "CronCreate",
              input: { cron: "0 * * * *", prompt: "Durable test", durable: false },
            },
          ],
        },
      },
      {
        message: {
          content: [{ type: "tool_result", tool_use_id: "tu-dur" }],
        },
        toolUseResult: { id: "cj-dur", durable: true },
        timestamp: "2026-04-14T10:00:00Z",
      },
    ]);

    const { creates } = await parseSessionJsonl(filePath);
    const task = creates.get("cj-dur")!;
    expect(task.durable).toBe(true);
  });
});

// ── scanSessionCronTasks (integration) ──────────────────────────

describe("scanSessionCronTasks", () => {
  const projectsDir = join(testHome, ".claude", "projects");
  const scheduledPath = join(testHome, ".claude", "scheduled_tasks.json");

  function writeSessionJsonl(projDir: string, sessionId: string, lines: unknown[]): void {
    const dir = join(projectsDir, projDir);
    mkdirSync(dir, { recursive: true });
    const filePath = join(dir, `${sessionId}.jsonl`);
    writeFileSync(filePath, lines.map((l) => JSON.stringify(l)).join("\n") + "\n");
  }

  beforeEach(() => {
    mkdirSync(join(testHome, ".claude"), { recursive: true });
  });

  afterEach(() => {
    if (existsSync(testHome)) {
      rmSync(testHome, { recursive: true, force: true });
    }
  });

  it("returns empty array when projects dir does not exist", async () => {
    // Don't create projects dir
    const jobs = await scanSessionCronTasks();
    expect(jobs).toEqual([]);
  });

  it("discovers cron tasks from session JSONL files", async () => {
    writeSessionJsonl(
      "-Users-dev--my-project",
      "abc12345-6789-0000-0000-000000000000",
      [
        {
          message: {
            content: [
              {
                type: "tool_use",
                id: "tu-1",
                name: "CronCreate",
                input: { cron: "*/10 * * * *", prompt: "Health check", recurring: true },
              },
            ],
          },
        },
        {
          message: {
            content: [{ type: "tool_result", tool_use_id: "tu-1" }],
          },
          toolUseResult: { id: "cj-health" },
          timestamp: "2026-04-14T10:00:00Z",
          cwd: "/Users/dev/my-project",
        },
      ],
    );

    const jobs = await scanSessionCronTasks();
    expect(jobs.length).toBeGreaterThanOrEqual(1);

    const cronJob = jobs.find((j) => j.description.includes("Health check"));
    expect(cronJob).toBeDefined();
    expect(cronJob!.source).toBe("cron");
    expect(cronJob!.agent).toBe("claude-code");
    expect(cronJob!.schedule).toBe("*/10 * * * *");
    expect(cronJob!.id).toContain("cron-");
    expect(cronJob!.lifecycle).toBe("session-only");
  });

  it("excludes deleted cron tasks", async () => {
    writeSessionJsonl(
      "-Users-dev--project",
      "def12345-0000-0000-0000-000000000000",
      [
        // Create
        {
          message: {
            content: [
              {
                type: "tool_use",
                id: "tu-del",
                name: "CronCreate",
                input: { cron: "0 * * * *", prompt: "Temp task" },
              },
            ],
          },
        },
        {
          message: {
            content: [{ type: "tool_result", tool_use_id: "tu-del" }],
          },
          toolUseResult: { id: "cj-temp" },
          timestamp: "2026-04-14T10:00:00Z",
        },
        // Delete
        {
          message: {
            content: [
              {
                type: "tool_use",
                name: "CronDelete",
                input: { id: "cj-temp" },
              },
            ],
          },
        },
      ],
    );

    const jobs = await scanSessionCronTasks();
    const tempJob = jobs.find((j) => j.description.includes("Temp task"));
    expect(tempJob).toBeUndefined();
  });

  it("reads durable tasks from scheduled_tasks.json as fallback", async () => {
    mkdirSync(join(testHome, ".claude"), { recursive: true });
    writeFileSync(
      scheduledPath,
      JSON.stringify([
        { prompt: "Durable backup task", cron: "0 2 * * *" },
      ]),
    );

    const jobs = await scanSessionCronTasks();
    expect(jobs.length).toBeGreaterThanOrEqual(1);

    const durableJob = jobs.find((j) => j.description.includes("Durable backup task"));
    expect(durableJob).toBeDefined();
    expect(durableJob!.source).toBe("cron");
    expect(durableJob!.lifecycle).toBe("durable");
    expect(durableJob!.schedule).toBe("0 2 * * *");
  });

  it("deduplicates durable tasks found in both JSONL and scheduled_tasks.json", async () => {
    // Create durable task in JSONL
    writeSessionJsonl(
      "-Users-dev--dedup-project",
      "dup12345-0000-0000-0000-000000000000",
      [
        {
          message: {
            content: [
              {
                type: "tool_use",
                id: "tu-dup",
                name: "CronCreate",
                input: { cron: "0 3 * * *", prompt: "Nightly cleanup", durable: true },
              },
            ],
          },
        },
        {
          message: {
            content: [{ type: "tool_result", tool_use_id: "tu-dup" }],
          },
          toolUseResult: { id: "cj-dup", durable: true },
          timestamp: "2026-04-14T10:00:00Z",
        },
      ],
    );

    // Same task in scheduled_tasks.json
    writeFileSync(
      scheduledPath,
      JSON.stringify([
        { prompt: "Nightly cleanup", cron: "0 3 * * *" },
      ]),
    );

    const jobs = await scanSessionCronTasks();
    const nightlyJobs = jobs.filter((j) => j.description.includes("Nightly cleanup"));
    // Should be deduplicated — only one entry
    expect(nightlyJobs).toHaveLength(1);
  });

  it("handles corrupt scheduled_tasks.json gracefully", async () => {
    mkdirSync(join(testHome, ".claude"), { recursive: true });
    writeFileSync(scheduledPath, "not valid json!!!");

    const jobs = await scanSessionCronTasks();
    // Should not throw, returns empty or any JSONL-scanned jobs
    expect(Array.isArray(jobs)).toBe(true);
  });

  it("handles scheduled_tasks.json with non-array content", async () => {
    mkdirSync(join(testHome, ".claude"), { recursive: true });
    writeFileSync(scheduledPath, JSON.stringify({ not: "an array" }));

    const jobs = await scanSessionCronTasks();
    expect(Array.isArray(jobs)).toBe(true);
  });

  it("marks durable cron tasks with lifecycle='durable'", async () => {
    writeSessionJsonl(
      "-Users-dev--dur-project",
      "dur12345-0000-0000-0000-000000000000",
      [
        {
          message: {
            content: [
              {
                type: "tool_use",
                id: "tu-durr",
                name: "CronCreate",
                input: { cron: "0 9 * * 1-5", prompt: "Weekday standup", durable: true },
              },
            ],
          },
        },
        {
          message: {
            content: [{ type: "tool_result", tool_use_id: "tu-durr" }],
          },
          toolUseResult: { id: "cj-durr", durable: true },
          timestamp: "2026-04-14T10:00:00Z",
          cwd: "/Users/dev/dur-project",
        },
      ],
    );

    const jobs = await scanSessionCronTasks();
    const durJob = jobs.find((j) => j.description.includes("Weekday standup"));
    expect(durJob).toBeDefined();
    expect(durJob!.lifecycle).toBe("durable");
  });

  it("extracts project name from cwd when available", async () => {
    writeSessionJsonl(
      "-Users-dev--my-app",
      "cwd12345-0000-0000-0000-000000000000",
      [
        {
          message: {
            content: [
              {
                type: "tool_use",
                id: "tu-cwd",
                name: "CronCreate",
                input: { cron: "*/5 * * * *", prompt: "CWD test" },
              },
            ],
          },
        },
        {
          message: {
            content: [{ type: "tool_result", tool_use_id: "tu-cwd" }],
          },
          toolUseResult: { id: "cj-cwd" },
          timestamp: "2026-04-14T10:00:00Z",
          cwd: "/Users/dev/workspace/my-app",
        },
      ],
    );

    const jobs = await scanSessionCronTasks();
    const cwdJob = jobs.find((j) => j.description.includes("CWD test"));
    expect(cwdJob).toBeDefined();
    expect(cwdJob!.project).toBe("workspace/my-app");
  });
});
