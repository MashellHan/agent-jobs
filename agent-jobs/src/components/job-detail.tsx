import React from "react";
import { Box, Text } from "ink";
import type { Job } from "../types.js";
import { formatTime, formatRelativeTime, cronToHuman, statusIcon, resultColor, sourceToHuman } from "../utils.js";

interface Props {
  job: Job;
}

export function JobDetail({ job }: Props) {
  const { color } = statusIcon(job.status);
  const runCount = job.run_count < 0 ? "(live process)" : String(job.run_count);

  const fields: Array<{ label: string; value: string; valueColor?: string }> = [
    { label: "Command", value: job.description || "-" },
    { label: "Agent", value: job.agent },
    { label: "Schedule", value: cronToHuman(job.schedule) },
    { label: "Project", value: job.project || "-" },
    { label: "Source", value: sourceToHuman(job.source) },
    { label: "Status", value: job.status, valueColor: color },
    { label: "Created", value: `${formatTime(job.created_at)} (${formatRelativeTime(job.created_at)})` },
    { label: "Last Run", value: job.last_run ? `${formatTime(job.last_run)} (${formatRelativeTime(job.last_run)})` : "-" },
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

  // Build run history from available data
  const history: Array<{ time: string; result: string; resultColor: string }> = [];
  if (job.last_run) {
    history.push({
      time: `${formatTime(job.last_run)} (${formatRelativeTime(job.last_run)})`,
      result: job.last_result,
      resultColor: resultColor(job.last_result),
    });
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

      {history.length > 0 && (
        <Box flexDirection="column" marginTop={1}>
          <Text bold color="magenta">{"Run History:"}</Text>
          {history.map((h, i) => (
            <Box key={i} gap={1} marginLeft={2}>
              <Text dimColor>{`${i + 1}.`}</Text>
              <Text>{h.time}</Text>
              <Text color={h.resultColor}>{h.result}</Text>
            </Box>
          ))}
          {job.run_count > 1 && (
            <Box marginLeft={2}>
              <Text dimColor>{`... and ${job.run_count - 1} earlier run${job.run_count - 1 === 1 ? "" : "s"}`}</Text>
            </Box>
          )}
        </Box>
      )}

      <Text dimColor>{"\nESC or d to close"}</Text>
    </Box>
  );
}
