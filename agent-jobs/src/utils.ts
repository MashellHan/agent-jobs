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

export function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + "…";
}

/**
 * Extract a human-readable service name from a cron task prompt.
 * E.g. "pew sync --all" → "pew sync", "Run nightly backup of db" → "nightly database backup"
 * Caps at 20 chars.
 */
export function friendlyCronName(prompt: string): string {
  const trimmed = prompt.trim();
  if (!trimmed) return "cron task";

  // Try stripping leading action verbs (natural language prompts)
  const stripped = trimmed.replace(/^(run|execute|do|perform|check)\s+/i, "");
  const wasStripped = stripped !== trimmed;

  // If no verb was stripped, try parsing as a shell command (binary + first arg)
  if (!wasStripped) {
    const cmdMatch = trimmed.match(/^([\w./-]+)\s+([\w./-]+)/);
    if (cmdMatch) {
      const bin = cmdMatch[1]!.split("/").pop()!;
      const arg = cmdMatch[2]!;
      const name = `${bin} ${arg}`;
      return name.length > 20 ? name.slice(0, 19) + "…" : name;
    }
  }

  // Natural language or verb-stripped: take first 3 meaningful words from stripped version
  const words = stripped
    .split(/\s+/)
    .filter((w) => w.length > 1)
    .slice(0, 3)
    .join(" ");

  const result = words || trimmed.slice(0, 20);
  return result.length > 20 ? result.slice(0, 19) + "…" : result;
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
