import Testing
import Foundation

/// AC-Q-04, AC-Q-05, AC-Q-06: static-grep guards over the test corpus and
/// the package manifest. These tests are the "no-prod-paths" + "no-rogue
/// dependency" + "watchers always cleaned up" tripwires that protect
/// successive milestones from regressing M04's invariants.
///
/// Strategy: walk the repo Tests/ directory once, scan every `.swift` file
/// for forbidden substrings, then enforce three properties:
///
///   1. AC-Q-04 — no test references real-home discovery paths
///      (`.agent-jobs/`, `.claude/scheduled_tasks.json`, `.claude/projects`,
///      `NSHomeDirectory()`) outside a documented allow-list.
///   2. AC-Q-05 — `Package.swift` declares no external dependencies beyond
///      the M03 baseline (only `swift-testing`).
///   3. AC-Q-06 — every test file that calls `startWatchers(` also has at
///      least one no-arg `vm.stop()` / `viewModel.stop()` call. (The
///      architect's intent is "watchers don't leak between tests"; that's
///      satisfied iff `startWatchers` is paired with `stop()`. Tests that
///      construct a VM without calling `startWatchers` have nothing to
///      tear down.)
@Suite("M04 static-grep guards (AC-Q-04, Q-05, Q-06)")
struct StaticGrepRogueRefsTests {

    // MARK: - allow-lists

    /// Test files explicitly permitted to reference production-home paths
    /// (they assert WatchPaths.production resolves under NSHomeDirectory(),
    /// or document the path in a comment without touching it).
    private static let prodPathAllowList: Set<String> = [
        "ServiceRegistryViewModelWatchersTests.swift",  // AC-F-11 assertion
        "ClaudeSessionCronProviderTests.swift",         // doc comment only
        "StaticGrepRogueRefsTests.swift",               // this file (the patterns themselves)
    ]

    private static let forbiddenProdPaths = [
        ".agent-jobs/",
        ".claude/scheduled_tasks.json",
        ".claude/projects",
        "NSHomeDirectory()",
    ]

    // MARK: - AC-Q-04

    @Test("AC-Q-04: no test references real-home discovery paths outside allow-list")
    func noTestReferencesRealHomePaths() throws {
        let offenders = try Self.scanTests { url, body in
            guard !Self.prodPathAllowList.contains(url.lastPathComponent) else { return [] }
            return Self.forbiddenProdPaths.compactMap { needle in
                body.contains(needle)
                    ? "\(url.lastPathComponent): contains '\(needle)'"
                    : nil
            }
        }
        if !offenders.isEmpty {
            let detail = offenders.joined(separator: "\n")
            Issue.record("rogue prod-path references:\n\(detail)")
        }
    }

    // MARK: - AC-Q-05

    @Test("AC-Q-05: Package.swift declares no new dependency vs M03 baseline")
    func packageHasNoNewDependency() throws {
        let pkg = try String(contentsOf: Self.packageManifest(), encoding: .utf8)
        // Count `.package(url:` entries in the top-level dependencies array.
        // M03 baseline = 1 (swift-testing). Anything else = regression.
        let lines = pkg.split(separator: "\n").filter {
            $0.contains(".package(url:")
        }
        #expect(lines.count == 1,
                "expected exactly 1 .package(url:) entry (swift-testing); got \(lines.count):\n\(lines.joined(separator: "\n"))")
        #expect(pkg.contains("swift-testing"),
                "swift-testing dependency missing from Package.swift")
    }

    // MARK: - AC-Q-06

    @Test("AC-Q-06: every test file that calls startWatchers( also calls .stop()")
    func startWatchersPairedWithStop() throws {
        let offenders = try Self.scanTests { url, body in
            guard body.contains("startWatchers(") else { return [] }
            // Looking for either `vm.stop()` or `viewModel.stop()` — the
            // no-arg teardown call. `vm.stop(svc)` (action, takes a Service)
            // is structurally different and won't match.
            let hasTeardown = body.contains("vm.stop()")
                || body.contains("viewModel.stop()")
            return hasTeardown ? [] : ["\(url.lastPathComponent): startWatchers without matching .stop()"]
        }
        if !offenders.isEmpty {
            let detail = offenders.joined(separator: "\n")
            Issue.record("watcher-leak risks:\n\(detail)")
        }
    }

    // MARK: - sanity: app source no longer mentions startAutoRefresh

    @Test("AgentJobsMacApp no longer references the obsolete startAutoRefresh symbol")
    func startAutoRefreshIsGone() throws {
        let app = try String(contentsOf: Self.appSourceFile(), encoding: .utf8)
        #expect(!app.contains("startAutoRefresh"),
                "AgentJobsMacApp.swift still references startAutoRefresh (removed in M04 T05)")
    }

    // MARK: - infrastructure

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

    private static func packageManifest() -> URL {
        repoRoot().appendingPathComponent("macapp/AgentJobsMac/Package.swift")
    }

    private static func appSourceFile() -> URL {
        repoRoot().appendingPathComponent(
            "macapp/AgentJobsMac/Sources/AgentJobsMac/AgentJobsMacApp.swift")
    }

    private static func testsRoot() -> URL {
        repoRoot().appendingPathComponent("macapp/AgentJobsMac/Tests")
    }

    /// Recursively walks the Tests/ tree, applying `check` to each `.swift`
    /// file's body. Returns the concatenated offender list.
    private static func scanTests(
        _ check: (URL, String) -> [String]
    ) throws -> [String] {
        let root = testsRoot()
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            offenders.append(contentsOf: check(url, body))
        }
        return offenders
    }
}
