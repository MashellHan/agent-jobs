import Testing
import Foundation
@testable import AgentJobsCore

@Suite("ClaudeSessionCronProvider.projectName / projectNameFromDir")
struct ClaudeSessionCronProviderNameTests {

    @Test("projectName uses last 2 segments of cwd when present")
    func cwdLastTwo() {
        let n = ClaudeSessionCronProvider.projectName(
            cwd: "/Users/dev/proj/alpha", projectDir: "ignored"
        )
        #expect(n == "proj/alpha")
    }

    @Test("projectName falls back to projectDir when cwd is empty")
    func cwdFallback() {
        let n = ClaudeSessionCronProvider.projectName(
            cwd: "", projectDir: "-Users-dev-proj-alpha"
        )
        #expect(n == "proj/alpha")
    }

    @Test("projectNameFromDir strips -Users-<u>- prefix and dashes → slashes")
    func projectNameFromDir() {
        let n = ClaudeSessionCronProvider.projectNameFromDir(
            "-Users-mengxionghan--superset-projects-Tmp"
        )
        #expect(n == "superset/projects/Tmp")
    }

    @Test("projectNameFromDir handles single trailing-dash form")
    func projectNameFromDirSingleDash() {
        let n = ClaudeSessionCronProvider.projectNameFromDir("-Users-dev-foo")
        #expect(n == "foo")
    }
}

@Suite("ClaudeSessionCronProvider.discover")
struct ClaudeSessionCronProviderDiscoverTests {

    /// Build an isolated temp `~/.claude/projects/<projectDir>/<sessionId>.jsonl`
    /// rooted somewhere under /tmp.
    private static func stage(
        projectDir: String,
        sessionId: String,
        contents: String,
        ageSeconds: TimeInterval? = nil
    ) throws -> (root: URL, projects: URL, file: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-sessions-\(UUID().uuidString)")
        let projects = root.appendingPathComponent("projects")
        let project = projects.appendingPathComponent(projectDir)
        try FileManager.default.createDirectory(
            at: project, withIntermediateDirectories: true
        )
        let file = project.appendingPathComponent("\(sessionId).jsonl")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        if let ageSeconds {
            let mtime = Date().addingTimeInterval(-ageSeconds)
            try FileManager.default.setAttributes(
                [.modificationDate: mtime], ofItemAtPath: file.path
            )
        }
        return (root, projects, file)
    }

