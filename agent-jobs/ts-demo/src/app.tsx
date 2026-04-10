import React, { useState, useEffect, useCallback } from "react";
import { Box, Text, useInput, useApp } from "ink";
import type { Job, TabFilter } from "./types.js";
import { TAB_FILTERS } from "./types.js";
import { loadAllJobs, watchJobsFile } from "./loader.js";
import { Header } from "./components/header.js";
import { TabBar } from "./components/tab-bar.js";
import { TableHeader, JobRow } from "./components/job-table.js";
import { JobDetail } from "./components/job-detail.js";
import { Footer } from "./components/footer.js";

function filterJobs(jobs: Job[], tab: TabFilter): Job[] {
  switch (tab) {
    case "all":
      return jobs;
    case "registered":
      return jobs.filter((j) => j.source === "registered");
    case "live":
      return jobs.filter((j) => j.source === "live");
    case "active":
      return jobs.filter((j) => j.status === "active");
    case "error":
      return jobs.filter((j) => j.status === "error" || j.last_result === "error");
    default:
      return jobs;
  }
}

function computeTabCounts(jobs: Job[]): Record<TabFilter, number> {
  return {
    all: jobs.length,
    registered: jobs.filter((j) => j.source === "registered").length,
    live: jobs.filter((j) => j.source === "live").length,
    active: jobs.filter((j) => j.status === "active").length,
    error: jobs.filter((j) => j.status === "error" || j.last_result === "error").length,
  };
}

export default function App() {
  const { exit } = useApp();
  const [allJobs, setAllJobs] = useState<Job[]>([]);
  const [cursor, setCursor] = useState(0);
  const [expanded, setExpanded] = useState(-1);
  const [tab, setTab] = useState<TabFilter>("all");
  const [lastRefresh, setLastRefresh] = useState(new Date());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(() => {
    loadAllJobs()
      .then((jobs) => {
        setAllJobs(jobs);
        setLastRefresh(new Date());
        setLoading(false);
        setError(null);
      })
      .catch((err: Error) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  // Initial load
  useEffect(() => {
    refresh();
  }, [refresh]);

  // Auto-refresh live processes every 15 seconds
  useEffect(() => {
    const timer = setInterval(refresh, 10_000);
    return () => clearInterval(timer);
  }, [refresh]);

  // Watch jobs.json for changes
  useEffect(() => {
    return watchJobsFile(refresh);
  }, [refresh]);

  const filtered = filterJobs(allJobs, tab);
  const tabCounts = computeTabCounts(allJobs);

  useInput((input, key) => {
    if (input === "q") {
      exit();
      return;
    }

    if (input === "r") {
      refresh();
      return;
    }

    if (input === "d" || key.return) {
      if (filtered.length > 0) {
        setExpanded((prev) => (prev === cursor ? -1 : cursor));
      }
      return;
    }

    if (key.escape) {
      setExpanded(-1);
      return;
    }

    if (key.upArrow && cursor > 0) {
      setCursor((c) => c - 1);
      setExpanded(-1);
    }

    if (key.downArrow && cursor < filtered.length - 1) {
      setCursor((c) => c + 1);
      setExpanded(-1);
    }

    if (key.leftArrow) {
      const idx = TAB_FILTERS.indexOf(tab);
      if (idx > 0) {
        setTab(TAB_FILTERS[idx - 1]!);
        setCursor(0);
        setExpanded(-1);
      }
    }

    if (key.rightArrow) {
      const idx = TAB_FILTERS.indexOf(tab);
      if (idx < TAB_FILTERS.length - 1) {
        setTab(TAB_FILTERS[idx + 1]!);
        setCursor(0);
        setExpanded(-1);
      }
    }
  });

  if (loading) {
    return (
      <Box paddingX={1}>
        <Text>Loading jobs...</Text>
      </Box>
    );
  }

  if (error) {
    return (
      <Box flexDirection="column" paddingX={1}>
        <Text color="red">{`Error: ${error}`}</Text>
        <Text dimColor>{"Press r to retry, q to quit"}</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" paddingX={1}>
      <Header jobs={allJobs} lastRefresh={lastRefresh} currentTab={tab} />
      <TabBar current={tab} counts={tabCounts} />
      <TableHeader />

      {filtered.length === 0 ? (
        <Box flexDirection="column" paddingY={1} paddingX={2}>
          <Text dimColor>{"No jobs in this category"}</Text>
          {allJobs.length === 0 && (
            <Box flexDirection="column" marginTop={1}>
              <Text dimColor>{"Get started:"}</Text>
              <Text dimColor>{"  1. Run 'agent-jobs setup' to install the PostToolUse hook"}</Text>
              <Text dimColor>{"  2. Use Claude Code to create a background service"}</Text>
              <Text dimColor>{"  3. The hook will auto-detect and register it here"}</Text>
            </Box>
          )}
        </Box>
      ) : (
        filtered.map((job, i) => (
          <Box key={job.id} flexDirection="column">
            <JobRow job={job} selected={i === cursor} expanded={i === expanded} />
            {i === expanded && <JobDetail job={job} />}
          </Box>
        ))
      )}

      <Footer />
    </Box>
  );
}
