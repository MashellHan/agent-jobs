import { describe, it, expect, vi, beforeEach } from "vitest";
import { friendlyLiveName, parseLsofOutput, inferAgent, scanLiveProcesses, scanClaudeScheduledTasks, scanLaunchdServices, deriveSchedule, deriveFriendlyName } from "./scanner.js";
import type { PlistData } from "./scanner.js";

// We need to mock child_process and fs for integration tests
vi.mock("child_process", async (importOriginal) => {
  const actual = await importOriginal<typeof import("child_process")>();
  return {
    ...actual,
    execFile: vi.fn(),
  };
});

vi.mock("fs", async (importOriginal) => {
  const actual = await importOriginal<typeof import("fs")>();
  return {
    ...actual,
    readFile: vi.fn(),
    readdir: vi.fn(),
  };
});

vi.mock("fs/promises", async (importOriginal) => {
  const actual = await importOriginal<typeof import("fs/promises")>();
  return {
    ...actual,
    stat: vi.fn(() => Promise.resolve({ mtime: new Date("2026-04-01T00:00:00Z") })),
  };
});

vi.mock("os", () => ({
  homedir: vi.fn(() => "/mock-home"),
}));

import { execFile } from "child_process";
import { readFile, readdir } from "fs";

const mockExecFile = vi.mocked(execFile);
const mockReadFile = vi.mocked(readFile);
const mockReaddir = vi.mocked(readdir);

beforeEach(() => {
  vi.resetAllMocks();
});

describe("friendlyLiveName", () => {
  it("extracts script filename with port", () => {
    expect(friendlyLiveName("node", "node /Users/dev/api/server.js", 4000)).toBe("server.js :4000");
  });

  it("extracts script filename without port", () => {
    expect(friendlyLiveName("node", "node /Users/dev/api/server.js", 0)).toBe("server.js");
  });

  it("detects next framework with port", () => {
    expect(friendlyLiveName("node", "node /usr/local/bin/next start", 3000)).toBe("next :3000");
  });

  it("detects vite framework with port", () => {
    expect(friendlyLiveName("node", "node node_modules/.bin/vite --port 5173", 5173)).toBe("vite :5173");
  });

  it("detects uvicorn framework", () => {
    expect(friendlyLiveName("python3", "python3 -m uvicorn main:app", 8000)).toBe("uvicorn :8000");
  });

  it("detects gunicorn framework", () => {
    expect(friendlyLiveName("python3", "gunicorn app:application -w 4", 8000)).toBe("gunicorn :8000");
  });

  it("detects flask framework", () => {
    expect(friendlyLiveName("python3", "python3 -m flask run", 5000)).toBe("flask :5000");
  });

  it("falls back to command + port when no script, framework, or agent", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'some code'", 9292)).toBe("ruby :9292");
  });

  it("falls back to command only when no port and no agent", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'some code'", 0)).toBe("ruby");
  });

  it("prefers script over framework detection", () => {
    // If script arg is found, it wins over framework name
    expect(friendlyLiveName("node", "node app.ts", 3000)).toBe("app.ts :3000");
  });

  it("handles .py scripts", () => {
    expect(friendlyLiveName("python3", "python3 app.py", 8080)).toBe("app.py :8080");
  });

  it("handles nuxt framework", () => {
    expect(friendlyLiveName("node", "node .output/server/index.mjs nuxt", 3000)).toBe("index.mjs :3000");
  });

  // Agent-aware naming tests
  it("uses agent name when no script or framework detected", () => {
    expect(friendlyLiveName("node", "node -e 'require(\"openclaw\")'", 18789, "openclaw")).toBe("openclaw :18789");
  });

  it("extracts subcommand from openclaw gateway process", () => {
    expect(friendlyLiveName("node", "/opt/homebrew/opt/node/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/entry.js gateway --port 18789", 18789, "openclaw")).toBe("openclaw-gateway :18789");
  });

  it("uses claude label for claude-code agent", () => {
    expect(friendlyLiveName("node", "node claude-server", 3000, "claude-code")).toBe("claude :3000");
  });

  it("falls back to agent name without subcommand when no match", () => {
    expect(friendlyLiveName("node", "node something", 0, "openclaw")).toBe("openclaw");
  });

  it("ignores agent=manual and falls back to command", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'code'", 9292, "manual")).toBe("ruby :9292");
  });

  it("script detection takes priority over agent-aware naming", () => {
    expect(friendlyLiveName("node", "node server.js", 3000, "openclaw")).toBe("server.js :3000");
  });

  it("framework detection takes priority over agent-aware naming", () => {
    expect(friendlyLiveName("node", "node node_modules/.bin/vite", 5173, "openclaw")).toBe("vite :5173");
  });
});

