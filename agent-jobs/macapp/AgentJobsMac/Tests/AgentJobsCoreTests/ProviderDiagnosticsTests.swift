import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-14: provider diagnostics surface lastError + per-file failures.
/// Closes T-004 unit-test slice.
@Suite("ProviderDiagnostics + ProviderHealth (M05 T05 / closes T-004)")
struct ProviderDiagnosticsTests {

    @Test("recordSuccess clears lastError and stamps lastSuccessAt")
    func recordSuccessClears() async {
        let diag = ProviderDiagnostics()
        await diag.recordIOError("transient")
        let before = await diag.snapshot()
        #expect(before.0 != nil)
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        await diag.recordSuccess(at: stamp)
        let after = await diag.snapshot()
        #expect(after.0 == nil)
        #expect(after.1 == stamp)
        #expect(after.2.isEmpty)
    }

    @Test("AC-F-14: recordFileFailure populates per-file map and lastError")
    func perFileFailureRecorded() async {
        let diag = ProviderDiagnostics()
        await diag.recordFileFailure("session-a.jsonl", "EACCES: permission denied")
        await diag.recordFileFailure("session-b.jsonl", "malformed json line 12")
        let snap = await diag.snapshot()
        #expect(snap.2.count == 2)
        #expect(snap.2["session-a.jsonl"] == "EACCES: permission denied")
        if case .ioError(let msg) = snap.0 {
            #expect(msg.contains("2 source file(s)"))
        } else {
            Issue.record("expected lastError to be .ioError, got \(String(describing: snap.0))")
        }
    }

    @Test("AC-F-12 → diagnostics: ClaudeScheduledTasksProvider with valid file → no lastError, lastSuccessAt set")
    func scheduledTasksHealthOnValid() async throws {
        let url = try FixtureLoader.url("scheduled_tasks.valid", ext: "json")
        let provider = ClaudeScheduledTasksProvider(tasksPath: url)
        _ = try await provider.discover()
        let snap = await provider.diagnostics?.snapshot()
        #expect(snap?.0 == nil)
        #expect(snap?.1 != nil)
    }

    @Test("AC-F-14: ClaudeScheduledTasksProvider with malformed json → lastError populated")
    func scheduledTasksHealthOnMalformed() async throws {
        let url = try FixtureLoader.url("scheduled_tasks.malformed", ext: "json")
        let provider = ClaudeScheduledTasksProvider(tasksPath: url)
        _ = try await provider.discover()
        let snap = await provider.diagnostics?.snapshot()
        #expect(snap?.0 != nil, "malformed JSON must surface as lastError for tooltip")
        #expect(snap?.2["scheduled_tasks.malformed.json"] != nil)
    }

    @Test("AC-F-14: ProviderHealth round-trips through ServiceRegistry.DiscoverResult")
    func registrySurfacesHealth() async throws {
        let url = try FixtureLoader.url("scheduled_tasks.valid", ext: "json")
        let provider = ClaudeScheduledTasksProvider(tasksPath: url)
        let registry = ServiceRegistry(providers: [provider])
        let result = await registry.discoverAllDetailed()
        #expect(result.health.count == 1)
        #expect(result.health[0].providerId == ClaudeScheduledTasksProvider.providerId)
        #expect(result.health[0].lastError == nil)
        #expect(result.health[0].lastSuccessAt != nil)
    }

    @Test("DiscoverResult.health is empty when no provider exposes diagnostics")
    func emptyWhenNoDiagnostics() async {
        // ClaudeScheduledTasksProvider can be configured with diagnostics=nil
        // to opt out (e.g. when callers wire their own observability).
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nope-\(UUID().uuidString).json")
        let provider = ClaudeScheduledTasksProvider(tasksPath: url, loader: nil, diagnostics: nil)
        let registry = ServiceRegistry(providers: [provider])
        let result = await registry.discoverAllDetailed()
        #expect(result.health.isEmpty)
    }
}
