import Foundation

/// Cause attribution for a single `RefreshScheduler.trigger(_:)` call.
/// Used for debug logging and the `lastTriggers` storm trace; the
/// downstream sink (the view model's `refresh()`) is identical regardless
/// of cause.
public enum RefreshTrigger: Sendable, Equatable, Hashable {
    public enum WatchedSource: Sendable, Equatable, Hashable {
        case jobsJson
        case scheduledTasks
        case claudeProjects
    }

    /// A filesystem watcher fired (jobs.json, scheduled_tasks.json, or
    /// any *.jsonl under ~/.claude/projects/).
    case fileEvent(WatchedSource)
    /// The 10 s `PeriodicTicker` fired (live-process rescan).
    case periodic
    /// The user pressed the Refresh button or `vm.refreshNow()` was called.
    case manual
}
