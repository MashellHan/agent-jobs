import React from "react";
import { Box, Text } from "ink";

export function Footer() {
  const keys = [
    { key: "q", desc: "Quit" },
    { key: "r", desc: "Refresh" },
    { key: "d/↵", desc: "Details" },
    { key: "x", desc: "Hide" },
    { key: "s", desc: "Stop" },
    { key: "↑↓", desc: "Navigate" },
    { key: "←→", desc: "Tabs" },
  ];

  return (
    <Box marginTop={1} gap={1}>
      {keys.map((k) => (
        <Box key={k.key} gap={0}>
          <Text bold color="magenta">{k.key}</Text>
          <Text dimColor>{` ${k.desc}`}</Text>
        </Box>
      ))}
    </Box>
  );
}