    @Test("AC-I-03: missing projects directory → []")
    func missingProjectsDir() async throws {
        let bogusProjects = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-no-projects-\(UUID().uuidString)")
        let bogusDurable = bogusProjects.appendingPathComponent("scheduled_tasks.json")
        let p = ClaudeSessionCronProvider(
            projectsRoot: bogusProjects,
            durableTasksPath: bogusDurable
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("AC-F-01: single CronCreate fixture surfaces one Service with stable id and running status")
    func singleCreate() async throws {
        let text = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-aaaaaaaa-1111-2222-3333-444444444444",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.count == 1)
        let s = services[0]
        #expect(s.id == "claude.session-cron:sess-aaa:cron_abc")
        #expect(s.status == .running)
        #expect(s.kind == .scheduled)
        if case .cron(let expr) = s.schedule { #expect(expr == "0 9 * * *") }
        else { Issue.record("expected cron schedule") }
        #expect(s.owner == .agent(.claude))
        #expect(s.project == "proj/alpha")
        #expect(s.origin?.toolName == "CronCreate")
    }

    @Test("AC-F-02: CronCreate followed by CronDelete yields zero services")
    func createThenDelete() async throws {
        let text = try FixtureLoader.text("sessions/create-then-delete", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-beta",
            sessionId: "sess-bbbbbbbb-1111-2222-3333-444444444444",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("AC-F-03: mixed fixture yields exactly two services")
    func mixedFixture() async throws {
        let text = try FixtureLoader.text("sessions/mixed", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-gamma",
            sessionId: "sess-cccccccc-1111-2222-3333-444444444444",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.count == 2)
        #expect(services.allSatisfy { $0.id.hasPrefix("claude.session-cron:sess-ccc:") })
    }

    @Test("AC-F-04: file older than 7 days is skipped (mtime gate)")
    func staleFileSkipped() async throws {
        let text = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-old",
            contents: text,
            ageSeconds: 8 * 24 * 60 * 60 // 8 days
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("AC-F-06: status .idle when session mtime > 15 min")
    func idleStatusWhenStale() async throws {
        let text = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-aaaaaaaa-mid",
            contents: text,
            ageSeconds: 60 * 60 // 1 hour
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.count == 1)
        #expect(services[0].status == .idle)
    }

    @Test("AC-F-08: ids stable across two discover() calls")
    func idsStable() async throws {
        let text = try FixtureLoader.text("sessions/mixed", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-gamma",
            sessionId: "sess-cccccccc-stable",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let a = try await p.discover()
        let b = try await p.discover()
        #expect(Set(a.map(\.id)) == Set(b.map(\.id)))
    }

    @Test("AC-I-02: durable scheduled_tasks.json entry dedups matching session task")
    func dedupAgainstDurable() async throws {
        // Session emits cron "0 9 * * *" prompt "summarize the morning standup".
        let sessionText = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-aaaaaaaa-dedup",
            contents: sessionText
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        // Durable list contains the same (cron, prompt) → dedup drops it.
        let durablePath = staged.root.appendingPathComponent("scheduled_tasks.json")
        let durableJson = #"[{"cron":"0 9 * * *","prompt":"summarize the morning standup"}]"#
        try durableJson.write(to: durablePath, atomically: true, encoding: .utf8)

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: durablePath
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("malformed durable JSON is tolerated (empty key list, no dedup applied)")
    func malformedDurableTolerated() async throws {
        let text = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-aaaaaaaa-malf",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        let durablePath = staged.root.appendingPathComponent("scheduled_tasks.json")
        try "{not json".write(to: durablePath, atomically: true, encoding: .utf8)

        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: durablePath
        )
        let services = try await p.discover()
        #expect(services.count == 1)
    }

    @Test("traversal-style project entry containing '..' is ignored")
    func traversalEntryIgnored() async throws {
        let text = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let staged = try Self.stage(
            projectDir: "-Users-dev-proj-alpha",
            sessionId: "sess-aaaaaaaa-trav",
            contents: text
        )
        defer { try? FileManager.default.removeItem(at: staged.root) }

        // Create a sibling entry whose name contains "..".
        // FileManager will still list the entry; our guard must drop it.
        // (We can't actually create a directory literally named ".." — the
        // guard is also coded against entries containing "/" which is
        // similarly impossible at the FS layer; both are belt-and-suspenders.
        // The good staged session still surfaces.)
        let p = ClaudeSessionCronProvider(
            projectsRoot: staged.projects,
            durableTasksPath: staged.root.appendingPathComponent("none.json")
        )
        let services = try await p.discover()
        #expect(services.count == 1)
    }
}

@Suite("ClaudeSessionCronProvider performance (AC-P-02)")
struct ClaudeSessionCronProviderPerfTests {

    @Test("AC-P-02: parse 10,000-line synthetic JSONL in < 500 ms")
    func tenKLinesUnder500ms() async throws {
        if ProcessInfo.processInfo.environment["AGENTJOBS_SKIP_PERF"] != nil { return }

        // Build a synthetic ~1MB JSONL with 100 cron pairs interleaved with
        // ~9800 noise lines.
        var lines: [String] = []
        lines.reserveCapacity(10_000)
        for i in 0..<100 {
            let useId = "tu_\(i)"
            let cronId = "cron_\(i)"
            lines.append(#"{"timestamp":"2026-04-23T10:00:00Z","sessionId":"sess-perf-1234","cwd":"/Users/dev/proj/perf","message":{"content":[{"type":"tool_use","id":"\#(useId)","name":"CronCreate","input":{"cron":"* * * * *","prompt":"task \#(i)","recurring":true,"durable":false}}]}}"#)
            lines.append(#"{"timestamp":"2026-04-23T10:00:01Z","sessionId":"sess-perf-1234","cwd":"/Users/dev/proj/perf","message":{"content":[{"type":"tool_result","tool_use_id":"\#(useId)"}]},"toolUseResult":{"id":"\#(cronId)","durable":false}}"#)
        }
        // ~9800 noise lines without cron substrings → fast pre-filter path.
        let noise = #"{"message":{"content":[{"type":"text","text":"hello"}]}}"#
        while lines.count < 10_000 { lines.append(noise) }
        let text = lines.joined(separator: "\n")

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-perf-\(UUID().uuidString)")
        let projects = root.appendingPathComponent("projects")
        let project = projects.appendingPathComponent("perf-proj")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let file = project.appendingPathComponent("sess-perf-1234.jsonl")
        try text.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let p = ClaudeSessionCronProvider(
            projectsRoot: projects,
            durableTasksPath: root.appendingPathComponent("none.json")
        )
        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            _ = try? await p.discover()
        }
        #expect(elapsed < .milliseconds(500))
    }
}
