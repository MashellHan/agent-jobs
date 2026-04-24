# Competitive Analysis — M04 (Auto-refresh + fs.watch)

## Products surveyed

| Product | URL | License | Stars | Last release | Relevance |
|---|---|---|---|---|---|
| Apple Activity Monitor | https://support.apple.com/guide/activity-monitor/change-how-often-information-is-updated-actmntr2224/mac | Proprietary (built-in) | n/a | bundled w/ macOS 26 | Direct precedent for sampling cadence: default 5 s, options Very Often (1 s) / Often (2 s) / Normally (5 s); Apple explicitly warns more-frequent sampling hurts CPU/battery |
| Apple FSEvents / DispatchSource | https://developer.apple.com/documentation/dispatch/dispatchsource | Apple SDK | n/a | macOS 26 | The two native event-driven primitives we will compose: `DispatchSource.makeFileSystemObjectSource` per file (cheap, kqueue-backed) + `FSEventStreamCreate` per directory (CoreServices, latency-tunable) |
| Stats (exelban) | https://github.com/exelban/stats — issue #2407 | MIT | 30k+ | 2.12.x (2025/26) | Closest macOS menu-bar precedent for periodic polling: per-module update interval (1 s default). Open issue #2407 shows real users complaining when the configured interval silently reverts — anti-pattern: never silently ignore the user's cadence choice |
| SwiftBar (m03 carry-over) | https://github.com/swiftbar/SwiftBar — issue #321 | MIT | 4k+ | 2.0.1 (Feb 2025) | Refresh-feedback precedent: open issue #321 (multi-year) shows demand for visible "I'm refreshing" indicator. M02 already shipped `AutoRefreshIndicator`; M04 must wire it to fs.watch + lsof tick, not just the time-based label |
| Finder / NSFilePresenter | (Apple Foundation) | Apple SDK | n/a | macOS 26 | Reference for the "atomic-rename" gotcha: virtually every well-behaved writer (incl. our own `HiddenStore`) does `write tmp → rename(2)` which destroys the watched fd; correct handling is to re-`open(O_EVTONLY)` on `.delete`/`.rename` |

WebSearch confirmed the above as the top results for the four queries (file-monitor pattern, Activity Monitor cadence, Stats configurable interval, FSEventStream directory). No other Swift OSS menu-bar app surfaced that combines DispatchSource per-file + FSEventStream per-directory + a debounced periodic rescan in a public reference implementation we can borrow whole.

## Feature matrix

| Feature | Activity Monitor | Stats | SwiftBar | Finder/FSEvents | We have (M03) | Plan (M04) |
|---|---|---|---|---|---|---|
| Periodic rescan | Yes (5 s default, 1/2/5 s options) | Yes (1 s default per module) | Yes (per-plugin `refresh=N`) | N/A | Yes — fixed 30 s `startAutoRefresh()` loop | YES — 10 s lsof rescan, debounced, paused when window not visible |
| File-event-driven update | No (pure poll) | No (pure poll) | No (poll only) | Yes (FSEvents) | No | YES — DispatchSource on `jobs.json`, `scheduled_tasks.json`; FSEventStream on `~/.claude/projects/` |
| Atomic-rename safe | N/A | N/A | N/A | Yes (re-binds presenter) | N/A | YES — re-open file descriptor on `.delete`/`.rename` |
| Visible "refreshing now" affordance | Subtle (cursor) | Per-module spinner (sometimes) | Issue #321 still OPEN — users want this | N/A | `AutoRefreshIndicator` shows "updated Ns ago • next in Ns" with pulse | YES — reuse + extend with idle / refreshing / error states |
| Pause when occluded / battery on | No (polls regardless) | No (polls regardless) | No | N/A | No | YES — pause periodic tick when window hidden + menu-bar popover closed; fs.watch stays armed (event-driven, near-zero cost) |
| Coalescing / debounce | N/A (poll cadence is the debounce) | N/A | N/A | Yes (FSEvents `latency` arg) | N/A | YES — 250 ms trailing debounce on file events; events arriving inside the same window collapse to one `refresh()` |
| Preserves selection / scroll across refresh | Yes (table reuses row identity) | N/A (no selection model) | N/A | N/A | Implicit (SwiftUI Table keyed by `Service.ID`) — but never stress-tested under rapid auto-tick | YES — explicit AC; selection + scroll position survive 10 consecutive refresh ticks |
| User-tunable cadence | Yes (3 presets) | Yes (per module) | Yes (per plugin) | N/A | No | NO (out of scope — fixed 10 s; M06 Settings will expose) |

