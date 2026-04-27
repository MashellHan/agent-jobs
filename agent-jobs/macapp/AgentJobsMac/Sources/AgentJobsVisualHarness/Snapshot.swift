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
    ///
    /// T-014 fix: host the `NSHostingView` inside an offscreen `NSWindow` so that
    /// (a) `NSTableView` (which `SwiftUI.Table` lowers to) realizes its rows
    /// in response to a real window context, and (b) SwiftUI's
    /// background materials inherit `NSWindow.effectiveAppearance` so dark
    /// scheme paints across the entire frame (no white bleed).
    public static func capture<V: View>(
        _ view: V,
        size: CGSize,
        appearance: NSAppearance.Name = .aqua
    ) throws -> Data {
        let colorScheme: ColorScheme = (appearance == .darkAqua) ? .dark : .light

        // Offscreen borderless window so AppKit promotes our hosting view
        // into a real window context (NSTableView row realization +
        // material/background appearance propagation).
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.hasShadow = false

        let host = NSHostingView(
            rootView: view
                .environment(\.colorScheme, colorScheme)
                .frame(width: size.width, height: size.height)
        )
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        // First settle pass: commit initial layout.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded()
        // Second settle pass: allow NSTableView's delayed row realization
        // (and any deferred SwiftUI material redraws) to complete before we
        // cache-display the bitmap.
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
