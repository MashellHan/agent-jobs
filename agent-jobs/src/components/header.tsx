import React from "react";
import { Box, Text } from "ink";
import type { Job, TabFilter } from "../types.js";
import { statusIcon } from "../utils.js";

interface Props {
  jobs: Job[];
  lastRefresh: Date;
  currentTab: TabFilter;
}

export function Header({ jobs, lastRefresh, currentTab }: Props) {
  const active = jobs.filter((j) => j.status === "active").length;
  const errored = jobs.filter((j) => j.status === "error").length;
  const stopped = jobs.filter((j) => j.status === "stopped").length;
  const live = jobs.filter((j) => j.source === "live").length;

  return (
    <Box flexDirection="column" marginBottom={1}>
      <Text bold color="magenta">
        {"━━━ Agent Job Dashboard ━━━"}
      </Text>
      <Box gap={2}>
        <Text dimColor>
          {`${jobs.length} jobs`}
        </Text>
        <Text color="green">{`● ${active} active`}</Text>
        {errored > 0 && <Text color="red">{`✗ ${errored} error`}</Text>}
        {stopped > 0 && <Text dimColor>{`○ ${stopped} stopped`}</Text>}
        {live > 0 && <Text color="cyan">{`◉ ${live} live`}</Text>}
        <Text color="green" italic>
          {`↻ ${lastRefresh.toLocaleTimeString("en-GB")} (auto)`}
        </Text>
      </Box>
    </Box>
  );
}
