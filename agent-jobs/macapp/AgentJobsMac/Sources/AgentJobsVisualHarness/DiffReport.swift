import Foundation

/// Wraps the `scripts/visual-diff.sh` pixel-diff tool.
///
/// Locates the script via `AGENTJOBS_VISUAL_DIFF` env var first, then by
/// walking up from the test bundle / cwd until `scripts/visual-diff.sh`
/// is found (matches how the shell runner installs it for CI).
public enum DiffReport {

    public enum Verdict: String, Sendable, Codable {
        case identical, withinThreshold, regressed
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        case scriptNotFound
        case toolingMissing(String)
        case parseFailed(String)
        case fileMissing(URL)
        public var description: String {
            switch self {
            case .scriptNotFound:    return "scripts/visual-diff.sh not found (set AGENTJOBS_VISUAL_DIFF or run from repo root)"
            case .toolingMissing(let m): return "ImageMagick missing: \(m)"
            case .parseFailed(let s):    return "could not parse visual-diff.sh output: \(s)"
            case .fileMissing(let u):    return "missing file: \(u.path)"
            }
        }
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

    public static func compare(
        baseline: URL,
        candidate: URL,
        threshold: Double = 0.01
    ) throws -> DiffSummary {
        for u in [baseline, candidate] {
            if !FileManager.default.fileExists(atPath: u.path) {
                throw Error.fileMissing(u)
            }
        }
        // Identical bytes ⇒ short-circuit and skip the subprocess (the
        // shell tool also gives 0 pixels changed but ImageMagick may not
        // be installed in every CI image).
        if let a = try? Data(contentsOf: baseline),
           let b = try? Data(contentsOf: candidate),
           a == b {
            return DiffSummary(
                pixelsChanged: 0, percentage: 0,
                threshold: threshold, verdict: .identical
            )
        }
        guard let script = locateScript() else { throw Error.scriptNotFound }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path, baseline.path, candidate.path]
        var env = ProcessInfo.processInfo.environment
        env["THRESHOLD"] = String(format: "%.6f", threshold)
        task.environment = env
        let stdout = Pipe()
        let stderr = Pipe()
        task.standardOutput = stdout
        task.standardError = stderr
        do {
            try task.run()
        } catch {
            throw Error.toolingMissing("could not run bash: \(error.localizedDescription)")
        }
        task.waitUntilExit()
        let outStr = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errStr = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if task.terminationStatus == 2 {
            // Tooling-missing path the script signals with exit 2.
            throw Error.toolingMissing(errStr.isEmpty ? outStr : errStr)
        }

        // The script prints `diff=N total=M ratio=R threshold=T` on stdout.
        let combined = outStr + "\n" + errStr
        guard let pixels = parseInt(combined, key: "diff="),
              let ratio = parseDouble(combined, key: "ratio=") else {
            throw Error.parseFailed(combined)
        }
        let verdict: Verdict
        if pixels == 0 { verdict = .identical }
        else if ratio < threshold { verdict = .withinThreshold }
        else { verdict = .regressed }
        return DiffSummary(
            pixelsChanged: pixels,
            percentage: ratio * 100.0,
            threshold: threshold,
            verdict: verdict
        )
    }

    // MARK: - helpers

    static func locateScript() -> URL? {
        if let env = ProcessInfo.processInfo.environment["AGENTJOBS_VISUAL_DIFF"],
           FileManager.default.isExecutableFile(atPath: env) {
            return URL(fileURLWithPath: env)
        }
        // Walk up from cwd looking for scripts/visual-diff.sh.
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("scripts/visual-diff.sh")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    private static func parseInt(_ s: String, key: String) -> Int? {
        guard let r = s.range(of: key) else { return nil }
        let tail = s[r.upperBound...]
        let token = tail.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return Int(token)
    }

    private static func parseDouble(_ s: String, key: String) -> Double? {
        guard let r = s.range(of: key) else { return nil }
        let tail = s[r.upperBound...]
        let token = tail.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return Double(token)
    }
}
