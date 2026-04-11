import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock fs module
vi.mock("fs", () => ({
  readFile: vi.fn(),
  watch: vi.fn(),
}));

// Mock scanner module
vi.mock("./scanner.js", () => ({
  scanLiveProcesses: vi.fn(),
  scanClaudeScheduledTasks: vi.fn(),
  scanLaunchdServices: vi.fn(),
}));

// Mock os to control homedir
vi.mock("os", () => ({
  homedir: vi.fn(() => "/mock-home"),
}));

import { readFile, watch } from "fs";
import { loadAllJobs, watchJobsFile } from "./loader.js";
import { scanLiveProcesses, scanClaudeScheduledTasks, scanLaunchdServices } from "./scanner.js";

const mockReadFile = vi.mocked(readFile);
const mockWatch = vi.mocked(watch);
const mockScanLive = vi.mocked(scanLiveProcesses);
const mockScanCron = vi.mocked(scanClaudeScheduledTasks);
const mockScanLaunchd = vi.mocked(scanLaunchdServices);

beforeEach(() => {
  vi.resetAllMocks();
});

describe("loadAllJobs", () => {
  it("merges registered, cron, and live jobs into a single array", async () => {
    const registeredJob = {
      id: "r1",
      name: "web-server",
      description: "My web server",
      agent: "claude-code",
      schedule: "always-on",
      status: "active" as const,
      source: "registered" as const,
      project: "/proj",
      created_at: "2026-01-01T00:00:00Z",
      last_run: null,
      next_run: null,
      last_result: "success" as const,
      run_count: 5,
    };

    const cronJob = {
      id: "cron-0",
      name: "backup",
      description: "Backup task",
      agent: "claude-code",
      schedule: "0 2 * * *",
      status: "active" as const,
      source: "cron" as const,
      project: "",
      created_at: "2026-01-01T00:00:00Z",
      last_run: null,
      next_run: null,
      last_result: "unknown" as const,
      run_count: -1,
    };

    const liveJob = {
      id: "live-1234",
      name: "server.js :3000",
      description: "node server.js",
      agent: "manual",
      schedule: "always-on",
      status: "active" as const,
      source: "live" as const,
      project: "",
      pid: 1234,
      port: 3000,
      created_at: "2026-01-01T00:00:00Z",
      last_run: "2026-01-01T00:00:00Z",
      next_run: null,
      last_result: "success" as const,
      run_count: -1,
    };

    // loadRegisteredJobs reads from file
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(
        null,
        JSON.stringify({
          version: "1",
          jobs: [{ ...registeredJob, source: undefined }],
        }),
      );
    });
    mockScanLive.mockResolvedValue([liveJob]);
    mockScanCron.mockResolvedValue([cronJob]);
    mockScanLaunchd.mockResolvedValue([]);

    const jobs = await loadAllJobs();

    // Order: registered, cron, launchd, live
    expect(jobs).toHaveLength(3);
    expect(jobs[0]!.source).toBe("registered");
    expect(jobs[1]!.source).toBe("cron");
    expect(jobs[2]!.source).toBe("live");
  });

  it("merges launchd jobs into the result (4 sources)", async () => {
    const launchdJob = {
      id: "launchd-com.pew.sync",
      name: "pew sync",
      description: "/opt/homebrew/bin/pew sync",
      agent: "system",
      schedule: "every 10 min",
      status: "active" as const,
      source: "launchd" as const,
      project: "",
      created_at: "2026-01-01T00:00:00Z",
      last_run: "2026-04-11T14:00:00Z",
      next_run: null,
      last_result: "success" as const,
      run_count: -1,
    };

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: Error) => void)(new Error("ENOENT"));
    });
    mockScanLive.mockResolvedValue([]);
    mockScanCron.mockResolvedValue([]);
    mockScanLaunchd.mockResolvedValue([launchdJob]);

    const jobs = await loadAllJobs();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.source).toBe("launchd");
    expect(jobs[0]!.name).toBe("pew sync");
    expect(jobs[0]!.schedule).toBe("every 10 min");
  });

  it("returns only live and cron when jobs.json does not exist", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: Error) => void)(new Error("ENOENT"));
    });
    mockScanLive.mockResolvedValue([]);
    mockScanCron.mockResolvedValue([]);
    mockScanLaunchd.mockResolvedValue([]);

    const jobs = await loadAllJobs();
    expect(jobs).toEqual([]);
  });
});

