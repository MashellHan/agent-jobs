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
        let isDark = (appearance == .darkAqua)

        // T-017 (cycle 2): NavigationSplitView's per-pane NSHostingView
        // children read NSApp.effectiveAppearance for SwiftUI material
        // rendering (sidebar, regularMaterial, etc.). Setting only
        // window.appearance is not enough while the window is offscreen
        // and not key. Pin NSApp.appearance for the duration of the
        // capture (dark only), then restore. We only flip NSApp.appearance
        // for dark captures to keep light-mode pixel-diff baselines
        // (M02–M04 tests) byte-stable; the historical light-mode path
        // was already correct.
        let app = NSApplication.shared
        let priorAppAppearance = app.appearance
        if isDark {
            app.appearance = NSAppearance(named: appearance)
        }
        defer {
            if isDark {
                app.appearance = priorAppAppearance
            }
        }

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
        // T-017 (cycle 2, dark-only): paint the window background to a
        // fully opaque color resolved against the target appearance NOW.
        // The default `windowBackgroundColor` is dynamic, but in the
        // offscreen + unrealized case its CGColor is captured at first
        // use under the light appearance and cached, so transparent pane
        // wrappers keep a light tint even after we re-stamp the
        // appearance. Resolving `windowBackgroundColor` against the
        // target NSAppearance and assigning it as a static color sidesteps
        // the cache. Light path keeps the historical default to remain
        // byte-stable against M02–M04 baselines.
        if isDark {
            window.backgroundColor = Self.resolvedBackgroundColor(for: appearance)
        }

        let host = NSHostingView(
            rootView: view
                .environment(\.colorScheme, colorScheme)
                .frame(width: size.width, height: size.height)
        )
        host.appearance = NSAppearance(named: appearance)
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        // T-017 (cycle 2, dark-only): NavigationSplitView spawns one
        // NSHostingView per pane (sidebar / content / detail). These
        // children only inherit the parent NSWindow's effectiveAppearance
        // reliably when the window is in the window-list — i.e. ordered
        // front. Position the window far offscreen so it never appears
        // on a visible display, but DO order it front so AppKit treats
        // it as a real participant. Light path skips this to remain
        // byte-stable against the M02–M04 light baselines that were
        // captured WITHOUT an ordered-front window.
        if isDark {
            window.setFrameOrigin(NSPoint(x: -50_000, y: -50_000))
            window.orderFront(nil)
        }
        host.layoutSubtreeIfNeeded()

        // First settle pass: commit initial layout.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded()
        // Second settle pass: allow NSTableView's delayed row realization
        // (and any deferred SwiftUI material redraws) to complete before we
        // cache-display the bitmap.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        host.layoutSubtreeIfNeeded()
        // T-017 (cycle 2, dark-only) fix: NavigationSplitView lowers to
        // NSSplitView with multiple NSSplitViewItems whose contentViews
        // include NSVisualEffectView (sidebar material) +
        // NSScrollView/NSTableView backings. These do NOT inherit
        // window.appearance reliably while the window is offscreen and
        // not key/main, so the sidebar pane, top toolbar band, and
        // inspector pane all paint with .aqua material even under
        // .darkAqua. Walk the view subtree and force the appearance on
        // every descendant — for NSVisualEffectView we also explicitly
        // re-stamp the material so the underlying CALayer backing
        // rebuilds with the correct tint.
        //
        // Apply ONLY for dark captures: light captures already render
        // correctly via the default sidebar material, and the NSScrollView
        // backgroundColor override would mask SF symbol icon tints in
        // .aqua sidebar rows.
        if isDark {
            Self.forceDarkAppearance(NSAppearance(named: appearance), on: host)
            host.layoutSubtreeIfNeeded()
            // Third settle pass: let any redraws triggered by the appearance
            // override flush to the layer backing before we cache-display.
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            host.layoutSubtreeIfNeeded()
            // cacheDisplay reuses any cached layer backings. After our
            // forceDarkAppearance walk those backings still hold the
            // pre-darkening pixels, so the rendered PNG keeps the light
            // sidebar/inspector chrome. Invalidate every layer so
            // cacheDisplay forces a fresh draw at the new appearance.
            Self.invalidateLayers(on: host)
            host.displayIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        if ProcessInfo.processInfo.environment["AGENTJOBS_SNAPSHOT_DUMP"] == "1" {
            Self.dumpHierarchy(host, depth: 0)
        }

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw CaptureError.bitmapAllocFailed
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        if isDark {
            window.orderOut(nil)
        }
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

    // MARK: - T-017 cycle-2 helper

    /// Resolve `NSColor.windowBackgroundColor` against an explicit
    /// appearance and return a static (non-dynamic) NSColor. Avoids the
    /// dynamic-color cache that ties the first-resolved appearance to
    /// the color identity for the rest of the offscreen window's life.
    private static func resolvedBackgroundColor(for appearance: NSAppearance.Name) -> NSColor {
        guard let target = NSAppearance(named: appearance) else {
            return NSColor.windowBackgroundColor
        }
        var resolved = NSColor.windowBackgroundColor
        target.performAsCurrentDrawingAppearance {
            resolved = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB)
                ?? NSColor.windowBackgroundColor
        }
        return resolved
    }

    /// Invalidate every CALayer in the subtree so cacheDisplay forces a
    /// fresh paint with the current appearance, instead of reusing the
    /// pre-appearance-change cached pixels.
    private static func invalidateLayers(on view: NSView) {
        view.needsDisplay = true
        view.layer?.setNeedsDisplay()
        view.layer?.displayIfNeeded()
        for sub in view.subviews { invalidateLayers(on: sub) }
    }

    private static func dumpHierarchy(_ view: NSView, depth: Int) {
        let pad = String(repeating: "  ", count: depth)
        let cls = String(describing: type(of: view))
        let appr = view.appearance?.name.rawValue ?? "(inherit)"
        let frame = view.frame
        FileHandle.standardError.write(Data("\(pad)\(cls) frame=\(frame) appearance=\(appr)\n".utf8))
        for sub in view.subviews { dumpHierarchy(sub, depth: depth + 1) }
    }

    /// NavigationSplitView's NSSplitViewItem-backed panes wrap their
    /// content in NSVisualEffectView (sidebar material) which, while
    /// offscreen and not key, fails to inherit `window.effectiveAppearance`
    /// — leaving the sidebar pane + top header band + inspector pane
    /// painting in light material under `.darkAqua`. Pinning each view's
    /// `appearance` directly is the deterministic fix that avoids
    /// activating an offscreen window.
    ///
    /// **WL-A (M07):** renamed from `forceAppearance` to make the dark-only
    /// contract explicit at every call site. The precondition traps any
    /// future caller that hands in a non-dark appearance — the helper's
    /// scroll/table backgroundColor re-stamping (line ~256) would mask SF
    /// Symbol icon tints in `.aqua` sidebar rows and break light-mode
    /// pixel-diff baselines.
    internal static func forceDarkAppearance(_ appearance: NSAppearance?, on view: NSView) {
        precondition(
            appearance?.name == .darkAqua,
            "forceDarkAppearance must be called with .darkAqua (got \(appearance?.name.rawValue ?? "nil"))"
        )
        view.appearance = appearance
        if let vfx = view as? NSVisualEffectView {
            // Re-assigning the material kicks the layer to rebuild against
            // the new appearance. Don't change the material itself — only
            // re-stamp the same value.
            let m = vfx.material
            vfx.material = m
            vfx.appearance = appearance
        }
        // T-017 (cycle 2): NSScrollView + NSTableView (which List/.sidebar
        // and Table lower to) cache their `backgroundColor` against the
        // appearance at first display. After our appearance flip those
        // colors stay locked at their original value, painting the
        // sidebar/list scroll bg light under .darkAqua. Re-stamping the
        // backgroundColor with `controlBackgroundColor` (dynamic, but
        // re-resolved against the now-current view appearance) restores
        // dark paint.
        if let scroll = view as? NSScrollView {
            scroll.backgroundColor = .windowBackgroundColor
            scroll.drawsBackground = true
        }
        if let table = view as? NSTableView {
            table.backgroundColor = .windowBackgroundColor
        }
        // Force a redisplay to flush any cached layer content captured
        // under the previous appearance.
        view.needsDisplay = true
        view.needsLayout = true
        for sub in view.subviews {
            forceDarkAppearance(appearance, on: sub)
        }
    }
}
