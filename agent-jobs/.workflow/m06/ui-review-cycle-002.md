# M06 UI Review — Cycle 2 (ui-critic)

**Captured:** 2026-04-27 (cycle-2 baselines per `impl-cycle-002.md`)
**App commit:** post-cycle-2 implementer (T-017 P0 + T-018 P1 closed)
**Scenarios reviewed:** 10 PNG + 10 JSON in `.workflow/m06/screenshots/baseline/` (byte-identical to `critique/`)
**Mode:** ENFORCING (M06 is the first milestone where visual P0 can REJECT). Threshold raised to **24/30** per spec.
**Cycle-1 verdict:** REJECT 20/30 (AC-D-07 white-bleed trigger fired; Empty/Error 2/5).

---

## Score: 27/30 -> PASS-with-tickets

| Axis | Cycle-1 | Cycle-2 | Delta | One-line finding |
|---|---|---|---|---|
| Clarity | 4/5 | **5/5** | +1 | Popover and dashboard both legible at a glance; dark inspector now exposes the full friendly title + breadcrumb + command stack. |
| Density & Hierarchy | 4/5 | **4/5** | 0 | Unchanged — popover groups + count chips still strong; Name column still ~80pt at 1280pt (T-019 deferred). |
| Identity | 3/5 | **5/5** | +2 | Dark dashboard 05 + dark inspector 08 are now fully dark-themed, including sidebar interior + top header band + inspector chrome. Reads as a 2026 Mac app, on par with Linear / Things. |
| Affordance | 4/5 | **4/5** | 0 | Retry on FAILED row, Stop/Hide on inspector, deselect+hide row icons all hold. Unchanged. |
| Empty/Error | 2/5 | **5/5** | +3 | Empty popover (03) restored to RUNNING(0) / SCHEDULED(0) / FAILED(0) scaffolding with per-section microcopy ("No services running right now." / "Nothing scheduled in the next hour." / "Nothing has failed recently.") — strictly better than M05's two-section version. |
| Novelty / Polish | 3/5 | **4/5** | +1 | Popover continues to be screenshot-worthy; dark frame is now tweet-tier. Held back from 5/5 only by Name column truncation + bucket-strip header alignment (T-019, T-020, both P2). |

**Total: 27/30. Rubric REJECT trigger AC-D-07 cleared.** Tester's expanded 30-point luma sample (max 0.221, threshold 0.3) corroborates the visual read: scenarios 02/05/08 are now uniformly dark with no white-bleed in any region (corners, top header band, sidebar interior, inspector pane).

---

## Per-scenario notes

### 01-menubar-popover-light.png — clean (held)
- Three groups (RUNNING(2) / SCHEDULED(2) / OTHER(1)), count chips, semantic CPU/RSS colors, "289 MB" total chip, "updated 0s ago" + refresh. Identical to cycle-1.
- Severity: none.

### 02-menubar-popover-dark.png — clean (held)
- Full-frame dark; pills muted-but-readable; hierarchy preserved. Identical to cycle-1.
- Severity: none.

### 03-menubar-popover-empty-light.png — **FIXED** (T-018 closed)
- Now renders RUNNING(0), SCHEDULED(0), FAILED(0) section headers with per-section empty microcopy and tray glyph per group. Header chips show "0 running"/"0 scheduled"/"Zero KB". Strictly better than the cycle-1 single-line empty state, and at least on par with M05's two-section version (we added FAILED).
- Comparison: matches Things 3 grouped-empty pattern; better than Activity Monitor (which has no empty state).
- Severity: none. T-018 visually verified (note for retro: safe to close).

### 04-dashboard-populated-light.png — major win held; carry-forward polish
- Unchanged from cycle-1 (light-mode regressions explicitly avoided per impl-cycle-002.md). 5 rows render, horizontal bucket strip, Name column still tight (~80pt), "Last R..." header still clipped at 1280pt.
- Severity: P2 (T-019 / T-020 — deferred to M07; non-blocking).

