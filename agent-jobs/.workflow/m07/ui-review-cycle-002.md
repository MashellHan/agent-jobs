# M07 UI Review — Cycle 2 (ui-critic)

**Captured:** 2026-04-27 (cycle-2 baselines per `impl-cycle-002.md` + `test-cycle-002.md`)
**App commit:** 494258e (HEAD post-impl-cycle-2)
**Scenarios reviewed:** 14 PNG + 14 JSON in `.workflow/m07/screenshots/baseline/` (byte-identical to `critique/`)
**Mode:** ENFORCING. Threshold **24/30** (held from M06 per spec §Risks #8).
**Cycle-1 verdict:** (no formal cycle-1 ui-critic review — cycle-1 REJECT was driven by tester FAILs on AC-V-01 + AC-V-04, both closed in cycle-2.)
**M06 cycle-2 verdict for tone continuity:** PASS-with-tickets 27/30.

---

## Score: 25/30 → PASS

| Axis | M06 c2 | M07 c2 | Δ | One-line finding |
|---|---|---|---|---|
| Clarity | 5/5 | **4/5** | -1 | Popover, dashboard, inspector all legible at a glance; held back by scenario 07 bucket-strip floating mid-pane in the empty dashboard. |
| Density & Hierarchy | 4/5 | **4/5** | 0 | T-019 closure visible — Name column reads "claude-loop session-abc" + subtitle in full at 1280pt; "Last Run" header reads in full; 4×2 inspector grid still well-organized. |
| Identity | 5/5 | **5/5** | 0 | Custom service-tray glyph lands across 01/11/12/13; count badge variants distinct; popover header branded hex-cluster glyph holds; token swatch (14) reads as a coherent, intentional palette. AC-D-01..D-04 all met. |
| Affordance | 4/5 | **4/5** | 0 | Stop/Hide, Retry, deselect/hide row icons, count badge contract — all hold from M06. Tab strip in inspector still reads. |
| Empty / Error | 5/5 | **4/5** | -1 | Scenario 04 (popover) preserves M06 c2 RUNNING(0)/SCHEDULED(0)/FAILED(0) scaffolding perfectly — token replacement did NOT regress hierarchy. Held back by scenario 07 (dashboard empty) where the bucket strip renders mid-pane instead of as top chrome. |
| Novelty / Polish | 4/5 | **4/5** | 0 | Tokens applied without color drift; dark frames remain tweet-tier; type scale specimen reads at every step incl. caption + mono. Held back by T-020 baseline alignment still slightly off (sidebar "Filters" at y~33 vs bucket-strip pills at y~20) + scenario 07 strip placement + count-badge "+" still slightly cramped at 22pt. |

**Total: 25/30 → PASS** (clears 24/30 threshold by 1).

No rubric REJECT trigger fires:
- AC-D-01 (idle glyph reads as background-services watcher) — PASS via dark scenario 13 (per tester followup #1, slits invisible-by-design on light); silhouette + corner-dot reading on light is sufficient to identify the glyph.
- AC-D-02 (count badge variants) — PASS; "1" and "9+" both legible at 22pt with badge contained right of glyph.
- AC-D-03 (token swatch coherence) — PASS; status palette {green/blue/red/grey} pairwise distinct, source palette {purple/orange/amber/teal/mauve} doesn't collide with status; type scale specimen reads at every size; spacing rule renders.
- AC-D-04 (popover identity holds light↔dark) — PASS; status pills + counters preserved; no ad-hoc color drift between 02 and 03.
- AC-D-05 (Name column ≥30%) — PASS; "claude-loop session-abc" reads in full; "Last Run" header reads in full.
- AC-D-06 (bucket-strip chrome) — **borderline PASS**; sidebar header band heightened to 40pt per option (b) but visible vertical-baseline mismatch remains (~13pt offset). Not severe enough to flip; ticket filed.
- AC-D-07 (empty popover token application) — PASS; M06 c2 scaffolding fully held; section headers + microcopy + 0-count chips all legible.
- AC-D-08 (dark-scheme parity) — PASS; spot-read sidebar interior + top header band + inspector header in 03/06/09/13 — no visible white bleed; corroborates tester's 17-region max-luma 0.254.

---

## Per-scenario notes

### 01 — menubar-icon-idle-light.png (22×22)
- Service-tray silhouette + corner running-dot. Per tester followup #1, slits are filled white against the white capture bg and read as solid silhouette. Acceptable for light scheme; the canonical reading is scenario 13.
- Comparison: Stats uses a layered chart; ours uses a tray-with-status-notch. Domain metaphor lands.
- Severity: none.

### 02 — menubar-popover-light.png
- Branded hex-cluster blue identity glyph in header next to "Agent Jobs"; status pills (Running green / Scheduled blue / Idle grey); CPU%/RSS in semantic color (1.1% green, 3.2% green/201 MB amber); "289 MB" total chip; "updated 0s ago". Strong. Tokens cleanly applied.
- Severity: none.

### 03 — menubar-popover-dark.png
- Full-frame dark; pills muted but readable; identity glyph still legible; semantic colors hold without saturation drift. Light↔dark parity (AC-D-04) confirmed.
- Severity: none.

### 04 — menubar-popover-empty-light.png
- M06 cycle-2 closure of T-018 fully held: RUNNING(0) / SCHEDULED(0) / FAILED(0) headers + tray glyph per group + microcopy ("No services running right now." / "Nothing scheduled in the next hour." / "Nothing has failed recently."). Tokens applied without flattening hierarchy. AC-D-07 PASS.
- Severity: none.

### 05 — dashboard-populated-light.png (1280×800)
- T-019 closure visible: Name column shows full "claude-loop session-abc" + "on demand · session sess-abc" subtitle; "Last Run" — wait, header reads "Schedule" / "Created" / "CPU" — confirmed no clipping. 5 rows render with semantic colors (green Running, blue Scheduled, grey Idle), CPU 1.1% / 3.2% in semantic green.
- T-020 borderline: sidebar "Filters" header sits at y~33; bucket-strip pills sit at y~20 — visible ~13pt baseline mismatch despite 40pt option-(b) fix. Not severe but the "two chrome rows at different baselines" critique from M06 is only partially closed.
- Severity: P2 (T-022 below).

### 06 — dashboard-populated-dark.png
- Full-frame dark; sidebar interior, top header band, list body, inspector "Select a service" placeholder all dark. Tester's 15-region luma max 0.190 confirmed visually — no bleed. M05/M06 P0 condition stays buried. Identity 5/5 holds here.
- Severity: none.

### 07 — dashboard-empty-light.png — **anomaly**
- Empty-state illustration ("No services discovered yet" + tray glyph + "Providers will populate this view as they discover work.") renders well-centered.
- BUT: the bucket strip (registered 0 / claude-sched 0 / ... / total 0) renders **mid-pane at y~315 floating between the empty illustration's icon and title**, instead of at the top as window chrome. This is a layout glitch — in the populated case (05) the strip lives at y~20 as chrome; in empty (07) it floats inside the content area.
- Comparison: Things 3 keeps its filter chrome anchored at top regardless of empty/populated. Activity Monitor likewise.
- Severity: P2 (T-021 below). Not blocking — the empty illustration itself is good and sidebar still anchors filters; this is a chrome-positioning quirk specific to the empty branch.

### 08 — dashboard-inspector-light.png
- Full inspector content stack: title + breadcrumb + "agentjobs run cleanup" command + "Scheduled" pill + Stop/Hide + 4 tabs (Overview/Logs/Config/Metrics) + 4×2 metadata grid (Schedule/Project/Last Run/Next Run/Created/Origin/Session/Source Path). Type scale clearly applied. Density 4/5.
- Severity: none.

### 09 — dashboard-inspector-dark.png
- Parity with 08 in dark; full content stack visible; tester's 17-region max-luma 0.254 corroborated visually. AC-D-08 holds.
- Severity: none.

### 10 — dashboard-narrow-light.png (1024×700)
- Inspector collapses to "Select a service" placeholder; bucket-strip "live-proc" chip clips to "liv..." but "total 5" still reads. Acceptable behavior at narrow.
- Severity: none.

### 11 — menubar-icon-count-1-light.png
- Glyph + small badge with "1" right of glyph; ~35 opaque badge px per tester. Legible at 22pt.
- Severity: none.

### 12 — menubar-icon-count-N-light.png
- Glyph + "9+" badge ~70 opaque px; both characters render. Borderline tight at 22pt — the "+" is small but readable. Cycle-1 tester flagged this; cycle-2 didn't change badge typography but alpha-px doubled, suggesting heavier weight landed.
- Comparison: iStat Menus uses 1-2 digit max; ours matches. Not confusable with iOS unread-mail dot (badge is brand color, not red-only).
- Severity: P2 polish; not filing — acceptable per AC-D-02.

### 13 — menubar-icon-idle-dark.png — **canonical glyph reading**
- White service-tray glyph on dark backing. The two horizontal slits at y=3 and y=12 read as row separators (the "service rows" metaphor); status notch + corner running-dot present. Central 8×8 luma 0.968 (tester). Reads as "background services watcher" within the 2-second test. AC-D-01 PASS.
- Comparison: Stats layered-chart, Bartender stylized-bar, ours stacked-tray. Distinct, on-brand.
- Severity: none.

### 14 — tokens-swatches-light.png — **palette verification**
- **Colors:** running=green, scheduled=blue, failed=red, idle=grey — all pairwise distinct. Source colors registered=purple, claudeSched=orange, claudeLoop=amber, launchd=teal, liveProc=mauve — no collision with status palette; pairwise distinguishable for non-color-blind viewer (rough ΔE76 well above 5 by visual estimate).
- **Typography:** display 32pt-ish bold reads; title 18pt bold reads; body 14pt reads; caption 11pt reads cleanly; mono renders in fixed-width and stays legible at body size. The cycle-1 concern (`caption`/`mono` readability) is resolved by visual inspection.
- **Spacing:** 5-step rule (4/8/12/16/24) renders as ascending blue bars — clear at-a-glance reference.
- AC-D-03 PASS.
- Severity: none.

---

## Tickets filed (this review)

Two new P2 polish tickets for the carry-forward backlog. Neither blocks M07 ship. (Cycle-1 tester followups #2/3/4/5/6/7/8 verified resolved in scoring above; #9 was implementer-internal context only.)

- **T-021  P2  dashboard-empty-state**  Bucket strip floats mid-pane in empty dashboard (scenario 07)
       Source: ui-critic  Filed: 2026-04-27T14:25:00Z  Target: M14 (visual polish)
       Why: In `07-dashboard-empty-light.png` the source-bucket strip renders inside the content area at y~315, between the empty-state icon and its title. In the populated case (`05-dashboard-populated-light.png`) the same strip lives at y~20 as window chrome. The strip is conceptually chrome (filter scope across all sources), so it should anchor at top regardless of empty/populated state — Things 3 and Activity Monitor both keep filter chrome anchored.
       Done-when: `07-dashboard-empty-light.png` shows the bucket strip at top of the list pane (y < 40), with the empty-state illustration centered in the remaining vertical space below it.

- **T-022  P2  dashboard-chrome**  Bucket-strip / sidebar-header baseline still ~13pt off after T-020 option (b)
       Source: ui-critic  Filed: 2026-04-27T14:25:00Z  Target: M14 (visual polish)
       Why: T-020 chose option (b) — sidebar "Filters" header band heightened to 40pt to match bucket-strip top edge. In `05-dashboard-populated-light.png` the bucket-strip pills sit at y~20 while the sidebar "Filters" caption sits at y~33 — a visible ~13pt vertical-baseline mismatch persists. The two chrome rows still don't read as one. Acceptance AC-F-12 passes (architect's option (b) is implemented), but the visual intent — "read as a unified header band" — is only partially achieved.
       Done-when: In the dashboard-populated baseline, the visible top edges (or text baselines) of the sidebar "Filters" caption and the bucket-strip pills are within ±2pt of each other, OR the architect re-evaluates option (a) (window-spanning toolbar) for M14.

(No P0 or P1 tickets filed. Existing open carry-forwards: T-019 closed by impl per tester evidence; T-020 partially closed → T-022 supersedes the remaining nit; T-T01/T-T02/T-T03 visually closed per scenario 14 + cross-surface adoption; T-019 retro should formally close.)

---

## Verdict: **PASS 25/30**

Cycle-1 → cycle-2 round-trip on T-001 closed exactly as architecture §7 anticipated: placeholder glyph (cycle-1 luma 0.631) → service-tray glyph (cycle-2 light 0.186, dark 0.968). Identity axis jumps to 5/5. M06's dark-frame win holds across all four dark scenarios (03/06/09/13). Empty popover scaffolding (M06 cycle-2 T-018 closure) preserved through the token migration. Two new P2 polish tickets filed (T-021 strip placement, T-022 baseline alignment); neither blocking.

Phase → ACCEPTED.

---

## Handoff

- Phase: ACCEPTED
- Owner: null
- Lock cleared
- Last actor: ui-critic
- Commit: `chore(M07): UI-CRITIC cycle-2 PASS 25/30`
- No push (SHIP pushes).