describe("loadRegisteredJobs (via loadAllJobs)", () => {
  beforeEach(() => {
    mockScanLive.mockResolvedValue([]);
    mockScanCron.mockResolvedValue([]);
    mockScanLaunchd.mockResolvedValue([]);
  });

  it("returns empty when file read fails (ENOENT)", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: Error) => void)(new Error("ENOENT: no such file"));
    });

    const jobs = await loadAllJobs();
    expect(jobs).toEqual([]);
  });

  it("returns empty when file contains invalid JSON", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, "not-valid-json{{{");
    });

    const jobs = await loadAllJobs();
    expect(jobs).toEqual([]);
  });

  it("parses valid jobs.json and adds source:'registered'", async () => {
    const jobData = {
      version: "1",
      jobs: [
        {
          id: "j1",
          name: "api-server",
          description: "API",
          agent: "claude-code",
          schedule: "always-on",
          status: "active",
          project: "/proj",
          created_at: "2026-01-01T00:00:00Z",
          last_run: null,
          next_run: null,
          last_result: "success",
          run_count: 3,
        },
      ],
    };

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify(jobData));
    });

    const jobs = await loadAllJobs();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.source).toBe("registered");
    expect(jobs[0]!.name).toBe("api-server");
  });

  it("defaults last_result to 'unknown' when missing from JSON", async () => {
    const jobData = {
      version: "1",
      jobs: [
        {
          id: "j2",
          name: "worker",
          description: "Worker task",
          agent: "manual",
          schedule: "0 * * * *",
          status: "active",
          project: "",
          created_at: "2026-01-01T00:00:00Z",
          last_run: null,
          next_run: null,
          run_count: 0,
          // last_result intentionally missing
        },
      ],
    };

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify(jobData));
    });

    const jobs = await loadAllJobs();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.last_result).toBe("unknown");
  });

  it("returns empty when jobs array is missing from parsed JSON", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(
        null,
        JSON.stringify({ version: "1" }),
      );
    });

    const jobs = await loadAllJobs();
    expect(jobs).toEqual([]);
  });
});

describe("watchJobsFile", () => {
  it("returns a cleanup function that closes all three watchers", () => {
    const closeJobs = vi.fn();
    const closeHidden = vi.fn();
    const closeClaude = vi.fn();

    let callCount = 0;
    const closeFns = [closeJobs, closeHidden, closeClaude];
    mockWatch.mockImplementation(() => {
      const fn = closeFns[callCount]!;
      callCount++;
      return { close: fn } as unknown as ReturnType<typeof watch>;
    });

    const cleanup = watchJobsFile(() => {});
    expect(typeof cleanup).toBe("function");

    // Should have created 3 watchers (jobs.json + hidden.json + scheduled_tasks.json)
    expect(mockWatch).toHaveBeenCalledTimes(3);

    cleanup();
    expect(closeJobs).toHaveBeenCalledTimes(1);
    expect(closeHidden).toHaveBeenCalledTimes(1);
    expect(closeClaude).toHaveBeenCalledTimes(1);
  });

  it("handles watch errors gracefully (returns noop cleanup)", () => {
    mockWatch.mockImplementation(() => {
      throw new Error("ENOENT: path does not exist");
    });

    const cleanup = watchJobsFile(() => {});
    expect(typeof cleanup).toBe("function");

    // Should not throw when calling cleanup
    expect(() => cleanup()).not.toThrow();
  });
});
