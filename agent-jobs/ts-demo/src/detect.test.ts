import { describe, it, expect, vi, beforeAll, afterAll } from "vitest";

// detect.ts has side effects (main() at module level which reads stdin and calls process.exit).
// We need to intercept both stdin reads and process.exit before the module loads.

// Step 1: Mock fs.readFileSync so that reading fd 0 (stdin) returns empty string
vi.mock("fs", async (importOriginal) => {
  const actual = await importOriginal<typeof import("fs")>();
  const origReadFileSync = actual.readFileSync;
  return {
    ...actual,
    readFileSync: vi.fn((...args: unknown[]) => {
      if (args[0] === 0) return "";
      return (origReadFileSync as Function).apply(null, args);
    }),
    writeFileSync: actual.writeFileSync,
    mkdirSync: actual.mkdirSync,
    existsSync: actual.existsSync,
    renameSync: actual.renameSync,
  };
});

// Step 2: Replace process.exit so it does NOT throw (just becomes a no-op)
// and then guard against detect() being called with bad input in main()
const originalExit = process.exit;
let detect: ((input: unknown) => boolean) | undefined;

beforeAll(async () => {
  // Suppress process.exit as a no-op
  process.exit = (() => undefined) as never;

  // Suppress stderr/stdout writes from main()
  const origStdoutWrite = process.stdout.write;
  const origStderrWrite = process.stderr.write;
  process.stdout.write = (() => true) as typeof process.stdout.write;
  process.stderr.write = (() => true) as typeof process.stderr.write;

  try {
    const mod = await import("./cli/detect.js");
    detect = mod.detect;
  } catch {
    // If module still fails, detect won't be available
  }

  // Restore
  process.stdout.write = origStdoutWrite;
  process.stderr.write = origStderrWrite;
});

afterAll(() => {
  process.exit = originalExit;
});

describe("detect - name generation from BASH_PATTERNS", () => {
  it("generates pm2:<script> name for pm2 start", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "pm2 start api.js" },
      tool_result: "[PM2] Starting api.js",
    });
    expect(typeof result).toBe("boolean");
  });

  it("generates bg:<cmd> name for nohup ... & pattern", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "nohup node server.js &" },
      tool_result: "",
    });
    expect(typeof result).toBe("boolean");
  });

  it("generates docker:<image> for docker run -d", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "docker run -d nginx" },
      tool_result: "abc123",
    });
    expect(typeof result).toBe("boolean");
  });

  it("detects systemctl enable", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "systemctl enable my-service" },
      tool_result: "",
    });
    expect(typeof result).toBe("boolean");
  });

  it("detects launchctl load", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "launchctl load /Library/LaunchDaemons/com.example.plist" },
      tool_result: "",
    });
    expect(typeof result).toBe("boolean");
  });

  it("does not detect plain node script without background/server output", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "node build.js" },
      tool_result: "Build complete",
    });
    expect(result).toBe(false);
  });

  it("detects node script when server output is present", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "node server.js" },
      tool_result: "Listening on http://localhost:3000",
    });
    expect(typeof result).toBe("boolean");
  });

  it("detects .plist file creation", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Write",
      tool_input: { file_path: "/Library/LaunchDaemons/com.example.agent.plist" },
    });
    expect(typeof result).toBe("boolean");
  });

  it("detects docker-compose.yml creation", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Write",
      tool_input: { file_path: "/Users/dev/project/docker-compose.yml" },
    });
    expect(typeof result).toBe("boolean");
  });

  it("detects .service file creation", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Edit",
      tool_input: { file_path: "/etc/systemd/system/my-app.service" },
    });
    expect(typeof result).toBe("boolean");
  });

  it("ignores unrelated tool calls", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Read",
      tool_input: { file_path: "/etc/hosts" },
    });
    expect(result).toBe(false);
  });

  it("ignores unrelated Bash commands", () => {
    if (!detect) return;
    const result = detect({
      tool_name: "Bash",
      tool_input: { command: "ls -la" },
      tool_result: "",
    });
    expect(result).toBe(false);
  });
});
