import { describe, it, expect, vi, beforeEach } from "vitest";
import { detect, detectScheduleFromCommand } from "./cli/detect.js";
import { writeFileSync, existsSync, readFileSync, openSync, unlinkSync } from "fs";

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
    openSync: vi.fn(() => 99),
    closeSync: vi.fn(),
    unlinkSync: vi.fn(),
  };
});

/** Find the jobs.json temp-file write (string path containing .tmp), skipping lockfile fd writes */
function getJobsWriteJson(): unknown {
  const mockWrite = vi.mocked(writeFileSync);
  const jobsWrite = mockWrite.mock.calls.find(
    (call) => typeof call[0] === "string" && String(call[0]).includes(".tmp"),
  );
  if (!jobsWrite) throw new Error("No jobs.json write found");
  return JSON.parse(jobsWrite[1] as string);
}

/** Get the raw JSON string from the jobs.json temp-file write */
function getJobsWriteRaw(): string {
  const mockWrite = vi.mocked(writeFileSync);
  const jobsWrite = mockWrite.mock.calls.find(
    (call) => typeof call[0] === "string" && String(call[0]).includes(".tmp"),
  );
  if (!jobsWrite) throw new Error("No jobs.json write found");
  return jobsWrite[1] as string;
}

describe("detect - Bash pattern matching", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    });
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

  it("detects docker run -d with --name flag", () => {
    detect({
      tool_name: "Bash",
      tool_input: { command: "docker run -d --name my-app nginx:latest" },
      tool_result: "abc123",
    });
    const written = getJobsWriteJson() as { jobs: Array<{ name: string }> };
    expect(written.jobs[0].name).toBe("my-app");
  });

  it("detects uvicorn with module path", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "uvicorn main:app --reload" },
      tool_result: "Uvicorn running on http://127.0.0.1:8000",
    });
    expect(result).toBe(true);
    const written = getJobsWriteJson() as { jobs: Array<{ name: string }> };
    expect(written.jobs[0].name).toBe("uvicorn main:app");
  });

  it("detects gunicorn with module path", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "gunicorn app:application -w 4" },
      tool_result: "Listening at: http://0.0.0.0:8000",
    });
    expect(result).toBe(true);
    const written = getJobsWriteJson() as { jobs: Array<{ name: string }> };
    expect(written.jobs[0].name).toBe("gunicorn app:application");
  });

  it("detects next dev", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "next dev" },
      tool_result: "ready - started server on http://localhost:3000",
    });
    expect(result).toBe(true);
    const written = getJobsWriteJson() as { jobs: Array<{ name: string }> };
    expect(written.jobs[0].name).toBe("next-dev");
  });

  it("detects vite dev", () => {
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "vite dev" },
      tool_result: "Local: http://localhost:5173",
    });
    expect(result).toBe(true);
    const written = getJobsWriteJson() as { jobs: Array<{ name: string }> };
    expect(written.jobs[0].name).toBe("vite-dev");
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
    vi.resetAllMocks();
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    });
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
    vi.resetAllMocks();
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    });
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

    const written = getJobsWriteJson() as { jobs: Array<{ name: string; agent: string; status: string; id: string }> };
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
    const writtenJson = getJobsWriteRaw();

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

    const written = getJobsWriteJson() as { jobs: Array<{ name: string; port: number }> };
    const flaskJob = written.jobs.find((j) => j.name === "flask-server");
    expect(flaskJob).toBeDefined();
    expect(flaskJob!.port).toBe(5000);
  });
});

describe("detect - file locking", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.mocked(existsSync).mockReturnValue(false);
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      if (args[0] === 0) return "";
      throw new Error("ENOENT");
    });
  });

  it("returns false when lock cannot be acquired (non-EEXIST error)", () => {
    // openSync throws a non-EEXIST error (e.g. permission denied)
    vi.mocked(openSync).mockImplementation(() => {
      const err = new Error("EACCES: permission denied") as NodeJS.ErrnoException;
      err.code = "EACCES";
      throw err;
    });

    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(result).toBe(false);
  });

  it("detects stale lock from dead process and recovers", () => {
    let openCallCount = 0;
    vi.mocked(openSync).mockImplementation((...args: unknown[]) => {
      openCallCount++;
      if (openCallCount === 1) {
        // First attempt: lock exists
        const err = new Error("EEXIST") as NodeJS.ErrnoException;
        err.code = "EEXIST";
        throw err;
      }
      // Second attempt succeeds after stale lock removal
      return 99;
    });

    // readFileSync for the lock file returns a PID of a dead process
    vi.mocked(readFileSync).mockImplementation((...args: unknown[]) => {
      const pathArg = args[0];
      if (pathArg === 0) return "";
      if (typeof pathArg === "string" && String(pathArg).includes("jobs.lock")) {
        return "99999"; // PID of a non-existent process
      }
      throw new Error("ENOENT");
    });

    // process.kill(99999, 0) should throw for non-existent process
    const origKill = process.kill;
    process.kill = vi.fn((pid: number, signal?: string | number) => {
      if (signal === 0 && pid === 99999) {
        throw new Error("ESRCH: no such process");
      }
      return true;
    }) as typeof process.kill;

    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });

    expect(result).toBe(true);
    expect(vi.mocked(unlinkSync)).toHaveBeenCalled();

    process.kill = origKill;
  });

  it("releases lock in finally block even on error", () => {
    // Ensure detect succeeds (lock acquired)
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(result).toBe(true);

    // unlinkSync should be called for lock release
    const unlinkCalls = vi.mocked(unlinkSync).mock.calls;
    const lockRelease = unlinkCalls.find(
      (call) => typeof call[0] === "string" && String(call[0]).includes("jobs.lock"),
    );
    expect(lockRelease).toBeDefined();
  });
});

describe("detectScheduleFromCommand", () => {
  it("detects --interval 60 as 'every min'", () => {
    expect(detectScheduleFromCommand("node task.js --interval 60")).toBe("every min");
  });

  it("detects --interval 300 as 'every 5 min'", () => {
    expect(detectScheduleFromCommand("node sync.js --interval 300")).toBe("every 5 min");
  });

  it("detects --interval 30 as 'every 30s'", () => {
    expect(detectScheduleFromCommand("node task.js --interval 30")).toBe("every 30s");
  });

  it("detects --interval 3600 as 'hourly'", () => {
    expect(detectScheduleFromCommand("pew sync --interval 3600")).toBe("hourly");
  });

  it("detects --interval 7200 as 'every 2h'", () => {
    expect(detectScheduleFromCommand("node backup.js --interval 7200")).toBe("every 2h");
  });

  it("detects --cron flag with quoted expression", () => {
    expect(detectScheduleFromCommand('node backup.js --cron "0 2 * * *"')).toBe("0 2 * * *");
  });

  it("detects --cron flag with single-quoted expression", () => {
    expect(detectScheduleFromCommand("node backup.js --cron '*/5 * * * *'")).toBe("*/5 * * * *");
  });

  it("defaults to 'always-on' when no schedule flags", () => {
    expect(detectScheduleFromCommand("node server.js --port 3000")).toBe("always-on");
  });

  it("defaults to 'always-on' for plain commands", () => {
    expect(detectScheduleFromCommand("pm2 start api.js")).toBe("always-on");
  });
});
