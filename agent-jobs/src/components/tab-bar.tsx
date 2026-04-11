import React from "react";
import { Box, Text } from "ink";
import type { TabFilter } from "../types.js";
import { TAB_FILTERS } from "../types.js";

interface Props {
  current: TabFilter;
  counts: Record<TabFilter, number>;
}

const TAB_LABELS: Record<TabFilter, string> = {
  all: "All",
  registered: "Registered",
  live: "Live",
  active: "Active",
  error: "Errors",
};

export function TabBar({ current, counts }: Props) {
  return (
    <Box marginBottom={0} gap={1}>
      {TAB_FILTERS.map((tab) => {
        const isActive = tab === current;
        const label = `${TAB_LABELS[tab]} (${counts[tab]})`;

        return (
          <Box key={tab}>
            <Text
              bold={isActive}
              color={isActive ? "magenta" : undefined}
              inverse={isActive}
            >
              {` ${label} `}
            </Text>
          </Box>
        );
      })}
      <Text dimColor>{" ← →  switch tabs"}</Text>
    </Box>
  );
}
