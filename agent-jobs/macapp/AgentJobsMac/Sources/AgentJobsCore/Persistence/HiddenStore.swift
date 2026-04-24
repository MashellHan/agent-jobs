import Foundation
import OSLog

/// Durable, atomic-write store for the user's "hidden" service ids.
///
/// File layout: `~/.agent-jobs/hidden.json`
/// Schema:      `{ "version": 1, "hiddenIds": ["...", "..."] }`
///
/// Recovery contract:
/// - Missing file → empty set; first `add` creates the file.
/// - Malformed JSON or unknown version → empty set + log; next mutate
///   overwrites the bad file.
///
/// All file IO runs through the actor so concurrent `add` / `remove` calls
/// can never interleave a partial write.
public actor HiddenStore {

    /// On-disk representation. Codable so we get encode/decode for free.
    public struct File: Codable, Equatable, Sendable {
        public let version: Int
        public let hiddenIds: [String]
        public init(version: Int, hiddenIds: [String]) {
            self.version = version
            self.hiddenIds = hiddenIds
        }
    }

    public static let currentVersion = 1
    public static let defaultRelativePath = ".agent-jobs/hidden.json"

    private let url: URL
    private var ids: Set<String>
    private let logger = Logger(subsystem: "dev.agentjobs", category: "HiddenStore")

    /// `homeDir` lets tests pass a temp directory.
    public init(homeDir: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.url = homeDir.appendingPathComponent(Self.defaultRelativePath)
        self.ids = []
        self.ids = Self.loadOrEmpty(url: url, logger: logger)
    }

    public func snapshot() -> Set<String> { ids }
    public func contains(_ id: String) -> Bool { ids.contains(id) }

    @discardableResult
    public func add(_ id: String) throws -> Set<String> {
        ids.insert(id)
        try writeAtomic()
        return ids
    }

    @discardableResult
    public func remove(_ id: String) throws -> Set<String> {
        ids.remove(id)
        try writeAtomic()
        return ids
    }

    // MARK: - Private

    private func writeAtomic() throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload = File(version: Self.currentVersion, hiddenIds: ids.sorted())
        let data = try JSONEncoder().encode(payload)
        // Strategy: write to <url>.tmp then atomically swap via replaceItemAt
        // when the destination exists, else move into place. This guarantees
        // hidden.json is either old-content or new-content, never partial.
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }

    private static func loadOrEmpty(url: URL, logger: Logger) -> Set<String> {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        guard let data = try? Data(contentsOf: url) else {
            logger.warning("HiddenStore: unable to read \(url.path, privacy: .public); treating as empty")
            return []
        }
        guard let file = try? JSONDecoder().decode(File.self, from: data) else {
            logger.warning("HiddenStore: corrupt JSON at \(url.path, privacy: .public); treating as empty")
            return []
        }
        guard file.version == Self.currentVersion else {
            logger.warning("HiddenStore: unknown version \(file.version) at \(url.path, privacy: .public); treating as empty")
            return []
        }
        return Set(file.hiddenIds)
    }
}
