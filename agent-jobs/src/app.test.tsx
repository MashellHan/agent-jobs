import React from "react";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render } from "ink-testing-library";
import App from "./app.js";
import type { Job } from "./types.js";

// Mock loader module
vi.mock("./loader.js", () => ({
  loadAllJobs: vi.fn(),
  watchJobsFile: vi.fn(() => () => {}),
}));

// Mock store module
vi.mock("./store.js", () => ({
  loadHiddenIds: vi.fn(() => new Set()),
  addHiddenId: vi.fn(),
  removeRegisteredJob: vi.fn(),
  setRegisteredJobStatus: vi.fn(),
  killProcess: vi.fn(() => true),
  stopLaunchdService: vi.fn(() => Promise.resolve(true)),
}));

import { loadAllJobs, watchJobsFile } from "./loader.js";
import { loadHiddenIds, addHiddenId, removeRegisteredJob, setRegisteredJobStatus, killProcess } from "./store.js";

const mockLoadAllJobs = vi.mocked(loadAllJobs);
const mockWatchJobsFile = vi.mocked(watchJobsFile);
const mockLoadHiddenIds = vi.mocked(loadHiddenIds);
const mockAddHiddenId = vi.mocked(addHiddenId);
const mockRemoveRegisteredJob = vi.mocked(removeRegisteredJob);
const mockSetRegisteredJobStatus = vi.mocked(setRegisteredJobStatus);
const mockKillProcess = vi.mocked(killProcess);

function makeJob(overrides: Partial<Job> = {}): Job {
  return {
    id: "test-1",
    name: "test-server",
    description: "node test.js",
    agent: "claude-code",
    schedule: "always-on",
    status: "active",
    source: "registered",
    project: "/project",
    created_at: "2026-01-01T00:00:00Z",
    last_run: "2026-01-01T12:00:00Z",
    next_run: null,
    last_result: "success",
    run_count: 5,
    ...overrides,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers();
  mockWatchJobsFile.mockReturnValue(() => {});
});

describe("App", () => {
  it("renders loading state initially", () => {
    // loadAllJobs never resolves — stays in loading
    mockLoadAllJobs.mockReturnValue(new Promise(() => {}));

    const { lastFrame } = render(<App />);
    expect(lastFrame()).toContain("Loading jobs...");
  });

  it("renders error state when loadAllJobs rejects", async () => {
    mockLoadAllJobs.mockRejectedValue(new Error("Connection failed"));

    const { lastFrame } = render(<App />);

    // Flush the rejected promise
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("Error");
    expect(frame).toContain("Connection failed");
  });

  it("renders empty state with setup instructions when no jobs", async () => {
    mockLoadAllJobs.mockResolvedValue([]);

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("No jobs");
    expect(frame).toContain("agent-jobs setup");
  });

  it("renders job list after loading", async () => {
    const jobs = [
      makeJob({ id: "j1", name: "api-server" }),
      makeJob({ id: "j2", name: "worker", status: "stopped" }),
    ];
    mockLoadAllJobs.mockResolvedValue(jobs);

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("api-server");
    expect(frame).toContain("worker");
    expect(frame).toContain("Agent Job Dashboard");
  });

  it("renders dashboard header with job counts", async () => {
    const jobs = [
      makeJob({ id: "j1", status: "active" }),
      makeJob({ id: "j2", status: "error", last_result: "error" }),
    ];
    mockLoadAllJobs.mockResolvedValue(jobs);

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("2 jobs");
    expect(frame).toContain("1 active");
  });

  it("renders tab bar", async () => {
    mockLoadAllJobs.mockResolvedValue([makeJob()]);

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("All");
    expect(frame).toContain("Registered");
    expect(frame).toContain("Live");
  });

  it("renders footer with keyboard shortcuts", async () => {
    mockLoadAllJobs.mockResolvedValue([]);

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("Quit");
    expect(frame).toContain("Refresh");
    expect(frame).toContain("Navigate");
  });

  it("watches jobs file for changes", async () => {
    mockLoadAllJobs.mockResolvedValue([]);

    render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    expect(mockWatchJobsFile).toHaveBeenCalledWith(expect.any(Function));
  });
});

