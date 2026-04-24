import Testing
import Foundation
@testable import AgentJobsCore

/// AC-I-02 end-to-end: a registry containing both `ClaudeScheduledTasksProvider`
/// and `ClaudeSessionCronProvider` correctly suppresses the session-derived
/// duplicate so that a task present in both surfaces exactly once (via the
/// durable provider).
@Suite("ClaudeSessionCronProvider integration with scheduled-tasks provider")
struct ClaudeSessionCronProviderIntegrationTests {

    @Test("AC-I-02: durable + session both contain task → surfaces once via durable provider")
    func dedupAcrossProviders() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-int-\(UUID().uuidString)")
        let projects = root.appendingPathComponent("projects")
        let project = projects.appendingPathComponent("-Users-dev-proj-alpha")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Session JSONL emits cron "0 9 * * *" prompt "summarize the morning standup".
        let sessionText = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let sessionFile = project.appendingPathComponent(
            "sess-aaaaaaaa-1111-2222-3333-444444444444.jsonl"
        )
        try sessionText.write(to: sessionFile, atomically: true, encoding: .utf8)

        // Durable scheduled_tasks.json contains the same (cron, prompt).
        let durablePath = root.appendingPathComponent("scheduled_tasks.json")
        let durableJson = #"[{"cron":"0 9 * * *","prompt":"summarize the morning standup"}]"#
        try durableJson.write(to: durablePath, atomically: true, encoding: .utf8)

        let registry = ServiceRegistry(providers: [
            ClaudeScheduledTasksProvider(tasksPath: durablePath),
            ClaudeSessionCronProvider(
                projectsRoot: projects,
                durableTasksPath: durablePath
            )
        ])

        let services = await registry.discoverAll()
        // Exactly one — the durable copy. Session provider must dedup itself out.
        #expect(services.count == 1)
        #expect(services[0].id.hasPrefix("claude.scheduled-tasks:"))
    }

    @Test("AC-I-02 negative: distinct (cron, prompt) → both providers emit independently")
    func noDedupForDistinctTasks() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-int-distinct-\(UUID().uuidString)")
        let projects = root.appendingPathComponent("projects")
        let project = projects.appendingPathComponent("-Users-dev-proj-alpha")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionText = try FixtureLoader.text("sessions/single-create", ext: "jsonl")
        let sessionFile = project.appendingPathComponent(
            "sess-aaaaaaaa-1111-2222-3333-444444444444.jsonl"
        )
        try sessionText.write(to: sessionFile, atomically: true, encoding: .utf8)

        // Durable list has a different cron — should NOT dedup.
        let durablePath = root.appendingPathComponent("scheduled_tasks.json")
        let durableJson = #"[{"cron":"0 12 * * *","prompt":"different prompt entirely"}]"#
        try durableJson.write(to: durablePath, atomically: true, encoding: .utf8)

        let registry = ServiceRegistry(providers: [
            ClaudeScheduledTasksProvider(tasksPath: durablePath),
            ClaudeSessionCronProvider(
                projectsRoot: projects,
                durableTasksPath: durablePath
            )
        ])

        let services = await registry.discoverAll()
        #expect(services.count == 2)
        #expect(services.contains { $0.id.hasPrefix("claude.scheduled-tasks:") })
        #expect(services.contains { $0.id.hasPrefix("claude.session-cron:") })
    }
}
