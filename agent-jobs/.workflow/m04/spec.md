# M04 — Auto-refresh + fs.watch

## Goal (one sentence)

Replace the fixed 30-second timer-loop refresh with an event-driven hybrid — `DispatchSource` file watchers on the two source JSON files, an `FSEventStream` directory watcher on `~/.claude/projects/`, and a debounced 10 s `lsof` rescan that pauses when the app's UI is not visible — so a `jobs.json` mutation reflects in the UI within 500 ms, the live-process slice stays fresh on a 10 s budget, and the app stops burning wakeups when the user isn't looking.

## User value (why now)

Today, a developer who edits `~/.agent-jobs/jobs.json` (or whose Node CLI hook writes it) waits up to 30 s for the change to surface in the menu bar — long enough that they distrust the app and re-open the dashboard manually (the M03 Refresh button exists precisely because of this gap). Conversely, the same 30 s loop runs while the user is in another Space with the dashboard hidden, costing CPU wakeups for data nobody is looking at. M04 closes both ends: edits surface within half a second; idle hours cost approximately zero.

This also unblocks M05 (Swift hook migration): the hook will write `jobs.json` and rely on the UI surfacing the write in real time. Without M04, the hook's UX is "save, then click Refresh", which is no improvement over the Node CLI.

## Scope (in)

1. **File watchers** — three watchers, one per source location:
   - `~/.agent-jobs/jobs.json` — `DispatchSource.makeFileSystemObjectSource` on `O_EVTONLY` fd. Atomic-rename safe (re-open on `.delete`/`.rename`).
   - `~/.claude/scheduled_tasks.json` — same pattern.
   - `~/.claude/projects/` — directory-level `FSEventStreamCreate` (recursive, latency 0.25 s). Triggers a single `refresh()` regardless of which `*.jsonl` underneath changed; the existing `ClaudeSessionCronProvider` rescans the latest mtime as it does today. We do NOT install a per-jsonl `DispatchSource` (the directory can hold thousands of files and we'd exhaust the fd budget).

2. **Periodic `lsof` rescan** — fixed 10 s timer-driven full `registry.discoverAll()` (the file-event watchers do not by themselves re-scan live processes, which lsof must enumerate). Pauses when the dashboard window is hidden AND the menu-bar popover is closed; resumes immediately on first visibility, with an immediate catch-up tick.

3. **Debouncing** — every refresh trigger (file event, periodic tick, manual click) is funneled through a single `RefreshScheduler` with a 250 ms trailing debounce. Inputs arriving inside the window collapse to one `discoverAll()`. This guarantees the "save jobs.json from `vim` (which writes 3 swap-related events in ~50 ms)" case fires exactly one refresh.

4. **AutoRefreshIndicator wiring** — extend the existing `AutoRefreshIndicator` (already shipped, `Features/MenuBar/AutoRefreshIndicator.swift`) to render three states driven by the view model rather than its internal clock alone:
   - **idle** — no refresh in flight, no recent error. Shows existing "updated Ns ago" copy.
   - **refreshing** — `discoverAll()` is in flight (regardless of trigger). Pulse animation + "refreshing…" copy.
   - **error** — most recent refresh ended with `result.allFailed == true` OR a watcher could not be installed. Red dot + tooltip naming the failure.
   The indicator must reflect refreshes triggered by file events too, not just by the time-based loop.

5. **No flicker / no scroll loss / no selection loss** — every refresh path must mutate `services` in place (the SwiftUI `Table` keyed by `Service.ID` already preserves row identity). The view model does NOT clear the array first. `Service.ID` stability is a precondition; M01.5 already guarantees it.

6. **Visibility-pause** — observe `NSApplication.didChangeOcclusionStateNotification` and the dashboard `Window`'s `.onChange(of: scenePhase)`. When neither the dashboard window nor the popover is on-screen: cancel the periodic timer (file watchers stay armed — they're event-driven, near-zero cost). On first visibility: kick a single immediate `refresh()` and re-arm the timer.

7. **Test seam** — all watcher inputs MUST be parameterized by a `WatchPaths` struct (`jobsJson: URL, scheduledTasks: URL, claudeProjectsDir: URL`). Production passes `~/...`; tests pass `tempDir/...`. No test may touch the user's real `~/.agent-jobs/` or `~/.claude/`.

## Out of scope (explicit non-goals)

