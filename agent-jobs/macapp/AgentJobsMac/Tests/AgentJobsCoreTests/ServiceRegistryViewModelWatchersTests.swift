import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMac

/// AC-F-07, F-08, F-09, F-10, F-11, F-12, P-01 (gated), P-04 (gated).
/// All tests pass an explicit `WatchPaths` rooted under the temp dir,
/// per AC-Q-04 — no test touches `~/.agent-jobs/` or `~/.claude/`.
private let perfEnabled =
    ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1"

@MainActor
@Suite("ServiceRegistryViewModel watchers wiring (M04)")
struct ServiceRegistryViewModelWatchersTests {

    /// Build an isolated temp WatchPaths + ensure the dir + files exist.
    private static func tempPaths() -> (WatchPaths, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-vmwatch-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let jobs = root.appendingPathComponent("jobs.json")
        let st = root.appendingPathComponent("scheduled_tasks.json")
        let cd = root.appendingPathComponent("claude-projects")
        try? Data("{}".utf8).write(to: jobs)
        try? Data("{}".utf8).write(to: st)
        try? FileManager.default.createDirectory(at: cd, withIntermediateDirectories: true)
        return (WatchPaths(jobsJson: jobs, scheduledTasks: st, claudeProjectsDir: cd), root)
    }

    private static func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }

    private static func waitUntil(_ ms: Int, _ p: () async -> Bool) async -> Bool {
        let step = 25
        for _ in 0..<(ms/step) {
            if await p() { return true }
            try? await Task.sleep(for: .milliseconds(step))
        }
        return await p()
    }

    // MARK: - AC-F-11: production paths resolve under NSHomeDirectory()
    // (allow-listed reference per AC-Q-04 — the only test allowed to
    // assert on production paths.)

    @Test("AC-F-11: WatchPaths.production resolves under NSHomeDirectory()")
    func productionPathsResolveUnderHome() {
        let p = WatchPaths.production
        let home = NSHomeDirectory()
        #expect(p.jobsJson.path.hasPrefix(home))
        #expect(p.scheduledTasks.path.hasPrefix(home))
        #expect(p.claudeProjectsDir.path.hasPrefix(home))
    }

    // MARK: - AC-F-12: startWatchers idempotent + stop() cancels everything

    @Test("startWatchers is idempotent (second call no-op)")
    func startWatchersIdempotent() async {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        let visibility = FakeVisibilityProvider(initial: true)
        await vm.startWatchers(visibility: visibility)
        let count1 = vm.services.count
        await vm.startWatchers(visibility: visibility)  // no-op
        let count2 = vm.services.count
        #expect(count1 == count2)
        vm.stop()
    }

    // MARK: - AC-F-09: isRefreshing flips around any refresh

    @Test("AC-F-09: refresh sets isRefreshing true→false; clears lastRefreshError on success")
    func refreshFlipsIsRefreshingAndClearsError() async {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        await vm.refresh()
        #expect(vm.isRefreshing == false)
        #expect(vm.lastRefreshError == nil)
        vm.stop()
    }

    @Test("AC-F-09: lastRefreshError set when allFailed")
    func lastRefreshErrorOnAllFailed() async {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .failingRegistry(),
            watchPaths: paths)
        await vm.refresh()
        #expect(vm.lastRefreshError != nil)
        vm.stop()
    }

    // MARK: - AC-F-10: in-place mutation across N refreshes; no transient empty

    @Test("AC-F-10: 10 refreshes against identical stub never transiently empty; ids stable")
    func inPlaceMutationStable() async {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        await vm.refresh()
        let baseline = vm.services.map(\.id)
        #expect(!baseline.isEmpty)
        for _ in 0..<10 {
            await vm.refresh()
            #expect(vm.services.count == baseline.count, "transient empty observed")
            #expect(vm.services.map(\.id) == baseline, "id ordering changed")
        }
        vm.stop()
    }

    // MARK: - AC-F-07: visibility false pauses ticker; visibility true resumes

    @Test("AC-F-07: visibility false → ticker pauses; true → catch-up tick fires")
    func visibilityPauseResume() async {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        let visibility = FakeVisibilityProvider(initial: true)
        await vm.startWatchers(visibility: visibility)
        let firstRefreshAt = vm.lastRefresh
        // Hide.
        visibility.set(false)
        try? await Task.sleep(for: .milliseconds(200))
        // Show again — should trigger an immediate catch-up.
        visibility.set(true)
        let observed = await Self.waitUntil(2_000) {
            vm.lastRefresh > firstRefreshAt
        }
        vm.stop()
        #expect(observed, "expected catch-up refresh after visibility resumed")
    }

    // MARK: - AC-F-13: jobs.json install failure surfaces lastRefreshError

    @Test("AC-F-13: missing jobs.json install failure → lastRefreshError")
    func installFailureSurfaces() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-vmwatch-fail-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { Self.cleanup(root) }
        // jobs.json absent → install fails
        let paths = WatchPaths(
            jobsJson: root.appendingPathComponent("missing.json"),
            scheduledTasks: root.appendingPathComponent("st.json"),
            claudeProjectsDir: root.appendingPathComponent("cd"))
        try? Data("{}".utf8).write(to: paths.scheduledTasks)
        try? FileManager.default.createDirectory(at: paths.claudeProjectsDir, withIntermediateDirectories: true)
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        let visibility = FakeVisibilityProvider(initial: true)
        await vm.startWatchers(visibility: visibility)
        let observed = await Self.waitUntil(2_000) { vm.lastRefreshError != nil }
        vm.stop()
        #expect(observed, "expected lastRefreshError set by missing jobs.json install failure")
    }

    // MARK: - AC-P-01 (gated): end-to-end median latency < 500 ms

    @Test("AC-P-01: median end-to-end refresh latency < 500 ms over 5 runs",
          .enabled(if: perfEnabled))
    func endToEndLatencyMedian() async throws {
        let (paths, root) = Self.tempPaths(); defer { Self.cleanup(root) }
        let vm = ServiceRegistryViewModel(
            registry: .fixtureRegistry(),
            watchPaths: paths)
        let visibility = FakeVisibilityProvider(initial: true)
        await vm.startWatchers(visibility: visibility)
        var deltas: [Double] = []
        for i in 0..<5 {
            let mark = vm.lastRefresh
            try Data("v\(i)".utf8).write(to: paths.jobsJson)
            let t0 = Date()
            let observed = await Self.waitUntil(2_000) { vm.lastRefresh > mark }
            #expect(observed)
            deltas.append(Date().timeIntervalSince(t0) * 1000)
        }
        vm.stop()
        let sorted = deltas.sorted()
        let median = sorted[sorted.count / 2]
        #expect(median <= 500.0, "median latency \(median)ms > 500ms")
    }
}
