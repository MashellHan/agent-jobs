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
}