describe("parseLsofOutput", () => {
  const HEADER = "COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME";

  it("parses a valid lsof line with port", () => {
    const output = `${HEADER}\nnode      12345 dev   24u  IPv4 0x1234      0t0  TCP *:3000 (LISTEN)`;
    const entries = parseLsofOutput(output);
    expect(entries).toHaveLength(1);
    expect(entries[0]).toEqual({ pid: 12345, command: "node", port: 3000, user: "dev" });
  });

  it("returns empty array for empty input", () => {
    expect(parseLsofOutput("")).toEqual([]);
  });

  it("returns empty array for header-only input", () => {
    expect(parseLsofOutput(HEADER)).toEqual([]);
  });

  it("skips irrelevant commands", () => {
    const output = `${HEADER}\nspotify   99999 dev   24u  IPv4 0x1234      0t0  TCP *:4070 (LISTEN)`;
    expect(parseLsofOutput(output)).toEqual([]);
  });

  it("deduplicates by PID", () => {
    const output = [
      HEADER,
      "node      12345 dev   24u  IPv4 0x1234      0t0  TCP *:3000 (LISTEN)",
      "node      12345 dev   25u  IPv6 0x5678      0t0  TCP *:3000 (LISTEN)",
    ].join("\n");
    expect(parseLsofOutput(output)).toHaveLength(1);
  });

  it("handles multiple valid entries", () => {
    const output = [
      HEADER,
      "node      1001 dev   24u  IPv4 0x1234      0t0  TCP *:3000 (LISTEN)",
      "python3   1002 dev   25u  IPv4 0x5678      0t0  TCP *:8000 (LISTEN)",
    ].join("\n");
    const entries = parseLsofOutput(output);
    expect(entries).toHaveLength(2);
    expect(entries[0]!.command).toBe("node");
    expect(entries[1]!.command).toBe("python3");
  });

  it("handles lines with too few fields", () => {
    const output = `${HEADER}\nnode 1234 dev`;
    expect(parseLsofOutput(output)).toEqual([]);
  });

  it("handles port extraction from IPv6 address", () => {
    const output = `${HEADER}\nnode      12345 dev   24u  IPv6 0x1234      0t0  TCP [::1]:8080 (LISTEN)`;
    const entries = parseLsofOutput(output);
    expect(entries).toHaveLength(1);
    expect(entries[0]!.port).toBe(8080);
  });
});

describe("inferAgent", () => {
  it("detects claude-code agent", () => {
    expect(inferAgent("claude code --project /foo")).toBe("claude-code");
  });

  it("detects cursor agent", () => {
    expect(inferAgent("/usr/bin/cursor server --port 3000")).toBe("cursor");
  });

  it("detects github-copilot agent", () => {
    expect(inferAgent("node copilot-language-server")).toBe("github-copilot");
  });

  it("detects openclaw agent", () => {
    expect(inferAgent("openclaw run --task build")).toBe("openclaw");
  });

  it("detects openclaw via claw keyword", () => {
    expect(inferAgent("claw serve --port 8080")).toBe("openclaw");
  });

  it("returns manual for unknown commands", () => {
    expect(inferAgent("node server.js")).toBe("manual");
  });

  it("is case insensitive", () => {
    expect(inferAgent("CLAUDE Desktop App")).toBe("claude-code");
    expect(inferAgent("OpenClaw Agent")).toBe("openclaw");
  });
});

