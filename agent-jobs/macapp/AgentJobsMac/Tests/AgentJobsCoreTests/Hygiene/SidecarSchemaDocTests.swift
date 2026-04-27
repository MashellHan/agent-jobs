import Testing
import Foundation

/// M07 WL-D / AC-F-16: the canonical sidecar field-name sentence must
/// appear in `.workflow/DESIGN.md` so future tooling is unambiguous
/// about which schema is authoritative (the impl-side names, not the
/// proposal-only short forms).
@Suite("M07 WL-D sidecar schema doc (AC-F-16)")
struct SidecarSchemaDocTests {

    private static func designMdURL() -> URL? {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let p = dir.appendingPathComponent(".workflow/DESIGN.md")
            if FileManager.default.fileExists(atPath: p.path) { return p }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    @Test("DESIGN.md mentions the canonical sidecar field names")
    func designMentionsCanonicalFields() throws {
        guard let url = Self.designMdURL() else {
            Issue.record("could not locate .workflow/DESIGN.md from cwd")
            return
        }
        let body = try String(contentsOf: url)
        #expect(body.contains("scenarioName"),
                "DESIGN.md must canonicalize `scenarioName`")
        #expect(body.contains("appCommit"),
                "DESIGN.md must canonicalize `appCommit`")
        #expect(body.contains("colorScheme"),
                "DESIGN.md must canonicalize `colorScheme`")
        #expect(body.contains("viewportWidth") && body.contains("viewportHeight"),
                "DESIGN.md must canonicalize `viewportWidth/viewportHeight`")
    }
}