### 05-dashboard-populated-dark.png — **FIXED** (T-017 P0 closed)
- Sidebar pane: dark. Top header band (bucket strip): dark. List body: dark with semantic-color CPU/Memory still readable. Inspector pane: dark, with "Select a service" placeholder rendered in the dark surface (icon + bold title + subtle subtitle).
- The cycle-1 P0 condition (light sidebar, white top band, blank inspector) is gone. Tester's 30-point luma sample (max 0.221) confirms no bleed anywhere in the frame.
- Comparison: now on par with Linear / Things 3 / Bartender for dark-frame coverage.
- Severity: none.

### 06-dashboard-empty-light.png — clean (held)
- Empty list state, dimmed-zero chips, sidebar with "0" counts. Same minor strip-alignment quibble as 04 (T-020 P2).
- Severity: none.

### 07-dashboard-inspector-light.png — exemplary (held)
- Full inspector content: title + monospace subtitle + breadcrumb + command + status pill + Stop/Hide + 4 tabs + 4×2 metadata grid; row deselect/hide inline icons.
- Severity: none.

### 08-dashboard-inspector-dark.png — **FIXED** (T-017 P0 closed)
- The single most-broken cycle-1 PNG is now the second-most-impressive. Inspector pane renders the full content stack on a dark surface: "daily-cleanup" title, "daily at 9am" subtitle, "Agent Jobs (local) · acme" breadcrumb, "agentjobs run cleanup" command, "Scheduled" pill top-right, Stop / Hide row, Overview/Logs/Config/Metrics tabs, and the full 4×2 metadata grid (Schedule / Project / Last Run / Next Run / Created / Origin / Session / Source Path) all dark-themed.
- Sidebar + top header band also fully dark; M05/cycle-1 P0 condition demonstrably eliminated.
- Severity: none. T-017 visually verified (note for retro: safe to close).

### 09-dashboard-narrow-light.png — clean (held)
- 1024×700, all 5 rows render, inspector collapses to "Select a service" placeholder, "live..." chip truncates at right edge with "total 5" still visible.
- Severity: none.

### 10-menubar-popover-with-failure-light.png — exemplary (held)
- FAILED(1) section with red pill + Retry icon, header chips include "1 failed". Unchanged.
- Severity: none.

---

## Why this is PASS-with-tickets, not PASS

Total 27/30 sits in the **PASS** band per the agent rubric (≥25), but the spec threshold for M06 is **24/30 PASS** with 2 carry-forward P2 design tickets (T-019, T-020) still open. That qualifies as PASS-with-tickets — both P0/P1 cycle-1 issues are visually closed, both P2s are deferred-to-M07 by design.

No new tickets filed this cycle. The cycle-1 P2s (T-019 Name column width; T-020 bucket-strip header alignment) remain open as already-tracked carry-forward to M07 (icon + tokens milestone where layout/density work logically lands).

---

## Tickets

- **T-017 P0 visual-harness — Dark dashboard chrome + inspector header bleed** — visually closed in scenarios 05 + 08. (DESIGN-TICKETS.md "Closed" edit deferred to retro per protocol.)
- **T-018 P1 empty-popover — Restore group-header scaffolding** — visually closed in scenario 03. (Same — retro to close.)
- **T-019 P2 dashboard-list — Name column too narrow at 1280pt** — open, deferred to M07.
- **T-020 P2 dashboard-chrome — Bucket-strip header bar does not span sidebar** — open, deferred to M07.
- No new tickets this cycle.

---

## Verdict: PASS-with-tickets

**27/30. AC-D-07 rubric REJECT trigger cleared.** Phase → ACCEPTED, owner=null, last_actor=ui-critic. M06 may proceed to retro/ship. T-017 + T-018 are visually verified closed; retro should formally migrate them to the DESIGN-TICKETS.md Closed section.
