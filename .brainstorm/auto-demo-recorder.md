# Auto Demo Recorder — Project Design Document

> On-demand terminal demo recording + AI annotation CLI tool, callable by agents or humans.

## 1. Problem Statement

### 1.1 Current Pain Points

- **No visual regression tracking**: CLI/TUI projects lack a way to detect UI regressions over time. Tests verify logic, but not visual rendering.
- **Demo videos are manual**: Creating demo recordings requires manual effort, making demos infrequent and quickly outdated.
- **Agent can't visually verify**: When an AI agent builds or modifies a TUI project, it has no way to "see" the result — only read stdout/stderr. A recording tool bridges this gap.
- **Bug detection is reactive**: Rendering, layout, or interaction bugs are only discovered when a human manually uses the tool.

### 1.2 Goal

Build a **standalone CLI tool** that:

1. Accepts a project config or ad-hoc scenario, records a terminal session as MP4 (30-60s)
2. Uses AI (Claude Vision) to analyze frames and annotate the video
3. Returns the annotated video path + analysis report for the caller to preview
4. Can be invoked by an **AI agent** (via CLI or MCP), a **human** (via CLI), or a **CI pipeline**

### 1.3 Non-Goals

- ~~Scheduled/periodic recording~~ — The caller decides when to run. No built-in cron.
- ~~Web dashboard~~ — Simple file output. The caller (agent/human) previews directly.
- ~~Browser recording~~ — Terminal only for v1. Playwright is a future extension.

---

## 2. Architecture

### 2.1 High-Level Pipeline

```
                         ┌─────────────────────────────────────────────┐
                         │           auto-demo-recorder CLI            │
  Agent / Human          │                                             │
  ─────────────────▸     │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  ──▸ annotated.mp4
  "record this TUI"      │  │  Tape    │─▸│  VHS     │─▸│  AI      │  │  ──▸ report.json
                         │  │  Builder  │  │  Runner  │  │  Annotate│  │  ──▸ thumbnail.png
                         │  └──────────┘  └──────────┘  └──────────┘  │
                         └─────────────────────────────────────────────┘
```

### 2.2 Invocation Modes

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Invocation Modes                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. CLI (human or agent)                                            │
│     $ demo-recorder record --config demo-recorder.yaml              │
│     $ demo-recorder record --scenario basic-navigation              │
│     $ demo-recorder record --adhoc "run ./my-tui, press j 3x, q"   │
│                                                                      │
│  2. MCP Server (agent integration)                                  │
│     Tool: demo_recorder.record                                      │
│     Input: { project_dir, scenario?, adhoc_steps? }                 │
│     Output: { video_path, report, thumbnail_path }                  │
│                                                                      │
│  3. Programmatic (import as library)                                │
│     import { record } from 'auto-demo-recorder'                    │
│     const result = await record({ config, scenario })               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.3 Component Breakdown

| Component | Responsibility | Tech |
|-----------|---------------|------|
| **CLI** | Parse args, dispatch commands | Node.js (commander) |
| **Config Loader** | Read and validate `demo-recorder.yaml` | yaml + zod |
| **Tape Builder** | Compile scenario config → VHS `.tape` file | Template engine |
| **VHS Runner** | Execute `.tape` → raw MP4 | VHS (charmbracelet) |
| **Frame Extractor** | Extract key frames from video | ffmpeg |
| **AI Annotator** | Analyze frames, detect bugs, generate annotations | Claude Vision API |
| **Post-Processor** | Overlay annotations on video, generate thumbnail | ffmpeg |
| **MCP Server** | Expose `record` tool for agent integration | MCP SDK |

### 2.4 Data Flow

```
1. CLI receives command (record --config ... --scenario ...)
2. Config Loader reads demo-recorder.yaml, validates with zod
3. Tape Builder:
   a. Resolves scenario from config (or uses adhoc steps)
   b. Generates .tape file with setup (hidden) + recording steps
4. VHS Runner executes .tape → raw.mp4
5. Frame Extractor: ffmpeg extracts frames at 1fps → frame-NNN.png
6. AI Annotator: sends frames to Claude Vision API
   - Identifies UI elements, status, bugs
   - Generates per-frame annotation text
7. Post-Processor:
   - Overlays annotation text via ffmpeg drawtext
   - Generates thumbnail from first frame
   - Writes report.json
8. CLI outputs:
   - Path to annotated.mp4
   - Path to report.json
   - Summary to stdout (for agent consumption)
```

