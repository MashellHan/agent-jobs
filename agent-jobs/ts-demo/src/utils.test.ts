import { describe, it, expect } from "vitest";
import { formatTime, truncate, statusIcon, resultColor } from "./utils.js";

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
    const badName = 'pm2:api.js"},"tool_result":"started process [api]\\nid: 0"';
    const result = truncate(badName, 29);
    // Truncated to 29 chars: first 28 chars + "…"
    expect(result).toBe('pm2:api.js"},"tool_result":"…');
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
