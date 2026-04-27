// `capture-all` — produces the 10 PNG + 10 JSON sidecar pairs the
// ui-critic agent reviews. M05 T08.
//
// Usage: capture-all --out <directory>
//
// Each scenario is defined in `Scenarios.swift`. This file owns only the
// argument parsing + the loop that writes one PNG and one JSON sidecar
// per scenario. AC-F-02 / AC-V-03 / AC-P-03.

import Foundation
import AppKit
import AgentJobsCore
import AgentJobsMacUI
import AgentJobsVisualHarness

@MainActor
func runCaptureAll() -> Int32 {
    let args = CommandLine.arguments
    var outDir: URL?
    var i = 1
    while i < args.count {
        let a = args[i]
        switch a {
        case "--out", "-o":
            if i + 1 < args.count {
                outDir = URL(fileURLWithPath: args[i + 1])
                i += 2
                continue
            } else {
                eprint("error: --out requires a path argument")
                return 2
            }
        case "--help", "-h":
            print("""
            capture-all — render the 10 ui-critic scenarios to PNG + JSON.

            Usage:
              capture-all --out <directory>

            Each scenario writes <name>.png + <name>.json (sidecar with
            scenarioName, capturedAt, appCommit, osVersion, colorScheme,
            datasetHash, pngBasename, metadata).
            """)
            return 0
        default:
            eprint("warning: ignoring unknown argument: \(a)")
            i += 1
        }
    }
    guard let outDir else {
        eprint("error: --out <directory> is required (try --help)")
        return 2
    }

    do {
        try FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true
        )
    } catch {
        eprint("error: could not create out directory: \(error.localizedDescription)")
        return 2
    }

    let started = Date()
    var written = 0
    var unchanged = 0
    for scenario in Scenarios.all {
        do {
            let viewModel = scenario.buildViewModel()
            let view = scenario.buildView(viewModel)
            let png = outDir.appendingPathComponent("\(scenario.name).png")
            let json = outDir.appendingPathComponent("\(scenario.name).json")
            // WL-B (M07): capture into memory first; if the existing PNG
            // on disk is byte-identical, skip both the PNG and the
            // sidecar write so the file mtime stays stable across
            // back-to-back runs (AC-F-14: byte-stable rerun).
            let data = try Snapshot.capture(
                view, size: scenario.size,
                appearance: scenario.appearance
            )
            let existing = (try? Data(contentsOf: png))
            if existing == data {
                unchanged += 1
                print("unchanged: \(scenario.name)")
                continue
            }
            try FileManager.default.createDirectory(
                at: png.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: png)
            let critique = Critique(
                name: scenario.name,
                kind: scenario.kind,
                pngURL: png,
                metadata: [
                    "colorScheme": scenario.appearance == .darkAqua ? "dark" : "light",
                    "datasetHash": scenario.datasetTag,
                    "viewportWidth": String(Int(scenario.size.width)),
                    "viewportHeight": String(Int(scenario.size.height)),
                ]
            )
            try critique.write(to: json)
            written += 1
            print("captured \(scenario.name) (\(Int(scenario.size.width))x\(Int(scenario.size.height)))")
        } catch {
            eprint("error: \(scenario.name) failed: \(error.localizedDescription)")
            return 1
        }
    }
    let elapsed = Date().timeIntervalSince(started)
    print("done: \(written) captured, \(unchanged) unchanged in \(String(format: "%.2f", elapsed))s → \(outDir.path)")
    return 0
}

func eprint(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

// Entry point — synchronous main-actor call. Snapshot.capture runs the
// runloop briefly internally to settle SwiftUI layout; no outer await
// needed.
let exitCode: Int32 = MainActor.assumeIsolated { runCaptureAll() }
exit(exitCode)
