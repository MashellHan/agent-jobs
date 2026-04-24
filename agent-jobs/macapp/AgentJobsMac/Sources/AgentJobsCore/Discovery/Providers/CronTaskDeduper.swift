import Foundation

/// Pure helper that drops session-derived cron tasks that already appear in
/// `~/.claude/scheduled_tasks.json` (the durable list).
///
/// Mirrors the TS dedup logic in src/scanner.ts:611-619:
/// the key is `cron + "|" + prompt[..<50]`. No project prefix is included
/// because durable tasks lack project context.
public enum CronTaskDeduper {

    /// One scheduled-tasks.json entry, reduced to the fields used in the
    /// dedup key. Keeping a tiny dedicated struct (rather than coupling to
    /// `ClaudeScheduledTasksProvider.Entry`) keeps this helper purely
    /// data-driven and testable in isolation.
    public struct DurableKey: Equatable, Sendable {
        public let cron: String
        public let prompt: String
        public init(cron: String, prompt: String) {
            self.cron = cron
            self.prompt = prompt
        }
    }

    /// Returns the subset of `sessionCreates` that does NOT collide with any
    /// `durable` entry on `(cron, prompt[..<50])`. Order of `sessionCreates`
    /// is preserved (helps deterministic test assertions).
    public static func dedup(
        sessionCreates: [SessionCronTask],
        durable: [DurableKey]
    ) -> [SessionCronTask] {
        if durable.isEmpty { return sessionCreates }
        let blocked = Set(durable.map(key))
        return sessionCreates.filter { !blocked.contains(key(for: $0)) }
    }

    /// Exposed for tests / the provider's own diagnostics.
    public static func key(for task: SessionCronTask) -> String {
        task.cron + "|" + prefix50(task.prompt)
    }

    public static func key(_ d: DurableKey) -> String {
        d.cron + "|" + prefix50(d.prompt)
    }

    private static func prefix50(_ s: String) -> String {
        if s.count <= 50 { return s }
        return String(s.prefix(50))
    }
}