---

## 3. Project Structure

```
auto-demo-recorder/
├── package.json
├── tsconfig.json
├── README.md
├── bin/
│   └── demo-recorder.ts          # CLI entry point
├── src/
│   ├── index.ts                  # Library entry (export record())
│   ├── cli.ts                    # CLI command definitions
│   ├── config/
│   │   ├── loader.ts             # YAML config loader
│   │   ├── schema.ts             # Zod schema for demo-recorder.yaml
│   │   └── types.ts              # TypeScript types
│   ├── pipeline/
│   │   ├── tape-builder.ts       # Scenario → .tape file
│   │   ├── vhs-runner.ts         # Execute VHS
│   │   ├── frame-extractor.ts    # ffmpeg frame extraction
│   │   ├── annotator.ts          # Claude Vision API integration
│   │   └── post-processor.ts     # ffmpeg annotation overlay
│   ├── mcp/
│   │   └── server.ts             # MCP server exposing record tool
│   └── utils/
│       ├── ffmpeg.ts             # ffmpeg command helpers
│       └── logger.ts             # Structured logging
├── templates/
│   └── tape.hbs                  # Handlebars template for .tape files
├── examples/
│   └── demo-recorder.yaml        # Example config for agent-file-preview
└── test/
    ├── tape-builder.test.ts
    ├── config-loader.test.ts
    └── fixtures/
        └── sample-config.yaml
```

---

## 4. CLI Interface

### 4.1 Commands

```bash
# Record using project config
demo-recorder record
demo-recorder record --config ./demo-recorder.yaml
demo-recorder record --scenario basic-navigation

# Record with ad-hoc steps (no config file needed)
demo-recorder record --adhoc \
  --command "./my-tui" \
  --steps "j,j,j,Enter,sleep:2s,q" \
  --width 1200 --height 800

# List available scenarios from config
demo-recorder list

# Show last recording info
demo-recorder last

# Validate config file
demo-recorder validate --config ./demo-recorder.yaml

# Start MCP server
demo-recorder serve
```

### 4.2 CLI Output (for agent consumption)

```
Recording scenario: basic-navigation
  ✓ Tape generated
  ✓ VHS recording complete (14.5s)
  ✓ Frames extracted (15 frames)
  ✓ AI annotation complete
  ✓ Video annotated

Result:
  Video:     .demo-recordings/2026-04-11_14-30/basic-navigation/annotated.mp4
  Report:    .demo-recordings/2026-04-11_14-30/basic-navigation/report.json
  Thumbnail: .demo-recordings/2026-04-11_14-30/basic-navigation/thumbnail.png

Summary: All 15 frames analyzed. Status: OK. No bugs detected.
  - Frame 0-2: TUI startup, file list loaded (4 files)
  - Frame 3-8: File navigation, preview rendering
  - Frame 9-14: Detail view, clean exit
```

---

## 5. MCP Server Interface

### 5.1 Tool Definition

```typescript
{
  name: "demo_recorder_record",
  description: "Record a terminal demo video of a CLI/TUI project. Runs the project, captures a video, and uses AI to annotate it with feature descriptions and bug detection.",
  inputSchema: {
    type: "object",
    properties: {
      project_dir: {
        type: "string",
        description: "Path to the project directory containing demo-recorder.yaml"
      },
      scenario: {
        type: "string",
        description: "Name of scenario to record (from config). If omitted, records all scenarios."
      },
      adhoc: {
        type: "object",
        description: "Ad-hoc recording without config file",
        properties: {
          command: { type: "string", description: "Command to run (e.g., './my-tui')" },
          steps: {
            type: "array",
            items: {
              type: "object",
              properties: {
                action: { enum: ["type", "key", "sleep"] },
                value: { type: "string" },
                pause: { type: "string", default: "500ms" }
              }
            }
          },
          width: { type: "number", default: 1200 },
          height: { type: "number", default: 800 }
        }
      },
      annotate: {
        type: "boolean",
        default: true,
        description: "Whether to run AI annotation (disable for faster recording)"
      }
    },
    required: ["project_dir"]
  }
}
```

