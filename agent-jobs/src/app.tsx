import React, { useState, useEffect, useCallback } from "react";
import { Box, Text, useInput, useApp } from "ink";
import type { Job, TabFilter, ConfirmAction } from "./types.js";
import { TAB_FILTERS } from "./types.js";
import { loadAllJobs, watchJobsFile } from "./loader.js";
import { loadHiddenIds, addHiddenId, removeRegisteredJob, setRegisteredJobStatus, killProcess, stopLaunchdService } from "./store.js";
import { Header } from "./components/header.js";
import { TabBar } from "./components/tab-bar.js";
import { TableHeader, JobRow } from "./components/job-table.js";
import { JobDetail } from "./components/job-detail.js";
import { Footer } from "./components/footer.js";

/**
 * Clear the entire terminal screen and reset cursor to top-left.
 * This works around an Ink bug where `log-update`'s `previousLineCount`
 * gets out of sync when the UI height changes (e.g. detail panel
 * expand/collapse), causing old frames to persist ("stacking").
 *
 * By clearing the screen before state changes that alter height,
 * Ink's `eraseLines(staleCount)` becomes harmless — the screen is
 * already blank.
 */
function clearScreen(): void {
  if (process.stdout.isTTY) {
    process.stdout.write("\x1b[2J\x1b[H");
  }
}

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
  const [hiddenIds, setHiddenIds] = useState<Set<string>>(new Set());
  const [cursor, setCursor] = useState(0);
  const [expanded, setExpanded] = useState(-1);
  const [tab, setTab] = useState<TabFilter>("all");
  const [lastRefresh, setLastRefresh] = useState(new Date());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmAction, setConfirmAction] = useState<ConfirmAction | null>(null);
  const [statusMsg, setStatusMsg] = useState<string | null>(null);

  const refresh = useCallback(() => {
    clearScreen();
    loadAllJobs()
      .then((jobs) => {
        setAllJobs(jobs);
        setHiddenIds(loadHiddenIds());
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

  // Auto-refresh live processes every 10 seconds
  useEffect(() => {
    const timer = setInterval(refresh, 10_000);
    return () => clearInterval(timer);
  }, [refresh]);

  // Watch jobs.json for changes
  useEffect(() => {
    return watchJobsFile(refresh);
  }, [refresh]);

  // Clear status message after 3 seconds
  useEffect(() => {
    if (!statusMsg) return;
    const timer = setTimeout(() => setStatusMsg(null), 3000);
    return () => clearTimeout(timer);
  }, [statusMsg]);

  const filtered = filterJobs(allJobs, tab).filter((j) => !hiddenIds.has(j.id));
  const tabCounts = computeTabCounts(allJobs.filter((j) => !hiddenIds.has(j.id)));

  const handleStopConfirm = useCallback(async (job: Job) => {
    switch (job.source) {
      case "registered":
        setRegisteredJobStatus(job.id, "stopped");
        setStatusMsg(`Stopped ${job.name}`);
        break;
      case "live":
        if (job.pid) {
          const killed = killProcess(job.pid);
          setStatusMsg(killed ? `Killed PID ${job.pid}` : `Failed to kill PID ${job.pid}`);
        }
        break;
      case "launchd": {
        const label = job.id.replace("launchd-", "");
        const stopped = await stopLaunchdService(label);
        setStatusMsg(stopped ? `Stopped ${label}` : `Failed to stop ${label}`);
        break;
      }
      case "cron":
        setStatusMsg("Cron tasks managed by Claude Code");
        break;
    }
    setConfirmAction(null);
    refresh();
  }, [refresh]);

  useInput((input, key) => {
    // Confirmation mode — only respond to y/n/Escape
    if (confirmAction) {
      if (input === "y" || input === "Y") {
        const job = filtered[confirmAction.index];
        if (job) {
          clearScreen();
          void handleStopConfirm(job);
        }
        return;
      }
      if (input === "n" || input === "N" || key.escape) {
        clearScreen();
        setConfirmAction(null);
        return;
      }
      return; // Block all other keys during confirmation
    }

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
        clearScreen();
        setExpanded((prev) => (prev === cursor ? -1 : cursor));
      }
      return;
    }

    if (key.escape) {
      clearScreen();
      setExpanded(-1);
      return;
    }

    // Hide (delete from view)
    if (input === "x") {
      if (filtered.length > 0 && cursor < filtered.length) {
        clearScreen();
        const job = filtered[cursor]!;
        addHiddenId(job.id);
        if (job.source === "registered") {
          removeRegisteredJob(job.id);
        }
        setHiddenIds(loadHiddenIds());
        setExpanded(-1);
        // Adjust cursor if it's now out of bounds
        const newLen = filtered.length - 1;
        if (cursor >= newLen && newLen > 0) {
          setCursor(newLen - 1);
        }
        setStatusMsg(`Hidden ${job.name}`);
      }
      return;
    }

    // Stop (disable with confirmation)
    if (input === "s") {
      if (filtered.length > 0 && cursor < filtered.length) {
        clearScreen();
        setConfirmAction({ type: "stop", index: cursor });
        setExpanded(-1);
      }
      return;
    }

    if (key.upArrow && cursor > 0) {
      if (expanded >= 0) clearScreen();
      setCursor((c) => c - 1);
      setExpanded(-1);
    }

    if (key.downArrow && cursor < filtered.length - 1) {
      if (expanded >= 0) clearScreen();
      setCursor((c) => c + 1);
      setExpanded(-1);
    }

    if (key.leftArrow) {
      const idx = TAB_FILTERS.indexOf(tab);
      if (idx > 0) {
        clearScreen();
        setTab(TAB_FILTERS[idx - 1]!);
        setCursor(0);
        setExpanded(-1);
      }
    }

    if (key.rightArrow) {
      const idx = TAB_FILTERS.indexOf(tab);
      if (idx < TAB_FILTERS.length - 1) {
        clearScreen();
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
      <Header jobs={allJobs.filter((j) => !hiddenIds.has(j.id))} lastRefresh={lastRefresh} currentTab={tab} />
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
            <JobRow
              job={job}
              selected={i === cursor}
              expanded={i === expanded}
              confirmMessage={confirmAction?.index === i ? `Stop this job? [y]es / [n]o` : undefined}
            />
            {i === expanded && <JobDetail job={job} />}
          </Box>
        ))
      )}

      {statusMsg && (
        <Box marginTop={0}>
          <Text color="green" italic>{`  ${statusMsg}`}</Text>
        </Box>
      )}

      <Footer />
    </Box>
  );
}
