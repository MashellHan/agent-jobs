import Foundation
import AppKit
import SwiftUI

/// In-process SwiftUI → PNG renderer. Layer-2 of the visual harness pillar
/// (M05 §"DESIGN.md"). Lifted verbatim from `Tests/.../Visual/ScreenshotHarness.swift`
/// so production capture tooling (`capture-all` CLI, ui-critic) can render
/// the same SwiftUI views the production app composes — without depending
/// on the test target.
///
/// Strategy:
///   1. Wrap the view in `NSHostingView`.
///   2. Force a fixed frame.
///   3. Set NSAppearance + colorScheme env so light/dark variants are
///      deterministic.
///   4. Spin runloop briefly so async layout settles.
///   5. Capture via `bitmapImageRepForCachingDisplay(in:)` +
///      `cacheDisplay(in:to:)` and serialize as PNG.
@MainActor
public enum Snapshot {

    public enum CaptureError: Error, CustomStringConvertible {
        case bitmapAllocFailed
        case pngEncodeFailed
        public var description: String {
            switch self {
            case .bitmapAllocFailed: return "NSBitmapImageRep allocation failed"
            case .pngEncodeFailed:   return "PNG encoding failed"
            }
        }
    }

    /// Capture the rendered view as PNG `Data`.
    public static func capture<V: View>(
        _ view: V,
        size: CGSize,
        appearance: NSAppearance.Name = .aqua
    ) throws -> Data {
        let colorScheme: ColorScheme = (appearance == .darkAqua) ? .dark : .light
        let host = NSHostingView(
            rootView: view
                .environment(\.colorScheme, colorScheme)
                .frame(width: size.width, height: size.height)
        )
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        // Allow async SwiftUI layout work to settle.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CaptureError.bitmapAllocFailed
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.pngEncodeFailed
        }
        return data
    }

    /// Capture and write to URL. Creates intermediate directories.
    @discardableResult
    public static func write<V: View>(
        _ view: V,
        size: CGSize,
        appearance: NSAppearance.Name = .aqua,
        to url: URL
    ) throws -> Data {
        let data = try capture(view, size: size, appearance: appearance)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url)
        return data
    }
}
