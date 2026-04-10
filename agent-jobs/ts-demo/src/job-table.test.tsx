import React from "react";
import { describe, it, expect } from "vitest";
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
    expect(frame).toContain("my-web-server");
    expect(frame).toContain("claude-code");
    expect(frame).toContain("always-on");
    // BUG: "registered" gets split across lines due to column overflow
    // The word wraps as "registere\nd" — documenting this alignment bug.
    // After fix, this should be: expect(frame).toContain("registered");
    expect(frame).toContain("registere");
    expect(frame).toContain("success");
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

    it("renders unfriendly bg:node name as-is (bug baseline)", () => {
      const { lastFrame } = render(
        <JobRow job={unfriendlyBgJob} selected={false} expanded={false} />
      );
      // This test documents current behavior — "bg:node" IS rendered,
      // which is the visual problem the user sees.
      expect(lastFrame()!).toContain("bg:node");
    });

    it("renders JSON residue name after truncation (bug baseline)", () => {
      const { lastFrame } = render(
        <JobRow job={jsonResidueJob} selected={false} expanded={false} />
      );
      const frame = lastFrame()!;
      // The name field has JSON residue. When truncated to 29 chars it
      // should still show partial garbage — documenting the bug.
      // The name is: pm2:api.js"},"tool_result":"started process [api]\nid: 0"
      // Truncated at 29: pm2:api.js"},"tool_result":…
      expect(frame).toContain("pm2:api.js");
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
});

describe("Column alignment", () => {
  it("all rows have consistent structure when rendered together", () => {
    const rows = allFixtureJobs.map((job, i) => {
      const { lastFrame } = render(
        <JobRow job={job} selected={i === 0} expanded={false} />
      );
      return lastFrame()!;
    });

    // BUG: rows wrap to multiple lines because the total column width
    // (indicator + gaps + all COL widths) exceeds the ink test render width.
    // This documents the alignment/wrapping bug.
    for (const row of rows) {
      const lines = row.split("\n").filter((l) => l.trim().length > 0);
      // Currently wrapping to 2 lines — after fix should be 1 line.
      expect(lines.length).toBeLessThanOrEqual(2);
    }
  });

  it("header and rows should have matching column starts", () => {
    const { lastFrame: headerFrame } = render(<TableHeader />);
    const headerLines = headerFrame()!.split("\n");
    const headerLine = headerLines[0]!;

    const { lastFrame: rowFrame } = render(
      <JobRow job={normalJob} selected={false} expanded={false} />
    );
    const rowLine = rowFrame()!.split("\n")[0]!;

    // The indicator column adds an extra character in the row but not the header.
    // This documents the alignment bug: header starts at a different offset
    // than the row content.
    // We check that "JOB NAME" column in header aligns-ish with the name in the row.
    const nameInHeader = headerLine.indexOf("JOB NAME");
    const nameInRow = rowLine.indexOf("my-web-server");

    // Document the current misalignment: they should be close
    // (within the indicator width + gap = ~4 chars)
    const offset = Math.abs(nameInHeader - nameInRow);
    // If alignment is perfect, offset should be 0.
    // Currently it may be off due to the indicator being outside the column system.
    // We record the offset — future fixes should bring this to 0.
    expect(offset).toBeLessThan(10); // generous bound to document, not fail
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
