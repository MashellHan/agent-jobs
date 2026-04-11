import React from "react";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render } from "ink-testing-library";
import { Box } from "ink";
import { TableHeader, JobRow } from "./components/job-table.js";
import {
  normalJob,
  unfriendlyBgJob,
  jsonResidueJob,
  longNameJob,
  liveProcessJob,
  errorJob,
  pewSyncJob,
  cronJob,
  openclawJob,
  neverRunJob,
  allFixtureJobs,
} from "./fixtures.js";

/**
 * Helper: join all lines into one string and collapse whitespace so that
 * Ink word-wrap in narrow test terminal (80 cols) doesn't break `toContain`.
 */
function joinFrame(frame: string): string {
  return frame.replace(/\n/g, " ").replace(/\s+/g, " ").trim();
}

// Freeze clock so formatRelativeTime produces stable output for snapshot tests.
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-04-10T17:00:00Z"));
});

afterEach(() => {
  vi.useRealTimers();
});

describe("TableHeader", () => {
  it("renders all new column headers", () => {
    const { lastFrame } = render(<TableHeader />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("ST");
    expect(joined).toContain("SERVICE");
    expect(joined).toContain("COMMAND");
    expect(joined).toContain("SCHEDULE");
    expect(joined).toContain("LAST RUN");
    expect(joined).toContain("RESULT");
    expect(joined).toContain("CREATED");
  });

  it("does NOT render old column headers", () => {
    const { lastFrame } = render(<TableHeader />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("JOB NAME");
    expect(joined).not.toContain("AGENT");
    // SOURCE could match part of other text, check exact header
    expect(joined).not.toMatch(/\bAGE\b/);
  });

  it("renders separator line", () => {
    const { lastFrame } = render(<TableHeader />);
    expect(lastFrame()!).toContain("─");
  });
});

describe("JobRow", () => {
  it("renders a normal job with new columns", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("my-web-server");
    expect(joined).toContain("node src/server.js"); // COMMAND column
    expect(joined).toContain("always-on");
    expect(joined).toContain("success");
  });

  it("shows COMMAND column content on the row", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("node src/server.js");
  });

  it("shows LAST RUN time (not creation time as AGE)", () => {
    const { lastFrame } = render(
      <JobRow job={cronJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    // cronJob.last_run = "2026-04-11T02:00:00Z" → future from clock 2026-04-10T17:00 → "just now"
    // cronJob.created_at = "2026-04-09T14:00:00Z" → "1d ago"
    expect(joined).toContain("1d ago"); // CREATED column
  });

  it("shows dash for LAST RUN when job has never run", () => {
    const { lastFrame } = render(
      <JobRow job={neverRunJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("-");
  });

  it("renders active status icon (●)", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    expect(lastFrame()!).toContain("●");
  });

  it("renders error status icon (✗)", () => {
    const { lastFrame } = render(
      <JobRow job={errorJob} selected={false} expanded={false} />
    );
    expect(lastFrame()!).toContain("✗");
  });

  it("renders stopped status icon (○)", () => {
    const { lastFrame } = render(
      <JobRow job={longNameJob} selected={false} expanded={false} />
    );
    expect(lastFrame()!).toContain("○");
  });

  it("shows ▶ indicator when selected (not expanded)", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={true} expanded={false} />
    );
    expect(lastFrame()!).toContain("▶");
  });

  it("shows ▼ indicator when selected and expanded", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={true} expanded={true} />
    );
    expect(lastFrame()!).toContain("▼");
  });

  it("shows space when not selected", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    expect(lastFrame()!).not.toContain("▶");
    expect(lastFrame()!).not.toContain("▼");
  });

  describe("name display issues", () => {
    it("truncates long names with ellipsis in service column", () => {
      const { lastFrame } = render(
        <JobRow job={longNameJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("…");
      // The full untruncated name should NOT appear
      expect(joined).not.toContain(longNameJob.name);
    });

    it("renders friendly nohup name (node server.js)", () => {
      const { lastFrame } = render(
        <JobRow job={unfriendlyBgJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("node server.js");
    });

    it("renders JSON residue name after sanitization (cleaned up)", () => {
      const { lastFrame } = render(
        <JobRow job={jsonResidueJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pm2 api.js");
      expect(joined).not.toContain("tool_result");
    });
  });

  describe("command column display", () => {
    it("shows command for cron job", () => {
      const { lastFrame } = render(
        <JobRow job={cronJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      // Command may be truncated in narrow terminal, just check prefix
      expect(joined).toContain("Run nightly database");
    });

    it("shows command for live process job", () => {
      const { lastFrame } = render(
        <JobRow job={liveProcessJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("node /Users/dev/api");
    });

    it("sanitizes command column for JSON residue job", () => {
      const { lastFrame } = render(
        <JobRow job={jsonResidueJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).not.toContain("tool_result");
      expect(joined).toContain("pm2 start api.js");
    });
  });

  describe("schedule column clarity", () => {
    it("shows always-on for daemon-like services", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("always-on");
      expect(joined).not.toContain("daemon");
    });

    it("shows human-readable cron schedule", () => {
      const { lastFrame } = render(
        <JobRow job={cronJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("daily 2am");
    });

    it("shows every 30 min for openclaw job", () => {
      const { lastFrame } = render(
        <JobRow job={openclawJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("every 30 min");
    });

    it("shows weekdays schedule", () => {
      const { lastFrame } = render(
        <JobRow job={neverRunJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("weekdays 9am");
    });
  });

  describe("real-world service names", () => {
    it("displays 'pew sync' service name clearly", () => {
      const { lastFrame } = render(
        <JobRow job={pewSyncJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pew sync");
      expect(joined).toContain("success");
    });

    it("displays openclaw-monitor service name", () => {
      const { lastFrame } = render(
        <JobRow job={openclawJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("openclaw-monitor");
      expect(joined).toContain("python monitor.py"); // may be truncated, just check prefix
    });

    it("pew sync is visible in the full table", () => {
      const { lastFrame } = render(
        <Box flexDirection="column">
          <TableHeader />
          {allFixtureJobs.map((job) => (
            <JobRow key={job.id} job={job} selected={false} expanded={false} />
          ))}
        </Box>
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pew sync");
    });
  });
});

describe("Column alignment", () => {
  it("all content from each row is present in the rendered output", () => {
    const rows = allFixtureJobs.map((job, i) => {
      const { lastFrame } = render(
        <JobRow job={job} selected={i === 0} expanded={false} />
      );
      return { name: job.name, frame: lastFrame()! };
    });

    for (const { name, frame } of rows) {
      const lines = frame.split("\n").filter((l) => l.trim().length > 0);
      // Rows may wrap in narrow test terminal, but should have at most 2 lines
      expect(lines.length, `Job "${name}" should render on at most 2 lines`).toBeLessThanOrEqual(2);
      expect(lines.length, `Job "${name}" should have at least 1 line`).toBeGreaterThanOrEqual(1);
    }
  });

  it("header and rows have matching SERVICE column start", () => {
    const { lastFrame: headerFrame } = render(<TableHeader />);
    const headerLine = headerFrame()!.split("\n")[0]!;

    const { lastFrame: rowFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const rowLine = rowFrame()!.split("\n")[0]!;

    const nameInHeader = headerLine.indexOf("SERVICE");
    const nameInRow = rowLine.indexOf("my-web-server");

    expect(Math.abs(nameInHeader - nameInRow)).toBe(0);
  });
});

describe("Full table snapshot", () => {
  it("renders a complete table with header and all fixture jobs", () => {
    const { lastFrame } = render(
      <Box flexDirection="column">
        <TableHeader />
        {allFixtureJobs.map((job, i) => (
          <JobRow key={job.id} job={job} selected={i === 0} expanded={false} />
        ))}
      </Box>
    );
    expect(lastFrame()).toMatchSnapshot();
  });

  it("renders a table with expanded detail", async () => {
    const { JobDetail } = await import("./components/job-detail.js");
    const { lastFrame } = render(
      <Box flexDirection="column">
        <TableHeader />
        <Box flexDirection="column">
          <JobRow job={normalJob} selected={true} expanded={true} />
          <JobDetail job={normalJob} />
        </Box>
      </Box>
    );
    expect(lastFrame()).toMatchSnapshot();
  });
});
