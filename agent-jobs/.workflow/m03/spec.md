# M03 — Actions (stop / hide / refresh)

## Goal (one sentence)

Give users three direct actions on every discovered service — **Stop** (graceful SIGTERM / `launchctl unload`), **Hide** (durable client-side mute), and **Refresh** (force re-discovery) — wrapped in macOS-native confirmation and safety rails so a misclick cannot kill the user's shell, init, or AgentJobs itself.

## User value (why now)

Today, a developer running multiple AI-coding-agent loops sees rows but cannot do anything with them; agent-jobs is a strictly-read-only telescope. Users have to drop to Terminal (`launchctl unload`, `kill`) and re-trigger discovery by quitting/relaunching the app. That breaks the "single pane of glass" promise of the product and means users keep the old TUI / shell aliases around. M03 closes the loop: **see → decide → act**, without leaving the menu bar.

Stop is the headline action; hide solves the secondary annoyance ("I know about this row, stop showing it to me") that otherwise drives users to write filter shell-aliases; refresh removes the only justification users have to quit-and-relaunch the app.

## Scope (in)

1. **Stop action** — graceful termination per source:
   - Live processes (`ServiceSource.process`): `kill(pid, SIGTERM)`. No SIGKILL in M03.
   - launchd (`ServiceSource.launchdUser`): `launchctl unload <plist-path>` via `Shell`. The plist path comes from the existing `LaunchdPlistReader` mapping (label → plist URL); if absent, the action is unavailable (button disabled, tooltip explains).
   - All other sources (`agentJobsJson`, `claudeScheduledTask`, `claudeLoop`): action unavailable in M03 — button rendered but disabled with tooltip "Stop not supported for {source}". Not a no-op error — visibly grayed.
   - Confirmation dialog (`.confirmationDialog`, destructive role) before sending; default button is **Cancel**, destructive button is **Stop**. Dialog body shows service name, source, command (truncated), and PID/label.
   - After confirm: action runs through `StopExecutor` (protocol — see Safety rules below). On success, view model marks the service `.idle` optimistically; the next `discoverAll()` reconciles. On failure, an inline `ErrorBanner`-style row error renders for ≥4s with the underlying message.

2. **Hide action** — durable client-side mute:
   - Click "Hide" on a row → service id added to a `Set<String>` persisted at `~/.agent-jobs/hidden.json` (atomic write: write to `hidden.json.tmp` → `rename(2)`).
   - Hidden rows are removed from `filteredServices` by default.
   - Dashboard toolbar gets a **Show hidden** toggle (`Toggle` + label, off by default). When on: hidden rows are reincluded with a visual de-emphasis (50% opacity) AND an "Unhide" button replaces "Hide" in their action stack.
   - No confirmation for hide / unhide — it's reversible.
   - File schema: `{ "version": 1, "hiddenIds": ["<id>", ...] }`. Unknown versions are ignored (logged) and a fresh empty file is rewritten on first hide.

3. **Refresh action** — manual force-rediscovery:
   - Toolbar button (refresh SF Symbol). On tap: triggers `ServiceRegistryViewModel.refreshNow()` which calls `registry.discoverAll()`.
   - While in flight: button is `.disabled(true)` AND a spinner (`ProgressView()`) replaces or sits adjacent to the icon.
   - The existing `AutoRefreshIndicator` is reused; manual refresh marks it active for the duration.
   - No confirmation — reads only.

