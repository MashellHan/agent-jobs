import Testing
import Foundation
@testable import AgentJobsCore

@Suite("ClaudeScheduledTasksProvider.friendlyCronName")
struct ClaudeFriendlyCronNameTests {

    @Test("collapses whitespace runs and trims")
    func collapseWhitespace() {
        let n = ClaudeScheduledTasksProvider.friendlyCronName("  hello   world  ")
        #expect(n == "hello world")
    }

    @Test("strips leading punctuation")
    func stripsLeadingPunctuation() {
        let n = ClaudeScheduledTasksProvider.friendlyCronName("...summarize PRs")
        #expect(n == "summarize PRs")
    }

    @Test("takes the first 6 words")
    func firstSixWords() {
        let n = ClaudeScheduledTasksProvider.friendlyCronName(
            "one two three four five six seven eight"
        )
        #expect(n == "one two three four five six")
    }

    @Test("truncates > 40 chars and appends ellipsis")
    func truncatesLong() {
        let n = ClaudeScheduledTasksProvider.friendlyCronName(
            "averylongwordhere anotherlongwordhere yetanotherlong wow huh ok"
        )
        #expect(n.hasSuffix("…"))
        #expect(n.count == 41)
    }

    @Test("empty / whitespace-only / punctuation-only → 'Claude task'")
    func emptyDefault() {
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("") == "Claude task")
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("    ") == "Claude task")
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("...!!!") == "Claude task")
    }
}

@Suite("ClaudeScheduledTasksProvider.discover")
struct ClaudeScheduledTasksProviderDiscoverTests {

    private static func provider(loaderResult: Result<Data, Error>) -> ClaudeScheduledTasksProvider {
        ClaudeScheduledTasksProvider(
            tasksPath: URL(fileURLWithPath: "/tmp/fake-claude-tasks.json"),
            loader: { _, _ in
                switch loaderResult {
                case .success(let d): return d
                case .failure(let e): throw e
                }
            }
        )
    }

