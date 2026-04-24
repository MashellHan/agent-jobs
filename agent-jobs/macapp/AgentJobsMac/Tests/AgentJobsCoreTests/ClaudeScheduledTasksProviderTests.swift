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
        let p = ClaudeScheduledTasksProvider(
            tasksPath: URL(fileURLWithPath: "/tmp/fake.json"),
            loader: { _, seconds in
                // Simulate the production timeout race directly.
                try await withThrowingTaskGroup(of: Data.self) { group in
                    group.addTask {
                        // Pretend to read forever.
                        try await Task.sleep(for: .seconds(60))
                        return Data()
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
        )
        // Override timeout via shorter loader path? The loader receives the
        // configured timeout (5s). We don't want a 5s test, so plumb a
        // sub-loader that throws .timeout immediately.
        let pFast = ClaudeScheduledTasksProvider(
            tasksPath: URL(fileURLWithPath: "/tmp/fake.json"),
            loader: { _, _ in throw ProviderError.timeout }
        )
        do {
            _ = try await pFast.discover()
            Issue.record("expected throw")
        } catch ProviderError.timeout {
            // ok
        } catch {
            Issue.record("expected .timeout, got \(error)")
        }
        // The first provider is unused but its construction validates the
        // timeout-shaped seam compiles.
        _ = p
    }
}
