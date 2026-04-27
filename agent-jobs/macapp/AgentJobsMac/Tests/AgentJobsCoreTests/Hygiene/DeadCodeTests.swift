import Testing
import Foundation

/// M07 WL-C / AC-F-15: dead code purge. Asserts that the symbols
/// removed from `MenuBarPopoverView` and the deleted `ServiceRowCompact`
/// view produce zero matches in the production source tree.
@Suite("M07 WL-C dead-code purge (AC-F-15)")
struct DeadCodeTests {

    private static func sourcesRoot() -> URL? {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let p = dir.appendingPathComponent("Sources")
            if FileManager.default.fileExists(atPath: p.path) { return p }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    private static func grepCount(_ needle: String, in dir: URL) -> Int {
        var hits = 0
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: nil
        ) else { return 0 }
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            guard let body = try? String(contentsOf: url) else { continue }
            // Tokenize on word boundaries — a substring match would
            // false-positive against e.g. comments containing the word.
            // We accept any occurrence, since both helpers should be
            // gone from the impl entirely.
            if body.contains(needle) { hits += 1 }
        }
        return hits
    }

    @Test("ServiceRowCompact symbol removed from production sources")
    func serviceRowCompactRemoved() {
        guard let root = Self.sourcesRoot() else {
            Issue.record("could not locate Sources/ from cwd")
            return
        }
        let n = Self.grepCount("ServiceRowCompact", in: root)
        #expect(n == 0, "ServiceRowCompact must be fully removed (found in \(n) file(s))")
    }

    @Test("MenuBarPopoverView dead helpers removed")
    func menuBarPopoverDeadHelpersRemoved() {
        guard let root = Self.sourcesRoot() else {
            Issue.record("could not locate Sources/ from cwd")
            return
        }
        let upcoming = Self.grepCount("upcomingServices", in: root)
        let section  = Self.grepCount("private func section(", in: root)
        // `activeServices` was the third dead helper — also removed.
        let active   = Self.grepCount("private var activeServices", in: root)
        #expect(upcoming == 0, "upcomingServices must be removed (found in \(upcoming) file(s))")
        #expect(section  == 0, "section(title:services:emptyMessage:) must be removed")
        #expect(active   == 0, "activeServices must be removed (found in \(active) file(s))")
    }
}
