import { defineConfig } from "tsup";

const shared = {
  format: "esm" as const,
  target: "node18" as const,
  platform: "node" as const,
  outDir: "dist",
  sourcemap: true,
  dts: true,
  external: ["ink", "react", "yoga-wasm-web"],
};

export default defineConfig([
  {
    ...shared,
    entry: {
      "cli/index": "src/cli/index.ts",
      "cli/detect": "src/cli/detect.ts",
    },
    clean: true,
    splitting: false,
    banner: { js: "#!/usr/bin/env node" },
  },
  {
    ...shared,
    entry: { index: "src/index.tsx" },
    // No shebang for the TUI entry
  },
]);
