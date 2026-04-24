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
        // 6 words but their concatenation is > 40 chars.
        let n = ClaudeScheduledTasksProvider.friendlyCronName(
            "averylongwordhere anotherlongwordhere yetanotherlong wow huh ok"
        )
        #expect(n.hasSuffix("…"))
        // Original 40-char body + 1 ellipsis scalar.
        #expect(n.count == 41)
    }

    @Test("empty / whitespace-only / punctuation-only → 'Claude task'")
    func emptyDefault() {
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("") == "Claude task")
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("    ") == "Claude task")
        #expect(ClaudeScheduledTasksProvider.friendlyCronName("...!!!") == "Claude task")
    }

    @Test("stub discover() returns []")
    func stubDiscover() async throws {
        let p = ClaudeScheduledTasksProvider(
            tasksPath: URL(fileURLWithPath: "/nonexistent")
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }
}
