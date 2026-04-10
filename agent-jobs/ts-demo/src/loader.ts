import { readFile, watch } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { Job, JobsFile } from "./types.js";
import { scanLiveProcesses, scanClaudeScheduledTasks } from "./scanner.js";

const JOBS_PATH = join(homedir(), ".agent-jobs", "jobs.json");
const CLAUDE_TASKS_PATH = join(homedir(), ".claude", "scheduled_tasks.json");

export function loadAllJobs(): Promise<Job[]> {
  return new Promise((resolve) => {
    loadRegisteredJobs().then((registered) => {
      const live = scanLiveProcesses();
      const cron = scanClaudeScheduledTasks();
      resolve([...registered, ...cron, ...live]);
    });
  });
}

function loadRegisteredJobs(): Promise<Job[]> {
  return new Promise((resolve) => {
    readFile(JOBS_PATH, "utf-8", (err, data) => {
      if (err) {
        resolve([]);
        return;
      }
      try {
        const parsed: JobsFile = JSON.parse(data);
        const jobs: Job[] = (parsed.jobs ?? []).map((j) => ({
          ...j,
          source: "registered" as const,
          last_result: j.last_result ?? "unknown",
        }));
        resolve(jobs);
      } catch {
        resolve([]);
      }
    });
  });
}

function createWatcher(path: string, onChange: () => void): () => void {
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;

  try {
    const watcher = watch(path, () => {
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(onChange, 300);
    });

    return () => {
      watcher.close();
      if (debounceTimer) clearTimeout(debounceTimer);
    };
  } catch {
    return () => {};
  }
}

export function watchJobsFile(onChange: () => void): () => void {
  const cleanupJobs = createWatcher(JOBS_PATH, onChange);
  const cleanupClaude = createWatcher(CLAUDE_TASKS_PATH, onChange);

  return () => {
    cleanupJobs();
    cleanupClaude();
  };
}