### 5.2 Tool Response

```json
{
  "success": true,
  "video_path": "/abs/path/.demo-recordings/2026-04-11_14-30/basic-navigation/annotated.mp4",
  "raw_video_path": "/abs/path/.demo-recordings/2026-04-11_14-30/basic-navigation/raw.mp4",
  "report_path": "/abs/path/.demo-recordings/2026-04-11_14-30/basic-navigation/report.json",
  "thumbnail_path": "/abs/path/.demo-recordings/2026-04-11_14-30/basic-navigation/thumbnail.png",
  "summary": {
    "status": "ok",
    "duration_seconds": 14.5,
    "frames_analyzed": 15,
    "bugs_found": 0,
    "features_demonstrated": ["file navigation", "preview rendering", "keyboard shortcuts"],
    "description": "All UI elements rendered correctly. Navigation responsive. No visual regressions."
  }
}
```

### 5.3 MCP Server Configuration

```json
// In Claude settings or .claude.json
{
  "mcpServers": {
    "demo-recorder": {
      "command": "npx",
      "args": ["auto-demo-recorder", "serve"],
      "env": {
        "ANTHROPIC_API_KEY": "sk-..."
      }
    }
  }
}
```

---

## 6. Project Configuration

### 6.1 Config File: `demo-recorder.yaml`

```yaml
# demo-recorder.yaml — placed in the project root
project:
  name: agent-file-preview
  description: "TUI file preview tool for AI agent outputs"
  build_command: "make build"      # optional: run before recording
  binary: "./agent-file-preview"

recording:
  width: 1200
  height: 800
  font_size: 16
  theme: "Catppuccin Mocha"
  fps: 25
  max_duration: 60  # seconds

output:
  dir: ".demo-recordings"    # relative to project root
  keep_raw: true              # keep raw.mp4 alongside annotated
  keep_frames: false          # delete extracted frames after annotation

annotation:
  enabled: true
  model: "claude-sonnet-4-6"
  extract_fps: 1
  language: "zh"
  overlay_position: "bottom"
  overlay_font_size: 14

scenarios:
  - name: "basic-navigation"
    description: "Add files and navigate through the list"
    setup:
      - "agent-file-preview clear"
      - "agent-file-preview add README.md"
      - "agent-file-preview add go.mod"
      - "agent-file-preview add internal/ui/model.go"
      - "agent-file-preview add internal/preview/detect.go"
    steps:
      - { action: "type", value: "agent-file-preview", pause: "2s" }
      - { action: "key", value: "j", pause: "500ms" }
      - { action: "key", value: "j", pause: "500ms" }
      - { action: "key", value: "j", pause: "500ms" }
      - { action: "key", value: "Enter", pause: "2s" }
      - { action: "key", value: "k", pause: "500ms" }
      - { action: "key", value: "k", pause: "500ms" }
      - { action: "key", value: "Enter", pause: "2s" }
      - { action: "key", value: "q", pause: "500ms" }

  - name: "file-filter"
    description: "Test file filtering functionality"
    setup:
      - "agent-file-preview clear"
      - "agent-file-preview add README.md"
      - "agent-file-preview add go.mod"
      - "agent-file-preview add Makefile"
      - "agent-file-preview add internal/ui/model.go"
      - "agent-file-preview add internal/preview/detect.go"
    steps:
      - { action: "type", value: "agent-file-preview", pause: "2s" }
      - { action: "key", value: "/", pause: "500ms" }
      - { action: "type", value: "go", pause: "1s" }
      - { action: "key", value: "Enter", pause: "1s" }
      - { action: "key", value: "Enter", pause: "2s" }
      - { action: "key", value: "q", pause: "500ms" }

  - name: "markdown-preview"
    description: "Preview markdown file rendering"
    setup:
      - "agent-file-preview clear"
      - "agent-file-preview add README.md"
    steps:
      - { action: "type", value: "agent-file-preview", pause: "2s" }
      - { action: "key", value: "Enter", pause: "3s" }
      - { action: "key", value: "j", pause: "500ms", repeat: 5 }
      - { action: "key", value: "q", pause: "500ms" }
```

