import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { formatTime, formatRelativeTime, cronToHuman, truncate, statusIcon, resultColor } from "./utils.js";

describe("truncate", () => {
  it("returns string unchanged when shorter than max", () => {
    expect(truncate("hello", 10)).toBe("hello");
  });

  it("returns string unchanged when equal to max", () => {
    expect(truncate("hello", 5)).toBe("hello");
  });

  it("truncates and adds ellipsis when longer than max", () => {
    expect(truncate("hello world", 5)).toBe("hell…");
  });

  it("handles single char max", () => {
    expect(truncate("abc", 1)).toBe("…");
  });

  it("handles empty string", () => {
    expect(truncate("", 5)).toBe("");
  });

  // This test documents how truncate handles the JSON residue bug:
  // When JSON garbage like 'pm2:api.js"},"tool_result":"...' is truncated,
  // it produces unreadable partial JSON.
  it("truncates JSON residue to partial garbage (bug baseline)", () => {
    const badName = 'pm2 api.js"},"tool_result":"started process [api]\\nid: 0"';
    const result = truncate(badName, 29);
    // Truncated to 29 chars: first 28 chars + "…"
    expect(result).toBe('pm2 api.js"},"tool_result":"…');
    expect(result.length).toBe(29);
  });
});

describe("formatTime", () => {
  it("returns dash for null", () => {
    expect(formatTime(null)).toBe("-");
  });

  it("returns original string for invalid date", () => {
    expect(formatTime("not-a-date")).toBe("not-a-date");
  });

  it("formats valid ISO date", () => {
    const result = formatTime("2026-04-10T10:30:00Z");
    // Result depends on locale but should contain date parts
    expect(result).toMatch(/2026/);
    expect(result).toMatch(/04/);
    expect(result).toMatch(/10/);
  });
});

describe("statusIcon", () => {
  it("returns green circle for active", () => {
    expect(statusIcon("active")).toEqual({ icon: "●", color: "green" });
  });

  it("returns gray circle for stopped", () => {
    expect(statusIcon("stopped")).toEqual({ icon: "○", color: "gray" });
  });

  it("returns red X for error", () => {
    expect(statusIcon("error")).toEqual({ icon: "✗", color: "red" });
  });
});

describe("resultColor", () => {
  it("returns green for success", () => {
    expect(resultColor("success")).toBe("green");
  });

  it("returns red for error", () => {
    expect(resultColor("error")).toBe("red");
  });

  it("returns yellow for unknown", () => {
    expect(resultColor("unknown")).toBe("yellow");
  });
});

describe("cronToHuman", () => {
  it("converts always-on to daemon", () => {
    expect(cronToHuman("always-on")).toBe("daemon");
  });

  it("converts every 5 min cron", () => {
    expect(cronToHuman("*/5 * * * *")).toBe("every 5 min");
  });

  it("converts every 1 min cron", () => {
    expect(cronToHuman("*/1 * * * *")).toBe("every min");
  });

  it("converts hourly cron", () => {
    expect(cronToHuman("0 * * * *")).toBe("hourly");
  });

  it("converts every 2 hours cron", () => {
    expect(cronToHuman("0 */2 * * *")).toBe("every 2h");
  });

  it("converts daily cron at 2am", () => {
    expect(cronToHuman("0 2 * * *")).toBe("daily 2am");
  });

  it("converts daily cron at 2:30pm", () => {
    expect(cronToHuman("30 14 * * *")).toBe("daily 2:30pm");
  });

  it("converts weekdays 9am", () => {
    expect(cronToHuman("0 9 * * 1-5")).toBe("weekdays 9am");
  });

  it("passes through unrecognized patterns", () => {
    expect(cronToHuman("0 0 1 * *")).toBe("0 0 1 * *");
  });

  it("passes through non-cron strings", () => {
    expect(cronToHuman("manual")).toBe("manual");
  });
});

describe("formatRelativeTime", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-04-11T02:00:00Z"));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns dash for null", () => {
    expect(formatRelativeTime(null)).toBe("-");
  });

  it("returns original string for invalid date", () => {
    expect(formatRelativeTime("not-a-date")).toBe("not-a-date");
  });

  it("returns just now for recent timestamps", () => {
    expect(formatRelativeTime("2026-04-11T01:59:30Z")).toBe("just now");
  });

  it("returns minutes ago", () => {
    expect(formatRelativeTime("2026-04-11T01:45:00Z")).toBe("15m ago");
  });

  it("returns hours ago", () => {
    expect(formatRelativeTime("2026-04-10T23:00:00Z")).toBe("3h ago");
  });

  it("returns days ago", () => {
    expect(formatRelativeTime("2026-04-09T02:00:00Z")).toBe("2d ago");
  });

  it("returns months ago", () => {
    expect(formatRelativeTime("2026-01-11T02:00:00Z")).toBe("3mo ago");
  });

  it("returns just now for future timestamps", () => {
    expect(formatRelativeTime("2026-04-11T03:00:00Z")).toBe("just now");
  });
});
