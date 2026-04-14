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

  const infoFields: Array<{ label: string; value: string; valueColor?: string }> = [
    { label: "Command", value: job.description || "-" },
    { label: "Status", value: job.status, valueColor: color },
    { label: "Agent", value: job.agent },
    { label: "Source", value: sourceToHuman(job.source) },
    { label: "Project", value: job.project || "-" },
  ];

  if (job.port) {
    infoFields.push({ label: "Port", value: String(job.port) });
  }
  if (job.pid) {
    infoFields.push({ label: "PID", value: String(job.pid) });
  }
  if (job.sessionId) {
    infoFields.push({ label: "Session", value: job.sessionId });
  }
  if (job.lifecycle) {
    const lifecycleLabel = job.lifecycle === "session-only"
      ? "session-only (7d auto-expire)"
      : "durable (persisted)";
    infoFields.push({ label: "Lifecycle", value: lifecycleLabel });
  }

  const scheduleFields: Array<{ label: string; value: string }> = [
    { label: "Frequency", value: cronToHuman(job.schedule) },
    { label: "Next Run", value: formatTime(job.next_run) },
  ];

  const historyFields: Array<{ label: string; value: string; valueColor?: string }> = [
    { label: "Created", value: `${formatTime(job.created_at)} (${formatRelativeTime(job.created_at)})` },
    { label: "Last Run", value: job.last_run ? `${formatTime(job.last_run)} (${formatRelativeTime(job.last_run)})` : "-" },
    { label: "Run Count", value: runCount },
    { label: "Last Result", value: job.last_result, valueColor: resultColor(job.last_result) },
  ];

  const renderField = (f: { label: string; value: string; valueColor?: string }) => (
    <Box key={f.label} gap={1}>
      <Box width={14}>
        <Text bold color="magenta">{f.label + ":"}</Text>
      </Box>
      <Text color={f.valueColor}>{f.value}</Text>
    </Box>
  );

  return (
    <Box
      flexDirection="column"
      borderStyle="round"
      borderColor="magenta"
      paddingX={2}
      paddingY={0}
      marginLeft={3}
    >
      {infoFields.map(renderField)}

      <Box marginTop={1}>
        <Text bold dimColor>{"── Schedule ──"}</Text>
      </Box>
      {scheduleFields.map(renderField)}

      <Box marginTop={1}>
        <Text bold dimColor>{"── History ──"}</Text>
      </Box>
      {historyFields.map(renderField)}

      {job.last_run && (
        <Box flexDirection="column" marginTop={0} marginLeft={2}>
          {job.run_count > 1 && (
            <Text dimColor>{`... and ${job.run_count - 1} earlier run${job.run_count - 1 === 1 ? "" : "s"}`}</Text>
          )}
        </Box>
      )}

      <Text dimColor>{"\nESC or d to close"}</Text>
    </Box>
  );
}
