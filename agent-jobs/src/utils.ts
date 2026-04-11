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
  if (schedule === "always-on") return "daemon";

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

export function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + "…";
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
