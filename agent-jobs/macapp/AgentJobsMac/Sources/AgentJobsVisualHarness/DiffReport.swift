import Foundation

/// Wraps the `scripts/visual-diff.sh` pixel-diff tool. Real implementation
/// lands in M05 T07.
public enum DiffReport {

    public enum Verdict: String, Sendable, Codable {
        case identical, withinThreshold, regressed
    }

    public struct DiffSummary: Sendable, Hashable {
        public let pixelsChanged: Int
        public let percentage: Double
        public let threshold: Double
        public let verdict: Verdict
        public init(pixelsChanged: Int, percentage: Double, threshold: Double, verdict: Verdict) {
            self.pixelsChanged = pixelsChanged
            self.percentage = percentage
            self.threshold = threshold
            self.verdict = verdict
        }
    }

    public static func compare(baseline: URL, candidate: URL, threshold: Double = 0.01) throws -> DiffSummary {
        throw NSError(domain: "AgentJobsVisualHarness.DiffReport", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "T07 pending"])
    }
}
