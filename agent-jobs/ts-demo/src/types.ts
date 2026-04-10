export type JobStatus = "active" | "stopped" | "error";
export type JobResult = "success" | "error" | "unknown";
export type JobSource = "registered" | "live" | "cron" | "launchd";

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
}

export interface JobsFile {
  version: string;
  jobs: Array<Omit<Job, "source">>;
}

export type TabFilter = "all" | "registered" | "live" | "active" | "error";

export const TAB_FILTERS: TabFilter[] = [
  "all",
  "registered",
  "live",
  "active",
  "error",
];
