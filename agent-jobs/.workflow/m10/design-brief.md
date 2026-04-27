# M10 Design Brief: Live Agent Observability

> Filed 2026-04-27 to capture the research-backed plan before M05-M09 ship. PM agent will turn this into a full spec when M10 enters SPECCING.

## Why this brief exists now

User asked (during M05 SPECCING) to add a "current agent + subagents" visualization to the roadmap. M10 already existed as "Agent + Subagent inspector page" but with a vague spec. Web research located 8 reference projects + 2 industry standards (OpenInference span kinds, OTel GenAI conventions). Capturing the synthesis here so M10 doesn't redo the research.

## Vision (one sentence)

A second top-level page in agent-jobs that answers, at a glance: **what AI agents are running on this machine right now, what are they working on, and what subagents did they spawn?**

## Three surfaces

### 1. Sessions panel (left list)

One row per active session detected from `~/.claude/projects/**/*.jsonl` (mtime within last 30min by default).

Row anatomy (borrowing the 4-tier pattern distilled in M05 competitive analysis):

```
[icon]  [project name (cwd basename)]                              [activity dot]
        Claude Code · session abc1234                              2s ago
        Currently: Editing src/Discovery/LsofProcessProvider.swift
```

- **Tier 1**: project name (large, primary)
- **Tier 2**: agent kind + short session id
- **Tier 3**: "currently doing X" derived from latest non-terminal tool_use entry
- **Tier 4**: time-since-last-event + activity dot (green = active <30s, yellow = idle 30-60s, gray = stale >60s)

Special: when cwd matches the agent-jobs repo path, show a 🪞 self-badge and overlay milestone/phase from `.workflow/CURRENT.md` (T-011).

### 2. Subagent tree (right pane)

Selecting a session opens a collapsible parentUuid DAG. Borrowed from Arize Phoenix span tree.

```
▼ assistant (Opus, sessionId xyz)
  ├─ tool: Read /Users/.../Service.swift
  ├─ tool: Edit Service.swift
  ├─ ▼ Task (subagent_type=general-purpose)  ← own sessionId, indent + border
  │   ├─ tool: Glob '**/*.swift'
  │   ├─ tool: Grep 'class Service'
  │   └─ assistant (response, returned to parent)
  ├─ tool: Bash 'swift test'
  └─ assistant (final reply)
```

- **Color by event kind** (OpenInference taxonomy):
  - AGENT (assistant turns) — purple
  - LLM (model calls) — blue
  - TOOL (Read/Edit/Bash/Grep/etc.) — green; subdivide by tool name with subtle hue shift
  - CHAIN (Task subagent dispatches) — orange, with indent + border
  - SYSTEM (hooks, notifications) — gray
- **Stuck detection**: nodes with no child progress > 60s pulse softly (T-010 done-when).
- **Collapse policy**: by default expand to depth 2; subagent dispatches always rendered as expandable headers.

### 3. Self-banner (top of Sessions panel)

When ANY session is editing the agent-jobs repo, pin a banner:

```
🪞 You're watching yourself
M05 IMPLEMENTING (cycle 1) — Content fidelity + Visual Harness library
Owner: implementer  ·  3 subagents active  ·  Started 12m ago
```

This is the dogfooding moment. Closes T-011.

## Architecture

### Data sources (priority order, dual-path)

1. **Primary: `~/.claude/projects/**/*.jsonl` tail-watching** (ground truth, ~1-2s lag).
   Reuse `SessionJSONLParser` from M01.5 — extend it to emit a richer event stream, not just CronCreate/Delete pairs.