describe("App keyboard interactions", () => {
  const threeJobs = [
    makeJob({ id: "j1", name: "api-server", source: "registered" }),
    makeJob({ id: "j2", name: "worker", source: "registered", status: "stopped" }),
    makeJob({ id: "j3", name: "live-proc", source: "live" }),
  ];

  beforeEach(() => {
    mockLoadAllJobs.mockResolvedValue(threeJobs);
  });

  it("navigates down with arrow key — cursor moves to next job", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // First job should be selected (▶ indicator)
    expect(lastFrame()).toContain("▶");
    expect(lastFrame()).toContain("api-server");

    // Press down arrow
    stdin.write("\u001B[B");
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("worker");
  });

  it("navigates up with arrow key — cursor moves to previous job", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Move down first
    stdin.write("\u001B[B");
    await vi.advanceTimersByTimeAsync(0);

    // Then move back up
    stdin.write("\u001B[A");
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("api-server");
  });

  it("expands detail with 'd' key", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Press 'd' to expand detail for first job
    stdin.write("d");
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    // Detail panel should show expanded indicator ▼
    expect(frame).toContain("▼");
  });

  it("collapses detail when pressing 'd' again on same job", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Expand
    stdin.write("d");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).toContain("▼");

    // Collapse
    stdin.write("d");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).not.toContain("▼");
  });

  it("collapses detail when pressing escape", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Expand
    stdin.write("d");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).toContain("▼");

    // Escape to collapse
    stdin.write("\u001B");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).not.toContain("▼");
  });

  it("refreshes data when pressing 'r'", async () => {
    const { stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // loadAllJobs called once on mount
    expect(mockLoadAllJobs).toHaveBeenCalledTimes(1);

    // Press 'r' to refresh
    stdin.write("r");
    await vi.advanceTimersByTimeAsync(0);

    expect(mockLoadAllJobs).toHaveBeenCalledTimes(2);
  });

  it("switches tabs with right arrow key", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Start on "All" tab — all 3 jobs visible
    expect(lastFrame()).toContain("api-server");
    expect(lastFrame()).toContain("live-proc");

    // Press right arrow to switch to "Registered" tab
    stdin.write("\u001B[C");
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    // Registered tab should be active — only registered jobs shown
    expect(frame).toContain("api-server");
    expect(frame).toContain("worker");
  });

  it("switches tabs with left arrow key back to previous tab", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Move right then left should return to "All"
    stdin.write("\u001B[C"); // right to "Registered"
    await vi.advanceTimersByTimeAsync(0);
    stdin.write("\u001B[D"); // left back to "All"
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("api-server");
    expect(frame).toContain("live-proc");
  });

  it("auto-refreshes on interval", async () => {
    render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    expect(mockLoadAllJobs).toHaveBeenCalledTimes(1);

    // Advance by 10 seconds (auto-refresh interval)
    await vi.advanceTimersByTimeAsync(10_000);

    expect(mockLoadAllJobs).toHaveBeenCalledTimes(2);
  });
});

describe("App hide/stop features", () => {
  const threeJobs = [
    makeJob({ id: "j1", name: "api-server", source: "registered" }),
    makeJob({ id: "j2", name: "worker", source: "registered", status: "stopped" }),
    makeJob({ id: "j3", name: "live-proc", source: "live", pid: 12345 }),
  ];

  beforeEach(() => {
    mockLoadAllJobs.mockResolvedValue(threeJobs);
    mockLoadHiddenIds.mockReturnValue(new Set());
  });

  it("renders footer with Hide and Stop shortcuts", async () => {
    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("Hide");
    expect(frame).toContain("Stop");
  });

  it("hides a registered job when pressing 'x'", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // First job is selected — press 'x' to hide it
    stdin.write("x");
    await vi.advanceTimersByTimeAsync(0);

    expect(mockAddHiddenId).toHaveBeenCalledWith("j1");
    expect(mockRemoveRegisteredJob).toHaveBeenCalledWith("j1");
  });

  it("hides a live job without removing from registered store", async () => {
    const { stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Move to 3rd row (live-proc)
    stdin.write("\u001B[B"); // down
    await vi.advanceTimersByTimeAsync(0);
    stdin.write("\u001B[B"); // down
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("x");
    await vi.advanceTimersByTimeAsync(0);

    expect(mockAddHiddenId).toHaveBeenCalledWith("j3");
    expect(mockRemoveRegisteredJob).not.toHaveBeenCalled();
  });

  it("shows status message after hiding", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("x");
    await vi.advanceTimersByTimeAsync(0);

    expect(lastFrame()).toContain("Hidden api-server");
  });

  it("shows confirmation prompt when pressing 's'", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).toContain("Stop this job?");
    expect(frame).toContain("[y]es");
    expect(frame).toContain("[n]o");
  });

  it("cancels stop action when pressing 'n'", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).toContain("Stop this job?");

    stdin.write("n");
    await vi.advanceTimersByTimeAsync(0);

    // Confirmation should be gone
    expect(lastFrame()).not.toContain("Stop this job?");
  });

  it("cancels stop action when pressing Escape", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).toContain("Stop this job?");

    stdin.write("\u001B");
    await vi.advanceTimersByTimeAsync(0);

    expect(lastFrame()).not.toContain("Stop this job?");
  });

  it("stops a registered job when confirming with 'y'", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("y");
    await vi.advanceTimersByTimeAsync(0);

    expect(mockSetRegisteredJobStatus).toHaveBeenCalledWith("j1", "stopped");
    expect(lastFrame()).toContain("Stopped api-server");
  });

  it("kills a live process when confirming stop with 'y'", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    // Move to live-proc (3rd row)
    stdin.write("\u001B[B"); // down
    await vi.advanceTimersByTimeAsync(0);
    stdin.write("\u001B[B"); // down
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("y");
    await vi.advanceTimersByTimeAsync(0);

    expect(mockKillProcess).toHaveBeenCalledWith(12345);
    expect(lastFrame()).toContain("Killed PID 12345");
  });

  it("blocks other keys during confirmation mode", async () => {
    const { lastFrame, stdin } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    stdin.write("s");
    await vi.advanceTimersByTimeAsync(0);
    expect(lastFrame()).toContain("Stop this job?");

    // Try pressing 'r' (refresh) — should be blocked
    const callsBefore = mockLoadAllJobs.mock.calls.length;
    stdin.write("r");
    await vi.advanceTimersByTimeAsync(0);
    expect(mockLoadAllJobs).toHaveBeenCalledTimes(callsBefore);

    // Confirmation should still be showing
    expect(lastFrame()).toContain("Stop this job?");
  });

  it("filters out hidden jobs from display", async () => {
    mockLoadHiddenIds.mockReturnValue(new Set(["j1"]));

    const { lastFrame } = render(<App />);
    await vi.advanceTimersByTimeAsync(0);

    const frame = lastFrame();
    expect(frame).not.toContain("api-server");
    expect(frame).toContain("worker");
    expect(frame).toContain("live-proc");
  });
});
