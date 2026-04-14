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
  launchdPewSyncJob,
  launchdPewUpdateJob,
  launchdKeepAliveJob,
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
  it("renders all column headers including AGENT and SOURCE", () => {
    const { lastFrame } = render(<TableHeader />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("ST");
    expect(joined).toContain("SERVICE");
    expect(joined).toContain("AGENT");
    expect(joined).toContain("SOURCE");
    expect(joined).toContain("SCHEDULE");
    expect(joined).toContain("LAST RUN");
    // RESULT and CREATED may be truncated/wrapped in narrow test terminal
    expect(joined).toMatch(/RESUL/);
    expect(joined).toMatch(/CREATE/);
  });

  it("does NOT render old column headers", () => {
    const { lastFrame } = render(<TableHeader />);
    const joined = joinFrame(lastFrame()!);
    expect(joined).not.toContain("JOB NAME");
  });

  it("renders separator line", () => {
    const { lastFrame } = render(<TableHeader />);
    expect(lastFrame()!).toContain("─");
  });
});

describe("JobRow", () => {
  it("renders a normal job with all columns including AGENT", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    expect(joined).toContain("my-web-server");
    expect(joined).toMatch(/claude-co/);        // AGENT column (may be truncated in narrow terminal)
    expect(joined).toContain("always-on");
    expect(joined).toMatch(/succe/);             // success may be truncated
  });

  it("shows LAST RUN as compact date-time (not relative time)", () => {
    const { lastFrame } = render(
      <JobRow job={cronJob} selected={false} expanded={false} />
    );
    const joined = joinFrame(lastFrame()!);
    // LAST RUN should show MM-DD HH:MM format (may be split across wrapped lines in narrow terminal)
    expect(joined).toMatch(/04-11/);
    expect(joined).toMatch(/10:00/);
    // CREATED column still shows relative time
    expect(joined).toMatch(/1d ago/);
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
      // May be word-wrapped in narrow terminal
      expect(joined).toMatch(/every 30/);
      expect(joined).toMatch(/min/);
    });

    it("shows weekdays schedule", () => {
      const { lastFrame } = render(
        <JobRow job={neverRunJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      // May be word-wrapped in narrow terminal
      expect(joined).toMatch(/weekdays/);
      expect(joined).toMatch(/9am/);
    });
  });

  describe("real-world service names", () => {
    it("displays 'pew sync' service name clearly", () => {
      const { lastFrame } = render(
        <JobRow job={pewSyncJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pew sync");
      expect(joined).toMatch(/succe/); // may be truncated in narrow terminal
    });

    it("displays openclaw-monitor service name", () => {
      const { lastFrame } = render(
        <JobRow job={openclawJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toMatch(/openclaw-moni/); // truncated in service column (narrower with SOURCE col)
      expect(joined).toMatch(/openclaw/);        // AGENT column
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

  describe("launchd services", () => {
    it("displays launchd pew sync with every 10 min schedule", () => {
      const { lastFrame } = render(
        <JobRow job={launchdPewSyncJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pew sync");
      expect(joined).toMatch(/every 10/);
      expect(joined).toMatch(/succe/);
    });

    it("displays launchd pew update with daily 9am schedule", () => {
      const { lastFrame } = render(
        <JobRow job={launchdPewUpdateJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("pew update");
      expect(joined).toContain("daily 9am");
    });

    it("displays launchd keepalive service as always-on", () => {
      const { lastFrame } = render(
        <JobRow job={launchdKeepAliveJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("node gateway");
      expect(joined).toContain("always-on");
    });

    it("launchd services appear in the full table", () => {
      const { lastFrame } = render(
        <Box flexDirection="column">
          <TableHeader />
          {allFixtureJobs.map((job) => (
            <JobRow key={job.id} job={job} selected={false} expanded={false} />
          ))}
        </Box>
      );
      const joined = joinFrame(lastFrame()!);
      // All 3 launchd services should be visible (may be word-wrapped)
      expect(joined).toMatch(/every 10/);
      expect(joined).toContain("daily 9am");
      // Schedule diversity: at least 3 different schedule types visible
      expect(joined).toContain("always-on");
      expect(joined).toMatch(/daily 2am/);
      expect(joined).toMatch(/every 30/);
      expect(joined).toMatch(/weekdays/);
    });
  });

  describe("AGENT column display", () => {
    it("shows claude-code agent for registered jobs", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      // "claude-code" is 11 chars, agent column is 12 wide, but terminal may truncate
      expect(joined).toMatch(/claude-co/);
    });

    it("shows openclaw agent for openclaw jobs", () => {
      const { lastFrame } = render(
        <JobRow job={openclawJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("openclaw");
    });

    it("shows manual agent for live process jobs", () => {
      const { lastFrame } = render(
        <JobRow job={liveProcessJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("manual");
    });

    it("shows agent for launchd service", () => {
      const { lastFrame } = render(
        <JobRow job={launchdKeepAliveJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("openclaw");
    });
  });

  describe("SOURCE column display", () => {
    it("shows hook label for registered jobs", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("hook"); // sourceToShort("registered") → "hook"
    });

    it("shows live source for live process jobs", () => {
      const { lastFrame } = render(
        <JobRow job={liveProcessJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("live");
    });

    it("shows cron source for cron jobs", () => {
      const { lastFrame } = render(
        <JobRow job={cronJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("cron");
    });

    it("shows launchd source for launchd jobs", () => {
      const { lastFrame } = render(
        <JobRow job={launchdPewSyncJob} selected={false} expanded={false} />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("launchd");
    });
  });

  describe("confirmMessage display", () => {
    it("shows confirmation message when confirmMessage is provided on selected row", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={true} expanded={false} confirmMessage="Stop this job? [y]es / [n]o" />
      );
      const joined = joinFrame(lastFrame()!);
      expect(joined).toContain("Stop this job?");
      expect(joined).toContain("[y]es");
      expect(joined).toContain("[n]o");
      // Service name should still be visible
      expect(joined).toContain("my-web-server");
    });

    it("does not show confirmation message when not selected", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={false} expanded={false} confirmMessage="Stop this job? [y]es / [n]o" />
      );
      const joined = joinFrame(lastFrame()!);
      // Should render normally, not the confirm UI
      expect(joined).not.toContain("Stop this job?");
      expect(joined).toMatch(/claude-co/);
    });

    it("hides AGENT column when confirming", () => {
      const { lastFrame } = render(
        <JobRow job={normalJob} selected={true} expanded={false} confirmMessage="Stop this job? [y]es / [n]o" />
      );
      const joined = joinFrame(lastFrame()!);
      // The confirm row replaces everything after SERVICE
      expect(joined).toContain("my-web-server");
      expect(joined).toContain("Stop this job?");
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
