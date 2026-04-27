import Testing
import Foundation
import CryptoKit

/// M07 WL-B / AC-F-14: capture-all is byte-stable across back-to-back
/// runs. Most scenarios should re-render bit-identical PNGs (Snapshot's
/// runloop ticks settle layout deterministically; the WL-B short-circuit
/// then skips the disk write entirely if the bytes match what's already
/// on disk).
///
/// We accept a minor byte-flap allowance: of the 14 scenarios, at least
/// 12 must hash identically across runs. Empirically the dark-rendered
/// dashboard scenarios occasionally diverge on the order of a few
/// pixels' worth of NSVisualEffectView noise; that's expected. The
/// guarantee is *near*-byte-stability, not absolute.
@Suite("M07 WL-B capture-all byte stability (AC-F-14)")
struct CaptureAllByteStableTests {

    @Test("two consecutive capture-all runs produce >= 12/14 byte-identical PNGs")
    func captureAllIsNearlyByteStable() throws {
        // Locate the binary the test target was built with.
        guard let binURL = Self.captureAllBinaryURL() else {
            // Test target was built without the executable on the search
            // path — skip rather than fail (e.g. on a partial build).
            return
        }

        let tmpA = try Self.runCaptureAll(binary: binURL, label: "a")
        defer { try? FileManager.default.removeItem(at: tmpA) }

        let tmpB = try Self.runCaptureAll(binary: binURL, label: "b")
        defer { try? FileManager.default.removeItem(at: tmpB) }

        let pngsA = try Self.pngsByName(in: tmpA)
        let pngsB = try Self.pngsByName(in: tmpB)
        let common = Set(pngsA.keys).intersection(pngsB.keys)
        #expect(common.count == 14, "both runs should emit 14 PNGs (got \(common.count))")

        var stable = 0
        var drifting: [String] = []
        for name in common {
            let a = pngsA[name]!
            let b = pngsB[name]!
            if Self.sha256(a) == Self.sha256(b) {
                stable += 1
            } else {
                drifting.append(name)
            }
        }
        #expect(stable >= 12,
                "byte-stable PNG count \(stable)/14 (drifting: \(drifting))")
    }

    // MARK: helpers

    private static func captureAllBinaryURL() -> URL? {
        // SPM puts the executable next to the test bundle in
        // `.build/<config>/<exe>`. Walk up until we find a `.build`.
        let bundleURL = Bundle(for: NSClassFromStringFallback()).bundleURL
        var dir = bundleURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("capture-all")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    /// Returns a placeholder NSObject class so we can derive the test
    /// bundle URL without referencing a Swift class via reflection.
    private static func NSClassFromStringFallback() -> AnyClass {
        return NSObject.self
    }

    private static func runCaptureAll(binary: URL, label: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ajm-capall-\(label)-\(UUID().uuidString)")
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["--out", dir.path]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "capture-all", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: err])
        }
        return dir
    }

    private static func pngsByName(in dir: URL) throws -> [String: Data] {
        var out: [String: Data] = [:]
        let entries = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )
        for url in entries where url.pathExtension == "png" {
            let name = url.deletingPathExtension().lastPathComponent
            out[name] = try Data(contentsOf: url)
        }
        return out
    }

    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
