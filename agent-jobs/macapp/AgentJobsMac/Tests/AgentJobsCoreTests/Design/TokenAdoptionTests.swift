import Testing
import Foundation

/// M07 AC-F-09 (token adoption clause): asserts the new
/// `DesignTokens.SemanticColor` namespace is referenced in ≥3 visible-surface
/// files. Implemented as a source-file grep so we don't need a runtime hook
/// into SwiftUI render plumbing.
@Suite("Token adoption (M07 AC-F-08/F-09)")
struct TokenAdoptionTests {

    private static func sourcesRoot() -> URL? {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let p = dir.appendingPathComponent("Sources/AgentJobsMacUI")
            if FileManager.default.fileExists(atPath: p.path) {
                return p
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    private static func files(matching needle: String, in dir: URL) -> [URL] {
        var matches: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: nil
        ) else { return matches }
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            if let body = try? String(contentsOf: url),
               body.contains(needle) {
                matches.append(url)
            }
        }
        return matches
    }

    @Test("AC-F-08 adoption: SemanticColor referenced in ≥ 3 visible-surface files")
    func semanticColorAdoption() throws {
        guard let root = Self.sourcesRoot() else {
            Issue.record("Could not locate Sources/AgentJobsMacUI from cwd")
            return
        }
        let hits = Self.files(matching: "DesignTokens.SemanticColor", in: root)
        #expect(hits.count >= 3,
                "expected ≥ 3 files referencing DesignTokens.SemanticColor; found \(hits.map(\.lastPathComponent))")
    }

    @Test("AC-F-08 adoption: SourceColor referenced in ≥ 1 visible-surface file")
    func sourceColorAdoption() throws {
        guard let root = Self.sourcesRoot() else {
            Issue.record("Could not locate Sources/AgentJobsMacUI from cwd")
            return
        }
        let hits = Self.files(matching: "DesignTokens.SourceColor", in: root)
        #expect(hits.count >= 1)
    }
}
