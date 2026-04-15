import React from "react";
import { describe, it, expect } from "vitest";
import { render } from "ink-testing-library";
import { JobDetail } from "./components/job-detail.js";
import {
  normalJob,
  liveProcessJob,
  errorJob,
  cronJob,
  neverRunJob,
  sessionCronJob,
  durableCronJob,
} from "./fixtures.js";
import type { Job } from "./types.js";

/** Join all lines of a rendered frame into a single string for easier assertion */
function joinFrame(frame: string): string {
  return frame.replace(/\n/g, " ");
}

describe("JobDetail", () => {
  it("renders basic info fields for a normal job", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Command:");
    expect(joined).toContain("node src/server.js --port 3000");
    expect(joined).toContain("Status:");
    expect(joined).toContain("active");
    expect(joined).toContain("Agent:");
    expect(joined).toContain("claude-code");
    expect(joined).toContain("Source:");
    expect(joined).toContain("Hook-registered");
    expect(joined).toContain("Project:");
    expect(joined).toContain("/Users/dev/my-project");
  });

  it("shows Port field when job has a port", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Port:");
    expect(joined).toContain("3000");
  });

  it("hides Port field when job has no port", () => {
    const { lastFrame } = render(<JobDetail job={cronJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("Port:");
  });

  it("shows PID field when job has a pid", () => {
    const { lastFrame } = render(<JobDetail job={liveProcessJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("PID:");
    expect(joined).toContain("12345");
  });

  it("hides PID field when job has no pid", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("PID:");
  });

  it("shows Session field for session cron tasks", () => {
    const { lastFrame } = render(<JobDetail job={sessionCronJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Session:");
    expect(joined).toContain("095d7258");
  });

  it("hides Session field for non-session jobs", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("Session:");
  });

  it("shows session-only lifecycle label", () => {
    const { lastFrame } = render(<JobDetail job={sessionCronJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Lifecycle:");
    expect(joined).toContain("session-only");
    expect(joined).toContain("7d auto-expire");
  });

  it("shows durable lifecycle label", () => {
    const { lastFrame } = render(<JobDetail job={durableCronJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Lifecycle:");
    expect(joined).toContain("durable");
    expect(joined).toContain("persisted");
  });

  it("hides Lifecycle field for non-cron jobs", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("Lifecycle:");
  });

  // ── Schedule section ──

  it("shows schedule section with frequency", () => {
    const { lastFrame } = render(<JobDetail job={cronJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Schedule");
    expect(joined).toContain("Frequency:");
    expect(joined).toContain("daily 2am");
  });

  it("shows always-on for non-scheduled jobs", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("always-on");
  });

  // ── History section ──

  it("shows history section with created time", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("History");
    expect(joined).toContain("Created:");
    expect(joined).toContain("Run Count:");
    expect(joined).toContain("Last Result:");
  });

  it("shows last run time when available", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Last Run:");
    // Should show formatted date, not just "-"
    expect(joined).not.toMatch(/Last Run:\s+-\s/);
  });

  it("shows dash for last run when never run", () => {
    const { lastFrame } = render(<JobDetail job={neverRunJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Last Run:");
  });

  it("shows run count as number for registered jobs", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Run Count:");
    expect(joined).toContain("5");
  });

  it("shows (live process) for negative run count", () => {
    const { lastFrame } = render(<JobDetail job={liveProcessJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("(live process)");
  });

  it("shows earlier runs count for jobs with multiple runs", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    // normalJob has run_count=5 and last_run set
    expect(joined).toContain("4 earlier runs");
  });

  it("uses singular 'run' for exactly 2 runs", () => {
    const twoRunJob: Job = { ...errorJob, run_count: 2 };
    const { lastFrame } = render(<JobDetail job={twoRunJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("1 earlier run");
    expect(joined).not.toContain("runs");
  });

  it("hides earlier runs for run_count <= 1", () => {
    const oneRunJob: Job = { ...normalJob, run_count: 1 };
    const { lastFrame } = render(<JobDetail job={oneRunJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("earlier run");
  });

  it("shows error status with correct color attribute", () => {
    const { lastFrame } = render(<JobDetail job={errorJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("error");
    expect(joined).toContain("Last Result:");
  });

  it("shows escape instruction", () => {
    const { lastFrame } = render(<JobDetail job={normalJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("ESC or d to close");
  });

  it("handles job with no description", () => {
    const noDescJob: Job = { ...normalJob, description: "" };
    const { lastFrame } = render(<JobDetail job={noDescJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Command:");
    expect(joined).toContain("-");
  });

  it("handles job with no project", () => {
    const noProjJob: Job = { ...normalJob, project: "" };
    const { lastFrame } = render(<JobDetail job={noProjJob} />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("Project:");
    expect(joined).toContain("-");
  });
});
