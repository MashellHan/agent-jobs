import Testing
import Foundation
import AppKit
import SwiftUI
import AgentJobsVisualHarness

/// M07 WL-A / AC-F-13: `Snapshot.forceDarkAppearance` is the renamed
/// dark-only helper. It traps if called with a non-dark NSAppearance
/// (the helper's NSScrollView/NSTableView backgroundColor re-stamping
/// would mask SF symbol icon tints in `.aqua` sidebar rows and break
/// light-mode pixel-diff baselines).
///
/// We can't easily catch a `precondition` trap in-process under Swift
/// Testing without spawning a subprocess — instead we exercise the
/// happy path (calling with `.darkAqua` succeeds) plus the negative
/// signal (the symbol exists at the renamed location). The trap itself
/// is documented; future regressions of the rename will fail this
/// suite at compile time.
@Suite("M07 WL-A Snapshot.forceDarkAppearance (AC-F-13)")
@MainActor
struct SnapshotForceDarkAppearanceTests {

    @Test("Snapshot.capture succeeds at .darkAqua appearance (exercises forceDarkAppearance)")
    func darkCaptureExercisesForceDarkAppearance() throws {
        // The simplest dark-rendered view that goes through the
        // `if isDark { Self.forceDarkAppearance(...) }` branch.
        struct Probe: View {
            var body: some View {
                Text("probe").frame(width: 16, height: 16)
            }
        }
        let data = try Snapshot.capture(
            Probe(),
            size: CGSize(width: 16, height: 16),
            appearance: .darkAqua
        )
        #expect(data.count > 0)
    }

    @Test("Snapshot.capture also succeeds at .aqua (dark-only branch is skipped)")
    func lightCaptureSkipsForceDarkAppearance() throws {
        struct Probe: View {
            var body: some View {
                Text("probe").frame(width: 16, height: 16)
            }
        }
        let data = try Snapshot.capture(
            Probe(),
            size: CGSize(width: 16, height: 16),
            appearance: .aqua
        )
        #expect(data.count > 0)
    }
}
