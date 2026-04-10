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
