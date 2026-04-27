import Testing
import Foundation
@testable import AgentJobsVisualHarness

/// AC-F-05: sidecar JSON contains the pinned key set.
@Suite("CritiqueReport (M05 T07)")
struct CritiqueReportTests {

    @Test("AC-F-05: sidecar JSON contains all pinned keys")
    func sidecarKeysComplete() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("critique-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let png = dir.appendingPathComponent("01-popover.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: png)
        let critique = Critique(
            name: "01-popover-light",
            kind: .popover,
            pngURL: png,
            metadata: [
                "colorScheme": "light",
                "datasetHash": "abcdef12",
                "scenarioGroup": "menubar"
            ]
        )
        let sidecar = dir.appendingPathComponent("01-popover.json")
        try critique.write(to: sidecar)

        let data = try Data(contentsOf: sidecar)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let required: Set<String> = [
            "scenarioName", "kind", "capturedAt", "appCommit",
            "osVersion", "colorScheme", "datasetHash",
            "pngBasename", "metadata"
        ]
        let actual = Set(json?.keys.map { $0 } ?? [])
        #expect(required.isSubset(of: actual), "missing keys: \(required.subtracting(actual))")
        #expect(json?["scenarioName"] as? String == "01-popover-light")
        #expect(json?["kind"] as? String == "popover")
        #expect(json?["colorScheme"] as? String == "light")
        #expect(json?["datasetHash"] as? String == "abcdef12")
        #expect(json?["pngBasename"] as? String == "01-popover.png")
    }

    @Test("appCommit honours AGENTJOBS_APP_COMMIT env override")
    func appCommitOverride() {
        // Set a marker in a sub-process scope. We can't unset env between
        // tests cleanly, so just verify the documented contract: env wins.
        let key = "AGENTJOBS_APP_COMMIT"
        let prev = ProcessInfo.processInfo.environment[key]
        setenv(key, "deadbee", 1)
        defer {
            if let p = prev { setenv(key, p, 1) } else { unsetenv(key) }
        }
        #expect(Critique.appCommit() == "deadbee")
    }

    @Test("osVersion returns N.N.N format")
    func osVersionFormat() {
        let v = Critique.osVersion()
        let parts = v.split(separator: ".")
        #expect(parts.count == 3, "got \(v)")
        for p in parts {
            #expect(Int(p) != nil, "non-numeric component in \(v)")
        }
    }

    @Test("iso8601 timestamp parses round-trip")
    func iso8601RoundTrip() {
        let stamp = Critique.iso8601(Date(timeIntervalSince1970: 1_714_000_000))
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(f.date(from: stamp) != nil)
    }
}
