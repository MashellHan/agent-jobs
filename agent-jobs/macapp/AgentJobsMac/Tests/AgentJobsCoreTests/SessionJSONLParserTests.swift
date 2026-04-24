import Testing
import Foundation
@testable import AgentJobsCore

@Suite("SessionJSONLParser (sync)")
struct SessionJSONLParserSyncTests {

    private static func loadFixture(_ name: String) throws -> String {
        try FixtureLoader.text("sessions/\(name)", ext: "jsonl")
    }

    @Test("single CronCreate yields exactly one create entry keyed by result id")
    func singleCreate() throws {
        let text = try Self.loadFixture("single-create")
        let out = SessionJSONLParser.parse(text: text, projectDir: "-Users-dev-proj-alpha")
        #expect(out.creates.count == 1)
        #expect(out.deletes.isEmpty)
        let task = out.creates["cron_abc"]
        #expect(task != nil)
        #expect(task?.cron == "0 9 * * *")
        #expect(task?.prompt == "summarize the morning standup")
        #expect(task?.recurring == true)
        #expect(task?.durable == false)
        #expect(task?.cwd == "/Users/dev/proj/alpha")
        #expect(task?.projectDir == "-Users-dev-proj-alpha")
        #expect(task?.sessionId.hasPrefix("sess-aaaaaaaa") == true)
    }

    @Test("CronCreate followed by CronDelete leaves create + delete sets populated")
    func createThenDelete() throws {
        let text = try Self.loadFixture("create-then-delete")
        let out = SessionJSONLParser.parse(text: text, projectDir: "-Users-dev-proj-beta")
        #expect(out.creates["cron_zzz"] != nil)
        #expect(out.deletes.contains("cron_zzz"))
        // durable from result wins over pending
        #expect(out.creates["cron_zzz"]?.durable == true)
    }

    @Test("mixed fixture: 2 creates, 1 unrelated delete, 1 malformed line skipped")
    func mixedFixture() throws {
        let text = try Self.loadFixture("mixed")
        let out = SessionJSONLParser.parse(text: text, projectDir: "-Users-dev-proj-gamma")
        #expect(out.creates.count == 2)
        #expect(out.creates["cron_one"] != nil)
        #expect(out.creates["cron_two"] != nil)
        #expect(out.deletes == ["cron_unrelated"])
    }

    @Test("empty input → empty output")
    func emptyInput() {
        let out = SessionJSONLParser.parse(text: "", projectDir: "p")
        #expect(out.creates.isEmpty)
        #expect(out.deletes.isEmpty)
    }

    @Test("lines without cron substrings are short-circuited (no parse)")
    func noCronSubstrings() {
        let line = "{\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"hello\"}]}}"
        let out = SessionJSONLParser.parse(text: line, projectDir: "p")
        #expect(out.creates.isEmpty)
        #expect(out.deletes.isEmpty)
    }

    @Test("tool_result without matching pending tool_use is ignored")
    func orphanToolResult() {
        // Contains "CronCreate" so pre-filter passes, but no pending to match.
        let line = #"{"message":{"content":[{"type":"tool_result","tool_use_id":"missing"}]},"toolUseResult":{"id":"x"},"_marker":"CronCreate"}"#
        let out = SessionJSONLParser.parse(text: line, projectDir: "p")
        #expect(out.creates.isEmpty)
    }

    @Test("CronDelete with empty id is ignored")
    func cronDeleteEmptyId() {
        let line = #"{"message":{"content":[{"type":"tool_use","name":"CronDelete","input":{"id":""}}]}}"#
        let out = SessionJSONLParser.parse(text: line, projectDir: "p")
        #expect(out.deletes.isEmpty)
    }

    @Test("non-object message content is ignored without throwing")
    func nonArrayContent() {
        let line = #"{"message":{"content":"CronCreate not really"}}"#
        let out = SessionJSONLParser.parse(text: line, projectDir: "p")
        #expect(out.creates.isEmpty)
    }
}

@Suite("SessionJSONLParser (async stream)")
struct SessionJSONLParserAsyncTests {

    /// Adapter: turn a `[String]` into an `AsyncSequence<String>`.
    private struct ArrayLines: AsyncSequence {
        typealias Element = String
        let lines: [String]
        struct AsyncIterator: AsyncIteratorProtocol {
            var iter: IndexingIterator<[String]>
            mutating func next() async -> String? { iter.next() }
        }
        func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(iter: lines.makeIterator())
        }
    }

    @Test("parse(lines:) sums creates from a streamed sequence")
    func streamedCreates() async throws {
        let text = try FixtureLoader.text("sessions/mixed", ext: "jsonl")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let out = try await SessionJSONLParser.parse(
            lines: ArrayLines(lines: lines),
            projectDir: "-Users-dev-proj-gamma"
        )
        #expect(out.creates.count == 2)
        #expect(out.deletes == ["cron_unrelated"])
    }

    @Test("parse(lines:) with empty stream → empty output")
    func emptyStream() async throws {
        let out = try await SessionJSONLParser.parse(
            lines: ArrayLines(lines: []),
            projectDir: "p"
        )
        #expect(out.creates.isEmpty)
        #expect(out.deletes.isEmpty)
    }
}
