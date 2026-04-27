// M05 T10 / AC-UC-01 + AC-UC-02. Validates that
// `scripts/ui-critic-smoke.sh` runs end-to-end and that each sidecar
// JSON has the documented metadata shape.
//
// Heavy + flaky-prone (it shells out to `swift run capture-all`), so
// this suite is gated behind `AGENTJOBS_INTEGRATION=1`. CI sets the var.

import Testing
import Foundation

@Suite("ui-critic smoke (M05 T10 / AC-UC-01..02)",
       .enabled(if: ProcessInfo.processInfo.environment["AGENTJOBS_INTEGRATION"] == "1"),
       .serialized)
struct UICriticSmokeTests {

    @Test("AC-UC-01: scripts/ui-critic-smoke.sh exits 0 with all 10 PNGs present")
    func smokeRuns() throws {
        let repo = Self.repoRoot()
        let script = repo.appendingPathComponent("scripts/ui-critic-smoke.sh")
        guard FileManager.default.fileExists(atPath: script.path) else {
            Issue.record("script missing: \(script.path)")
            return
        }
        let outDir = try Self.makeTempOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }
        guard let bin = Self.captureAllBinary(repo: repo) else {
            Issue.record("capture-all binary not found — build with `swift build`")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path, outDir.path]
        var env = ProcessInfo.processInfo.environment
        env["AGENTJOBS_CAPTURE_ALL_BIN"] = bin.path
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
                         as: UTF8.self)
        #expect(proc.terminationStatus == 0, "smoke failed:\n\(out)")

        let pngs = try FileManager.default
            .contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
        #expect(pngs.count == 10, "expected 10 PNGs, got \(pngs.count)")
    }

    @Test("AC-UC-02: each sidecar JSON parses; scenarioName matches NN-… prefix; colorScheme valid")
    func sidecarsParse() throws {
        let outDir = try Self.makeTempOutDir()
        defer { try? FileManager.default.removeItem(at: outDir) }
        let repo = Self.repoRoot()
        guard let bin = Self.captureAllBinary(repo: repo) else {
            Issue.record("capture-all binary not found — build with `swift build`")
            return
        }

        let script = repo.appendingPathComponent("scripts/ui-critic-smoke.sh")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path, outDir.path]
        var env = ProcessInfo.processInfo.environment
        env["AGENTJOBS_CAPTURE_ALL_BIN"] = bin.path
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
                             as: UTF8.self)
            Issue.record("smoke failed: \(out)")
            return
        }

        let validColorSchemes: Set<String> = ["light", "dark"]
        let prefixRegex = try NSRegularExpression(pattern: #"^\d{2}-"#)
        let jsons = try FileManager.default
            .contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(jsons.count == 10)
        for url in jsons {
            let data = try Data(contentsOf: url)
            let parsed = try JSONSerialization.jsonObject(with: data)
            guard let dict = parsed as? [String: Any] else {
                Issue.record("\(url.lastPathComponent) is not a JSON object")
                continue
            }
            // Required keys per AC-F-05.
            for key in ["scenarioName", "kind", "capturedAt", "appCommit",
                        "osVersion", "colorScheme", "datasetHash",
                        "pngBasename", "metadata"] {
                #expect(dict[key] != nil,
                        "\(url.lastPathComponent) missing key \(key)")
            }
            if let name = dict["scenarioName"] as? String {
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                #expect(prefixRegex.firstMatch(in: name, range: range) != nil,
                        "\(name) does not start with NN-")
            }
            if let scheme = dict["colorScheme"] as? String {
                #expect(validColorSchemes.contains(scheme),
                        "invalid colorScheme: \(scheme)")
            }
        }
    }

    // MARK: - helpers

    private static func makeTempOutDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ui-critic-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir,
                                                withIntermediateDirectories: true)
        return dir
    }

    /// Locate the prebuilt `capture-all` binary in `.build`. Avoids
    /// re-invoking `swift run` (which would deadlock on the SPM build
    /// lock held by the parent `swift test`).
    private static func captureAllBinary(repo: URL) -> URL? {
        let pkg = repo.appendingPathComponent("macapp/AgentJobsMac/.build")
        let candidates = [
            "arm64-apple-macosx/debug/capture-all",
            "x86_64-apple-macosx/debug/capture-all",
            "debug/capture-all",
        ]
        for c in candidates {
            let url = pkg.appendingPathComponent(c)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Walk up from this file's location to find the repo root (where
    /// `scripts/` lives). Avoids relying on cwd.
    private static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        for _ in 0..<10 {
            if FileManager.default.fileExists(atPath:
                url.appendingPathComponent("scripts/visual-diff.sh").path) {
                return url
            }
            url = url.deletingLastPathComponent()
        }
        // Fallback: cwd.
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
