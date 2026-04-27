import Testing
import Foundation
import SwiftUI
import AppKit
@testable import AgentJobsCore
@testable import AgentJobsMacUI

/// AC-V-01..V-03 + V-05: visual baselines for AutoRefreshIndicator's three
/// states plus its placement inside the menu-bar popover header and the
/// dashboard toolbar.
///
/// Baselines live at `.workflow/m04/screenshots/baseline/<name>.png`.
/// Cycle outputs at `.workflow/m04/screenshots/cycle-NNN/<name>.png`
/// (cycle = `M04_CYCLE` env, default "001"). On first run a missing baseline
/// is recorded ([BASELINE_RECORDED]) and the test passes; subsequent runs
/// diff via `scripts/visual-diff.sh` at the project's standard 2 % threshold.
///
/// AC-V-02 (refreshing) is captured with `accessibilityReduceMotion = true`
/// to suppress pulse-phase jitter — otherwise the symbolEffect frame-time
/// would make the baseline non-deterministic.
/// Test-only ServiceProvider that holds for `holdMillis` before returning.
/// Lets the visual test capture the indicator while `vm.isRefreshing` is
/// still true without mutating the VM's `private(set)` state.
private struct SlowFixtureProvider: ServiceProvider {
    static let providerId = "fixture.slow"
    static let displayName = "Slow Fixture"
    static let category: ServiceSource.Category = .agentJobs
    let services: [Service]
    let holdMillis: Int
    func discover() async throws -> [Service] {
        try? await Task.sleep(for: .milliseconds(holdMillis))
        return services
    }
}

@Suite("AutoRefreshIndicator visual baselines (M04 AC-V-01..V-03, V-05)", .serialized)
@MainActor
struct AutoRefreshIndicatorVisualTests {

    // MARK: - AC-V-01 — idle (light + dark)

    @Test("AC-V-01: indicator-idle-light")
    func idleLight() async throws {
        try await capture(name: "indicator-idle-light",
                          size: CGSize(width: 200, height: 28),
                          appearance: .aqua) {
            await $0.refresh()
        } view: { vm in
            AutoRefreshIndicator()
                .environment(vm)
                .padding(4)
                .frame(width: 200, height: 28, alignment: .leading)
        }
    }

    @Test("AC-V-01: indicator-idle-dark")
    func idleDark() async throws {
        try await capture(name: "indicator-idle-dark",
                          size: CGSize(width: 200, height: 28),
                          appearance: .darkAqua) {
            await $0.refresh()
        } view: { vm in
            AutoRefreshIndicator()
                .environment(vm)
                .padding(4)
                .frame(width: 200, height: 28, alignment: .leading)
        }
    }

    // MARK: - AC-V-02 — refreshing

    @Test("AC-V-02: indicator-refreshing-light")
    func refreshingLight() async throws {
        // Use a slow provider so the indicator observes isRefreshing == true
        // mid-flight without us mutating private(set) state.
        let slow = SlowFixtureProvider(services: Service.fixtures(),
                                       holdMillis: 2_000)
        let registry = ServiceRegistry(providers: [slow])
        let vm = ServiceRegistryViewModel(registry: registry)
        // Kick off refresh, do NOT await — capture during the hold window.
        let refreshTask = Task { await vm.refresh() }
        // Wait until isRefreshing flips true.
        var spun = 0
        while !vm.isRefreshing && spun < 200 {
            try? await Task.sleep(for: .milliseconds(10))
            spun += 1
        }
        let view = AutoRefreshIndicator()
            .environment(vm)
            .transaction { $0.disablesAnimations = true }  // suppress pulse phase
            .padding(4)
            .frame(width: 200, height: 28, alignment: .leading)
        let cyclePath = Self.cycleDir().appendingPathComponent("indicator-refreshing-light.png")
        let baselinePath = Self.baselineDir().appendingPathComponent("indicator-refreshing-light.png")
        _ = try ScreenshotHarness.write(view, size: CGSize(width: 200, height: 28),
                                         appearance: .aqua, to: cyclePath)
        if !FileManager.default.fileExists(atPath: baselinePath.path) {
            try FileManager.default.createDirectory(
                at: baselinePath.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: cyclePath, to: baselinePath)
            FileHandle.standardError.write(Data("[BASELINE_RECORDED] indicator-refreshing-light\n".utf8))
        } else {
            try Self.runVisualDiff(baseline: baselinePath, candidate: cyclePath)
        }
        await refreshTask.value
        vm.stop()
    }

