import { describe, it, expect } from "vitest";
import { friendlyLiveName, parseLsofOutput, inferAgent } from "./scanner.js";

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

  it("falls back to command + port when no script or framework", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'some code'", 9292)).toBe("ruby :9292");
  });

  it("falls back to command only when no port", () => {
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
