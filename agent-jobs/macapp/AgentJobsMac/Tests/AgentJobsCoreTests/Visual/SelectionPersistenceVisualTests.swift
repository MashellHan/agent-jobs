import Testing
import Foundation
import SwiftUI
import AppKit
@testable import AgentJobsCore
@testable import AgentJobsMacUI

/// AC-V-04: selection persistence across refreshes.
///
/// Renders the dashboard with a deterministic initial selection, then
/// refreshes the registry 10 times against the identical-output fixture
/// registry. Each post-refresh frame is captured into the cycle directory
/// and pixel-diff'd against the pre-refresh baseline. Drift indicates the
/// view-model swapped its services array out-of-place (transient empty,
/// reordering, or selection clear) — exactly what AC-F-10 + AC-V-04
/// prohibit.
///
/// First-run: the pre-refresh frame is recorded as the baseline; the 10
/// subsequent frames are diffed against it. Pass = all 10 within the
/// `scripts/visual-diff.sh` 2 % threshold.
@Suite("Selection persistence under refresh stress (M04 AC-V-04)", .serialized)
@MainActor
struct SelectionPersistenceVisualTests {

    @Test("AC-V-04: dashboard-selection-preserved-light")
    func selectionPreservedAcrossRefreshes() async throws {
        let vm = ServiceRegistryViewModel(registry: .fixtureRegistry())
        await vm.refresh()
        // Pick a deterministic row (3rd fixture so the selection is mid-list,
        // not row 0 which is the SwiftUI default).
        let ids = vm.services.map(\.id)
        guard ids.count >= 3 else {
            Issue.record("expected ≥3 fixture services, got \(ids.count)")
            vm.stop()
            return
        }
        let selected = ids[2]

        let view = DashboardView(initialSelection: selected)
            .environment(vm)
            .frame(width: 1200, height: 700)

        let baselinePath = Self.baselineDir()
            .appendingPathComponent("dashboard-selection-preserved-light.png")
        let cycleDir = Self.cycleDir()

        // Pre-refresh frame.
        let preCycle = cycleDir.appendingPathComponent("dashboard-selection-preserved-light.png")
        _ = try ScreenshotHarness.write(view, size: CGSize(width: 1200, height: 700),
                                         appearance: .aqua, to: preCycle)

        if !FileManager.default.fileExists(atPath: baselinePath.path) {
            try FileManager.default.createDirectory(
                at: baselinePath.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: preCycle, to: baselinePath)
            FileHandle.standardError.write(
                Data("[BASELINE_RECORDED] dashboard-selection-preserved-light\n".utf8))
        } else {
            try Self.runVisualDiff(baseline: baselinePath, candidate: preCycle)
        }

        // Stress: 10 refreshes against identical-output stub. Each post
        // frame must match the baseline. Also assert in-place-mutation
        // invariants (AC-F-10) at the model layer for belt-and-suspenders.
        for i in 0..<10 {
            await vm.refresh()
            #expect(vm.services.count == ids.count, "transient size change at iter \(i)")
            #expect(vm.services.map(\.id) == ids, "id ordering changed at iter \(i)")
            let frame = cycleDir.appendingPathComponent(
                "dashboard-selection-preserved-light-iter\(i).png")
            _ = try ScreenshotHarness.write(view, size: CGSize(width: 1200, height: 700),
                                             appearance: .aqua, to: frame)
            try Self.runVisualDiff(baseline: baselinePath, candidate: frame)
        }
        vm.stop()
    }

    // MARK: - paths (mirrors AutoRefreshIndicatorVisualTests)

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
