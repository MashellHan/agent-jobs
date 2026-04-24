import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-08, F-10, F-11, P-01.
@Suite("HiddenStore (persistence + recovery)")
struct HiddenStoreTests {

    private static func tempHome() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-hiddenstore-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("add then snapshot persists across instances")
    func addPersists() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s1 = HiddenStore(homeDir: home)
        try await s1.add("svc-a")
        try await s1.add("svc-b")
        let snap1 = await s1.snapshot()
        #expect(snap1 == ["svc-a", "svc-b"])

        let s2 = HiddenStore(homeDir: home)
        let snap2 = await s2.snapshot()
        #expect(snap2 == ["svc-a", "svc-b"])
    }

    @Test("remove deletes id and persists")
    func removePersists() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s1 = HiddenStore(homeDir: home)
        try await s1.add("svc-a")
        try await s1.add("svc-b")
        try await s1.remove("svc-a")
        let s2 = HiddenStore(homeDir: home)
        let snap = await s2.snapshot()
        #expect(snap == ["svc-b"])
    }

    @Test("on-disk JSON has version=1 and sorted hiddenIds")
    func onDiskShape() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s = HiddenStore(homeDir: home)
        try await s.add("z")
        try await s.add("a")
        try await s.add("m")
        let url = home.appendingPathComponent(HiddenStore.defaultRelativePath)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(HiddenStore.File.self, from: data)
        #expect(decoded.version == 1)
        #expect(decoded.hiddenIds == ["a", "m", "z"])
    }

    @Test("corrupt JSON loads as empty set; next add overwrites")
    func corruptFileRecovery() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let dir = home.appendingPathComponent(".agent-jobs")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = home.appendingPathComponent(HiddenStore.defaultRelativePath)
        try Data("not json".utf8).write(to: url)

        let s = HiddenStore(homeDir: home)
        let snap = await s.snapshot()
        #expect(snap.isEmpty)
        try await s.add("svc-x")
        let s2 = HiddenStore(homeDir: home)
        let snap2 = await s2.snapshot()
        #expect(snap2 == ["svc-x"])
    }

    @Test("unknown version loads as empty set")
    func unknownVersionRecovery() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let dir = home.appendingPathComponent(".agent-jobs")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = home.appendingPathComponent(HiddenStore.defaultRelativePath)
        let bad = HiddenStore.File(version: 999, hiddenIds: ["should-be-ignored"])
        try JSONEncoder().encode(bad).write(to: url)

        let s = HiddenStore(homeDir: home)
        let snap = await s.snapshot()
        #expect(snap.isEmpty)
    }

    @Test("missing file → empty set, no throw")
    func missingFile() async {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s = HiddenStore(homeDir: home)
        let snap = await s.snapshot()
        #expect(snap.isEmpty)
    }

    @Test("write atomicity: tmp file is cleaned up after replace")
    func tmpCleanedUp() async throws {
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s = HiddenStore(homeDir: home)
        try await s.add("a")
        try await s.add("b")
        let tmp = home.appendingPathComponent(HiddenStore.defaultRelativePath + ".tmp")
        // After successful replace, tmp should not exist (replaceItemAt
        // moves it into place; first-write moveItem leaves nothing behind).
        #expect(!FileManager.default.fileExists(atPath: tmp.path))
    }

    /// AC-P-01: median round-trip < 50 ms over 50 runs. Strict per E001 —
    /// gated behind AGENTJOBS_PERF=1 so dev-box noise doesn't fail CI.
    @Test("AC-P-01: HiddenStore.add round-trip median < 50 ms (gated AGENTJOBS_PERF=1)")
    func addPerformance() async throws {
        guard ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1" else {
            return
        }
        let home = Self.tempHome(); defer { Self.cleanup(home) }
        let s = HiddenStore(homeDir: home)
        var samples: [Double] = []
        for i in 0..<50 {
            let start = Date()
            try await s.add("svc-\(i)")
            samples.append(Date().timeIntervalSince(start) * 1000.0)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        FileHandle.standardError.write(
            Data("[AC-P-01] HiddenStore.add median: \(median) ms\n".utf8))
        #expect(median < 50.0)
    }
}
