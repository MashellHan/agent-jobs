import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from "fs";
import { execFile } from "child_process";
import { join } from "path";
import { homedir } from "os";
import type { JobsFile, HiddenFile, JobStatus } from "./types.js";

const JOBS_DIR = join(homedir(), ".agent-jobs");
const JOBS_PATH = join(JOBS_DIR, "jobs.json");
const HIDDEN_PATH = join(JOBS_DIR, "hidden.json");

function ensureDir(): void {
  if (!existsSync(JOBS_DIR)) {
    mkdirSync(JOBS_DIR, { recursive: true });
  }
}

function atomicWrite(path: string, data: string): void {
  ensureDir();
  const tmpPath = join(JOBS_DIR, `.tmp.${process.pid}.${Date.now()}`);
  writeFileSync(tmpPath, data);
  renameSync(tmpPath, path);
}

// ── Hidden IDs ──────────────────────────────────────────────────

export function loadHiddenIds(): Set<string> {
  try {
    if (!existsSync(HIDDEN_PATH)) return new Set();
    const raw: HiddenFile = JSON.parse(readFileSync(HIDDEN_PATH, "utf-8"));
    return new Set(Array.isArray(raw.hidden) ? raw.hidden : []);
  } catch {
    return new Set();
  }
}

export function addHiddenId(id: string): void {
  const ids = loadHiddenIds();
  ids.add(id);
  atomicWrite(HIDDEN_PATH, JSON.stringify({ hidden: [...ids] }, null, 2) + "\n");
}

// ── Registered Jobs mutations ───────────────────────────────────

function loadJobsFile(): JobsFile {
  try {
    if (!existsSync(JOBS_PATH)) return { version: "1.0", jobs: [] };
    return JSON.parse(readFileSync(JOBS_PATH, "utf-8")) as JobsFile;
  } catch {
    return { version: "1.0", jobs: [] };
  }
}

function saveJobsFile(file: JobsFile): void {
  atomicWrite(JOBS_PATH, JSON.stringify(file, null, 2) + "\n");
}

export function removeRegisteredJob(id: string): void {
  const file = loadJobsFile();
  file.jobs = file.jobs.filter((j) => j.id !== id);
  saveJobsFile(file);
}

export function setRegisteredJobStatus(id: string, status: JobStatus): void {
  const file = loadJobsFile();
  const found = file.jobs.some((j) => j.id === id);
  if (found) {
    file.jobs = file.jobs.map((j) => (j.id === id ? { ...j, status } : j));
    saveJobsFile(file);
  }
}

// ── Process actions ─────────────────────────────────────────────

export function killProcess(pid: number): boolean {
  try {
    process.kill(pid, "SIGTERM");
    return true;
  } catch {
    return false;
  }
}

export function stopLaunchdService(label: string): Promise<boolean> {
  return new Promise((resolve) => {
    execFile("launchctl", ["stop", label], { timeout: 5000 }, (err) => {
      resolve(!err);
    });
  });
}