---

## 7. AI Annotation Pipeline

### 7.1 Frame Analysis Prompt

```
You are analyzing a screenshot from a terminal TUI application called "{project_name}".
This is frame {n} of {total} (timestamp: {timestamp}).

Project description: {project_description}
Scenario being recorded: {scenario_description}

Analyze the screenshot and provide a JSON response:

{
  "status": "ok" | "warning" | "error",
  "ui_elements": [
    { "name": "file list", "visible": true, "status": "normal" },
    { "name": "preview pane", "visible": true, "status": "normal" }
  ],
  "description": "Brief description of what is shown",
  "feature_being_demonstrated": "e.g., file navigation",
  "bugs_detected": [],
  "visual_quality": "good" | "degraded" | "broken",
  "annotation_text": "Short text (< 50 chars) to overlay on this frame"
}
```

### 7.2 Annotation Overlay

- Semi-transparent black bar at video bottom
- Per-frame annotation text via `ffmpeg drawtext`
- Bug frames get a red border
- Status dot (green/yellow/red) in top-right corner

```bash
ffmpeg -i raw.mp4 \
  -vf "drawbox=x=0:y=ih-60:w=iw:h=60:color=black@0.7:t=fill, \
       drawtext=text='File list navigation — 4 files loaded':
         fontcolor=white:fontsize=20:
         x=(w-text_w)/2:y=h-40:
         enable='between(t,2,5)'" \
  -codec:a copy annotated.mp4
```

---

## 8. Output Structure

```
.demo-recordings/
├── 2026-04-11_14-30/
│   ├── basic-navigation/
│   │   ├── raw.mp4                 # Original VHS recording
│   │   ├── annotated.mp4           # AI-annotated version
│   │   ├── thumbnail.png           # First frame as thumbnail
│   │   └── report.json             # AI analysis report
│   ├── file-filter/
│   │   └── ...
│   └── session-report.json         # Combined report for all scenarios
│
└── latest -> 2026-04-11_14-30/     # Symlink to most recent
```

---

## 9. Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| CLI Framework | **commander** | Command parsing |
| Language | **TypeScript** | Type safety, Node.js ecosystem |
| Config | **yaml** + **zod** | Config parsing + validation |
| Recording | **VHS** (charmbracelet) | Terminal session → MP4 |
| Video Processing | **ffmpeg** | Frame extraction, annotation overlay |
| AI Analysis | **Claude API** (Vision) | Frame analysis, bug detection |
| MCP | **@modelcontextprotocol/sdk** | Agent integration |
| Template | **handlebars** | .tape file generation |

### 9.1 System Dependencies

```bash
# Required (must be installed on host)
brew install vhs ffmpeg

# Optional
brew install jq  # for report inspection
```

### 9.2 Why These Choices

- **TypeScript over Shell**: Shell scripts are fragile for multi-step pipelines with error handling. TS gives type safety, testability, and easy MCP server integration.
- **VHS over asciinema**: VHS outputs real MP4 natively with full theming control.
- **Commander over yargs**: Lighter, sufficient for this CLI surface.
- **MCP over custom protocol**: Standard agent integration — Claude, Cursor, and other AI tools can call it natively.
- **Zod over manual validation**: Schema-as-code, great inference, familiar in TS ecosystem.

---

## 10. Agent Usage Examples

### 10.1 Claude Code (via MCP)

```
User: "帮我测试一下 agent-file-preview 的文件导航功能，录制一段 demo"

Agent: [calls demo_recorder_record tool]
  project_dir: "/path/to/agent-file-preview"
  scenario: "basic-navigation"

Agent: "录制完成。视频在 .demo-recordings/2026-04-11_14-30/basic-navigation/annotated.mp4
        分析结果：15 帧全部正常，文件导航、预览渲染均正常工作，未检测到 bug。"
```

