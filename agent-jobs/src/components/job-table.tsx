import React from "react";
import { Box, Text } from "ink";
import type { Job } from "../types.js";
import { formatRelativeTime, truncate, cronToHuman, statusIcon, resultColor, sanitizeName } from "../utils.js";

const GAP = 1;

const COL = {
  indicator: 2,
  status: 2,
  service: 18,
  command: 28,
  schedule: 14,
  lastRun: 10,
  result: 7,
  created: 10,
};

export function TableHeader() {
  return (
    <Box flexDirection="column">
      <Box gap={GAP}>
        <Box width={COL.indicator}><Text>{" "}</Text></Box>
        <Box width={COL.status}><Text bold color="magenta">{"ST"}</Text></Box>
        <Box width={COL.service}><Text bold color="magenta">{"SERVICE"}</Text></Box>
        <Box width={COL.command}><Text bold color="magenta">{"COMMAND"}</Text></Box>
        <Box width={COL.schedule}><Text bold color="magenta">{"SCHEDULE"}</Text></Box>
        <Box width={COL.lastRun}><Text bold color="magenta">{"LAST RUN"}</Text></Box>
        <Box width={COL.result}><Text bold color="magenta">{"RESULT"}</Text></Box>
        <Box width={COL.created}><Text bold color="magenta">{"CREATED"}</Text></Box>
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
  const displayName = sanitizeName(job.name);
  const displayCommand = sanitizeName(job.description);

  return (
    <Box>
      <Box gap={GAP}>
        <Box width={COL.indicator}><Text>{indicator}</Text></Box>
        <Box width={COL.status}><Text color={color}>{icon}</Text></Box>
        <Box width={COL.service}>
          <Text bold={selected} inverse={selected}>
            {truncate(displayName, COL.service - 1)}
          </Text>
        </Box>
        <Box width={COL.command}>
          <Text>{truncate(displayCommand, COL.command - 1)}</Text>
        </Box>
        <Box width={COL.schedule}><Text>{truncate(cronToHuman(job.schedule), COL.schedule - 1)}</Text></Box>
        <Box width={COL.lastRun}><Text>{formatRelativeTime(job.last_run)}</Text></Box>
        <Box width={COL.result}>
          <Text color={resultColor(job.last_result)}>{job.last_result}</Text>
        </Box>
        <Box width={COL.created}><Text dimColor>{formatRelativeTime(job.created_at)}</Text></Box>
      </Box>
    </Box>
  );
}