- User-tunable refresh cadence (Settings UI). M06 owns Settings; M04 ships fixed 10 s.
- Per-provider differential refresh (refresh only the lsof slice when only `lsof`'s timer fires). Could halve work but adds slicing complexity; M04 always calls `discoverAll()`.
- File event → which-source-changed routing for telemetry. We log the trigger reason for debugging, but the user-facing indicator is binary (refreshing vs not).
- Watching the launchd plist directories (`~/Library/LaunchAgents/`, `/Library/LaunchAgents/`, `/Library/LaunchDaemons/`). Defer to a later milestone — these directories rarely change in user workflow and would add three more watchers.
- Sparkle / iCloud / cross-machine event propagation.
- Replacing `lsof` with a faster mechanism (e.g., `proc_listpids` + `proc_pidinfo`). Out of scope; we keep the existing provider and bound it with the 10 s pause-when-hidden tick.
- `NSFilePresenter` / `NSFileCoordinator` integration. Heavier than `DispatchSource` for our needs.
- Rate-limiting / circuit-breaking when the watcher fires hundreds of events per second (e.g., a misbehaving editor). The 250 ms debounce is the only protection in M04; if it proves insufficient in M05+ we add a sliding-window cap.

## Constraints (tech, time, dependencies on other milestones)

- Must NOT regress M02's 26 ACs nor M03's 26 ACs. The `SourceBucketStrip`, `ServiceInspector`, action stack, hide store, and stop confirmation all stay byte-identical; the only UI surface change is the indicator's three-state rendering.
- Discovery layer (M01 / M01.5) is FROZEN. Watchers live in a new `AgentJobsCore/Refresh/` layer that calls `registry.discoverAll()` but does not modify provider code.
- The view model's existing `startAutoRefresh()` loop is REPLACED by a new `startWatchers()` entry point; the public method names visible to callers stay (`refresh()`, `refreshNow()`, `stop()`) so M03 call-sites continue to compile. The 30-second `refreshIntervalSeconds` constant is removed (or repurposed as the periodic 10 s for lsof — implementation detail).
- No new third-party Swift package dependency. `DispatchSource`, `FSEventStream`, `Combine` debounce (or a hand-rolled `DispatchWorkItem` debounce — architect's call) are all in the SDK.
- Tests must use `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)` for file paths; CI must show zero writes to `~/.agent-jobs/` or `~/.claude/`. A static-grep test (M03 pattern, `StaticGrepRogueRefs`) asserts no test file string-references those real paths.
- Timing-sensitive ACs (the 500 ms latency bound, the 250 ms debounce) gated behind `AGENTJOBS_PERF=1` per E001; the strict spec assertion is the only one in the test, no relaxed fallback.
- The 10 s tick MUST be cancellable cleanly on app quit so `swift test` does not leak a background `Task`.

## User stories

- **U1.** As a developer, I save `~/.agent-jobs/jobs.json` from my editor. The dashboard updates within half a second; I see the new entry without touching the app.
- **U2.** As a developer, my Claude Code session creates a new background loop (writes a `*.jsonl` line under `~/.claude/projects/`). The dashboard reflects it within ~750 ms (250 ms FSEvents latency + 250 ms debounce + discovery time).
- **U3.** As a laptop user on battery, I tab away from agent-jobs for an hour. During that hour the app does not run lsof (it's paused); when I bring it back, I see fresh data within a second of the window appearing.
- **U4.** As a user, I watch the AutoRefreshIndicator. When a refresh fires (any trigger), it pulses. When all providers fail (e.g., I revoked permissions), it goes red with a tooltip explaining what's wrong.
- **U5.** As a user with the dashboard open and a row selected, the auto-refresh tick runs every 10 s. My selection and my scroll position never jump.

## UX details

### AutoRefreshIndicator three states

| State | Icon | Text | Animation | Trigger |
|---|---|---|---|---|
| idle | `arrow.clockwise.circle` (secondary) | "updated Ns ago" | none | no refresh in flight, last refresh succeeded |
| refreshing | `arrow.clockwise.circle` (accent) | "refreshing…" | `.symbolEffect(.pulse, options: .repeating)` (gated by `accessibilityReduceMotion`) | `viewModel.isRefreshing == true` for any trigger |
| error | `exclamationmark.triangle` (red) | "refresh failed" | none | `viewModel.lastRefreshError != nil` (most recent refresh's `allFailed`, or watcher-install failure) |

The "next in Ns" tail of the existing label is dropped — with event-driven refresh, "next in" is misleading (the next refresh might fire in 9 s OR in 50 ms when a file changes).

The indicator is rendered in BOTH the menu-bar popover (existing M02 location) and the dashboard toolbar (left of the M03 Refresh button), so visibility doesn't depend on which surface the user has open.

### Visibility pause

- Periodic 10 s tick is cancelled when both:
  1. `NSApplication.shared.occlusionState.contains(.visible) == false` for the dashboard `NSWindow`, AND
  2. The MenuBarExtra popover is closed (no `MenuBarPopoverView` `.task` is alive).
- File watchers stay armed regardless — they're event-driven and cost effectively zero idle CPU.
- On first visibility OR popover-open after a pause, kick a single immediate `refresh()` then re-arm the timer.

### Manual refresh interaction

- M03's Refresh button still works; it now feeds into the same `RefreshScheduler` debounce. Spamming it during the 250 ms window collapses to one refresh (small UX change — previously M03 just `await`ed a single in-flight check).

## Watcher topology

```
                ┌──────────────────────────────────────────────────────────┐
                │                  RefreshScheduler                         │
                │   (250 ms trailing debounce, dedupes triggers)            │
                │                                                            │
                │   trigger sources:                                         │
                │   ┌─ DispatchSource(jobs.json)        .write/.rename/.delete
                │   ┌─ DispatchSource(scheduled_tasks.json) .write/.rename/.delete
                │   ┌─ FSEventStream(claude/projects/, latency 0.25s, recursive)
                │   ┌─ Periodic(10s, paused when hidden)
                │   ┌─ Manual(refreshNow from M03 button)
                └──────────────────────────────────────────────────────────┘
                                          │
                                          │ (one debounced call)
                                          ▼
                          ServiceRegistryViewModel.refresh()
                                          │
                                          ▼
                              registry.discoverAll() (M01/M01.5/M03)
                                          │
                                          ▼
                  services = sorted (preserving Service.ID identity for Table)
                                          │
                                          ▼
                       AutoRefreshIndicator state derived from VM:
                          isRefreshing → "refreshing" pulse
                          lastRefreshError != nil → "error" red
                          else → "idle"
```

### Atomic-rename handling (CRITICAL)

When the watched file is replaced via temp+rename (the `HiddenStore` pattern, the Node CLI pattern, every well-behaved editor's pattern), the kernel sends `.delete` or `.rename` and our `O_EVTONLY` fd becomes orphaned. Handler MUST:

1. Cancel the existing source.
2. `close(oldFd)` (the cancel handler does this).
3. After a 50 ms delay (let the writer finish renaming), re-`open(O_EVTONLY)` and install a fresh `DispatchSource`.
4. Fire one refresh (the file content has effectively changed).

If the re-open fails (file genuinely gone), retry with exponential backoff capped at 5 s; surface as `lastRefreshError` after 3 consecutive failures so the indicator goes red.

## Debounce strategy

- **Window:** 250 ms trailing.
- **Reason for trailing (not leading):** trailing ensures the *latest* state of all triggered sources is what `discoverAll()` reads. A leading edge would refresh on the first event and miss the rest.
- **Coalescing key:** none — any trigger from any source contributes to the same single pending refresh. We do NOT split per-source debouncing because the cheapest correct thing is one `discoverAll()` per cluster of events.
- **Implementation:** a `DispatchWorkItem` (cancel + reschedule on each trigger) is the simplest correct primitive; a `Combine.Publishers.Debounce` over a `PassthroughSubject<RefreshTrigger, Never>` is equivalent. Architect picks; both meet the AC.

## Battery considerations

- File watchers are kqueue/FSEvents — kernel-driven, near-zero idle cost. They stay armed always.
- Periodic 10 s tick is the only background CPU draw and is the thing we pause when hidden. With a typical desktop usage pattern (dashboard hidden 90 % of the time), this saves ~9× the wakeups vs the M03 30 s always-on loop, despite a faster nominal cadence.
- We do NOT use `Timer.publish(every: 10, …)` at the SwiftUI layer — it fires on the main run loop even when nobody is observing. Use a cancellable `Task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(10)); … } }` whose lifetime is tied to the visibility predicate.
- `discoverAll()` runs on the registry actor (off main); only the final assignment to `@Observable` properties hops back to `MainActor`. UI thread blocks must stay < 16 ms (one frame at 60 Hz) — the AC explicitly bounds this.
- We do NOT register a `DispatchSource` per `.jsonl` file under `~/.claude/projects/`; with thousands of files this would (a) exhaust the per-process fd budget, (b) spend more on tracking than scanning. The directory-level `FSEventStream` with recursive flag is correct.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `DispatchSource` fd dies on first atomic save by the writer (the very first user action triggers a regression) | Critical | Atomic-rename handler is a binding code-path AC (AC-F-04). One unit test writes via temp+rename through the watcher; refresh must fire and the watcher must remain live for a second write. |
| FSEventStream history-replay floods on first arm (default behavior is to deliver historical events) | Medium | Use `kFSEventStreamEventIdSinceNow` so we only get events from arm-time forward. AC asserts no spurious refresh in the first 250 ms after watcher install. |
| Periodic timer leaks across `swift test` runs (background `Task` outlives the test) | Medium | View-model `stop()` cancels all watchers + the timer Task. Test suite calls `stop()` in `deinit` of the harness; a `StaticGrepRogueRefs`-style test asserts every test that constructs `ServiceRegistryViewModel` also calls `.stop()` (or uses an `@MainActor` defer block). |
| Tests touch real `~/.agent-jobs/` or `~/.claude/` and corrupt user data | Critical | `WatchPaths` is the only constructor entry point for paths; tests pass `tempDir`. Static-grep test asserts no test file references `NSHomeDirectory()`, `~`, `.agent-jobs/`, `.claude/` literally. |
| Selection / scroll lost on refresh because `services` is reassigned | High | Two visual ACs (selection persistence, scroll persistence) capture before/after baselines after 10 forced refreshes. SwiftUI Table is keyed by `Service.ID` which is stable across refreshes per M01.5. |
| Fast-firing editor (Vim writes 3 events in 50 ms) triggers 3 refreshes | High | 250 ms trailing debounce. Unit test fires 5 triggers in 100 ms and asserts exactly 1 `refresh()` call. |
| Watcher-install failure (e.g., `~/.agent-jobs/` doesn't exist on a fresh machine) crashes the app | High | Watcher install is best-effort and non-throwing at the call site. Failure logs once and surfaces as `lastRefreshError`; the periodic timer + the other watchers continue normally. |
| Visibility-pause logic deadlocks (window-state observation never fires the resume) | Medium | A hard upper bound: even when "paused", run a 5-minute keepalive tick so the worst case is 5 min of staleness, not infinite. AC asserts this safety net. |
| `lsof` enumeration on a busy box exceeds 16 ms on the main thread | Medium | `discoverAll()` already runs on the registry actor (off main); only the final `services = …` assignment touches `MainActor`. AC-P-04 bounds main-thread block at 16 ms during refresh. |
| Auto-refresh races a user's stop click (M03 optimistic overlay regression) | Medium | M03's `optimisticallyStopped` overlay is preserved untouched; faster refresh cadence makes the overlay TTL (currently 2 × `refreshIntervalSeconds` = 60 s under M03 / now 2 × 10 s = 20 s under M04) tighter but still sufficient. Architect to confirm. |

## Open questions for architect

1. **Where does `RefreshScheduler` live?** Recommendation: `AgentJobsCore/Refresh/RefreshScheduler.swift` as an `actor` owning the debounce + the `WatchPaths`. The view model holds one `RefreshScheduler` and feeds its trigger stream. Keeps the debounce primitive testable in isolation.
2. **`Combine.Debounce` vs hand-rolled `DispatchWorkItem`** — both are correct. Combine adds a tiny dependency-shape cost (we already use `Foundation`, no extra modules) but is more idiomatic; DispatchWorkItem is leaner. Architect picks; the AC is on observable behavior, not on the primitive.
3. **Visibility-pause signal source** — `NSApplication.didChangeOcclusionStateNotification` for the dashboard window is the obvious choice. Open: how do we observe MenuBarExtra popover state? SwiftUI does not expose it cleanly. Fallback: assume popover is "closed" 1 s after the `MenuBarPopoverView`'s `.task` is cancelled. Architect to confirm or propose a cleaner signal.