### 10.2 Claude Code (via CLI)

```
User: "测试一下文件过滤功能"

Agent: [runs bash]
  $ cd /path/to/agent-file-preview
  $ npx auto-demo-recorder record --scenario file-filter

Agent: [reads stdout summary + report.json]
Agent: "录制完成。视频路径: ...  结果: 过滤功能正常，输入 'go' 后正确过滤出 2 个 .go 文件。"
```

### 10.3 Ad-hoc Recording

```
User: "我刚改了 TUI 的布局，帮我录一段看看效果"

Agent: [runs bash]
  $ npx auto-demo-recorder record --adhoc \
      --command "./agent-file-preview" \
      --steps "sleep:2s,j,j,Enter,sleep:3s,q"

Agent: [previews the video / reads report]
Agent: "视频已录制。布局看起来正常，左侧文件列表和右侧预览面板对齐良好。"
```

---

## 11. Implementation Plan

### Phase 1: Core Pipeline (MVP)

**Goal**: Record a single scenario → extract frames → AI annotate → produce annotated video.

| Step | Task | Output |
|------|------|--------|
| 1.1 | Project scaffold: package.json, tsconfig, directory structure | Project skeleton |
| 1.2 | Config schema (zod) + loader | `src/config/` |
| 1.3 | Tape builder: scenario config → `.tape` file | `src/pipeline/tape-builder.ts` |
| 1.4 | VHS runner: execute `.tape`, capture output | `src/pipeline/vhs-runner.ts` |
| 1.5 | Frame extractor: ffmpeg frame extraction | `src/pipeline/frame-extractor.ts` |
| 1.6 | AI annotator: Claude Vision API integration | `src/pipeline/annotator.ts` |
| 1.7 | Post-processor: ffmpeg annotation overlay + thumbnail | `src/pipeline/post-processor.ts` |
| 1.8 | CLI: `record` command wiring | `src/cli.ts` |
| 1.9 | Test with `agent-file-preview` basic-navigation | First annotated video |

### Phase 2: Full CLI + MCP

**Goal**: Complete CLI interface, add MCP server for agent integration.

| Step | Task | Output |
|------|------|--------|
| 2.1 | CLI commands: `list`, `last`, `validate` | Full CLI |
| 2.2 | Ad-hoc recording mode (`--adhoc`) | Configless recording |
| 2.3 | MCP server with `demo_recorder_record` tool | `src/mcp/server.ts` |
| 2.4 | Output directory management + `latest` symlink | Storage logic |
| 2.5 | `--no-annotate` flag for fast raw recording | Speed option |

### Phase 3: Polish

**Goal**: Improve annotation quality, add multi-scenario, tests.

| Step | Task | Output |
|------|------|--------|
| 3.1 | Multi-scenario recording (run all scenarios in one invocation) | Batch mode |
| 3.2 | Regression detection: diff consecutive reports | Comparison logic |
| 3.3 | Improved annotation overlay (fade, status indicator) | Better visuals |
| 3.4 | Unit + integration tests | Test suite |
| 3.5 | README + example configs | Documentation |
| 3.6 | npm publish setup | Distributable package |

### Implementation Priority

```
Phase 1 (MVP)          ████████████████████  Core value — record + annotate
Phase 2 (CLI + MCP)    ████████████████░░░░  Agent integration — key differentiator
Phase 3 (Polish)       ████████░░░░░░░░░░░░  Quality of life
```

---

## 12. Quick Start (After Implementation)

```bash
# Install
npm install -g auto-demo-recorder

# Ensure system deps
brew install vhs ffmpeg

# In your project directory, create config
demo-recorder init    # generates demo-recorder.yaml template

# Record a scenario
demo-recorder record --scenario basic-navigation

# Record all scenarios
demo-recorder record

# Quick ad-hoc recording
demo-recorder record --adhoc --command "./my-tui" --steps "j,j,Enter,sleep:2s,q"

# Start MCP server (for agent integration)
demo-recorder serve

# Preview result
open .demo-recordings/latest/basic-navigation/annotated.mp4
```
