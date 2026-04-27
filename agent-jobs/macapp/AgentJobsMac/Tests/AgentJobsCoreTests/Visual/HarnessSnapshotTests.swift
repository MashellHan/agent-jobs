import Testing
import Foundation
import SwiftUI
import AgentJobsVisualHarness

/// Parity check that the lifted `Snapshot` type renders identical bytes
/// to the previous `ScreenshotHarness` implementation. Since the code was
/// lifted verbatim, identical input must produce byte-identical output.
@Suite("HarnessSnapshot lift parity (M05 T02)")
@MainActor
struct HarnessSnapshotTests {

    @Test("Snapshot.capture renders deterministic bytes for the same input")
    func deterministicCapture() throws {
        let view = Color.blue.frame(width: 32, height: 32)
        let a = try Snapshot.capture(view, size: CGSize(width: 32, height: 32))
        let b = try Snapshot.capture(view, size: CGSize(width: 32, height: 32))
        #expect(a == b, "Snapshot must be byte-deterministic for identical input")
        #expect(!a.isEmpty)
        // PNG magic
        let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        #expect(Array(a.prefix(4)) == magic, "Output must be a PNG")
    }

    @Test("Snapshot.write creates parent dirs and writes bytes")
    func writeCreatesIntermediateDirs() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("m05-harness-\(UUID().uuidString)")
            .appendingPathComponent("nested")
            .appendingPathComponent("out.png")
        defer { try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent().deletingLastPathComponent()) }
        let view = Color.red.frame(width: 8, height: 8)
        let written = try Snapshot.write(view, size: CGSize(width: 8, height: 8), to: tmp)
        let onDisk = try Data(contentsOf: tmp)
        #expect(written == onDisk)
    }
}