## Gaps we should fill (this milestone)

1. **No competitor combines fs.watch + periodic rescan + visibility-pause.** Activity Monitor and Stats are pure pollers; Finder uses pure events. The hybrid we need (event-driven for the JSON sources, polling for live-process discovery via `lsof`, with battery-aware pausing) has no off-the-shelf precedent in the macOS menu-bar category. This is the milestone's value: a refresh story that is *both* sub-second on file edits *and* cheap on battery.
2. **The atomic-rename gotcha is universally under-handled in toy examples.** Our own `HiddenStore` (M03) writes via temp+rename, and so does the Node CLI that owns `~/.agent-jobs/jobs.json`. A naïve `DispatchSource` watcher dies after the first save. M04 must explicitly handle `.delete`/`.rename` by re-opening the descriptor — this is a code-path AC, not just a "would be nice".
3. **Visible feedback is universally weak.** SwiftBar issue #321 (open, multi-year) confirms demand. M02/M03 shipped a time-label indicator; M04 must drive its three states (idle / refreshing / error) from the actual auto-refresh pipeline, not just from a clock.
4. **Battery awareness is absent in the category.** Stats and Activity Monitor poll regardless of window visibility. We have an obvious win because we're a menu-bar app whose main window is hidden most of the time — pausing the 10 s tick when the dashboard window is not visible AND the popover is closed costs nothing and saves measurable wakeups.

## Patterns worth borrowing

- **Apple FSEvents `latency` parameter.** The CoreServices API exposes a coalescing-window argument; we adopt the same idea via a 250 ms trailing debounce in the Swift layer (so we get identical semantics for the per-file `DispatchSource` watchers too, which have no built-in latency).
- **Activity Monitor's 5 s default as the conservative pole.** For the lsof rescan we picked 10 s (twice as conservative) because lsof is heavier than Apple's in-process sampling and our spec already lists 10 s. Activity Monitor's 1 s "Very Often" option is the speed cap we will *not* approach in M04.
- **NSFilePresenter atomic-rename handling.** We don't adopt `NSFilePresenter` itself (it's heavier than we need and tangles us into `NSFileCoordinator`), but we copy its insight: never trust a single fd across a save; always be ready to re-open.
- **SwiftBar `SWIFTBAR_PLUGIN_REFRESH_REASON` (deferred).** The architectural shape — tagging each refresh with its trigger source (manual / periodic / file-event) — is good. M04 keeps it as an internal enum (`RefreshTrigger`) used for logging and the indicator's "refreshing because X" tooltip; not user-facing telemetry until later.

## Anti-patterns observed (avoid)

- **Pure polling at 1 s (Stats default).** Wakes the CPU 60×/min for data that mostly hasn't changed. We deliberately do NOT poll at 1 s; we poll at 10 s and let fs.watch cover the latency-sensitive paths.
- **Silently ignoring the user's interval choice (Stats issue #2407).** When we add user-tunable cadence in M06, the setting must visibly take effect; in M04 we sidestep this by not exposing a setting at all (one fixed 10 s value, documented).
- **Silent refresh (SwiftBar issue #321).** Every refresh tick — periodic OR fs.watch-driven — must drive the AutoRefreshIndicator into its `refreshing` state visibly. No invisible churn.
- **Watch-everything FSEventStream on `$HOME` or root.** Tempting and wrong: huge event volume, privacy footprint, Full-Disk-Access prompt. M04 watches three specific paths only.
- **Holding the watcher fd while the file is gone (atomic-rename trap).** A naïve `DispatchSource` example breaks after the first save by the writer; we must re-open on `.delete`/`.rename`.
- **Refreshing while the window is hidden.** A menu-bar app whose main window is closed should not be doing 10 s lsof scans — events alone keep us correct, and the next time the user opens the window we do an immediate catch-up tick.
- **Re-rendering the whole list (loses selection + scroll).** SwiftUI `Table` keyed by stable ids is the cure; the AC suite explicitly asserts selection and scroll survive 10 consecutive ticks.
