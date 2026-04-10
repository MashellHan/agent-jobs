import { describe, it, expect, vi, beforeEach } from "vitest";
import { detect } from "./cli/detect.js";
import { writeFileSync, existsSync, readFileSync } from "fs";

// Mock fs to prevent writing to real ~/.agent-jobs/jobs.json
vi.mock("fs", async (importOriginal) => {
  const actual = await importOriginal<typeof import("fs")>();
  return {
    ...actual,
    existsSync: vi.fn(() => false),
    readFileSync: vi.fn((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    }),
    writeFileSync: vi.fn(),
    mkdirSync: vi.fn(),
    renameSync: vi.fn(),
  };
});

describe("detect - Bash pattern matching", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("detects pm2 start and registers job", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(result).toBe(true);
  });

  it("detects nohup ... & background pattern", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "nohup node server.js &" },
      tool_result: "",
    });
    expect(result).toBe(true);
  });

  it("detects docker run -d", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "docker run -d nginx" },
      tool_result: "abc123",
    });
    expect(result).toBe(true);
  });

  it("detects systemctl enable", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "systemctl enable my-service" },
      tool_result: "",
    });
    expect(result).toBe(true);
  });

  it("detects launchctl load", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "launchctl load /Library/LaunchDaemons/com.example.plist" },
      tool_result: "",
    });
    expect(result).toBe(true);
  });

  it("does not detect plain node script without background/server output", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "node build.js" },
      tool_result: "Build complete",
    });
    expect(result).toBe(false);
  });

  it("detects node script when server output is present", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "node server.js" },
      tool_result: "Listening on http://localhost:3000",
    });
    expect(result).toBe(true);
  });

  it("detects docker-compose up -d", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "docker-compose up -d" },
      tool_result: "Starting services...",
    });
    expect(result).toBe(true);
  });

  it("detects flask run", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "flask run --port 5000" },
      tool_result: "Running on http://127.0.0.1:5000",
    });
    expect(result).toBe(true);
  });

  it("ignores unrelated Bash commands", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "ls -la" },
      tool_result: "",
    });
    expect(result).toBe(false);
  });
});

describe("detect - File pattern matching", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("detects .plist file creation", () => {
    const result = detect({
      tool_name: "Write",
      tool_input: { file_path: "/Library/LaunchDaemons/com.example.agent.plist" },
    });
    expect(result).toBe(true);
  });

  it("detects docker-compose.yml creation", () => {
    const result = detect({
      tool_name: "Write",
      tool_input: { file_path: "/Users/dev/project/docker-compose.yml" },
    });
    expect(result).toBe(true);
  });

  it("detects .service file creation", () => {
    const result = detect({
      tool_name: "Edit",
      tool_input: { file_path: "/etc/systemd/system/my-app.service" },
    });
    expect(result).toBe(true);
  });

  it("ignores unrelated file writes", () => {
    const result = detect({
      tool_name: "Write",
      tool_input: { file_path: "/Users/dev/project/README.md" },
    });
    expect(result).toBe(false);
  });
});

describe("detect - tool filtering", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("ignores Read tool calls", () => {
    const result = detect({
      tool_name: "Read",
      tool_input: { file_path: "/etc/hosts" },
    });
    expect(result).toBe(false);
  });

  it("ignores calls with no tool_name", () => {
    const result = detect({
      tool_input: { command: "pm2 start api.js" },
    });
    expect(result).toBe(false);
  });
});

describe("detect - job registration", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    // Reset default mock implementations
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    });
  });

  it("writes correct job payload to disk", () => {
    detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });

    const mockWrite = vi.mocked(writeFileSync);
    expect(mockWrite).toHaveBeenCalledTimes(1);

    const written = JSON.parse(mockWrite.mock.calls[0]![1] as string);
    expect(written.jobs).toHaveLength(1);
    expect(written.jobs[0].name).toBe("pm2 api.js");
    expect(written.jobs[0].agent).toBe("claude-code");
    expect(written.jobs[0].status).toBe("active");
    expect(written.jobs[0].id).toMatch(/^hook-/);
  });

  it("deduplicates by name — second detect returns false", () => {
    // First call: empty jobs file (existsSync returns false)
    const first = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(first).toBe(true);

    // Capture what was written so the second call sees the existing job
    const mockWrite = vi.mocked(writeFileSync);
    const writtenJson = mockWrite.mock.calls[0]![1] as string;

    // Now simulate the file existing with that content
    vi.mocked(existsSync).mockReturnValue(true);
    vi.mocked(readFileSync).mockReturnValue(writtenJson);

    // Second call with same pattern should be deduped
    const second = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(second).toBe(false);
  });

  it("extracts port from --port flag", () => {
    detect({
      tool_name: "Bash",
      tool_input: { command: "flask run --port 5000" },
      tool_result: "Running on http://127.0.0.1:5000",
    });

    const mockWrite = vi.mocked(writeFileSync);
    const written = JSON.parse(mockWrite.mock.calls[0]![1] as string);
    const flaskJob = written.jobs.find((j: { name: string }) => j.name === "flask-server");
    expect(flaskJob).toBeDefined();
    expect(flaskJob.port).toBe(5000);
  });
});
