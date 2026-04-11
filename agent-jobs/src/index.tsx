import React from "react";
import { render } from "ink";
import App from "./app.js";
import { setInkInstance } from "./ink-instance.js";

// Enter alternate screen buffer to prevent TUI stacking/overlapping.
// This gives us a clean fullscreen canvas, like htop or vim.
process.stdout.write("\x1b[?1049h");
// Move cursor to top-left
process.stdout.write("\x1b[H");

const instance = render(React.createElement(App));
setInkInstance(instance);

// Restore main screen buffer on exit
function restoreScreen(): void {
  process.stdout.write("\x1b[?1049l");
}

process.on("exit", restoreScreen);
process.on("SIGINT", () => {
  restoreScreen();
  process.exit(0);
});
process.on("SIGTERM", () => {
  restoreScreen();
  process.exit(0);
});
