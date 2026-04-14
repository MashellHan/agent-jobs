import type { JobStatus, JobResult } from "./types.js";

export function formatTime(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  return d.toLocaleString("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).replace(",", "");
}

/**
 * Compact date-time for table columns: "MM-DD HH:MM" (11 chars).
 * Omits the year to fit narrow columns while still showing an absolute timestamp.
 */
export function formatCompactTime(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  return `${mm}-${dd} ${hh}:${mi}`;
}

export function formatRelativeTime(iso: string | null): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;

  const now = Date.now();
  const diffMs = now - d.getTime();
  if (diffMs < 0) return "just now";

  const seconds = Math.floor(diffMs / 1000);
  if (seconds < 60) return "just now";

  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;

  const months = Math.floor(days / 30);
  return `${months}mo ago`;
}

export function cronToHuman(schedule: string): string {
  if (schedule === "always-on") return "always-on";

  const parts = schedule.trim().split(/\s+/);
  if (parts.length !== 5) return schedule;

  const [min, hour, dom, mon, dow] = parts;

  // every N minutes: */N * * * *
  const everyMin = min!.match(/^\*\/(\d+)$/);
  if (everyMin && hour === "*" && dom === "*" && mon === "*" && dow === "*") {
    const n = parseInt(everyMin[1]!, 10);
    return n === 1 ? "every min" : `every ${n} min`;
  }

  // every hour: 0 * * * * or N * * * *
  if (/^\d+$/.test(min!) && hour === "*" && dom === "*" && mon === "*" && dow === "*") {
    return "hourly";
  }

  // every N hours: 0 */N * * *
  const everyHour = hour!.match(/^\*\/(\d+)$/);
  if (/^\d+$/.test(min!) && everyHour && dom === "*" && mon === "*" && dow === "*") {
    const n = parseInt(everyHour[1]!, 10);
    return n === 1 ? "hourly" : `every ${n}h`;
  }

  // daily at specific time: M H * * *
  if (/^\d+$/.test(min!) && /^\d+$/.test(hour!) && dom === "*" && mon === "*" && dow === "*") {
    const h = parseInt(hour!, 10);
    const m = parseInt(min!, 10);
    const ampm = h >= 12 ? "pm" : "am";
    const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return m === 0 ? `daily ${h12}${ampm}` : `daily ${h12}:${String(m).padStart(2, "0")}${ampm}`;
  }

  // weekdays: M H * * 1-5
  if (/^\d+$/.test(min!) && /^\d+$/.test(hour!) && dom === "*" && mon === "*" && dow === "1-5") {
    const h = parseInt(hour!, 10);
    const ampm = h >= 12 ? "pm" : "am";
    const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return `weekdays ${h12}${ampm}`;
  }

  return schedule;
}

/**
 * Strip JSON residue, tool_result leaks, and other garbage from service names.
 * Returns a clean, human-readable name.
 */
