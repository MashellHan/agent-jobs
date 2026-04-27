import Testing
import Foundation
import AppKit

/// AC-V-06: capture the system menu-bar strip via CGWindowListCreateImage
/// while the real binary is running, then diff against a baseline at 5%
/// threshold (per spec — menu bar varies more across systems).
///
/// This test depends on `swift build` having produced
/// `.build/debug/AgentJobsMac`. Skips silently if the binary is absent
/// (matches AppLaunchTests behavior).
@Suite("Menu-bar icon visual (AC-V-06)", .serialized)
struct MenuBarIconVisualTest {

    private static func locateBinary() -> URL? {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        // Executable was renamed AgentJobsMac → AgentJobsMacApp in M05 T01
        // (package surgery). Search both names; prefer the new one.
        let names = ["AgentJobsMacApp", "AgentJobsMac"]
        var candidates: [URL] = []
        for n in names {
            candidates.append(cwd.appendingPathComponent(".build/debug/\(n)"))
            candidates.append(cwd.appendingPathComponent("macapp/AgentJobsMac/.build/debug/\(n)"))
        }
        var dir = cwd
        for _ in 0..<6 {
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                for n in names {
                    candidates.append(dir.appendingPathComponent(".build/debug/\(n)"))
                }
                break
            }
            dir.deleteLastPathComponent()
        }
        return candidates.first { fm.fileExists(atPath: $0.path) }
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

    @Test("AC-V-06: menubar icon visible in status layer")
    func menubarIconVisible() async throws {
        guard let binary = Self.locateBinary() else { return }
        let proc = Process()
        proc.executableURL = binary
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try proc.run()
        defer { if proc.isRunning { proc.terminate() } }

        // Poll up to 5s for the status-layer window to appear.
        var rect: CGRect?
        let pid = proc.processIdentifier
        for _ in 0..<25 {
            try await Task.sleep(for: .milliseconds(200))
            if let r = Self.findStatusWindowRect(forPid: pid) {
                rect = r
                break
            }
        }
        guard let captureRect = rect else {
            Issue.record("menu-bar window for pid \(pid) not found within 5s")
            return
        }

        // Capture the small bounding box of just the icon.
        let opts: CGWindowListOption = [.optionOnScreenOnly]
        guard let cgImage = CGWindowListCreateImage(
            captureRect, opts, kCGNullWindowID, .nominalResolution)
        else {
            Issue.record("CGWindowListCreateImage returned nil")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("PNG encode failed")
            return
        }

        // Write into the standard cycle dir.
        let cycle = ProcessInfo.processInfo.environment["M02_CYCLE"] ?? "001"
        let cycleDir = Self.repoRoot()
            .appendingPathComponent(".workflow/m02/screenshots/cycle-\(cycle)")
        try FileManager.default.createDirectory(at: cycleDir, withIntermediateDirectories: true)
        let outPath = cycleDir.appendingPathComponent("menubar-icon-visible.png")
        try png.write(to: outPath)

        let baselinePath = Self.repoRoot()
            .appendingPathComponent(".workflow/m02/screenshots/baseline/menubar-icon-visible.png")
        if !FileManager.default.fileExists(atPath: baselinePath.path) {
            try FileManager.default.createDirectory(
                at: baselinePath.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: outPath, to: baselinePath)
            FileHandle.standardError.write(Data("[BASELINE_RECORDED] menubar-icon-visible\n".utf8))
            return
        }
        try Self.runVisualDiff(baseline: baselinePath, candidate: outPath, threshold: "0.05")
    }

    private static func findStatusWindowRect(forPid pid: Int32) -> CGRect? {
        guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        for info in infos {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int32, owner == pid else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            if layer != statusLayer { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let x = bounds["X"] ?? 0
            let y = bounds["Y"] ?? 0
            let w = bounds["Width"] ?? 0
            let h = bounds["Height"] ?? 0
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }

    private static func runVisualDiff(baseline: URL, candidate: URL, threshold: String) throws {
        let script = repoRoot().appendingPathComponent("scripts/visual-diff.sh")
        guard FileManager.default.fileExists(atPath: script.path) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path, baseline.path, candidate.path]
        proc.environment = ProcessInfo.processInfo.environment.merging(
            ["THRESHOLD": threshold], uniquingKeysWith: { _, new in new })
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            Issue.record("visual-diff failed for menubar-icon-visible:\n\(out)")
        }
    }
}
