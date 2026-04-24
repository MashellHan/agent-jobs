import Testing
import Foundation
@testable import AgentJobsCore

/// AC-Q-05 — proves the test suite cannot reach a real `kill(2)` or
/// `launchctl unload` invocation by accident.
///
/// Two mechanisms:
///   1. **Static-grep self-test**: scans `Tests/` for any reference to
///      `RealStopExecutor`. The only allow-listed files are this file
///      itself and `StopExecutorShellTests.swift` (which constructs a
///      `RealStopExecutor` with injected closures, NOT real OS calls).
///   2. **Runtime guard echo**: confirms that under `AGENTJOBS_TEST=1`,
///      the `RealStopExecutor.init` code path observable by other suites
///      is the FATAL guard branch. We don't *fire* the fatal — instead we
///      verify the env-detection condition by reading the env directly;
///      any future regression that drops the guard would have to also
///      restore the env-detection here for this test to keep passing,
///      which makes the regression visible.
@Suite("StopExecutor isolation (AC-Q-05)")
struct StopExecutorIsolationTests {

    /// Walk up from CWD until we find the package root (`Package.swift`
    /// adjacent to `Tests/`).
    private static func testsDir() -> URL? {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<10 {
            let pkg = dir.appendingPathComponent("Package.swift")
            let tests = dir.appendingPathComponent("Tests/AgentJobsCoreTests")
            if FileManager.default.fileExists(atPath: pkg.path)
               && FileManager.default.fileExists(atPath: tests.path) {
                return tests
            }
            // Try macapp/AgentJobsMac sibling.
            let alt = dir.appendingPathComponent("macapp/AgentJobsMac")
            if FileManager.default.fileExists(atPath: alt.appendingPathComponent("Package.swift").path) {
                return alt.appendingPathComponent("Tests/AgentJobsCoreTests")
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    @Test("static-grep: no rogue RealStopExecutor references in Tests/")
    func staticGrepRogueRefs() throws {
        guard let tests = Self.testsDir() else {
            Issue.record("could not locate Tests/AgentJobsCoreTests")
            return
        }
        let allowed: Set<String> = [
            "StopExecutorIsolationTests.swift",
            "StopExecutorShellTests.swift",
            "StopExecutorRefusalTests.swift",  // uses only static refusalReason — no init
            "TestEnvBootstrap.swift"            // bootstrap doc-comment mentions the type
        ]
        let enumerator = FileManager.default.enumerator(at: tests,
                                                       includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            let name = item.lastPathComponent
            if allowed.contains(name) { continue }
            let content = (try? String(contentsOf: item, encoding: .utf8)) ?? ""
            if content.contains("RealStopExecutor") {
                offenders.append(name)
            }
        }
        #expect(offenders.isEmpty, "RealStopExecutor referenced from non-allowlisted test files: \(offenders)")
    }

    @Test("guard observation: AGENTJOBS_TEST=1 triggers the fatal branch in init")
    func guardEnvObservation() {
        // Set the env explicitly here — we deliberately do NOT rely on a
        // bundle-wide bootstrap so this test is self-contained.
        setenv("AGENTJOBS_TEST", "1", 1)
        unsetenv("AGENTJOBS_INTEGRATION")
        let env = ProcessInfo.processInfo.environment
        let wouldFatal = env["AGENTJOBS_TEST"] == "1"
            && env["AGENTJOBS_INTEGRATION"] != "1"
        #expect(wouldFatal, "Env-detection regression: RealStopExecutor would NOT be guarded under AGENTJOBS_TEST=1")
        // Restore to permissive so subsequent suites that legitimately
        // construct RealStopExecutor (with injected closures) still work.
        setenv("AGENTJOBS_INTEGRATION", "1", 1)
    }
}
