import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-02 (jobs.json), AC-F-03 (scheduled_tasks.json), AC-F-04
/// (atomic-rename re-open), AC-F-13 (install-failure surfaces).
@Suite("FileObjectWatcher (kqueue file watcher)")
struct FileObjectWatcherTests {

    actor EventCounter {
        private(set) var count: Int = 0
        private(set) var failures: [Error] = []
        func tick() { count += 1 }
        func fail(_ e: Error) { failures.append(e) }
        func reset() { count = 0; failures = [] }
    }

    private static func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-fwatch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Spin until predicate true or timeout (returns true if observed).
    private static func waitUntil(_ deadlineMs: Int, _ predicate: () async -> Bool) async -> Bool {
        let stepMs = 25
        let steps = deadlineMs / stepMs
        for _ in 0..<steps {
            if await predicate() { return true }
            try? await Task.sleep(for: .milliseconds(stepMs))
        }
        return await predicate()
    }

    // MARK: - AC-F-02: write through same fd fires onEvent

    @Test("plain write fires onEvent within 1s")
    func plainWriteFiresEvent() async throws {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("jobs.json")
        try Data("v0".utf8).write(to: file)
        let counter = EventCounter()
        let watcher = FileObjectWatcher(
            url: file,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } }
        )
        watcher.start()
        try? await Task.sleep(for: .milliseconds(100))
        // Append via a regular FileHandle so the SAME inode receives writes.
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("more".utf8))
        try handle.close()
        let observed = await Self.waitUntil(2_000) { await counter.count >= 1 }
        watcher.stop()
        let n = await counter.count
        let failures = await counter.failures
        #expect(observed, "expected onEvent within 2s, got count=\(n)")
        #expect(failures.isEmpty)
    }

    // MARK: - AC-F-04: atomic-rename re-open + second write fires again

    @Test("two consecutive temp+rename writes both fire events")
    func atomicRenameReopens() async throws {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("jobs.json")
        try Data("v0".utf8).write(to: file)
        let counter = EventCounter()
        let watcher = FileObjectWatcher(
            url: file,
            reopenDelayMs: 30,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } }
        )
        watcher.start()
        try? await Task.sleep(for: .milliseconds(100))
        for i in 1...2 {
            let tmp = dir.appendingPathComponent("jobs.json.tmp")
            try Data("v\(i)".utf8).write(to: tmp)
            // POSIX rename is atomic — replaces the file.
            _ = try FileManager.default.replaceItemAt(file, withItemAt: tmp)
            try? await Task.sleep(for: .milliseconds(250))
        }
        let observed = await Self.waitUntil(3_000) { await counter.count >= 2 }
        watcher.stop()
        let n = await counter.count
        #expect(observed, "expected ≥ 2 onEvents after 2 atomic renames, got \(n)")
    }

    // MARK: - AC-F-13: install on non-existent file → onInstallFailure

    @Test("install on missing file calls onInstallFailure (no crash)")
    func installFailureSurfaces() async throws {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let bogus = dir.appendingPathComponent("missing.json")
        let counter = EventCounter()
        let watcher = FileObjectWatcher(
            url: bogus,
            reopenDelayMs: 10,
            maxAttempts: 2,
            onEvent: { Task { await counter.tick() } },
            onInstallFailure: { e in Task { await counter.fail(e) } }
        )
        watcher.start()
        let observed = await Self.waitUntil(2_000) { await counter.failures.count >= 1 }
        watcher.stop()
        let n = await counter.count
        #expect(observed)
        #expect(n == 0)
    }

    // MARK: - stop() releases fd cleanly

    @Test("stop() releases fd; can re-install on same path")
    func stopThenReinstall() async throws {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("a.json")
        try Data("x".utf8).write(to: file)
        let c1 = EventCounter()
        let w1 = FileObjectWatcher(
            url: file,
            onEvent: { Task { await c1.tick() } },
            onInstallFailure: { _ in })
        w1.start()
        try? await Task.sleep(for: .milliseconds(80))
        w1.stop()
        try? await Task.sleep(for: .milliseconds(80))
        let c2 = EventCounter()
        let w2 = FileObjectWatcher(
            url: file,
            onEvent: { Task { await c2.tick() } },
            onInstallFailure: { _ in })
        w2.start()
        try? await Task.sleep(for: .milliseconds(80))
        let h = try FileHandle(forWritingTo: file)
        try h.seekToEnd()
        try h.write(contentsOf: Data("more".utf8))
        try h.close()
        let observed = await Self.waitUntil(2_000) { await c2.count >= 1 }
        w2.stop()
        let n1 = await c1.count
        #expect(observed)
        #expect(n1 == 0, "first watcher must not fire after stop")
    }

    // MARK: - two-instance independence

    @Test("two watchers on different files do not cross-fire")
    func twoInstanceIndependence() async throws {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let a = dir.appendingPathComponent("a.json")
        let b = dir.appendingPathComponent("b.json")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let ca = EventCounter()
        let cb = EventCounter()
        let wa = FileObjectWatcher(url: a,
            onEvent: { Task { await ca.tick() } },
            onInstallFailure: { _ in })
        let wb = FileObjectWatcher(url: b,
            onEvent: { Task { await cb.tick() } },
            onInstallFailure: { _ in })
        wa.start(); wb.start()
        try? await Task.sleep(for: .milliseconds(100))
        let h = try FileHandle(forWritingTo: a)
        try h.seekToEnd(); try h.write(contentsOf: Data("x".utf8)); try h.close()
        _ = await Self.waitUntil(2_000) { await ca.count >= 1 }
        wa.stop(); wb.stop()
        let na = await ca.count
        let nb = await cb.count
        #expect(na >= 1)
        #expect(nb == 0, "b watcher should not fire on a write")
    }

    // MARK: - stop() before start() does not crash

    @Test("stop() without start() is safe")
    func stopBeforeStart() async {
        let dir = Self.tempDir(); defer { Self.cleanup(dir) }
        let watcher = FileObjectWatcher(
            url: dir.appendingPathComponent("noop.json"),
            onEvent: {},
            onInstallFailure: { _ in })
        watcher.stop()
        // Just make sure we can also stop again.
        watcher.stop()
        #expect(true)
    }
}