describe("scanLiveProcesses", () => {
  it("returns empty array when lsof produces no output", async () => {
    mockExecFile.mockImplementation((_cmd, _args, _opts, cb) => {
      (cb as (err: null, stdout: string) => void)(null, "");
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLiveProcesses();
    expect(jobs).toEqual([]);
  });

  it("returns empty array when lsof output has no COMMAND header", async () => {
    mockExecFile.mockImplementation((_cmd, _args, _opts, cb) => {
      (cb as (err: null, stdout: string) => void)(null, "some random output\nwithout headers");
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLiveProcesses();
    expect(jobs).toEqual([]);
  });

  it("maps lsof entries to Job objects with correct fields", async () => {
    const lsofOutput = [
      "COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME",
      "node      12345 dev   24u  IPv4 0x1234      0t0  TCP *:3000 (LISTEN)",
    ].join("\n");

    let callCount = 0;
    mockExecFile.mockImplementation((cmd, _args, _opts, cb) => {
      if (cmd === "lsof") {
        (cb as (err: null, stdout: string) => void)(null, lsofOutput);
      } else if (cmd === "ps") {
        // getFullCommand call
        (cb as (err: null, stdout: string) => void)(null, "node /app/server.js --port 3000\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLiveProcesses();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.id).toBe("live-12345");
    expect(jobs[0]!.name).toBe("server.js :3000");
    expect(jobs[0]!.source).toBe("live");
    expect(jobs[0]!.schedule).toBe("always-on");
    expect(jobs[0]!.status).toBe("active");
    expect(jobs[0]!.port).toBe(3000);
    expect(jobs[0]!.pid).toBe(12345);
  });

  it("catches errors from lsof and returns empty array", async () => {
    mockExecFile.mockImplementation((_cmd, _args, _opts, cb) => {
      (cb as (err: Error, stdout: string) => void)(new Error("lsof failed"), "");
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLiveProcesses();
    expect(jobs).toEqual([]);
  });

  it("handles lsof error with stdout on error object", async () => {
    const lsofOutput = [
      "COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME",
      "node      99999 dev   24u  IPv4 0x1234      0t0  TCP *:8080 (LISTEN)",
    ].join("\n");

    mockExecFile.mockImplementation((cmd, _args, _opts, cb) => {
      if (cmd === "lsof") {
        // lsof sometimes returns non-zero exit with valid stdout
        const err = Object.assign(new Error("exit code 1"), { stdout: lsofOutput });
        (cb as (err: Error, stdout: string) => void)(err, "");
      } else if (cmd === "ps") {
        (cb as (err: null, stdout: string) => void)(null, "node app.js\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLiveProcesses();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.port).toBe(8080);
  });
});

describe("scanClaudeScheduledTasks", () => {
  it("returns empty array when file does not exist", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: Error) => void)(new Error("ENOENT"));
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs).toEqual([]);
  });

  it("returns empty array when file is not an array", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify({ not: "an array" }));
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs).toEqual([]);
  });

  it("maps tasks to Job objects with source:'cron'", async () => {
    const tasks = [
      { prompt: "Run backup script", cron: "0 2 * * *" },
      { prompt: "Check health endpoint", cron: "*/5 * * * *" },
    ];

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify(tasks));
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs).toHaveLength(2);
    expect(jobs[0]!.source).toBe("cron");
    expect(jobs[0]!.agent).toBe("claude-code");
    expect(jobs[0]!.name).toBe("backup script");
    expect(jobs[0]!.schedule).toBe("0 2 * * *");
    expect(jobs[0]!.id).toBe("cron-0");
    expect(jobs[1]!.id).toBe("cron-1");
    expect(jobs[1]!.name).toBe("health endpoint");
  });

  it("returns empty array on corrupt JSON", async () => {
    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, "{{corrupt json!!!");
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs).toEqual([]);
  });

  it("truncates long prompt names to 20 chars max", async () => {
    const longPrompt = "A".repeat(100);
    const tasks = [{ prompt: longPrompt, cron: "0 * * * *" }];

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify(tasks));
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs[0]!.name).toHaveLength(20);
    expect(jobs[0]!.name).toContain("…");
  });

  it("uses fallback name when prompt is empty", async () => {
    const tasks = [{ prompt: "", cron: "0 * * * *" }];

    mockReadFile.mockImplementation((_path, _enc, cb) => {
      (cb as (err: null, data: string) => void)(null, JSON.stringify(tasks));
    });

    const jobs = await scanClaudeScheduledTasks();
    expect(jobs[0]!.name).toBe("cron task");
  });
});

// ── Launchd Scanner Tests ──────────────────────────────────────

describe("deriveSchedule", () => {
  it("converts StartInterval 600 to 'every 10 min'", () => {
    expect(deriveSchedule({ StartInterval: 600 })).toBe("every 10 min");
  });

  it("converts StartInterval 3600 to 'hourly'", () => {
    expect(deriveSchedule({ StartInterval: 3600 })).toBe("hourly");
  });

  it("converts StartInterval 60 to 'every min'", () => {
    expect(deriveSchedule({ StartInterval: 60 })).toBe("every min");
  });

  it("converts StartInterval 30 to 'every 30s'", () => {
    expect(deriveSchedule({ StartInterval: 30 })).toBe("every 30s");
  });

  it("converts StartInterval 7200 to 'every 2h'", () => {
    expect(deriveSchedule({ StartInterval: 7200 })).toBe("every 2h");
  });

  it("converts StartInterval 86400 to 'daily'", () => {
    expect(deriveSchedule({ StartInterval: 86400 })).toBe("daily");
  });

  it("converts StartInterval 172800 to 'every 2d'", () => {
    expect(deriveSchedule({ StartInterval: 172800 })).toBe("every 2d");
  });

  it("converts StartCalendarInterval with Hour:9 Minute:0 to 'daily 9am'", () => {
    expect(deriveSchedule({ StartCalendarInterval: { Hour: 9, Minute: 0 } })).toBe("daily 9am");
  });

  it("converts StartCalendarInterval with Hour:14 Minute:30 to 'daily 2:30pm'", () => {
    expect(deriveSchedule({ StartCalendarInterval: { Hour: 14, Minute: 30 } })).toBe("daily 2:30pm");
  });

  it("converts StartCalendarInterval with Hour:0 to 'daily 12am'", () => {
    expect(deriveSchedule({ StartCalendarInterval: { Hour: 0, Minute: 0 } })).toBe("daily 12am");
  });

  it("handles StartCalendarInterval array (takes first entry)", () => {
    expect(deriveSchedule({ StartCalendarInterval: [{ Hour: 9, Minute: 0 }] })).toBe("daily 9am");
  });

  it("converts weekday-specific StartCalendarInterval", () => {
    const result = deriveSchedule({ StartCalendarInterval: { Hour: 9, Minute: 0, Weekday: 1 } });
    expect(result).toBe("Mon 9am");
  });

  it("returns 'always-on' for KeepAlive:true", () => {
    expect(deriveSchedule({ KeepAlive: true })).toBe("always-on");
  });

  it("returns 'always-on' for RunAtLoad without interval", () => {
    expect(deriveSchedule({ RunAtLoad: true })).toBe("always-on");
  });

  it("prefers StartInterval over RunAtLoad", () => {
    expect(deriveSchedule({ StartInterval: 600, RunAtLoad: true })).toBe("every 10 min");
  });

  it("returns 'on-demand' for empty plist data", () => {
    expect(deriveSchedule({})).toBe("on-demand");
  });
});

describe("deriveFriendlyName", () => {
  it("extracts binary and subcommand from ProgramArguments", () => {
    expect(deriveFriendlyName("com.pew.sync", ["/opt/homebrew/bin/pew", "sync"])).toBe("pew sync");
  });

  it("extracts binary and subcommand for pew update", () => {
    expect(deriveFriendlyName("com.pew.update", ["/opt/homebrew/bin/pew", "update"])).toBe("pew update");
  });

  it("strips flags from subcommand", () => {
    expect(deriveFriendlyName("com.test", ["/usr/bin/rsync", "-avz", "src/", "dest/"])).toBe("rsync");
  });

  it("handles single-arg ProgramArguments", () => {
    expect(deriveFriendlyName("com.myservice", ["/usr/local/bin/myservice"])).toBe("myservice");
  });

  it("handles node with multiple args", () => {
    expect(deriveFriendlyName("ai.openclaw.gateway", [
      "/opt/homebrew/opt/node/bin/node",
      "/opt/homebrew/lib/node_modules/openclaw/dist/entry.js",
      "gateway",
      "--port",
      "18789",
    ])).toBe("node gateway");
  });

  it("falls back to label suffix when no args", () => {
    expect(deriveFriendlyName("com.example.thing", [])).toBe("thing");
  });

  it("falls back to last part for short labels", () => {
    expect(deriveFriendlyName("myservice", [])).toBe("myservice");
  });

  it("truncates long names to 20 chars", () => {
    const result = deriveFriendlyName("com.test", ["/bin/cmd", "very-long-subcommand-name-here"]);
    expect(result.length).toBeLessThanOrEqual(20);
    expect(result).toContain("…");
  });
});

describe("scanLaunchdServices", () => {

  it("returns empty array when LaunchAgents dir does not exist", async () => {
    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: Error) => void)(new Error("ENOENT"));
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toEqual([]);
  });

  it("returns empty array when no plists found", async () => {
    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, ["smartcard-monitor.sock"]);
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toEqual([]);
  });

  it("skips com.apple.* plists", async () => {
    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, [
        "com.apple.Bird.plist",
        "com.apple.Safari.plist",
      ]);
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toEqual([]);
  });

  it("parses a valid plist and produces a Job", async () => {
    const pewSyncPlist: PlistData = {
      Label: "com.pew.sync",
      ProgramArguments: ["/opt/homebrew/bin/pew", "sync"],
      StartInterval: 600,
      RunAtLoad: true,
      StandardOutPath: "/tmp/pew-sync.log",
      StandardErrorPath: "/tmp/pew-sync.err",
    };

    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, ["com.pew.sync.plist"]);
    });

    mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
      if (cmd === "plutil") {
        (cb as (err: null, stdout: string) => void)(null, JSON.stringify(pewSyncPlist));
      } else if (cmd === "launchctl") {
        // launchctl list (no label arg) returns tab-separated format
        (cb as (err: null, stdout: string) => void)(null, "PID\tStatus\tLabel\n-\t0\tcom.pew.sync\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.id).toBe("launchd-com.pew.sync");
    expect(jobs[0]!.name).toBe("pew sync");
    expect(jobs[0]!.schedule).toBe("every 10 min");
    expect(jobs[0]!.source).toBe("launchd");
    expect(jobs[0]!.status).toBe("active");
    expect(jobs[0]!.description).toBe("/opt/homebrew/bin/pew sync");
  });

  it("marks unloaded services as stopped", async () => {
    const plist: PlistData = {
      Label: "com.test.stopped",
      ProgramArguments: ["/usr/bin/test"],
      StartInterval: 300,
    };

    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, ["com.test.stopped.plist"]);
    });

    mockExecFile.mockImplementation((cmd, _args, _opts, cb) => {
      if (cmd === "plutil") {
        (cb as (err: null, stdout: string) => void)(null, JSON.stringify(plist));
      } else if (cmd === "launchctl") {
        // launchctl list returns no matching label → service not loaded
        (cb as (err: null, stdout: string) => void)(null, "PID\tStatus\tLabel\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.status).toBe("stopped");
    expect(jobs[0]!.last_result).toBe("unknown");
  });

  it("handles KeepAlive service with PID", async () => {
    const plist: PlistData = {
      Label: "ai.openclaw.gateway",
      ProgramArguments: ["/opt/homebrew/opt/node/bin/node", "/openclaw/dist/entry.js", "gateway", "--port", "18789"],
      KeepAlive: true,
      RunAtLoad: true,
    };

    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, ["ai.openclaw.gateway.plist"]);
    });

    mockExecFile.mockImplementation((cmd, _args, _opts, cb) => {
      if (cmd === "plutil") {
        (cb as (err: null, stdout: string) => void)(null, JSON.stringify(plist));
      } else if (cmd === "launchctl") {
        // launchctl list returns the service with PID 1786
        (cb as (err: null, stdout: string) => void)(null, "PID\tStatus\tLabel\n1786\t0\tai.openclaw.gateway\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toHaveLength(1);
    expect(jobs[0]!.schedule).toBe("always-on");
    expect(jobs[0]!.pid).toBe(1786);
    expect(jobs[0]!.agent).toBe("openclaw");
    expect(jobs[0]!.name).toBe("node gateway");
  });

  it("handles plutil parsing failure gracefully", async () => {
    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, ["com.broken.plist"]);
    });

    mockExecFile.mockImplementation((cmd, _args, _opts, cb) => {
      if (cmd === "plutil") {
        (cb as (err: Error, stdout: string) => void)(new Error("plutil failed"), "");
      } else if (cmd === "launchctl") {
        (cb as (err: null, stdout: string) => void)(null, "PID\tStatus\tLabel\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toEqual([]);
  });

  it("handles multiple plists in one scan", async () => {
    const plist1: PlistData = {
      Label: "com.pew.sync",
      ProgramArguments: ["/opt/homebrew/bin/pew", "sync"],
      StartInterval: 600,
    };
    const plist2: PlistData = {
      Label: "com.pew.update",
      ProgramArguments: ["/opt/homebrew/bin/pew", "update"],
      StartCalendarInterval: { Hour: 9, Minute: 0 },
    };

    mockReaddir.mockImplementation((_path, cb) => {
      (cb as (err: null, files: string[]) => void)(null, [
        "com.pew.sync.plist",
        "com.pew.update.plist",
      ]);
    });

    mockExecFile.mockImplementation((cmd, args, _opts, cb) => {
      if (cmd === "plutil") {
        const argStr = (args as string[]).join(" ");
        const plistData = argStr.includes("sync") ? plist1 : plist2;
        (cb as (err: null, stdout: string) => void)(null, JSON.stringify(plistData));
      } else if (cmd === "launchctl") {
        // launchctl list returns both services loaded
        (cb as (err: null, stdout: string) => void)(null, "PID\tStatus\tLabel\n-\t0\tcom.pew.sync\n-\t0\tcom.pew.update\n");
      }
      return {} as ReturnType<typeof execFile>;
    });

    const jobs = await scanLaunchdServices();
    expect(jobs).toHaveLength(2);
    expect(jobs.map(j => j.name).sort()).toEqual(["pew sync", "pew update"]);
    expect(jobs.find(j => j.name === "pew sync")!.schedule).toBe("every 10 min");
    expect(jobs.find(j => j.name === "pew update")!.schedule).toBe("daily 9am");
  });
});
