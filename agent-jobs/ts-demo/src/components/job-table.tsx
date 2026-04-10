import React from "react";
import { Box, Text } from "ink";
import type { Job } from "../types.js";
import { formatTime, truncate, statusIcon, resultColor } from "../utils.js";

const GAP = 2;

const COL = {
  status: 4,
  name: 30,
  agent: 16,
  schedule: 20,
  source: 12,
  lastRun: 20,
  result: 10,
};

export function TableHeader() {
  return (
    <Box flexDirection="column">
      <Box gap={GAP}>
        <Box width={COL.status}><Text bold color="magenta">{"ST"}</Text></Box>
        <Box width={COL.name}><Text bold color="magenta">{"JOB NAME"}</Text></Box>
        <Box width={COL.agent}><Text bold color="magenta">{"AGENT"}</Text></Box>
        <Box width={COL.schedule}><Text bold color="magenta">{"SCHEDULE"}</Text></Box>
        <Box width={COL.source}><Text bold color="magenta">{"SOURCE"}</Text></Box>
        <Box width={COL.lastRun}><Text bold color="magenta">{"LAST RUN"}</Text></Box>
        <Box width={COL.result}><Text bold color="magenta">{"RESULT"}</Text></Box>
      </Box>
      <Text dimColor>{"─".repeat(process.stdout.columns ? Math.min(process.stdout.columns - 2, 140) : 120)}</Text>
    </Box>
  );
}

interface RowProps {
  job: Job;
  selected: boolean;
  expanded: boolean;
}

export function JobRow({ job, selected, expanded }: RowProps) {
  const { icon, color } = statusIcon(job.status);
  const indicator = selected ? (expanded ? "▼" : "▶") : " ";

  return (
    <Box gap={GAP}>
      <Text>{indicator}</Text>
      <Box width={COL.status}><Text color={color}>{icon}</Text></Box>
      <Box width={COL.name}>
        <Text bold={selected} inverse={selected}>
          {truncate(job.name, COL.name - 1)}
        </Text>
      </Box>
      <Box width={COL.agent}><Text>{truncate(job.agent, COL.agent - 1)}</Text></Box>
      <Box width={COL.schedule}><Text dimColor>{truncate(job.schedule, COL.schedule - 1)}</Text></Box>
      <Box width={COL.source}>
        <Text color={job.source === "live" ? "cyan" : undefined}>
          {job.source}
        </Text>
      </Box>
      <Box width={COL.lastRun}><Text>{formatTime(job.last_run)}</Text></Box>
      <Box width={COL.result}>
        <Text color={resultColor(job.last_result)}>{job.last_result}</Text>
      </Box>
    </Box>
  );
}