4. **Action button placement** — the "row hover vs inspector vs both" fork:
   - **Decision: BOTH, with the inspector as primary.** Inspector shows a horizontal action bar at the top (right of the title). Row-hover shows a compact icon-only stack (Stop / Hide) on the right side of the row, only when the pointer is over that row, mirroring the Linear / Things pattern.
   - Refresh lives ONLY in the dashboard toolbar (not per-row — it's a global action).
   - Show-hidden toggle lives ONLY in the dashboard toolbar.

5. **Safety rails (MANDATORY)** — see Safety rules section.

6. **Visual baselines** for the new affordances — confirm dialog open state, show-hidden toggle on/off, disabled action button states, refresh-in-flight spinner.

## Out of scope (explicit non-goals)

- SIGKILL / Force-Stop. M03 is graceful-only.
- Restart action. Slated for a later milestone — would need to durably persist plist/json source so we can re-load it.
- Bulk actions (multi-select stop/hide). Single-row only in M03.
- Undo for hide beyond toggling Show-hidden + clicking Unhide. No history stack.
- Sync of `hidden.json` across machines. Local file only.
- Auto-refresh tuning / fs.watch. That is M04.
- Remote / cross-machine action dispatch.
- Action audit log / history pane. Errors render transiently; no permanent log surface in M03.

## Constraints (tech, time, dependencies on other milestones)

- Must NOT regress M02's 26 ACs. The `SourceBucketStrip`, inspector, and dashboard layout stay as-is; we are adding affordances within them.
- Discovery layer (M01 / M01.5) is FROZEN — actions live in a new layer (`AgentJobsCore/Actions/`) that consumes existing `Service` objects but does not modify provider code.
- Tests MUST NOT actually kill processes nor mutate launchd. `StopExecutor` protocol with a `FakeStopExecutor` for tests; production wires `RealStopExecutor` (which under `#if DEBUG` and `AGENTJOBS_TEST=1` env still refuses to act). Tester baseline is the fake.
- `~/.agent-jobs/hidden.json` write must be atomic (temp + rename) so an interrupted write cannot leave a corrupt file mid-launch.
- No new third-party deps. Use Foundation `Process`, `FileManager`, and Darwin `kill(2)` for live processes.
- Visual-test harness from M02 (`NSHostingView` + `scripts/visual-diff.sh`) is reused as-is for the four new visual ACs.
- Activation-policy + main window plumbing from M02 stays unchanged.

## User stories

- **U1.** As a developer with three abandoned `claude` background loops, I open the dashboard, hover a row, click Stop, confirm, and the loop is gone next refresh — without opening Terminal.
- **U2.** As a user with a launchd job I never want to see, I click Hide. It disappears. A week later I want to bring it back; I flip "Show hidden", click Unhide on the dimmed row.
- **U3.** As a user who just edited a `~/.agent-jobs/jobs.json` manually, I click Refresh and immediately see my edit reflected, with a spinner so I know the app is working.
- **U4.** As a clumsy user, I click Stop on the wrong row. The confirmation dialog catches me; I click Cancel; nothing happens.
- **U5.** As a security-paranoid user, I'm assured the app cannot be tricked into killing PID 1 or its own process — even if a corrupt provider returns a malformed `Service`.

## UX details

### Row-hover action stack
- Right-aligned `HStack` of icon-only `HoverableIconButton`s (reuses existing M01.5 component): `[Stop, Hide]` for non-hidden rows, `[Stop, Unhide]` for hidden rows when Show-hidden is on.
- Stop button uses `xmark.octagon` SF Symbol with red tint, disabled (gray) when `service.canStop == false`.
- Hide uses `eye.slash` for hide, `eye` for unhide.
- Tooltips on every state, including the disabled reason ("Stop not supported for claude-scheduled task").
- Buttons appear only on hover OR when the row is selected (so keyboard nav still discloses them).

### Inspector action bar
- Above the existing tab chip row, right-aligned, mirrors the row-hover icon stack but with text labels: **Stop** / **Hide** (or **Unhide**).
- Same disabled / tooltip semantics.

### Dashboard toolbar
- Existing leftward content (sidebar split) preserved.
- Add right-aligned trailing toolbar group: `[Show hidden Toggle] [Refresh button]`.
- Refresh button shows a spinner inside (or beside) it while `isRefreshing == true`; disabled during.

### Confirmation dialog
- SwiftUI `.confirmationDialog("Stop {service.name}?", isPresented:, titleVisibility: .visible)`.
- Body text: "This will send SIGTERM to PID {pid}." (live-process variant) or "This will run `launchctl unload {plist}`." (launchd variant).
- Buttons: `Button("Stop", role: .destructive) { ... }` then `Button("Cancel", role: .cancel) {}`. SwiftUI puts Cancel as default automatically given `.cancel` role.

### Visual feedback for failure
- Stop failure: row gains a red border for 4s + a one-line error caption underneath the row in the table cell renderer (or, if inspector is open for that row, an `ErrorBanner` at the top of the inspector content area). Auto-dismisses.

### Empty / edge states
- All rows hidden + Show-hidden off → `ContentUnavailableView("All services hidden", systemImage: "eye.slash", description: Text("Toggle Show hidden to see them."))`.

## Data flow

```
User click ─► DashboardView (or ServiceInspector)
                │
                │  intent: .stop(serviceId) | .hide(serviceId) | .unhide(serviceId) | .refresh
                ▼
       ServiceRegistryViewModel  ──── (for .stop) ──► confirmationDialog binding flips
                │                                                  │
                │                                                  │ user taps Stop
                │                                                  ▼
                │                                       StopExecutor.stop(service:) async throws
                │                                                  │
                │                                                  ▼
                │                              [Real]  Darwin kill(pid,SIGTERM) | Shell launchctl unload
                │                              [Fake]  records call, returns Result per scripted plan
                │                                                  │
                │ ◀────────────── result (success | error) ────────┘
                │
                │  optimistic mutate (.idle) on success
                │  errorByServiceId[id] = msg on failure (auto-clears in 4s)
                │
                │  for .hide / .unhide:
                ▼
       HiddenStore (actor) ──► reads/writes ~/.agent-jobs/hidden.json (atomic)
                │
                │  publishes Set<String> via @Observable
                ▼
       DashboardView.filteredServices = base
           .filter { showHidden ? true : !hiddenIds.contains($0.id) }
           .filter(category) .filter(bucket)

       for .refresh:
       ServiceRegistryViewModel.refreshNow()
           sets isRefreshing = true
           awaits registry.discoverAll()
           sets isRefreshing = false
```

## Safety rules (BINDING — Tester verifies, Reviewer reads code path)

`RealStopExecutor.stop(service:)` MUST refuse and throw `StopError.refused(reason:)` when ANY of the following holds, **before** invoking `kill(2)` or `Shell`:

1. `service.pid == 0` → reason `"PID 0 is the kernel scheduler"`.
2. `service.pid == 1` → reason `"PID 1 is launchd; refusing"`.
3. `service.pid == ProcessInfo.processInfo.processIdentifier` → reason `"refusing to kill self"`.
4. `service.source` is `.process` and `pid == nil` → reason `"no PID to send SIGTERM"`.
5. `service.source` is `.launchdUser` and the resolved plist URL is `nil` (LaunchdPlistReader cannot find it) → reason `"plist path unknown; cannot launchctl unload"`.
6. `service.source` is one of `.agentJobsJson, .claudeScheduledTask, .claudeLoop, .cron, .at, .brewServices, .loginItem` → reason `"stop not implemented for {source}"`.

These six refusals MUST be unit-testable WITHOUT touching the OS (no `Process` invocation reachable from the test).

`canStop` is a pure derived property on `Service` that returns `false` when any refusal predicate trips, so the UI can pre-disable the button and skip showing the confirmation dialog entirely. The executor still rechecks at action time (defense in depth).

## Open questions for architect

1. **Where does `HiddenStore` live?** Recommendation: `AgentJobsCore/Persistence/HiddenStore.swift` as an `actor`, exposed to UI via the `ServiceRegistryViewModel` (which holds the `@Observable` mirror of the set). Keeps the Core layer durable and the UI dumb.
2. **Does `StopExecutor` belong in Core or Mac?** Recommendation: Core (`AgentJobsCore/Actions/StopExecutor.swift`) so unit tests can exercise refusal logic without importing AppKit. The `Shell` invoker (already Core) handles `launchctl`.
3. **Inspector action bar vs contextual menu vs both** — spec already commits to row-hover + inspector. Architect should confirm SwiftUI Table row-hover + selected-state can both reveal the action stack on macOS 14 (we believe yes via `.onHover` per row content; if not, fall back to selected-state-only and document).
4. **Optimistic UI vs await-then-render** — spec commits to optimistic (`.idle` immediately on stop success, reconciled on next discover). Architect to confirm no race against an in-flight auto-refresh writing the still-running state back.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `kill(2)` race: PID is reused by an unrelated process between discovery and click | High | Re-fetch PID from `LsofProcessProvider` slice immediately before sending SIGTERM (≤ 200ms staleness). If it changed, refuse and tell user to refresh. |
| `launchctl unload` requires sudo for some plists | Medium | Detect non-zero exit; surface stderr in the row error. We do NOT prompt for sudo in M03 — out of scope. |
| `~/.agent-jobs/hidden.json` corrupted by external editor | Low | JSON decode failure → log + treat as empty set + rewrite on next hide. Don't crash. |
| Test harness accidentally wired to RealStopExecutor | Critical | `RealStopExecutor` short-circuits with a fatalError when `ProcessInfo.processInfo.environment["AGENTJOBS_TEST"] == "1"`. Belt + braces with the protocol injection. |
| Visual baseline flakiness on confirmation dialog (NSAlert vs SwiftUI dialog rendering jitter) | Medium | Use SwiftUI `.confirmationDialog` rendered into the in-process `NSHostingView` harness, not a real NSAlert. Document in baseline test that we capture the SwiftUI dialog content view, not the system alert chrome. |
