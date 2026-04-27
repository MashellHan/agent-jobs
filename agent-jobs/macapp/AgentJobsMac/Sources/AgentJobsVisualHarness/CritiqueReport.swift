import Foundation

/// Paired PNG + JSON sidecar describing a captured scenario. ui-critic
/// reads the sidecar to apply per-axis rubric weighting (M05 §DESIGN).
/// Real serializer lands in M05 T07.
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

    /// Writes the JSON sidecar next to the PNG (`<name>.png` → `<name>.json`).
    /// T07 fills the body; T02 ships the contract.
    public func write(to sidecarURL: URL) throws {
        // Real impl: encode {scenarioName, capturedAt, appCommit, osVersion,
        // colorScheme, datasetHash, ...} via JSONEncoder.sortedKeys + .pretty.
        throw NSError(domain: "AgentJobsVisualHarness.Critique", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "T07 pending"])
    }
}
