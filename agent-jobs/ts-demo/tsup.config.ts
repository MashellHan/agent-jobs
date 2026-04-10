import { defineConfig } from "tsup";

export default defineConfig({
  entry: {
    "cli/index": "src/cli/index.ts",
    "cli/detect": "src/cli/detect.ts",
    index: "src/index.tsx",
  },
  format: "esm",
  target: "node18",
  platform: "node",
  outDir: "dist",
  clean: true,
  splitting: true,
  sourcemap: true,
  external: ["ink", "react", "yoga-wasm-web"],
});
