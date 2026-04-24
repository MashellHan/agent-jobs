# Competitive Analysis — M03 (Actions: stop / hide / refresh)

## Products surveyed

| Product | URL | License | Stars | Last release | Relevance |
|---|---|---|---|---|---|
| Apple Activity Monitor | https://support.apple.com/guide/activity-monitor/quit-a-process-actmntr1002/mac | Proprietary (built-in) | n/a | bundled w/ macOS | Direct precedent for stop-process UX (Stop button + Quit/Force Quit/Cancel dialog) |
| Stats (exelban) | https://github.com/exelban/stats | MIT | 30k+ | 2.12.x (2025/26) | Closest macOS menu-bar precedent: process list per module, but no kill action surfaced — relevant as a "what NOT to copy" data point |
| SwiftBar | https://github.com/swiftbar/SwiftBar | MIT | 4k+ | 2.0.1 (Feb 2025) | Refresh patterns: `refresh=true` action items, `refreshOnOpen`, visible refresh indicator (open issue #321), URL-scheme refresh |

WebSearch confirmed the above as the top results for the queries; no other Swift OSS app surfaced that combines stop + hide + refresh UX in a menu-bar shell.

## Feature matrix

| Feature | Activity Monitor | Stats | SwiftBar | We have (M02) | Plan (M03) |
|---|---|---|---|---|---|
| Stop / kill process | Yes (Stop button → Quit/Force Quit dialog) | No (process list only) | N/A | No | YES — SIGTERM live processes, `launchctl unload` for launchd; refuse on PID 0/1/self/unknown |
| Confirmation before destructive action | Yes (modal NSAlert with three buttons) | N/A | N/A | No | YES — `.confirmationDialog` w/ destructive role |
| Hide / blacklist a row | No (filters but not hide) | Limited (per-module on/off) | Per-plugin enable/disable | No | YES — persisted to `~/.agent-jobs/hidden.json`, atomic write |
| "Show hidden" toggle | N/A | N/A | N/A | No | YES — toolbar toggle in Dashboard |
| Manual refresh | Yes (Cmd-R) | Auto-refresh on interval | Yes (`refresh=true` URL scheme + per-item action) | Auto-refresh background only | YES — toolbar Refresh button forcing `discoverAll()` + spinner |
| Visual feedback during refresh | Subtle (cursor) | Spinner per module | Issue #321 still OPEN — users want this | Auto-refresh indicator exists | Reuse / extend `AutoRefreshIndicator` for manual refresh too |
| Safety against self-kill | Yes ("could cause data loss" guard) | N/A | N/A | N/A | YES — refuse PID 0/1, refuse `getpid()`, refuse sources we cannot identify |

## Gaps we should fill (this milestone)

1. **No comparable macOS menu-bar tool ships a kill action with safety rails.** Activity Monitor has the action but is heavyweight; menu-bar monitors (Stats) avoid it entirely. Our user (developer running multiple AI-coding-agent loops) needs the kill action because background loops sometimes detach and become noise — that's the reason agent-jobs exists. Filling this gap is the milestone's value.
2. **Hide-not-delete pattern is missing in this category.** Activity Monitor has filters but not durable hide. SwiftBar disables whole plugins, not rows. A persisted hide list lets users mute false-positive rows (e.g. `node` long-running editor servers misdetected by `LsofProcessProvider`) without losing them forever.
3. **Refresh feedback is universally weak.** SwiftBar issue #321 (open, multi-year) shows real demand for visible "I'm refreshing now" affordance. M02 already has `AutoRefreshIndicator`; M03 should connect it to manual refresh too.

## Patterns worth borrowing

- **Activity Monitor's three-button confirmation** (Quit / Force Quit / Cancel). For our scope we collapse to two (`Stop` destructive + `Cancel`) because we always send SIGTERM (graceful) — never SIGKILL in M03. If a future milestone adds Force Quit it slots in as the third button.
- **Activity Monitor's protective refusal** ("if quitting could cause data loss, the process doesn't quit"). Our analog: refuse PID 0/1, self-PID, and any service whose source we cannot map to a stop strategy. Surface a clear inline error rather than a silent no-op.
- **SwiftBar's URL-scheme refresh** is overkill for M03 but informs the architect: keep the manual-refresh action behind a single entry point so a future `agentjobs://` scheme is a thin wrapper.
- **SwiftBar's `SWIFTBAR_PLUGIN_REFRESH_REASON`** — useful idea for telemetry later (manual vs auto vs fs.watch); not in M03 scope, noted for M04.

## Anti-patterns observed (avoid)

- **Stats has process lists with no actions.** Users repeatedly request kill in their issues; the maintainer keeps it read-only. We deliberately differ — but only with the safety rails above. Without rails we'd be the worst of both worlds.
- **Confirmation-dialog fatigue (Adobe / Reddit threads).** Don't show the dialog for non-destructive actions (hide, refresh). Keep it ONLY on stop.
- **SwiftBar issue #321 anti-pattern: silent refresh.** Users had to file an issue because they couldn't tell whether anything was happening. Always show the spinner during a manual refresh; disable the button while in flight.
- **Right-click-only actions (some menu-bar apps).** Action affordances must be visible — at minimum on row hover — not hidden behind a context menu. Discoverability matters for a tool whose users don't yet have muscle memory.
- **Destructive-action surface that ALSO accepts keyboard auto-fire** (some Linux PMs). Confirmation dialog must not have `Stop` as the default-Enter button. `Cancel` is the default; `Stop` requires explicit click or Cmd-Return.
