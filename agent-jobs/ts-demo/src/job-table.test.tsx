import React from "react";
import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { render } from "ink-testing-library";
import { Box } from "ink";
import { TableHeader, JobRow } from "./components/job-table.js";

// Patch ink-testing-library's mock stdout to use 140 columns (row needs ~126).
// The mock Stdout class hardcodes columns=100 on its prototype.
let origColumnsDescriptor: PropertyDescriptor | undefined;
beforeAll(() => {
  const inst = render(React.createElement(Box, null));
  const proto = Object.getPrototypeOf(inst.stdout);
  origColumnsDescriptor = Object.getOwnPropertyDescriptor(proto, "columns");
  Object.defineProperty(proto, "columns", { get: () => 140, configurable: true });
  inst.cleanup();
});
afterAll(() => {
  if (origColumnsDescriptor) {
    const inst = render(React.createElement(Box, null));
    const proto = Object.getPrototypeOf(inst.stdout);
    Object.defineProperty(proto, "columns", origColumnsDescriptor);
    inst.cleanup();
  }
});

import {
  normalJob,
  unfriendlyBgJob,
  jsonResidueJob,
  longNameJob,
  liveProcessJob,
  errorJob,
  pewSyncJob,
  allFixtureJobs,
} from "./fixtures.js";

describe("TableHeader", () => {
  it("renders all column headers", () => {
    const { lastFrame } = render(<TableHeader />);
    const frame = lastFrame()!;
    expect(frame).toContain("ST");
    expect(frame).toContain("JOB NAME");
    expect(frame).toContain("AGENT");
    expect(frame).toContain("SCHEDULE");
    expect(frame).toContain("SOURCE");
    expect(frame).toContain("LAST RUN");
    expect(frame).toContain("RESULT");
  });

  it("renders separator line", () => {
    const { lastFrame } = render(<TableHeader />);
    const frame = lastFrame()!;
    expect(frame).toContain("─");
  });
});

describe("JobRow", () => {
  it("renders a normal job with correct columns", () => {
    const { lastFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const frame = lastFrame()!;
    // Join lines to handle ink word-wrap in narrow test terminal
    const joined = frame.replace(/\n\s*/g, " ");
    expect(joined).toContain("my-web-server");
    expect(joined).toContain("claude-code");
    expect(joined).toContain("always-on");
    expect(joined).toContain("registered");
    expect(joined).toContain("success");
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
    // Should NOT show ▶ or ▼
    expect(lastFrame()!).not.toContain("▶");
    expect(lastFrame()!).not.toContain("▼");
  });

  describe("name display issues", () => {
    it("truncates long names with ellipsis", () => {
      const { lastFrame } = render(
        <JobRow job={longNameJob} selected={false} expanded={false} />
      );
      const frame = lastFrame()!;
      // The full name should NOT appear since COL.name=30
      expect(frame).not.toContain(longNameJob.name);
      expect(frame).toContain("…");
    });

    it("renders friendly nohup name (node server.js instead of bg:node)", () => {
      const { lastFrame } = render(
        <JobRow job={unfriendlyBgJob} selected={false} expanded={false} />
      );
      // After fix: "node server.js" is rendered instead of unfriendly "bg:node"
      expect(lastFrame()!).toContain("node server.js");
    });

    it("renders JSON residue name after truncation (bug baseline)", () => {
      const { lastFrame } = render(
        <JobRow job={jsonResidueJob} selected={false} expanded={false} />
      );
      const frame = lastFrame()!;
      // The name field has JSON residue. When truncated to 29 chars it
      // should still show partial garbage — documenting the bug.
      // The name is: pm2 api.js"},"tool_result":"started process [api]\nid: 0"
      // Truncated at 29: pm2 api.js"},"tool_result…
      expect(frame).toContain("pm2 api.js");
    });
  });

  describe("live source display", () => {
    it("renders live source label", () => {
      const { lastFrame } = render(
        <JobRow job={liveProcessJob} selected={false} expanded={false} />
      );
      expect(lastFrame()!).toContain("live");
    });
  });

  describe("real-world service names", () => {
    it("displays 'pew sync' service name clearly in the table row", () => {
      const { lastFrame } = render(
        <JobRow job={pewSyncJob} selected={false} expanded={false} />
      );
      const frame = lastFrame()!;
      expect(frame).toContain("pew sync");
      expect(frame).toContain("claude-code");
      expect(frame).toContain("success");
    });

    it("pew sync is visible in the full table alongside other jobs", () => {
      const { lastFrame } = render(
        <Box flexDirection="column">
          <TableHeader />
          {allFixtureJobs.map((job, i) => (
            <JobRow key={job.id} job={job} selected={false} expanded={false} />
          ))}
        </Box>
      );
      const frame = lastFrame()!;
      expect(frame).toContain("pew sync");
    });
  });
});

describe("Column alignment", () => {
  it("all rows render on a single line", () => {
    const rows = allFixtureJobs.map((job, i) => {
      const { lastFrame } = render(
        <JobRow job={job} selected={i === 0} expanded={false} />
      );
      return { name: job.name, frame: lastFrame()! };
    });

    for (const { name, frame } of rows) {
      const lines = frame.split("\n").filter((l) => l.trim().length > 0);
      expect(lines.length, `Job "${name}" wraps to ${lines.length} lines`).toBe(1);
    }
  });

  it("header and rows have matching column starts", () => {
    const { lastFrame: headerFrame } = render(<TableHeader />);
    const headerLines = headerFrame()!.split("\n");
    const headerLine = headerLines[0]!;

    const { lastFrame: rowFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const rowLine = rowFrame()!.split("\n")[0]!;

    const nameInHeader = headerLine.indexOf("JOB NAME");
    const nameInRow = rowLine.indexOf("my-web-server");

    // With indicator inside the column system, alignment should be exact
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
    // Snapshot captures the full visual output for comparison
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
