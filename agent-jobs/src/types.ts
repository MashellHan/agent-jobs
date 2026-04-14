export type JobStatus = "active" | "stopped" | "error";
export type JobResult = "success" | "error" | "unknown";
export type JobSource = "registered" | "live" | "cron" | "launchd";
export type CronLifecycle = "session-only" | "durable";

/** Max characters for job description field */
export const MAX_DESCRIPTION_LENGTH = 200;

export interface Job {
  id: string;
  name: string;
  description: string;
  agent: string;
  schedule: string;
  status: JobStatus;
  source: JobSource;
  project: string;
  port?: number;
  pid?: number;
  created_at: string;
  last_run: string | null;
  next_run: string | null;
  last_result: JobResult;
  run_count: number;
  /** Claude Code session ID (first 8 chars), only for cron source */
  sessionId?: string;
  /** Cron task lifecycle: session-only (7d auto-expire) or durable */
  lifecycle?: CronLifecycle;
}

export interface JobsFile {
  version: string;
  jobs: Array<Omit<Job, "source">>;
}

export interface HiddenFile {
  hidden: string[];
}

export interface ConfirmAction {
  type: "stop";
  index: number;
}

export type TabFilter = "all" | "registered" | "live" | "active" | "error";

export const TAB_FILTERS: TabFilter[] = [
  "all",
  "registered",
  "live",
  "active",
  "error",
];
