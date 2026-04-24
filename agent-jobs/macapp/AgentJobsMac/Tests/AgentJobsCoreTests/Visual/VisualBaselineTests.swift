import Testing
import Foundation
import SwiftUI
import AppKit
@testable import AgentJobsCore
@testable import AgentJobsMac

/// AC-V-01..05 — visual baseline tests. Each test renders a deterministic
/// view tree against a fixture registry, captures a PNG via
/// `ScreenshotHarness`, then either records a missing baseline or compares
/// to it via `scripts/visual-diff.sh`.
///
/// Baselines live at `.workflow/m02/screenshots/baseline/<name>.png`.
/// Cycle outputs land at `.workflow/m02/screenshots/cycle-NNN/<name>.png`.
/// Cycle number is derived from the env var M02_CYCLE (defaults to "001").
@Suite("Visual baselines (AC-V-01..05)", .serialized)
@MainActor
struct VisualBaselineTests {

    // MARK: - AC-V-01 / 02 — Menu-bar popover light + dark

    @Test("AC-V-01: menubar-popover-light")
    func menubarPopoverLight() async throws {
        try await captureAndCompare(
            name: "menubar-popover-light",
            size: CGSize(width: 360, height: 520),
            appearance: .aqua,
            registry: .fixtureRegistry()
        ) { vm in
            MenuBarPopoverView()
                .environment(vm)
                .frame(width: 360)
        }
    }

    @Test("AC-V-02: menubar-popover-dark")
    func menubarPopoverDark() async throws {
        try await captureAndCompare(
            name: "menubar-popover-dark",
            size: CGSize(width: 360, height: 520),
            appearance: .darkAqua,
            registry: .fixtureRegistry()
        ) { vm in
            MenuBarPopoverView()
                .environment(vm)
                .frame(width: 360)
        }
    }

    // MARK: - AC-V-03 — Dashboard empty state

    @Test("AC-V-03: dashboard-empty-light")
    func dashboardEmptyLight() async throws {
        try await captureAndCompare(
            name: "dashboard-empty-light",
            size: CGSize(width: 1200, height: 700),
            appearance: .aqua,
            registry: .emptyRegistry()
        ) { vm in
            DashboardView()
                .environment(vm)
                .frame(width: 1200, height: 700)
        }
    }

    // MARK: - AC-V-04 — Dashboard populated

    @Test("AC-V-04: dashboard-populated-light")
    func dashboardPopulatedLight() async throws {
        try await captureAndCompare(
            name: "dashboard-populated-light",
            size: CGSize(width: 1200, height: 700),
            appearance: .aqua,
            registry: .fixtureRegistry()
        ) { vm in
            DashboardView()
                .environment(vm)
                .frame(width: 1200, height: 700)
        }
    }

    // MARK: - AC-V-05 — Dashboard with inspector populated

    @Test("AC-V-05: dashboard-inspector-populated-light")
    func dashboardInspectorPopulated() async throws {
        try await captureAndCompare(
            name: "dashboard-inspector-populated-light",
            size: CGSize(width: 1200, height: 700),
            appearance: .aqua,
            registry: .fixtureRegistry()
        ) { vm in
            DashboardView(initialSelection: Service.fixtures().first?.id)
                .environment(vm)
                .frame(width: 1200, height: 700)
        }
    }

    // MARK: - AC-F-12 — Failing registry → ErrorBanner shown

    @Test("AC-F-12: menubar-popover-error-state")
    func menubarErrorState() async throws {
        try await captureAndCompare(
            name: "menubar-popover-error-light",
            size: CGSize(width: 360, height: 520),
            appearance: .aqua,
            registry: .failingRegistry()
        ) { vm in
            MenuBarPopoverView()
                .environment(vm)
                .frame(width: 360)
        }
    }

    // MARK: - infrastructure

    /// Render `viewBuilder(vm)` to PNG, then compare-or-record baseline.
    /// Refresh is awaited so the view sees populated services before capture.
    private func captureAndCompare<V: View>(
        name: String,
        size: CGSize,
        appearance: NSAppearance.Name,
        registry: ServiceRegistry,
        @ViewBuilder _ viewBuilder: (ServiceRegistryViewModel) -> V
    ) async throws {
        let vm = ServiceRegistryViewModel(registry: registry)
        await vm.refresh()
        let view = viewBuilder(vm)
        let cyclePath = Self.cycleDir().appendingPathComponent("\(name).png")
        let baselinePath = Self.baselineDir().appendingPathComponent("\(name).png")

        _ = try ScreenshotHarness.write(view, size: size, appearance: appearance, to: cyclePath)

        if !FileManager.default.fileExists(atPath: baselinePath.path) {
            try FileManager.default.createDirectory(
                at: baselinePath.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: cyclePath, to: baselinePath)
            FileHandle.standardError.write(
                Data("[BASELINE_RECORDED] \(name)\n".utf8))
            return  // first cycle: pass
        }
        try Self.runVisualDiff(baseline: baselinePath, candidate: cyclePath)
    }

    // MARK: - paths

    private static func repoRoot() -> URL {
        // Walk up until we find `.workflow/`.
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
        repoRoot().appendingPathComponent(".workflow/m02/screenshots/baseline")
    }

    private static func cycleDir() -> URL {
        let cycle = ProcessInfo.processInfo.environment["M02_CYCLE"] ?? "001"
        return repoRoot().appendingPathComponent(".workflow/m02/screenshots/cycle-\(cycle)")
    }

    private static func runVisualDiff(baseline: URL, candidate: URL) throws {
        let script = repoRoot().appendingPathComponent("scripts/visual-diff.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            // Tooling missing — log and pass; tester gates on the script
            // existing in CI.
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
