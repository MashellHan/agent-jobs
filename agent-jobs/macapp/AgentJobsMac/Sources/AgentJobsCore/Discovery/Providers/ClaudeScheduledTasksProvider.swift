import Foundation
import os

/// Reads `~/.claude/scheduled_tasks.json` and surfaces each entry as a
/// `Service`. Tolerant of every disk failure mode: missing, empty,
/// malformed JSON, non-array root all degrade to `[]` rather than throw.
/// Only a hung read raises `ProviderError.timeout`.
///
/// **T06 stub.** This commit lands the friendly-name helper and the
/// scaffolding only — `discover()` returns `[]` until T07 wires the
/// actual JSON read + mapping.
public struct ClaudeScheduledTasksProvider: ServiceProvider {
    public static let providerId = "claude.scheduled-tasks"
    public static let displayName = "Claude scheduled tasks"
    public static let category = ServiceSource.Category.claude

    public let tasksPath: URL
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "ClaudeScheduledTasksProvider")

    public init(tasksPath: URL? = nil) {
        if let p = tasksPath {
            self.tasksPath = p
        } else {
            self.tasksPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/scheduled_tasks.json")
        }
    }

    public func discover() async throws -> [Service] {
        // T06 stub. Real body lands in T07.
        []
    }

    /// Build a deterministic, human-friendly label for a Claude scheduled
    /// task derived from its `prompt` text. Rule (pinned by tests):
    ///
    /// 1. Trim and collapse internal whitespace runs to a single space.
    /// 2. Strip leading punctuation (`.,;:!?-—…` and friends).
    /// 3. Take the first 6 whitespace-separated words.
    /// 4. If the result is > 40 characters, truncate to 40 and append `…`.
    /// 5. If the result is empty after trimming, return `"Claude task"`.
    static func friendlyCronName(_ prompt: String) -> String {
        // 1. Trim + collapse whitespace.
        let collapsed = prompt
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if collapsed.isEmpty { return "Claude task" }

        // 2. Strip leading punctuation.
        let punctSet = CharacterSet(charactersIn: ".,;:!?-—…\"'`()[]{}")
        let stripped = collapsed.unicodeScalars.drop(while: { punctSet.contains($0) })
        let strippedString = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespaces)
        if strippedString.isEmpty { return "Claude task" }

        // 3. First 6 words.
        let words = strippedString
            .split(whereSeparator: \.isWhitespace)
            .prefix(6)
            .map(String.init)
        var result = words.joined(separator: " ")

        // 4. ≤ 40 chars + ellipsis.
        if result.count > 40 {
            let cutoff = result.index(result.startIndex, offsetBy: 40)
            result = String(result[..<cutoff]) + "…"
        }

        return result.isEmpty ? "Claude task" : result
    }
}
