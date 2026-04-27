import Foundation
import AppKit
import SwiftUI

/// Loader for the M07 visual-identity image assets.
///
/// **Why not `Image("MenuBarIcon")` against the .xcassets directly?** SwiftPM
/// ships `.xcassets` as raw directories — there is no `actool` step in the
/// non-Xcode build, so neither `NSImage(named:)` nor `Bundle.module.image(forResource:)`
/// finds entries inside `.imageset` subfolders. The committed `.xcassets`
/// catalog is preserved as the canonical source-of-truth (Xcode integration
/// + future asset-tool runs), but at runtime we load through flat-file
/// PNG mirrors at `Resources/Identity/<name>@Nx.png` written by
/// `scripts/build-icns.sh`.
public enum IdentityImage {

    /// Load the menubar template glyph as a SwiftUI `Image` ready for
    /// template rendering. Picks the @1x PNG; SwiftUI's `.resizable()` +
    /// fixed `.frame` upscales when needed (the @2x/@3x mirrors are
    /// committed for completeness — AppKit picks them up via `NSImage`'s
    /// representations API when constructing image-set instances).
    public static func menuBarTemplate() -> Image {
        if let nsimg = loadMenuBarNSImage() {
            return Image(nsImage: nsimg)
        }
        // Fallback: SF Symbol so a missing asset never silently renders
        // an invisible status item.
        return Image(systemName: "circle.grid.2x2")
    }

    /// Load the menubar glyph as an `NSImage` with all three reps
    /// (@1x/@2x/@3x) attached and `isTemplate = true`. Used by tests
    /// and any AppKit consumer.
    public static func loadMenuBarNSImage() -> NSImage? {
        let bundle = Bundle.module
        let img = NSImage(size: NSSize(width: 16, height: 16))
        var added = false
        for suffix in ["@1x", "@2x", "@3x"] {
            guard let url = bundle.url(forResource: "MenuBarIcon\(suffix)", withExtension: "png"),
                  let data = try? Data(contentsOf: url),
                  let rep = NSBitmapImageRep(data: data) else { continue }
            rep.size = NSSize(width: 16, height: 16)
            img.addRepresentation(rep)
            added = true
        }
        guard added else { return nil }
        img.isTemplate = true
        return img
    }

    /// Load the app icon as an `NSImage`. Used by tests and (eventually)
    /// any in-process about-window surface.
    public static func loadAppIconNSImage() -> NSImage? {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "AppIcon@1x", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        let img = NSImage(size: NSSize(width: 1024, height: 1024))
        img.addRepresentation(rep)
        return img
    }

    /// Verify both M07 assets resolve. Used by AC-F-04 / AC-F-05 tests.
    public static func assetsAreInstalled() -> Bool {
        loadMenuBarNSImage() != nil && loadAppIconNSImage() != nil
    }

    /// Return a non-template NSImage of the menubar glyph pre-tinted to
    /// the requested color. Used by the offscreen capture-all harness
    /// for the dark-scheme scenario (13) — SwiftUI's offscreen render
    /// path does NOT auto-invert template images the way AppKit does
    /// inside a real `NSStatusItem` button, so a pre-tinted source is
    /// the deterministic fix that mirrors what the user sees in the
    /// real menubar under `.darkAqua`.
    ///
    /// Implemented via `CGContext` rather than `NSImage.lockFocus()` so
    /// the path is reliable inside the headless `capture-all` tool
    /// (lockFocus needs an active graphics context that headless tools
    /// don't always have).
    public static func tintedMenuBarImage(color: NSColor) -> NSImage? {
        guard let src = loadMenuBarNSImage() else { return nil }
        // Render at @2x for a crisp 16pt result.
        let logical = NSSize(width: 16, height: 16)
        let pixelW = 32, pixelH = 32
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: pixelW * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Draw the source NSImage's best representation into the CG ctx.
        guard let cgSrc = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(cgSrc, in: CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
        // Tint by re-filling color over the alpha channel.
        ctx.setBlendMode(.sourceAtop)
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
        guard let cgOut = ctx.makeImage() else { return nil }
        let out = NSImage(cgImage: cgOut, size: logical)
        return out
    }
}
