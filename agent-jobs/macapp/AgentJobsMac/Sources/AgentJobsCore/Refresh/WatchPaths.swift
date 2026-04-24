import Foundation

/// Three filesystem locations the M04 watcher layer observes. Production
/// callers use `.production` to resolve under `NSHomeDirectory()`; tests
/// pass an explicit `WatchPaths(...)` rooted under
/// `FileManager.default.temporaryDirectory` so test runs never touch the
/// user's real `~/.agent-jobs/` or `~/.claude/` (AC-Q-04).
public struct WatchPaths: Sendable, Hashable {
    public let jobsJson: URL
    public let scheduledTasks: URL
    public let claudeProjectsDir: URL

    public init(jobsJson: URL, scheduledTasks: URL, claudeProjectsDir: URL) {
        self.jobsJson = jobsJson
        self.scheduledTasks = scheduledTasks
        self.claudeProjectsDir = claudeProjectsDir
    }

    /// Default production paths, resolved from `NSHomeDirectory()`.
    /// AC-F-11 — view model passes `.production` by default.
    public static var production: WatchPaths {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return WatchPaths(
            jobsJson: home.appendingPathComponent(".agent-jobs/jobs.json"),
            scheduledTasks: home.appendingPathComponent(".claude/scheduled_tasks.json"),
            claudeProjectsDir: home.appendingPathComponent(".claude/projects")
        )
    }
}
