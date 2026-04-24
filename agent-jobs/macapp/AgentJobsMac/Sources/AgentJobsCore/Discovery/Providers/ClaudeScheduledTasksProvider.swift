import Foundation
import CryptoKit
import os

/// Reads `~/.claude/scheduled_tasks.json` and surfaces each entry as a
/// `Service`. Tolerant of every disk failure mode: missing, empty,
/// malformed JSON, non-array root all degrade to `[]` rather than throw.
/// Only a hung read raises `ProviderError.timeout`.
public struct ClaudeScheduledTasksProvider: ServiceProvider {
    public static let providerId = "claude.scheduled-tasks"
    public static let displayName = "Claude scheduled tasks"
    public static let category = ServiceSource.Category.claude

    public let tasksPath: URL
    private let loader: Loader?
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "ClaudeScheduledTasksProvider")

    /// Read-with-timeout seam for tests. When `nil`, the production path
    /// reads the on-disk file with the same 5-second cap as
    /// `AgentJobsJsonProvider`.
    public typealias Loader = @Sendable (_ url: URL, _ timeout: TimeInterval) async throws -> Data

    public init(tasksPath: URL? = nil, loader: Loader? = nil) {
        if let p = tasksPath {
            self.tasksPath = p
        } else {
            self.tasksPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/scheduled_tasks.json")
        }
        self.loader = loader
    }

    public static let readTimeoutSeconds: TimeInterval = 5

    public func discover() async throws -> [Service] {
        // Missing file → []
        if loader == nil, !FileManager.default.fileExists(atPath: tasksPath.path) {
            return []
        }

        let data: Data
        do {
            if let loader {
                data = try await loader(tasksPath, Self.readTimeoutSeconds)
            } else {
                data = try await Self.readWithTimeout(
                    url: tasksPath,
                    seconds: Self.readTimeoutSeconds
                )
            }
        } catch ProviderError.timeout {
            logger.error("Read timed out: \(self.tasksPath.path, privacy: .public)")
            throw ProviderError.timeout
        } catch {
            // Any non-timeout I/O hiccup is treated as "absent" per spec.
            logger.error("Read failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        if data.isEmpty { return [] }

        // Decode root as `[Entry]`. Anything else (object root, scalar root,
        // malformed bytes) → [].
        let entries: [Entry]
        do {
            entries = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            logger.error("Malformed or non-array JSON: \(error.localizedDescription, privacy: .public)")
            return []
        }

        return entries.enumerated().map { idx, entry in
            buildService(entry: entry, index: idx)
        }
    }

    // MARK: - Helpers

    private struct Entry: Decodable {
        let prompt: String
        let cron: String
    }

    private func buildService(entry: Entry, index: Int) -> Service {
        let digest = sha8(of: entry.prompt + "|" + entry.cron)
        return Service(
            id: "claude.scheduled-tasks:\(index):\(digest)",
            source: .claudeScheduledTask(durable: true),
            kind: .scheduled,
            name: Self.friendlyCronName(entry.prompt),
            command: entry.prompt,
            schedule: .cron(entry.cron),
            status: .scheduled,
            createdAt: nil,
            owner: .agent(.claude),
            history: [],
            origin: ServiceOrigin(agent: .claude)
        )
    }

    private func sha8(of s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8))
    }

    /// Reads `url` off the main thread and races it against a timeout.
    /// Throws `ProviderError.timeout` if the read does not finish in time.
    /// Mirrors `AgentJobsJsonProvider.readWithTimeout`.
    static func readWithTimeout(url: URL, seconds: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask(priority: .utility) {
                try Data(contentsOf: url)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ProviderError.timeout
            }
            guard let first = try await group.next() else {
                throw ProviderError.ioError("no result")
            }
            group.cancelAll()
            return first
        }
    }

    /// Build a deterministic, human-friendly label for a Claude scheduled
    /// task derived from its `prompt` text. Rule (pinned by tests):
    ///
    /// 1. Trim and collapse internal whitespace runs to a single space.
    /// 2. Strip leading punctuation.
    /// 3. Take the first 6 whitespace-separated words.
    /// 4. If > 40 characters, truncate to 40 and append `…`.
    /// 5. If empty after trimming, return `"Claude task"`.
    static func friendlyCronName(_ prompt: String) -> String {
        let collapsed = prompt
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if collapsed.isEmpty { return "Claude task" }

        let punctSet = CharacterSet(charactersIn: ".,;:!?-—…\"'`()[]{}")
        let stripped = collapsed.unicodeScalars.drop(while: { punctSet.contains($0) })
        let strippedString = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespaces)
        if strippedString.isEmpty { return "Claude task" }

        let words = strippedString
            .split(whereSeparator: \.isWhitespace)
            .prefix(6)
            .map(String.init)
        var result = words.joined(separator: " ")

        if result.count > 40 {
            let cutoff = result.index(result.startIndex, offsetBy: 40)
            result = String(result[..<cutoff]) + "…"
        }

        return result.isEmpty ? "Claude task" : result
    }
}