export function sanitizeName(raw: string): string {
  // Remove tool_result leaks first (most specific)
  let name = raw.replace(/,?\s*"?tool_result"?.*$/i, "").trim();

  // Cut at first JSON-like boundary: { } or ","  (but only after valid content)
  name = name.replace(/["{}[\]].*$/, "").trim();

  // Remove trailing special chars
  name = name.replace(/[,;:'"\\]+$/, "").trim();

  // Collapse whitespace
  name = name.replace(/\s+/g, " ");

  return name || raw.split(/\s+/)[0] || raw;
}

/**
 * Convert internal source codes to human-readable labels.
 */
export function sourceToHuman(source: string): string {
  switch (source) {
    case "registered":
      return "Hook-registered";
    case "live":
      return "Live process";
    case "cron":
      return "Cron schedule";
    case "launchd":
      return "macOS launchd";
    default:
      return source;
  }
}

/** Short source label for table columns (max ~9 chars) */
export function sourceToShort(source: string): string {
  switch (source) {
    case "registered":
      return "hook";
    case "live":
      return "live";
    case "cron":
      return "cron";
    case "launchd":
      return "launchd";
    default:
      return source;
  }
}

export function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + "…";
}

/**
 * Extract a concise 2-5 word service name from a cron task prompt.
 *
 * Real-world prompts fall into a few patterns:
 * - Role prompts: "You are a senior code reviewer for the X project..."
 * - Action prompts: "Check the .review/ directory for new..."
 * - Chinese prompts: "你是 auto-demo-recorder 项目的 dev agent..."
 * - Command prompts: "Run `pew sync` in the project terminal..."
 * - Named tasks: "EyeGuard 30-minute iteration check..."
 *
 * The function extracts the core intent, not just the first words.
 */
export function friendlyCronName(prompt: string): string {
  const trimmed = prompt.trim();
  if (!trimmed) return "cron task";

  // Use only the first line for pattern matching — intent is always stated upfront.
  // Multi-line prompts contain implementation details that confuse pattern matching.
  const firstLine = trimmed.split(/\n/)[0]!.trim();

  // ── Pattern 1: Chinese role/project prompts ──
  // "你是 auto-demo-recorder 项目的 dev agent" → "auto-demo-recorder dev"
  // "你是 agent-file-preview 项目的资深 reviewer" → "agent-file-preview review"
  const zhProjectMatch = firstLine.match(/(?:你是|这是)\s+(\S+)\s+项目的?\s*(?:资深\s*)?(\S+)/);
  if (zhProjectMatch) {
    const proj = zhProjectMatch[1]!;
    const role = zhProjectMatch[2]!;
    return cap(`${proj} ${role}`, 22);
  }

  // "EyesHealth 项目 30 分钟迭代检查" → "EyesHealth iteration"
  const zhIterMatch = firstLine.match(/^(\S+)\s*项目.*?(?:迭代|检查|测试|review)/i);
  if (zhIterMatch) {
    const proj = zhIterMatch[1]!;
    return cap(`${proj} iteration`, 22);
  }

  // "30 分钟迭代检查：Claude Session Monitor" → "csm iteration"
  const zhIterMatch2 = firstLine.match(/分钟迭代检查[：:]\s*(.+?)(?:\s*[（(]|$)/);
  if (zhIterMatch2) {
    return cap(`${zhIterMatch2[1]!.trim()} iteration`, 22);
  }

  // "检查 Hermes Agent 深度分析报告" → "hermes report check"
  const zhCheckMatch = firstLine.match(/^检查\s+(.+?)(?:的文档|报告|完成度)/);
  if (zhCheckMatch) {
    const target = zhCheckMatch[1]!.trim().split(/\s+/).slice(0, 2).join(" ");
    return cap(`${target} check`, 22);
  }

  // "运行 `pew sync`" → "pew sync"
  const zhRunMatch = firstLine.match(/^运行\s+[`"']?([^`"'\s]+(?:\s+[^`"'\s]+)?)[`"']?/);
  if (zhRunMatch) {
    return cap(zhRunMatch[1]!, 22);
  }

  // ── Pattern 2: Named task headers ──
  // "EyeGuard 30-minute iteration check." → "EyeGuard iteration"
  const namedMatch = firstLine.match(/^([A-Z][\w-]+)\s+\d+-\w+\s+iteration/i);
  if (namedMatch) {
    return cap(`${namedMatch[1]!} iteration`, 22);
  }

  // "Agent Jobs E2E Test Check" → "agent jobs e2e test"
  const namedMatch2 = firstLine.match(/^([\w-]+(?:\s+[\w-]+)?)\s+((?:E2E|test|check|review|monitor)(?:\s+\w+)?)/i);
  if (namedMatch2 && /^[A-Z]/.test(firstLine) && !/^(?:Periodic|Recurring|Run|Check|Perform|Cancel|Delete|Stop|End|You)\b/i.test(firstLine)) {
    const prefix = namedMatch2[1]!.toLowerCase();
    const action = namedMatch2[2]!.toLowerCase();
    return cap(`${prefix} ${action}`, 22);
  }

  // ── Pattern 3: Role prompts ──
  // "You are a senior code reviewer for the X project" → "X code review"
  // "You are a senior Tech Lead + PM for the auto-demo-recorder project." → "auto-demo-recorder tech lead"
  const roleMatch = firstLine.match(/You are (?:a |the )?(?:senior )?(?:.+?\s+)?(?:for|of) (?:the )?(\S+)/i);
  if (roleMatch) {
    const target = roleMatch[1]!.replace(/[`'"]/g, "");
    const role = /review/i.test(firstLine) ? "code review"
      : /test/i.test(firstLine) ? "test runner"
      : /monitor/i.test(firstLine) ? "monitor"
      : /lead|pm/i.test(firstLine) ? "tech lead"
      : "agent";
    const projName = target.split("/").pop()!.split(".")[0]!;
    return cap(`${projName} ${role}`, 22);
  }

  // "Periodic review task for agent-file-preview." → "agent-file-preview review"
  // "Recurring test for claude-session-monitor" → "claude-session-monitor test"
  const periodicMatch = firstLine.match(/(?:Periodic|Recurring)\s+(\w+)\s+(?:task\s+)?for\s+(\S+)/i);
  if (periodicMatch) {
    const action = periodicMatch[1]!.toLowerCase();
    const target = periodicMatch[2]!.replace(/[`'"]/g, "").split("/").pop()!.replace(/[.:]+$/, "");
    return cap(`${target} ${action}`, 22);
  }

  // "Run a review iteration on agent-file-preview:" → "agent-file-preview review"
  // "Run the tests for my-project" → "my-project tests"
  const runOnMatch = firstLine.match(/Run\s+(?:a\s+|the\s+)?(\w+)\b.*?\b(?:on|for|against)\s+(\S+)/i);
  if (runOnMatch) {
    const action = runOnMatch[1]!.toLowerCase();
    const target = runOnMatch[2]!.replace(/[`'":/.,]+$/g, "").replace(/[`'"]/g, "").split("/").pop()!;
    return cap(`${target} ${action}`, 22);
  }

  // ── Pattern 4: Action prompts with directory/project context ──
  // "Check the .review/ directory for new..." → "review check"
  // "Check BOTH directories for new..." → "review+test check"
  // "Check for new/updated files in BOTH directories" → "review+test check"
  const checkDirMatch = firstLine.match(/Check\s+(?:.*?\s+)?(?:BOTH\s+)?(?:directories|\.(\w+)\/?\s+(?:directory|dir)?)/i);
  if (checkDirMatch) {
    if (/BOTH/i.test(firstLine)) {
      return "review+test check";
    }
    const dir = checkDirMatch[1];
    if (dir) return cap(`${dir} check`, 22);
  }

  // "Check the /path/to/project/.review/" → "project review check"
  // "Check the /path/to/project/.test/\ntest 1." → "project test check"
  const checkPathMatch = firstLine.match(/Check\s+the\s+(\S+)/i);
  if (checkPathMatch) {
    const rawPath = checkPathMatch[1]!.replace(/\/$/, "");
    // Extract .review/.test suffix and project name
    const suffixMatch = rawPath.match(/\/\.(\w+)\/?$/);
    if (suffixMatch) {
      const what = suffixMatch[1]!;
      const projPath = rawPath.replace(/\/\.\w+\/?$/, "");
      const projName = projPath.split("/").pop() || what;
      return cap(`${projName} ${what} check`, 22);
    }
  }

  // "Check for new code review documents in /path/to/project/.review/" → "project review check"
  const checkForMatch = firstLine.match(/Check\s+(?:for\s+)?(?:new\s+)?(?:code\s+)?(\w+)\s+(?:documents?|files?)\s+in\s+(\S+)/i);
  if (checkForMatch) {
    const what = checkForMatch[1]!;
    // Extract project name from path, stripping .review/.test/ suffixes
    const pathParts = checkForMatch[2]!.replace(/\/$/, "").replace(/\/\.\w+\/?$/, "").split("/");
    const path = pathParts.pop() || what;
    return cap(`${path} ${what} check`, 22);
  }

  // "Check if there are uncommitted changes" → "uncommitted check"
  const checkIfMatch = firstLine.match(/Check\s+if\s+(?:there\s+are\s+)?(\w+(?:\s+\w+)?)/i);
  if (checkIfMatch) {
    return cap(`${checkIfMatch[1]!} check`, 22);
  }

  // ── Pattern 5: Command prompts ──
  // "Run `pew sync` in the project..." → "pew sync"
  const runCmdMatch = firstLine.match(/Run\s+[`"']?(\S+(?:\s+\S+)?)[`"']?\s+(?:in|and|on)/i);
  if (runCmdMatch) {
    const cmd = runCmdMatch[1]!.replace(/[`"']/g, "");
    return cap(cmd, 22);
  }

  // "Run the agent-jobs dashboard test suite" → "agent-jobs test suite"
  const runTheMatch = firstLine.match(/Run\s+the\s+(\S+)\s+\S+\s+(\S+(?:\s+\S+)?)/i);
  if (runTheMatch) {
    return cap(`${runTheMatch[1]!} ${runTheMatch[2]!}`, 22);
  }

  // "Perform a code quality and test review" → "quality+test review"
  const performMatch = firstLine.match(/Perform\s+a\s+(.+?)\s+(?:for|on|of)\s+(?:the\s+)?(\S+)/i);
  if (performMatch) {
    const what = performMatch[1]!.replace(/\s+and\s+/g, "+").split(/\s+/).slice(-2).join(" ");
    const target = performMatch[2]!.split("/").pop()!;
    return cap(`${target} ${what}`, 22);
  }

  // ── Pattern 6: Cancel/cleanup tasks ──
  // "Cancel the recurring review job" → "cancel review job"
  const cancelMatch = firstLine.match(/^(Cancel|Delete|Stop|End)\s+the\s+(\w+(?:\s+\w+)?)/i);
  if (cancelMatch) {
    return cap(`${cancelMatch[1]!.toLowerCase()} ${cancelMatch[2]!}`, 22);
  }

  // "24-hour periodic review cycle has ended" → "review cycle end"
  const endedMatch = firstLine.match(/(\w+)\s+(?:review\s+)?cycle\s+has\s+ended/i);
  if (endedMatch) {
    return "review cycle cleanup";
  }

  // ── Fallback: improved word extraction ──
  // Strip markdown headers, role prefixes
  let clean = firstLine
    .replace(/^#+\s+/, "")                    // markdown headers
    .replace(/^(?:You are|I am|This is)\s+/i, "")
    .replace(/^(?:a|an|the)\s+/i, "")
    .replace(/^(?:senior|lead|chief)\s+/i, "");

  // Try to find a project name in backticks or after "for"
  const backtickProject = clean.match(/[`"](\S+)[`"]/);
  const forProject = clean.match(/for\s+(?:the\s+)?[`"]?(\S+)[`"]?/i);
  const project = backtickProject?.[1] ?? forProject?.[1] ?? "";

  // Extract action words
  const actionWords = clean
    .replace(/[`"']/g, "")
    .split(/[\s,.;:]+/)
    .filter((w) => w.length > 2 && !/^(the|for|and|you|are|this|that|with|from|into|have|been|will|your|each|also|just)$/i.test(w))
    .slice(0, 3);

  if (project && actionWords.length > 0) {
    const projShort = project.split("/").pop()!.split(".")[0]!;
    const action = actionWords.find((w) => !projShort.includes(w)) ?? actionWords[0]!;
    return cap(`${projShort} ${action}`, 22);
  }

  const result = actionWords.join(" ") || firstLine.slice(0, 20);
  return cap(result, 22);
}

/** Cap a string at max length with ellipsis */
function cap(s: string, max: number): string {
  const trimmed = s.trim();
  if (trimmed.length <= max) return trimmed;
  return trimmed.slice(0, max - 1) + "…";
}

export function statusIcon(status: JobStatus): { icon: string; color: string } {
  switch (status) {
    case "active":
      return { icon: "●", color: "green" };
    case "stopped":
      return { icon: "○", color: "gray" };
    case "error":
      return { icon: "✗", color: "red" };
    default:
      return { icon: "?", color: "white" };
  }
}

export function resultColor(result: JobResult): string {
  return result === "success" ? "green" : result === "error" ? "red" : "yellow";
}