2. **Optional: hook push channel** (T-013, deferred to M10.5+).
   Swift hook handler writes events to a SQLite ring buffer with sub-100ms latency.
   Anti-pattern guard: never use `SubagentStop` as sole source — known to drop parallel Task events (anthropics/claude-code#27755).
3. **Future: Cursor / Aider / Codex CLI** (T-012).
   `AgentSessionProvider` protocol — `ClaudeCodeProvider` ships in M10; one stub provider proves the protocol shape.

### Modules (proposed)

```
AgentJobsCore/
  Agents/
    AgentSession.swift               // domain model {id, kind, cwd, project, startedAt, events: [AgentEvent]}
    AgentEvent.swift                 // {uuid, parentUuid, kind: AGENT|LLM|TOOL|CHAIN|SYSTEM, tool: String?, summary, ts}
    AgentSessionProvider.swift       // protocol
    Providers/
      ClaudeCodeSessionProvider.swift  // tails JSONL, emits AgentEvents
      CursorSessionProviderStub.swift  // protocol-conformance stub
    Stuck/
      StuckDetector.swift            // pure: events × now → stuck node ids
    Tree/
      AgentEventTree.swift           // pure: events → DAG by parentUuid, ordered by ts
AgentJobsMacUI/
  Pages/
    SessionsPage.swift               // top-level NavigationSplitView
  Sessions/
    SessionRowView.swift             // 4-tier row
    SubagentTreeView.swift           // collapsible OutlineGroup
    SelfBannerView.swift             // T-011
    EventKindStyle.swift             // color tokens per OpenInference kind
```

### Reuse from earlier milestones

- `SessionJSONLParser` (M01.5) — extended to emit AgentEvent stream
- `FileObjectWatcher` + `DirectoryEventWatcher` (M04) — watch `~/.claude/projects/`
- `RefreshScheduler` (M04) — debounced re-render
- `ServiceFormatter` pattern (M05) — apply same to AgentEventFormatter
- `AgentJobsVisualHarness` (M05) — capture Sessions page + tree view scenarios

### Cost / scope estimate

10-14 tasks, ≤150 LOC each. Depends on a clean ServiceFormatter pattern from M05 to mirror, and a working `MenuBarInteraction` from the harness for ui-critic to capture popover→Sessions-page navigation.

## Reference products (from research)

| Project | What to borrow |
|---|---|
| disler/claude-code-hooks-multi-agent-observability | Session swimlanes, color-coded event kinds, hook ingest pipeline |
| simple10/agents-observe | Per-agent cards, parent-session grouping |
| OpenHands trajectory-visualizer | Collapsible chat-like tool calls (caveat: doesn't scale past 2 agents — use tree instead) |
| Arize Phoenix | Span-tree rendering, OpenInference taxonomy as the color/icon vocabulary |
| ClaudeUsageBar | Menu-bar headline pattern ("currently doing X") |
| Cyvid7-Darus10/claude-mission-control | Stuck-agent detection, token cost meter (cost meter → consider for M14) |

Anti-patterns avoided:
- Pure flat log → use tree (per OpenHands lesson)
- Hooks-only ingest → JSONL is ground truth (per SubagentStop bug)
- React/web stack for menubar → SwiftUI native

## Standards alignment

- **OpenInference span kinds** (AGENT/LLM/TOOL/CHAIN/RETRIEVER/GUARDRAIL) become our `AgentEvent.kind` enum.
- **OTel GenAI conventions** (`gen_ai.agent.name`, `gen_ai.tool.definitions`) inform field naming so future export to Phoenix/Langfuse is trivial.

## Open questions for M10 PM (when SPECCING starts)

1. Should the Sessions page be a separate top-level page in the dashboard, or a tab inside the existing dashboard? (Brief recommends separate — different mental model from "background services").
2. How aggressive should the "active in last 30min" filter be? Make it configurable in M09 Settings?
3. Self-banner — is "🪞 You're watching yourself" too cute or just right? PM decides UX tone with ui-critic.
4. Token / cost meter — defer to M13 (History + analytics) or include here? Brief recommends defer.

## Why this is in M10, not earlier

Depends on:
- M05 `AgentJobsVisualHarness` (to capture page scenarios for ui-critic)
- M05 `ServiceFormatter` pattern (mirror for `AgentEventFormatter`)
- M06 information architecture (multi-page navigation conventions)
- M07 visual identity (color tokens for event kinds, consistent spacing)

Doing M10 before these would mean re-doing it later. Order is right.
