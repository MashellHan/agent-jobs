import React from "react";
import { render } from "ink";
import App from "./app.js";

// Enter alternate screen buffer for a clean fullscreen canvas (like htop/vim).
process.stdout.write("\x1b[?1049h");
process.stdout.write("\x1b[H");

render(React.createElement(App));

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
