import Testing
import Foundation
@testable import AgentJobsVisualHarness

/// AC-F-05 / DiffReport: identical PNGs short-circuit to .identical with
/// 0 pixels changed; missing files raise .fileMissing.
@Suite("DiffReport (M05 T07)")
struct DiffReportTests {

    @Test("identical PNG bytes → 0 pixels changed, .identical verdict (no subprocess)")
    func identicalShortCircuit() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("diff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = dir.appendingPathComponent("a.png")
        let b = dir.appendingPathComponent("b.png")
        // Use a real-ish PNG header so any future content sniff doesn't reject.
        let bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        try Data(bytes).write(to: a)
        try Data(bytes).write(to: b)
        let summary = try DiffReport.compare(baseline: a, candidate: b, threshold: 0.01)
        #expect(summary.pixelsChanged == 0)
        #expect(summary.verdict == .identical)
        #expect(summary.percentage == 0)
    }

    @Test("missing baseline raises .fileMissing")
    func missingBaseline() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).png")
        let dir = FileManager.default.temporaryDirectory
        let real = dir.appendingPathComponent("\(UUID().uuidString).png")
        try? Data([0]).write(to: real)
        defer { try? FileManager.default.removeItem(at: real) }
        do {
            _ = try DiffReport.compare(baseline: missing, candidate: real)
            Issue.record("expected .fileMissing")
        } catch DiffReport.Error.fileMissing {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("locateScript discovers scripts/visual-diff.sh from repo")
    func locatesScript() {
        // The test process cwd for swift test starts in the package dir
        // (macapp/AgentJobsMac); the script lives at repo-root/scripts/.
        // The walk-up loop should find it within 8 hops.
        let url = DiffReport.locateScript()
        #expect(url != nil, "expected to find scripts/visual-diff.sh by walking up from CWD")
    }
}
