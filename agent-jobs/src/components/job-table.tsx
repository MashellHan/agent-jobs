import React from "react";
import { Box, Text } from "ink";
import type { Job } from "../types.js";
import { formatCompactTime, formatRelativeTime, truncate, cronToHuman, statusIcon, resultColor, sanitizeName, sourceToShort } from "../utils.js";

const GAP = 1;

function getColWidths() {
  const termWidth = process.stdout.columns || 120;
  return {
    indicator: 2,
    status: 2,
    service: 22,
    agent: 12,
    source: 10,
    schedule: 14,
    lastRun: 12,
    result: 7,
    created: 8,
  };
}

export function TableHeader() {
  const COL = getColWidths();
  return (
    <Box flexDirection="column">
      <Box gap={GAP}>
        <Box width={COL.indicator}><Text>{" "}</Text></Box>
        <Box width={COL.status}><Text bold color="magenta">{"ST"}</Text></Box>
        <Box width={COL.service}><Text bold color="magenta">{"SERVICE"}</Text></Box>
        <Box width={COL.agent}><Text bold color="magenta">{"AGENT"}</Text></Box>
        <Box width={COL.source}><Text bold color="magenta">{"SOURCE"}</Text></Box>
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
  confirmMessage?: string;
}

export function JobRow({ job, selected, expanded, confirmMessage }: RowProps) {
  const COL = getColWidths();
  const { icon, color } = statusIcon(job.status);
  const indicator = selected ? (expanded ? "▼" : "▶") : " ";
  const displayName = sanitizeName(job.name);

  if (confirmMessage && selected) {
    return (
      <Box>
        <Box gap={GAP}>
          <Box width={COL.indicator}><Text>{indicator}</Text></Box>
          <Box width={COL.status}><Text color={color}>{icon}</Text></Box>
          <Box width={COL.service}>
            <Text bold inverse>
              {truncate(displayName, COL.service - 1)}
            </Text>
          </Box>
          <Box>
            <Text bold color="yellow">{confirmMessage}</Text>
          </Box>
        </Box>
      </Box>
    );
  }

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
        <Box width={COL.agent}>
          <Text dimColor>{truncate(job.agent, COL.agent - 1)}</Text>
        </Box>
        <Box width={COL.source}>
          <Text dimColor>{truncate(sourceToShort(job.source), COL.source - 1)}</Text>
        </Box>
        <Box width={COL.schedule}><Text>{truncate(cronToHuman(job.schedule), COL.schedule - 1)}</Text></Box>
        <Box width={COL.lastRun}><Text>{formatCompactTime(job.last_run)}</Text></Box>
        <Box width={COL.result}>
          <Text color={resultColor(job.last_result)}>{job.last_result}</Text>
        </Box>
        <Box width={COL.created}><Text dimColor>{formatRelativeTime(job.created_at)}</Text></Box>
      </Box>
    </Box>
  );
}
