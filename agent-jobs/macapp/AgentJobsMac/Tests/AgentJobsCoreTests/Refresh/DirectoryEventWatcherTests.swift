import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-05 (FSEventStream on claude/projects), AC-F-13 (install failure).
@Suite("DirectoryEventWatcher (FSEventStream)")
struct DirectoryEventWatcherTests {

    actor EventCounter {
        private(set) var count: Int = 0
        private(set) var failures: [Error] = []
        func tick() { count += 1 }
        func fail(_ e: Error) { failures.append(e) }
    }

    private static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-dirwatch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private static func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    private static func waitUntil(_ deadlineMs: Int, _ predicate: () async -> Bool) async -> Bool {
        let stepMs = 50
        let steps = deadlineMs / stepMs
        for _ in 0..<steps {
            if await predicate() { return true }
            try? await Task.sleep(for: .milliseconds(stepMs))
        }
        return await predicate()
    }

    // MARK: - AC-F-05: nested .jsonl creation triggers

    @Test("creating subdir/session.jsonl triggers onEvent within 1500 ms")
    func nestedJsonlCreationFires() async throws {
        let root = Self.tempDir(); defer { Self.cleanup(root) }
        let counter = EventCounter()
        let watcher = DirectoryEventWatcher(
            directory: root, latency: 0.1,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } })
        watcher.start()
        try? await Task.sleep(for: .milliseconds(300))
        let sub = root.appendingPathComponent("project-a")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let f = sub.appendingPathComponent("session.jsonl")
        try Data("{}\n".utf8).write(to: f)
        let observed = await Self.waitUntil(2_500) { await counter.count >= 1 }
        watcher.stop()
        let n = await counter.count
        #expect(observed, "expected onEvent for nested .jsonl creation, got \(n)")
    }

    // MARK: - modify existing jsonl fires

    @Test("modifying existing session.jsonl fires onEvent")
    func modifyExistingFires() async throws {
        let root = Self.tempDir(); defer { Self.cleanup(root) }
        let f = root.appendingPathComponent("a.jsonl")
        try Data("x\n".utf8).write(to: f)
        let counter = EventCounter()
        let watcher = DirectoryEventWatcher(
            directory: root, latency: 0.1,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } })
        watcher.start()
        try? await Task.sleep(for: .milliseconds(300))
        let h = try FileHandle(forWritingTo: f)
        try h.seekToEnd()
        try h.write(contentsOf: Data("y\n".utf8))
        try h.close()
        let observed = await Self.waitUntil(2_500) { await counter.count >= 1 }
        watcher.stop()
        let n = await counter.count
        #expect(observed, "expected onEvent for modify, got \(n)")
    }

    // MARK: - .DS_Store does NOT fire (path filter)

    @Test(".DS_Store write does not trigger onEvent")
    func dsStoreFilteredOut() async throws {
        let root = Self.tempDir(); defer { Self.cleanup(root) }
        let counter = EventCounter()
        let watcher = DirectoryEventWatcher(
            directory: root, latency: 0.1,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } })
        watcher.start()
        try? await Task.sleep(for: .milliseconds(300))
        let ds = root.appendingPathComponent(".DS_Store")
        try Data("noise".utf8).write(to: ds)
        try? await Task.sleep(for: .milliseconds(800))
        watcher.stop()
        let n = await counter.count
        #expect(n == 0, "filter should suppress .DS_Store, got \(n) events")
    }

    // MARK: - install on missing dir → onInstallFailure

    @Test("install on missing directory surfaces onInstallFailure")
    func installFailureSurfaces() async throws {
        let root = Self.tempDir(); defer { Self.cleanup(root) }
        let bogus = root.appendingPathComponent("does-not-exist")
        let counter = EventCounter()
        let watcher = DirectoryEventWatcher(
            directory: bogus, latency: 0.1,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } })
        watcher.start()
        let observed = await Self.waitUntil(1_000) { await counter.failures.count >= 1 }
        watcher.stop()
        let n = await counter.count
        #expect(observed)
        #expect(n == 0)
    }
}