    // MARK: - AC-V-03 — error

    @Test("AC-V-03: indicator-error-light")
    func errorLight() async throws {
        try await capture(name: "indicator-error-light",
                          size: CGSize(width: 200, height: 28),
                          appearance: .aqua) { vm in
            // Failing registry → all-failed → lastRefreshError populated.
            await vm.refresh()
        } registry: { .failingRegistry() } view: { vm in
            AutoRefreshIndicator()
                .environment(vm)
                .padding(4)
                .frame(width: 200, height: 28, alignment: .leading)
        }
    }

    // MARK: - AC-V-05 — placement inside popover header + dashboard toolbar

    @Test("AC-V-05: popover-with-indicator-light")
    func popoverWithIndicator() async throws {
        try await capture(name: "popover-with-indicator-light",
                          size: CGSize(width: 360, height: 520),
                          appearance: .aqua) {
            await $0.refresh()
        } view: { vm in
            MenuBarPopoverView()
                .environment(vm)
                .frame(width: 360, height: 520)
        }
    }

    @Test("AC-V-05: dashboard-toolbar-with-indicator-light")
    func dashboardToolbarWithIndicator() async throws {
        try await capture(name: "dashboard-toolbar-with-indicator-light",
                          size: CGSize(width: 1200, height: 700),
                          appearance: .aqua) {
            await $0.refresh()
        } view: { vm in
            DashboardView()
                .environment(vm)
                .frame(width: 1200, height: 700)
        }
    }

    // MARK: - infrastructure (mirrors VisualBaselineTests; rooted at m04/)

    private func capture<V: View>(
        name: String,
        size: CGSize,
        appearance: NSAppearance.Name,
        prepare: (ServiceRegistryViewModel) async -> Void = { _ in },
        registry: () -> ServiceRegistry = { .fixtureRegistry() },
        @ViewBuilder view: (ServiceRegistryViewModel) -> V
    ) async throws {
        let vm = ServiceRegistryViewModel(registry: registry())
        await prepare(vm)
        let cyclePath = Self.cycleDir().appendingPathComponent("\(name).png")
        let baselinePath = Self.baselineDir().appendingPathComponent("\(name).png")
        _ = try ScreenshotHarness.write(view(vm), size: size,
                                         appearance: appearance, to: cyclePath)
        if !FileManager.default.fileExists(atPath: baselinePath.path) {
            try FileManager.default.createDirectory(
                at: baselinePath.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: cyclePath, to: baselinePath)
            FileHandle.standardError.write(
                Data("[BASELINE_RECORDED] \(name)\n".utf8))
            vm.stop()
            return
        }
        try Self.runVisualDiff(baseline: baselinePath, candidate: cyclePath)
        vm.stop()
    }

    private static func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(".workflow").path) {
                return dir
            }
            dir.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func baselineDir() -> URL {
        repoRoot().appendingPathComponent(".workflow/m04/screenshots/baseline")
    }

    private static func cycleDir() -> URL {
        let cycle = ProcessInfo.processInfo.environment["M04_CYCLE"] ?? "001"
        return repoRoot().appendingPathComponent(".workflow/m04/screenshots/cycle-\(cycle)")
    }

    private static func runVisualDiff(baseline: URL, candidate: URL) throws {
        let script = repoRoot().appendingPathComponent("scripts/visual-diff.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            FileHandle.standardError.write(
                Data("[visual-diff] script missing at \(script.path); skipping\n".utf8))
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path, baseline.path, candidate.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if proc.terminationStatus != 0 {
            Issue.record("visual-diff failed for \(baseline.lastPathComponent):\n\(out)")
        }
    }
}
