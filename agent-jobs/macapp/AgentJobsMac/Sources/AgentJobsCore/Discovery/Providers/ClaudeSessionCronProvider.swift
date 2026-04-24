import Foundation
import os

/// Discovers Claude cron tasks by streaming session JSONL files under
/// `~/.claude/projects/*/<sessionId>.jsonl`. Computes the live
/// `CronCreate − CronDelete` net set per session and dedups against
/// `~/.claude/scheduled_tasks.json` (so a task that's both session-derived
/// and durable surfaces only via `ClaudeScheduledTasksProvider`).
///
/// Mirrors `scanSessionCronTasks` in src/scanner.ts:542-622.
public struct ClaudeSessionCronProvider: ServiceProvider {
    public static let providerId = "claude.session-cron"
    public static let displayName = "Claude session cron tasks"
    public static let category = ServiceSource.Category.claude

    public let projectsRoot: URL
    public let durableTasksPath: URL
    private let now: @Sendable () -> Date
    private let lineReader: LineReader
    private let logger = Logger(
        subsystem: "com.agentjobs.mac",
        category: "ClaudeSessionCronProvider"
    )

    /// Reads a JSONL file as an `AsyncSequence<String>` of lines. Production
    /// uses `URL.lines` (Foundation streaming); tests inject a deterministic
    /// in-memory stream.
    public typealias LineReader = @Sendable (URL) async throws -> AsyncLineProvider

    /// Type-erased line stream so we can swap implementations without
    /// touching the parser signature.
    public struct AsyncLineProvider: AsyncSequence, Sendable {
        public typealias Element = String
        let upstream: @Sendable () -> AsyncStream<String>
        public init(_ upstream: @escaping @Sendable () -> AsyncStream<String>) {
            self.upstream = upstream
        }
        public func makeAsyncIterator() -> AsyncStream<String>.AsyncIterator {
            upstream().makeAsyncIterator()
        }
    }

    /// Max age for JSONL files to be considered (7 days = Claude cron auto-expiry).
    public static let jsonlMaxAge: TimeInterval = 7 * 24 * 60 * 60
    /// Window in which a session is considered active (matches TS).
    public static let sessionActiveWindow: TimeInterval = 15 * 60
    /// Concurrency cap for per-file streaming.
    public static let parseConcurrency = 8

    public init(
        projectsRoot: URL? = nil,
        durableTasksPath: URL? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        lineReader: LineReader? = nil
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.projectsRoot = projectsRoot
            ?? home.appendingPathComponent(".claude/projects")
        self.durableTasksPath = durableTasksPath
            ?? home.appendingPathComponent(".claude/scheduled_tasks.json")
        self.now = now
        self.lineReader = lineReader ?? Self.defaultLineReader
    }

    public func discover() async throws -> [Service] {
        let projectFiles = collectJSONLFiles()
        if projectFiles.isEmpty { return [] }

        let parsed = await parseAll(projectFiles)

        // Net active = creates − deletes (per file).
        var sessionTasks: [SessionCronTaskWithMeta] = []
        for entry in parsed {
            for (cronId, task) in entry.output.creates {
                if entry.output.deletes.contains(cronId) { continue }
                sessionTasks.append(SessionCronTaskWithMeta(
                    task: task,
                    sessionId: entry.sessionId,
                    sessionActive: entry.sessionActive,
                    projectDir: entry.projectDir
                ))
            }
        }

        let durableKeys = readDurableKeys()
        let kept = CronTaskDeduper.dedup(
            sessionCreates: sessionTasks.map(\.task),
            durable: durableKeys
        )
        let keptIds = Set(kept.map(\.cronJobId))

        return sessionTasks
            .filter { keptIds.contains($0.task.cronJobId) }
            .map(buildService)
    }

    // MARK: - parsing fan-out

    private struct ParsedFile: Sendable {
        let sessionId: String
        let projectDir: String
        let sessionActive: Bool
        let output: SessionJSONLParser.Output
    }

    private struct SessionCronTaskWithMeta {
        let task: SessionCronTask
        let sessionId: String
        let sessionActive: Bool
        let projectDir: String
    }

    private struct FileEntry {
        let url: URL
        let projectDir: String
        let sessionId: String
        let sessionActive: Bool
    }

