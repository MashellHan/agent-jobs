# Design Pillar: Visual Harness + UI Critique Loop

> Owned by retrospective + ui-critic agents. This is a first-class architecture pillar, not a test-folder utility. Every milestone from M05 onward depends on it.

## Why this exists

Auto-generated screenshots prove the UI didn't crash. They do **not** prove the UI is good. The user will judge this app on:
- Can I understand what each row is, in 2 seconds?
- Does the menu bar icon communicate "this is watching background tasks"?
- Does the default window size show me enough?
- Are empty states informative or scary?
- Does it feel like a 2026 native macOS app, not a debug TUI?

Functional ACs (does it crash? does the action fire?) cannot answer any of these. We need a **separate review pipeline** that:
1. Captures real screenshots from real interactions (menu bar click, window resize, etc.)
2. Scores them against a design rubric
3. Files actionable tickets back into the milestone plan

## Three-layer architecture

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: ui-critic agent                                │
│   Reads screenshots → scores rubric → writes tickets    │
│   Runs after TESTING in every milestone                 │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ PNGs + metadata
                          │
┌─────────────────────────────────────────────────────────┐
│ Layer 2: AgentJobsVisualHarness (Swift library target)  │
│   • Snapshot:           NSHostingView → PNG             │
│   • MenuBarInteraction: AX-locate + CGEvent click       │
│   • WindowInteraction:  resize, scroll, type, click     │
│   • CritiqueReport:     PNG + JSON metadata sidecar     │
│   Reusable from tests AND from CI screenshot scripts    │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ APIs
                          │
┌─────────────────────────────────────────────────────────┐
│ Layer 1: AgentJobsCore + AgentJobsMac (production)      │
│   Unchanged. Visual harness reads, never mutates.       │
└─────────────────────────────────────────────────────────┘
```

## Layer 2 — `AgentJobsVisualHarness` SwiftPM target

New library target alongside `AgentJobsCore` and `AgentJobsMac`. Code lives at `macapp/AgentJobsMac/Sources/AgentJobsVisualHarness/`.

### Modules

- **`Snapshot.swift`** — `func snapshot(_ view: some View, size: CGSize, scheme: ColorScheme) -> NSImage` (already exists in tests, lift here)
- **`MenuBarInteraction.swift`** — `func locateAgentJobsMenuExtra() throws -> CGRect` via AXUIElement; `func clickMenuExtra() throws` via `CGEventCreateMouseEvent`; `func dismissPopover()`
- **`WindowInteraction.swift`** — `func locateMainWindow() throws -> NSWindow?`; `func resizeMainWindow(to: CGSize)`; `func scrollList(by: Int)`; `func clickRow(at: Int)`
- **`CritiqueReport.swift`** — `struct Critique { name, kind (popover/dashboard/inspector/menubar), png URL, metadata: [String: String] }`; writes paired `.png` + `.json` so ui-critic agent has structured context
- **`DiffReport.swift`** — wraps `scripts/visual-diff.sh` calls, returns structured diff summary

### Why a separate library target

- Tests can import it (replaces ad-hoc snapshot helpers in `Tests/.../Visual/`)
- A standalone `swift run AgentJobsVisualHarness capture-all` CLI can produce the full screenshot set on demand for design review (and CI)
- ui-critic agent invokes that CLI rather than hand-running tests

### Public CLI

```
swift run capture-all --out .workflow/m{N}/screenshots/critique/
  → produces:
    01-menubar-icon.png + .json
    02-popover-default.png + .json
    03-popover-empty-state.png + .json
    04-popover-error-state.png + .json
    05-dashboard-1024x768.png + .json
    06-dashboard-1440x900.png + .json
    07-dashboard-resized-min.png + .json
    08-inspector-row-selected.png + .json
    09-confirm-stop.png + .json
    10-hidden-toggle-on.png + .json
```

Each `.json` carries: timestamp, app version, OS version, scheme, scenario name, dataset hash. ui-critic uses the metadata to score consistently.

> **Canonical sidecar schema (M07 WL-D):** the impl-side field names are authoritative — `scenarioName`, `appCommit`, `colorScheme`, `viewportWidth`/`viewportHeight`. Earlier proposal-only short forms (`scenario`, `commit`, `scheme`, `width`, `height`) are NOT adopted; do not introduce them in tooling or tests.

## Layer 3 — `ui-critic` agent

New agent at `.claude/agents/ui-critic.md`. Trigger points:

1. **After TESTING phase, before ACCEPTED** — runs critique on the milestone's `screenshots/critique/` set. If P0 issues found, can REJECT the milestone (but only on visual P0s — a milestone can otherwise be functionally green and visually broken).
2. **As a one-off via `/ui-review`** — for ad-hoc design audits (like the one you just did manually).

### Rubric (6 axes, 0-5 each, 30 max)

| Axis | What it scores | P0 trigger |
|---|---|---|
| **Clarity** | Can a new user identify what each element is in 2s? | Row name unreadable / icon meaningless |
| **Density & Hierarchy** | Is the most important info biggest/most prominent? | Critical info hidden / wasted whitespace |
| **Identity** | Does it look like one cohesive product, native to macOS 14? | Mixed metaphors / non-native chrome |
| **Affordance** | Are interactive elements discoverable and obviously clickable? | Hidden actions / mystery icons |
| **Empty & Error states** | Do zero-data and failure cases inform vs. scare? | Blank pane / raw error string |
| **Novelty / Polish** | Does it feel modern, considered, delightful? | Looks like a 2010 Cocoa app |

Score < 21/30 → can REJECT. Each missed axis writes a ticket to `.workflow/DESIGN-TICKETS.md`.

### Output: `.workflow/m{N}/ui-review.md`

```markdown
# M{N} UI Review (ui-critic)

**Captured:** ISO8601, app commit XXXXXX
**Scenarios:** N PNGs

## Score: X/30

| Axis | Score | Notes |
|---|---|---|
| Clarity | 3/5 | row names show launchd Label, not the program |
| ... |

## Tickets filed
- T-042 (P0, M+1): popover row needs program subtitle + status pill
- T-043 (P1, M+2): menu bar icon should badge running count

## Verdict: PASS / REQUEST_CHANGES
```

## Living document: `.workflow/DESIGN-TICKETS.md`

Append-only ticket log. Each ticket:

```
- [ ] T-NNN  P{0-2}  {scope}  {one-line title}
       Source: {ui-critic|user|retro}  Filed: ISO8601  Target: M{X}
       Why: {1-2 sentences}
       Done-when: {acceptance hint for the milestone PM}
```

PM agent reads this when speccing each milestone — open P0 tickets must be addressed in the next milestone or explicitly deferred with reason.

## Workflow integration

```
... → IMPLEMENTING → REVIEWING → TESTING → UI-CRITIC → ACCEPTED → SHIP
                                              │
                                  PASS  ──────┤
                                              │
                                  REJECT ─────┴──→ IMPLEMENTING (cycle++)
```

Phase machine in `PROTOCOL.md` gains one transition. ui-critic gets its own lock (60min TTL — capturing + reviewing 10 PNGs takes time).

## Migration plan

- **M05** introduces `AgentJobsVisualHarness` library + `MenuBarInteraction` (was tonight's gap)
- **M05** also seeds `DESIGN-TICKETS.md` with the 6 user-filed P0s from 2026-04-27
- **M06** is the first milestone with the ui-critic gate active
- M02-M04 baselines stay as-is (don't retrofit); ui-critic backfills critiques for them as historical record only
