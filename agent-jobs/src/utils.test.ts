import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { formatTime, formatCompactTime, formatRelativeTime, cronToHuman, truncate, statusIcon, resultColor, sanitizeName, sourceToHuman, sourceToShort, friendlyCronName } from "./utils.js";

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
  it("converts always-on to always-on", () => {
    expect(cronToHuman("always-on")).toBe("always-on");
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

describe("sanitizeName", () => {
  it("returns clean names unchanged", () => {
    expect(sanitizeName("my-web-server")).toBe("my-web-server");
  });

  it("strips JSON residue from pm2 output", () => {
    const dirty = 'pm2 api.js"},"tool_result":"started process [api]\\nid: 0"';
    expect(sanitizeName(dirty)).toBe("pm2 api.js");
  });

  it("strips tool_result leak", () => {
    const dirty = 'node server.js","tool_result":"listening on port 3000"';
    expect(sanitizeName(dirty)).toBe("node server.js");
  });

  it("handles names with only garbage — returns first token as fallback", () => {
    const dirty = '"},"tool_result":"something"';
    // After stripping tool_result and JSON chars, falls back to first token
    const result = sanitizeName(dirty);
    expect(result.length).toBeGreaterThan(0);
  });

  it("collapses extra whitespace", () => {
    expect(sanitizeName("node   server.js")).toBe("node server.js");
  });

  it("strips trailing colons and quotes", () => {
    expect(sanitizeName('flask-server":')).toBe("flask-server");
  });

  it("keeps simple space-separated names", () => {
    expect(sanitizeName("pew sync")).toBe("pew sync");
  });

  it("keeps names with ports", () => {
    expect(sanitizeName("server.js :4000")).toBe("server.js :4000");
  });
});

describe("sourceToHuman", () => {
  it("converts registered to Hook-registered", () => {
    expect(sourceToHuman("registered")).toBe("Hook-registered");
  });

  it("converts live to Live process", () => {
    expect(sourceToHuman("live")).toBe("Live process");
  });

  it("converts cron to Cron schedule", () => {
    expect(sourceToHuman("cron")).toBe("Cron schedule");
  });

  it("converts launchd to macOS launchd", () => {
    expect(sourceToHuman("launchd")).toBe("macOS launchd");
  });

  it("passes through unknown sources unchanged", () => {
    expect(sourceToHuman("custom-source")).toBe("custom-source");
  });
});

describe("sourceToShort", () => {
  it("converts registered to hook", () => {
    expect(sourceToShort("registered")).toBe("hook");
  });

  it("converts live to live", () => {
    expect(sourceToShort("live")).toBe("live");
  });

  it("converts cron to cron", () => {
    expect(sourceToShort("cron")).toBe("cron");
  });

  it("converts launchd to launchd", () => {
    expect(sourceToShort("launchd")).toBe("launchd");
  });

  it("passes through unknown sources unchanged", () => {
    expect(sourceToShort("custom")).toBe("custom");
  });

  it("all values fit within 9-char table column", () => {
    for (const source of ["registered", "live", "cron", "launchd"]) {
      expect(sourceToShort(source).length).toBeLessThanOrEqual(9);
    }
  });
});

describe("formatCompactTime", () => {
  it("returns dash for null", () => {
    expect(formatCompactTime(null)).toBe("-");
  });

  it("returns original string for invalid date", () => {
    expect(formatCompactTime("not-a-date")).toBe("not-a-date");
  });

  it("formats valid ISO date as MM-DD HH:MM", () => {
    // Use a date where we know the local time (test runs in system TZ)
    const result = formatCompactTime("2026-04-10T10:30:00Z");
    // Should match MM-DD HH:MM pattern
    expect(result).toMatch(/^\d{2}-\d{2} \d{2}:\d{2}$/);
  });

  it("pads single-digit months and days", () => {
    const result = formatCompactTime("2026-01-05T08:05:00Z");
    expect(result).toMatch(/^\d{2}-\d{2} \d{2}:\d{2}$/);
  });
});

describe("friendlyCronName", () => {
  it("returns 'cron task' for empty prompt", () => {
    expect(friendlyCronName("")).toBe("cron task");
  });

  it("truncates long names to 22 chars", () => {
    const result = friendlyCronName("very-long-command-name-here argument1");
    expect(result.length).toBeLessThanOrEqual(22);
  });

  // ── Chinese patterns ──
  it("extracts project+role from Chinese role prompt", () => {
    expect(friendlyCronName("你是 auto-demo-recorder 项目的 dev agent")).toBe("auto-demo-recorder dev");
  });

  it("extracts project iteration from Chinese prompt", () => {
    expect(friendlyCronName("EyesHealth 项目 30 分钟迭代检查")).toBe("EyesHealth iteration");
  });

  it("extracts Chinese run command", () => {
    expect(friendlyCronName("运行 `pew sync`")).toBe("pew sync");
  });

  it("extracts Chinese check target", () => {
    expect(friendlyCronName("检查 Hermes Agent 深度分析报告")).toBe("Hermes Agent check");
  });

  // ── Named task headers ──
  it("extracts named iteration tasks", () => {
    expect(friendlyCronName("EyeGuard 30-minute iteration check.")).toBe("EyeGuard iteration");
  });

  it("extracts named test/check/review tasks", () => {
    expect(friendlyCronName("Agent Jobs E2E Test Check")).toBe("agent jobs e2e test");
  });

  // ── Role prompts ──
  it("extracts project name from role prompt", () => {
    expect(friendlyCronName("You are a senior code reviewer for the agent-jobs project.")).toBe("agent-jobs code review");
  });

  // ── Periodic/Recurring ──
  it("extracts target from periodic prompt", () => {
    const result = friendlyCronName("Periodic review task for agent-file-preview.");
    expect(result).toContain("agent-file-preview");
    expect(result).toContain("review");
  });

  // ── Run on/for ──
  it("extracts target from Run...on prompt", () => {
    const result = friendlyCronName("Run a review iteration on agent-file-preview:");
    expect(result).toContain("agent-file-preview");
    expect(result).toContain("review");
  });

  // ── Check directory ──
  it("extracts directory check name", () => {
    expect(friendlyCronName("Check the .review/ directory for new documents")).toBe("review check");
  });

  it("handles BOTH directories check", () => {
    expect(friendlyCronName("Check BOTH directories for new review and test documents")).toBe("review+test check");
  });

  // ── Command prompts ──
  it("extracts command from Run...in prompt", () => {
    expect(friendlyCronName("Run `pew sync` in the project terminal")).toBe("pew sync");
  });

  // ── Cancel/cleanup ──
  it("handles cancel prompts", () => {
    const result = friendlyCronName("Cancel the recurring review job");
    expect(result).toContain("cancel");
  });

  // ── Fallback ──
  it("uses fallback word extraction for unknown patterns", () => {
    const result = friendlyCronName("simple task");
    expect(result).toBe("simple task");
  });
});