    @Test("missing file → []")
    func missingFile() async throws {
        // Real-FS path: a definitely-nonexistent file under /tmp.
        let bogus = URL(fileURLWithPath: "/tmp/agentjobs-claude-tasks-\(UUID().uuidString).json")
        let p = ClaudeScheduledTasksProvider(tasksPath: bogus)
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("empty file → []")
    func emptyFile() async throws {
        let p = Self.provider(loaderResult: .success(Data()))
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("malformed JSON → []")
    func malformedJson() async throws {
        let raw = try FixtureLoader.data("scheduled_tasks.malformed", ext: "json")
        let p = Self.provider(loaderResult: .success(raw))
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("non-array root → []")
    func nonArrayRoot() async throws {
        let raw = try FixtureLoader.data("scheduled_tasks.non-array", ext: "json")
        let p = Self.provider(loaderResult: .success(raw))
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("valid 2-entry array → 2 services with correct shape")
    func validArray() async throws {
        let raw = try FixtureLoader.data("scheduled_tasks.valid", ext: "json")
        let p = Self.provider(loaderResult: .success(raw))
        let services = try await p.discover()
        #expect(services.count == 2)
        for svc in services {
            if case .claudeScheduledTask(let durable) = svc.source {
                #expect(durable == true)
            } else {
                Issue.record("expected .claudeScheduledTask source, got \(svc.source)")
            }
            #expect(svc.kind == .scheduled)
            #expect(svc.status == .scheduled)
            if case .cron = svc.schedule { /* ok */ } else {
                Issue.record("expected .cron schedule, got \(svc.schedule)")
            }
            if case .agent(let kind) = svc.owner {
                #expect(kind == .claude)
            } else {
                Issue.record("expected owner .agent(.claude)")
            }
            #expect(svc.createdAt == nil)
            #expect(svc.id.hasPrefix("claude.scheduled-tasks:"))
        }
    }

    @Test("id stable across discovery calls for same input")
    func idStability() async throws {
        let raw = try FixtureLoader.data("scheduled_tasks.valid", ext: "json")
        let p = Self.provider(loaderResult: .success(raw))
        let a = try await p.discover()
        let b = try await p.discover()
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test("hung loader (timeout) → throws ProviderError.timeout")
    func hungLoaderTimesOut() async {
        // Loader throws .timeout immediately so the test is fast and the
        // provider's `catch ProviderError.timeout` branch is exercised.
        let p = ClaudeScheduledTasksProvider(
            tasksPath: URL(fileURLWithPath: "/tmp/fake.json"),
            loader: { _, _ in throw ProviderError.timeout }
        )
        do {
            _ = try await p.discover()
            Issue.record("expected throw")
        } catch ProviderError.timeout {
            // ok
        } catch {
            Issue.record("expected .timeout, got \(error)")
        }
    }

    // MARK: - Real-FS coverage (T-test-01) — exercises production
    // `Self.readWithTimeout` (no `loader` injection) and the non-timeout
    // I/O catch branch. Drives the previously-uncovered lines 46-49 +
    // 110-125 in `ClaudeScheduledTasksProvider.swift` so AC-Q-03 holds.

    @Test("real-FS: valid JSON on disk → parsed via readWithTimeout (no loader override)")
    func realDiskValidJsonGoesThroughReadWithTimeout() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-claude-tasks-\(UUID().uuidString).json")
        let raw = try FixtureLoader.data("scheduled_tasks.valid", ext: "json")
        try raw.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // No `loader:` argument → production path takes
        // `Self.readWithTimeout(url:seconds:)`.
        let p = ClaudeScheduledTasksProvider(tasksPath: tmp)
        let services = try await p.discover()
        #expect(services.count == 2)
        #expect(services.allSatisfy { $0.id.hasPrefix("claude.scheduled-tasks:") })
    }

    @Test("real-FS: empty file on disk → [] via readWithTimeout")
    func realDiskEmptyFileGoesThroughReadWithTimeout() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-claude-tasks-empty-\(UUID().uuidString).json")
        try Data().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let p = ClaudeScheduledTasksProvider(tasksPath: tmp)
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("real-FS: tasksPath points at a directory → I/O catch branch returns []")
    func realDiskUnreadablePathHitsIoCatchBranch() async throws {
        // Pointing at a directory makes `Data(contentsOf:)` throw a
        // non-timeout I/O error, which the provider's generic `catch`
        // branch (lines 54-58) must swallow as `[]`.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-claude-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // `fileExists(atPath:)` is true for the directory, so the
        // `missing-file` short-circuit (line 37-39) is bypassed and
        // execution reaches `readWithTimeout`, which then throws an
        // I/O error that the catch-all converts to [].
        let p = ClaudeScheduledTasksProvider(tasksPath: dir)
        let services = try await p.discover()
        #expect(services.isEmpty)
    }
}

// MARK: - T-test-02 — fixture-based smoke for AC-Q-09 (defaultRegistry()
// can't easily be redirected, so we wire up an equivalent registry whose
// providers point at deterministic fixture paths under a temp HOME-like
// directory and assert the full `discoverAll()` path produces services).

@Suite("ClaudeScheduledTasksProvider.smoke (AC-Q-09 fixture parity)")
struct ClaudeScheduledTasksProviderSmokeTests {

    @Test("registry with fixture-backed claude provider yields services via discoverAll()")
    func registrySmokeFromFixture() async throws {
        // Stage a fake "$HOME/.claude" dir under a temp HOME-like directory.
        let fakeHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-fake-home-\(UUID().uuidString)")
        let claudeDir = fakeHome.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fakeHome) }

        let tasksPath = claudeDir.appendingPathComponent("scheduled_tasks.json")
        let raw = try FixtureLoader.data("scheduled_tasks.valid", ext: "json")
        try raw.write(to: tasksPath)

        let registry = ServiceRegistry(providers: [
            ClaudeScheduledTasksProvider(tasksPath: tasksPath)
        ])
        let result = await registry.discoverAllDetailed()
        #expect(result.totalCount == 1)
        #expect(result.succeededCount == 1)
        #expect(result.allFailed == false)
        // Two entries in the fixture → two services discovered end-to-end.
        #expect(result.services.count == 2)
        #expect(result.services.contains { $0.owner == .agent(.claude) })
    }
}
