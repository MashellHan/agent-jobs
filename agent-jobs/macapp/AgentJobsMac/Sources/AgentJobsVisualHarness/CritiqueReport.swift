import Foundation

/// Paired PNG + JSON sidecar describing a captured scenario. ui-critic
/// reads the sidecar to apply per-axis rubric weighting (M05 §DESIGN).
public struct Critique: Sendable, Hashable {
    public enum Kind: String, Sendable, Codable, Hashable {
        case menubar, popover, dashboard, inspector, modal
    }

    public let name: String
    public let kind: Kind
    public let pngURL: URL
    public let metadata: [String: String]

    public init(name: String, kind: Kind, pngURL: URL, metadata: [String: String] = [:]) {
        self.name = name
        self.kind = kind
        self.pngURL = pngURL
        self.metadata = metadata
    }

    /// Writes the JSON sidecar next to the PNG. Sidecar key set is pinned by
    /// AC-F-05: scenarioName, capturedAt (ISO-8601), appCommit, osVersion,
    /// colorScheme, datasetHash. The optional `metadata` dictionary lands
    /// verbatim under `metadata` for ui-critic's consumption (per-rubric tags).
    public func write(to sidecarURL: URL) throws {
        let payload = Sidecar(
            scenarioName: name,
            kind: kind,
            capturedAt: Self.iso8601(Date()),
            appCommit: Self.appCommit(),
            osVersion: Self.osVersion(),
            colorScheme: metadata["colorScheme"] ?? "light",
            datasetHash: metadata["datasetHash"] ?? "",
            pngBasename: pngURL.lastPathComponent,
            metadata: metadata
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: sidecarURL, options: .atomic)
    }

    /// JSON shape — kept private so callers can't accidentally bypass
    /// the AC-F-05 invariant that every key is always written.
    private struct Sidecar: Codable {
        let scenarioName: String
        let kind: Kind
        let capturedAt: String
        let appCommit: String
        let osVersion: String
        let colorScheme: String
        let datasetHash: String
        let pngBasename: String
        let metadata: [String: String]
    }

    static func iso8601(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    /// Best-effort short SHA. Falls back to "unknown" outside a git checkout
    /// (e.g. distributed binary). Reads `AGENTJOBS_APP_COMMIT` first so the
    /// CLI can pre-stamp it.
    static func appCommit() -> String {
        if let env = ProcessInfo.processInfo.environment["AGENTJOBS_APP_COMMIT"],
           !env.isEmpty { return env }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["git", "rev-parse", "--short", "HEAD"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0,
               let s = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                              encoding: .utf8)?
                   .trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty {
                return s
            }
        } catch {
            // fall through
        }
        return "unknown"
    }

    static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
}
