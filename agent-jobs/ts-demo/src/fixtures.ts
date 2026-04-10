import type { Job } from "./types.js";

/**
 * Test fixtures that reproduce real-world visual issues.
 */

/** Normal well-formed job */
export const normalJob: Job = {
  id: "hook-1001",
  name: "my-web-server",
  description: "node src/server.js --port 3000",
  agent: "claude-code",
  schedule: "always-on",
  status: "active",
  source: "registered",
  project: "/Users/dev/my-project",
  port: 3000,
  created_at: "2026-04-10T10:00:00Z",
  last_run: "2026-04-10T10:00:00Z",
  next_run: null,
  last_result: "success",
  run_count: 5,
};

/** Unfriendly name from nohup pattern: now uses "node server.js" instead of "bg:node" */
export const unfriendlyBgJob: Job = {
  id: "hook-1002",
  name: "node server.js",
  description: "nohup node server.js &",
  agent: "claude-code",
  schedule: "always-on",
  status: "active",
  source: "registered",
  project: "/Users/dev/api",
  port: 8080,
  created_at: "2026-04-10T11:00:00Z",
  last_run: "2026-04-10T11:00:00Z",
  next_run: null,
  last_result: "success",
  run_count: 1,
};

/** JSON residue leaking into name — the detect hook stored raw JSON data */
export const jsonResidueJob: Job = {
  id: "hook-1003",
  name: 'pm2 api.js"},"tool_result":"started process [api]\\nid: 0"',
  description: 'pm2 start api.js --name api"},"tool_result":"started process [api]\\nid: 0"',
  agent: "claude-code",
  schedule: "always-on",
  status: "active",
  source: "registered",
  project: "/Users/dev/backend",
  created_at: "2026-04-10T12:00:00Z",
  last_run: "2026-04-10T12:00:00Z",
  next_run: null,
  last_result: "success",
  run_count: 3,
};

/** Very long name that tests truncation — now without docker: prefix */
export const longNameJob: Job = {
  id: "hook-1004",
  name: "my-very-long-container-image-name-that-exceeds-column-width",
  description: "docker run -d my-very-long-container-image-name-that-exceeds-column-width",
  agent: "claude-code",
  schedule: "always-on",
  status: "stopped",
  source: "registered",
  project: "/Users/dev/infra",
  created_at: "2026-04-10T13:00:00Z",
  last_run: "2026-04-10T13:00:00Z",
  next_run: null,
  last_result: "error",
  run_count: 0,
};

/** Live process detected by scanner — now shows "server.js :4000" instead of "node:server.js" */
export const liveProcessJob: Job = {
  id: "live-5678",
  name: "server.js :4000",
  description: "node /Users/dev/api/server.js",
  agent: "manual",
  schedule: "always-on",
  status: "active",
  source: "live",
  project: "/Users/dev/api",
  port: 4000,
  pid: 12345,
  created_at: "2026-04-10T09:00:00Z",
  last_run: "2026-04-10T14:00:00Z",
  next_run: null,
  last_result: "success",
  run_count: -1,
};

/** Job in error state */
export const errorJob: Job = {
  id: "hook-1005",
  name: "flask-server",
  description: "flask run --port 5000",
  agent: "claude-code",
  schedule: "always-on",
  status: "error",
  source: "registered",
  project: "/Users/dev/python-api",
  port: 5000,
  created_at: "2026-04-10T08:00:00Z",
  last_run: "2026-04-10T08:30:00Z",
  next_run: null,
  last_result: "error",
  run_count: 2,
};

/** Real-world named service — user should see exactly "pew sync" in the table */
export const pewSyncJob: Job = {
  id: "hook-2001",
  name: "pew sync",
  description: "node pew-sync.js --interval 60",
  agent: "claude-code",
  schedule: "always-on",
  status: "active",
  source: "registered",
  project: "/Users/dev/pew-project",
  port: undefined,
  created_at: "2026-04-11T00:00:00Z",
  last_run: "2026-04-11T01:00:00Z",
  next_run: null,
  last_result: "success",
  run_count: 10,
};

/** Cron-scheduled job — tests cronToHuman display */
export const cronJob: Job = {
  id: "cron-0",
  name: "backup script",
  description: "Run nightly database backup",
  agent: "claude-code",
  schedule: "0 2 * * *",
  status: "active",
  source: "cron",
  project: "/Users/dev/ops",
  created_at: "2026-04-09T14:00:00Z",
  last_run: "2026-04-11T02:00:00Z",
  next_run: "2026-04-12T02:00:00Z",
  last_result: "success",
  run_count: 3,
};

/** A representative set of all jobs for full table rendering */
export const allFixtureJobs: Job[] = [
  normalJob,
  unfriendlyBgJob,
  jsonResidueJob,
  longNameJob,
  liveProcessJob,
  errorJob,
  pewSyncJob,
  cronJob,
];