    private func collectJSONLFiles() -> [FileEntry] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(atPath: projectsRoot.path) else {
            return []
        }
        let nowDate = now()
        var results: [FileEntry] = []
        for projDir in projects {
            // Guard against directory traversal (parity with TS).
            if projDir.contains("..") || projDir.contains("/") { continue }
            let projPath = projectsRoot.appendingPathComponent(projDir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projPath.path, isDirectory: &isDir),
                  isDir.boolValue
            else { continue }

            let entries = (try? fm.contentsOfDirectory(atPath: projPath.path)) ?? []
            for name in entries where name.hasSuffix(".jsonl") {
                let fileURL = projPath.appendingPathComponent(name)
                guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                      let mtime = attrs[.modificationDate] as? Date
                else { continue }
                let age = nowDate.timeIntervalSince(mtime)
                if age > Self.jsonlMaxAge { continue }
                let sessionId = String(name.dropLast(".jsonl".count))
                results.append(FileEntry(
                    url: fileURL,
                    projectDir: projDir,
                    sessionId: sessionId,
                    sessionActive: age < Self.sessionActiveWindow
                ))
            }
        }
        return results
    }

    private func parseAll(_ files: [FileEntry]) async -> [ParsedFile] {
        let semaphore = AsyncSemaphore(value: Self.parseConcurrency)
        return await withTaskGroup(of: ParsedFile?.self) { group in
            for entry in files {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    do {
                        let stream = try await self.lineReader(entry.url)
                        let out = try await SessionJSONLParser.parse(
                            lines: stream, projectDir: entry.projectDir
                        )
                        return ParsedFile(
                            sessionId: entry.sessionId,
                            projectDir: entry.projectDir,
                            sessionActive: entry.sessionActive,
                            output: out
                        )
                    } catch {
                        self.logger.error(
                            "parse failed for \(entry.url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                        return nil
                    }
                }
            }
            var collected: [ParsedFile] = []
            for await item in group {
                if let item { collected.append(item) }
            }
            return collected
        }
    }

    // MARK: - durable read (best-effort)

    private func readDurableKeys() -> [CronTaskDeduper.DurableKey] {
        guard FileManager.default.fileExists(atPath: durableTasksPath.path),
              let data = try? Data(contentsOf: durableTasksPath),
              !data.isEmpty,
              let any = try? JSONSerialization.jsonObject(with: data),
              let arr = any as? [[String: Any]]
        else { return [] }
        return arr.compactMap { entry in
            guard let cron = entry["cron"] as? String,
                  let prompt = entry["prompt"] as? String
            else { return nil }
            return CronTaskDeduper.DurableKey(cron: cron, prompt: prompt)
        }
    }

    // MARK: - service builder

    private func buildService(_ meta: SessionCronTaskWithMeta) -> Service {
        let task = meta.task
        let sessionPrefix = String(meta.sessionId.prefix(8))
        let project = Self.projectName(cwd: task.cwd, projectDir: meta.projectDir)
        let createdAt = parseTimestamp(task.timestamp)
        return Service(
            id: "claude.session-cron:\(sessionPrefix):\(task.cronJobId)",
            source: .claudeLoop(sessionId: sessionPrefix),
            kind: .scheduled,
            name: ClaudeScheduledTasksProvider.friendlyCronName(task.prompt),
            project: project,
            command: task.prompt,
            schedule: .cron(task.cron),
            status: meta.sessionActive ? .running : .idle,
            createdAt: createdAt,
            owner: .agent(.claude),
            history: [],
            origin: ServiceOrigin(
                agent: .claude,
                sessionId: sessionPrefix,
                toolName: "CronCreate"
            )
        )
    }

    /// Friendly project name. Mirrors TS:
    /// - if `cwd` non-empty: take the last 2 path segments joined with "/".
    /// - else: `projectNameFromDir(projectDir)`.
    static func projectName(cwd: String, projectDir: String) -> String {
        if !cwd.isEmpty {
            let parts = cwd.split(separator: "/").map(String.init)
            if parts.count >= 2 {
                return parts.suffix(2).joined(separator: "/")
            }
            return parts.first ?? projectNameFromDir(projectDir)
        }
        return projectNameFromDir(projectDir)
    }

    /// Mirrors TS `projectNameFromDir` (src/scanner.ts:442-447):
    /// strip leading `-Users-<user>-+` then convert remaining `-` → `/`,
    /// collapse double slashes.
    static func projectNameFromDir(_ dirName: String) -> String {
        var stripped = dirName
        if let range = stripped.range(of: #"^-Users-[^-]+-+"#, options: .regularExpression) {
            stripped.removeSubrange(range)
        }
        let slashed = stripped.replacingOccurrences(of: "-", with: "/")
        return slashed.replacingOccurrences(of: "//", with: "/")
    }

    private func parseTimestamp(_ s: String) -> Date? {
        if s.isEmpty { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    // MARK: - default line reader

    /// Production reader: `URL.lines` is async/streaming on macOS 14+.
    static let defaultLineReader: LineReader = { url in
        AsyncLineProvider {
            AsyncStream { continuation in
                let task = Task {
                    do {
                        for try await line in url.lines {
                            if Task.isCancelled { break }
                            continuation.yield(line)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }
}
