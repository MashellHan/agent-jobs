import Testing
import Foundation
import AppKit

/// AC-F-02 / AC-F-03 / AC-Q-04: launch the built binary, verify it stays
/// alive 3s, and assert the menu-bar slot is taken (window in the status
/// layer owned by the AgentJobsMac process).
///
/// The binary is expected at `.build/debug/AgentJobsMac` relative to the
/// SPM package root — `swift build` (run before `swift test`) puts it
/// there. Tests skip gracefully if the binary is missing rather than
/// hard-failing CI environments without a built executable.
@Suite("App launch (AC-F-02, AC-F-03, AC-Q-04)", .serialized)
struct AppLaunchTests {

    /// Returns the URL of the built executable, walking up from this source
    /// file's expected location (Tests/.../AppLaunchTests.swift) to the
    /// package root and into .build/debug.
    private static func locateBinary() -> URL? {
        // SPM exposes the package root via env when running tests under
        // some configurations; fall back to walking from cwd.
        let candidates: [URL] = {
            var urls: [URL] = []
            let fm = FileManager.default
            let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
            urls.append(cwd.appendingPathComponent(".build/debug/AgentJobsMac"))
            urls.append(cwd.appendingPathComponent("macapp/AgentJobsMac/.build/debug/AgentJobsMac"))
            // Walk up to find a Package.swift sibling.
            var dir = cwd
            for _ in 0..<6 {
                let pkg = dir.appendingPathComponent("Package.swift")
                if fm.fileExists(atPath: pkg.path) {
                    urls.append(dir.appendingPathComponent(".build/debug/AgentJobsMac"))
                    break
                }
                dir.deleteLastPathComponent()
            }
            return urls
        }()
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    @Test("binary stays alive ≥ 3s after launch (AC-F-02)")
    func processSurvivesThreeSeconds() async throws {
        guard let binary = Self.locateBinary() else {
            // No built binary in this run env; skip silently per protocol.
            return
        }
        let proc = Process()
        proc.executableURL = binary
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try proc.run()
        defer {
            if proc.isRunning { proc.terminate() }
        }
        try await Task.sleep(for: .seconds(3))
        #expect(proc.isRunning, "process exited within 3s — likely crash on launch")
    }

    @Test("menu-bar window present in status layer (AC-F-03)")
    func menuBarWindowPresent() async throws {
        guard let binary = Self.locateBinary() else { return }
        let proc = Process()
        proc.executableURL = binary
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try proc.run()
        defer {
            if proc.isRunning { proc.terminate() }
        }
        // Poll up to 5s for the menu-bar window to appear.
        var found = false
        for _ in 0..<25 {
            try await Task.sleep(for: .milliseconds(200))
            if Self.menuBarWindowExists(forPid: proc.processIdentifier) {
                found = true
                break
            }
        }
        #expect(found, "no window owned by AgentJobsMac (pid=\(proc.processIdentifier)) found at status layer within 5s")
    }

    /// Walk every on-screen window and look for one owned by `pid` whose
    /// layer matches the system status (menu-bar) level.
    private static func menuBarWindowExists(forPid pid: Int32) -> Bool {
        let opts: CGWindowListOption = [.optionOnScreenOnly]
        guard let infos = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        for info in infos {
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? Int32 else { continue }
            guard ownerPid == pid else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            if layer == statusLayer { return true }
        }
        return false
    }
}
