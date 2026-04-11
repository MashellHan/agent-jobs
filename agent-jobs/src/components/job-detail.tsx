import React from "react";
import { Box, Text } from "ink";
import type { Job } from "../types.js";
import { formatTime, formatRelativeTime, cronToHuman, statusIcon, resultColor } from "../utils.js";

interface Props {
  job: Job;
}

export function JobDetail({ job }: Props) {
  const { color } = statusIcon(job.status);
  const runCount = job.run_count < 0 ? "(live process)" : String(job.run_count);

  const fields: Array<{ label: string; value: string; valueColor?: string }> = [
    { label: "Description", value: job.description || "-" },
    { label: "Agent", value: job.agent },
    { label: "Schedule", value: cronToHuman(job.schedule) },
    { label: "Project", value: job.project || "-" },
    { label: "Source", value: job.source },
    { label: "Status", value: job.status, valueColor: color },
    { label: "Created", value: `${formatTime(job.created_at)} (${formatRelativeTime(job.created_at)})` },
    { label: "Next Run", value: formatTime(job.next_run) },
    { label: "Run Count", value: runCount },
    { label: "Last Result", value: job.last_result, valueColor: resultColor(job.last_result) },
  ];

  if (job.port) {
    fields.push({ label: "Port", value: String(job.port) });
  }

  if (job.pid) {
    fields.push({ label: "PID", value: String(job.pid) });
  }

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="magenta"
      paddingX={2}
      paddingY={0}
      marginLeft={3}
    >
      {fields.map((f) => (
        <Box key={f.label} gap={1}>
          <Box width={14}>
            <Text bold color="magenta">{f.label + ":"}</Text>
          </Box>
          <Text color={f.valueColor}>{f.value}</Text>
        </Box>
      ))}
      <Text dimColor>{"\nESC or d to close"}</Text>
    </Box>
  );
}
