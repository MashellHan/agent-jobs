#!/bin/bash
# build-icns.sh — regenerate the M07 identity assets.
#
# Inputs (vector source-of-truth):
#   Sources/AgentJobsMacApp/Resources/Identity/menubar-glyph.svg
#   Sources/AgentJobsMacApp/Resources/Identity/app-icon.svg
#
# Outputs:
#   Sources/AgentJobsMacApp/Resources/Assets.xcassets/MenuBarIcon.imageset/menubar-glyph{,@2x,@3x}.png
#   Sources/AgentJobsMacApp/Resources/Assets.xcassets/AppIcon.appiconset/icon_{16,32,128,256,512}{,@2x}.png
#   .build/agent-jobs.icns
#
# Idempotent: re-running with no SVG edits produces no `git diff`. We
# render via a small embedded Swift+CoreGraphics program (no librsvg
# dependency) so output is byte-stable across dev machines.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_MENU_SVG="$ROOT/Sources/AgentJobsMacUI/Resources/Identity/menubar-glyph.svg"
SRC_APP_SVG="$ROOT/Sources/AgentJobsMacUI/Resources/Identity/app-icon.svg"
APPICON_OUT="$ROOT/Sources/AgentJobsMacUI/Resources/Assets.xcassets/AppIcon.appiconset"
MENUICON_OUT="$ROOT/Sources/AgentJobsMacUI/Resources/Assets.xcassets/MenuBarIcon.imageset"
BUILD_DIR="$ROOT/.build"
ICNS_OUT="$BUILD_DIR/agent-jobs.icns"

if [[ ! -f "$SRC_MENU_SVG" || ! -f "$SRC_APP_SVG" ]]; then
  echo "error: source SVGs missing (expected $SRC_MENU_SVG and $SRC_APP_SVG)" >&2
  exit 1
fi

mkdir -p "$APPICON_OUT" "$MENUICON_OUT" "$BUILD_DIR"

TMP_RUNNER="$(mktemp -t build-icns.XXXXXX.swift)"
trap 'rm -f "$TMP_RUNNER"' EXIT

cat >"$TMP_RUNNER" <<'SWIFTEOF'
import Foundation
import AppKit
import CoreGraphics

// Procedural renderer that mirrors the committed SVG sources. We chose
// procedural drawing over an SVG parser dependency because (a) it has zero
// extra runtime deps and (b) it's deterministic byte-for-byte across
// machines, which AC-F-14 (capture-all byte-stable rerun) needs.

// Match the commit-time SVG geometry exactly (16x16 menubar; 1024x1024 app).

func writePNG(_ data: Data, to path: String) {
    let url = URL(fileURLWithPath: path)
    do {
        try data.write(to: url)
    } catch {
        FileHandle.standardError.write(Data("write failed: \(path): \(error)\n".utf8))
        exit(1)
    }
}

func renderMenubarGlyph(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = ctx
    let g = ctx.cgContext
    g.interpolationQuality = .high
    g.setShouldAntialias(true)

    g.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let s = CGFloat(size) / 16.0

    // SVG y-axis runs top-down; Quartz runs bottom-up. Flip so we author
    // in SVG-coord space and rely on AppKit to invert.
    g.translateBy(x: 0, y: CGFloat(size))
    g.scaleBy(x: 1, y: -1)

    // Cycle-2 glyph (mirror menubar-glyph.svg):
    //   - Filled rounded "tray" body 14x14 centered in 16pt canvas.
    //   - Two 1px white slits at y=4 and y=11 split the tray into
    //     header / body / footer rows (hints at the service stack).
    //   - Small white "status notch" inside the body at right edge.
    //   - A black 1.5r "running" dot overhangs the upper-right corner
    //     (count-badge anchor).
    g.setFillColor(NSColor.black.cgColor)
    let body = CGPath(
        roundedRect: CGRect(x: 1*s, y: 1*s, width: 14*s, height: 14*s),
        cornerWidth: 2.5*s, cornerHeight: 2.5*s, transform: nil
    )
    g.addPath(body); g.fillPath()

    // Slits + status notch are negative space — paint as clear pixels.
    g.setBlendMode(.clear)
    g.fill(CGRect(x: 3*s, y: 3*s, width: 10*s, height: 1*s))
    g.fill(CGRect(x: 3*s, y: 12*s, width: 10*s, height: 1*s))
    g.fillEllipse(in: CGRect(x: (11.5 - 1)*s, y: (8 - 1)*s, width: 2*s, height: 2*s))
    g.setBlendMode(.normal)

    // Running-indicator dot — overhangs the upper-right corner.
    g.setFillColor(NSColor.black.cgColor)
    g.fillEllipse(in: CGRect(x: (14 - 1.5)*s, y: (4 - 1.5)*s, width: 3*s, height: 3*s))

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

func renderAppIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = ctx
    let g = ctx.cgContext
    g.interpolationQuality = .high
    g.setShouldAntialias(true)

    g.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let s = CGFloat(size) / 1024.0

    g.translateBy(x: 0, y: CGFloat(size))
    g.scaleBy(x: 1, y: -1)

    // Background tile
    g.setFillColor(NSColor(srgbRed: 0x2A/255, green: 0x8C/255, blue: 0x4A/255, alpha: 1).cgColor)
    let bg = CGPath(
        roundedRect: CGRect(x: 32*s, y: 32*s, width: 960*s, height: 960*s),
        cornerWidth: 220*s, cornerHeight: 220*s, transform: nil
    )
    g.addPath(bg); g.fillPath()

    // Highlight band — rounded rect, but we clip to a top-half band by
    // drawing the same shape only over y∈[32,512]. Easiest: stroke a
    // rounded-rect path and then fill a clip rect.
    g.saveGState()
    g.addRect(CGRect(x: 32*s, y: 32*s, width: 960*s, height: 480*s))
    g.clip()
    g.setFillColor(NSColor(srgbRed: 0x34/255, green: 0xA8/255, blue: 0x5B/255, alpha: 1).cgColor)
    let hi = CGPath(
        roundedRect: CGRect(x: 32*s, y: 32*s, width: 960*s, height: 960*s),
        cornerWidth: 220*s, cornerHeight: 220*s, transform: nil
    )
    g.addPath(hi); g.fillPath()
    g.restoreGState()

    // White stack rows
    g.setFillColor(NSColor.white.cgColor)
    let rows: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        (220, 300, 500, 80),
        (220, 460, 640, 80),
        (220, 620, 380, 80),
    ]
    for r in rows {
        let p = CGPath(
            roundedRect: CGRect(x: r.x*s, y: r.y*s, width: r.w*s, height: r.h*s),
            cornerWidth: 40*s, cornerHeight: 40*s, transform: nil
        )
        g.addPath(p); g.fillPath()
    }
    // Status dot
    g.setFillColor(NSColor(srgbRed: 0xFF/255, green: 0xD4/255, blue: 0x3B/255, alpha: 1).cgColor)
    g.fillEllipse(in: CGRect(x: (800-60)*s, y: (340-60)*s, width: 120*s, height: 120*s))

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count >= 2 else { exit(2) }
let mode = args[1]
let outDir = args[2]

switch mode {
case "menubar":
    writePNG(renderMenubarGlyph(size: 16), to: "\(outDir)/menubar-glyph.png")
    writePNG(renderMenubarGlyph(size: 32), to: "\(outDir)/menubar-glyph@2x.png")
    writePNG(renderMenubarGlyph(size: 48), to: "\(outDir)/menubar-glyph@3x.png")
case "appicon":
    let sizes = [(16, "16"), (32, "16@2x"), (32, "32"), (64, "32@2x"),
                 (128, "128"), (256, "128@2x"), (256, "256"), (512, "256@2x"),
                 (512, "512"), (1024, "512@2x")]
    for (px, name) in sizes {
        writePNG(renderAppIcon(size: px), to: "\(outDir)/icon_\(name).png")
    }
default:
    exit(2)
}
SWIFTEOF

# Render menubar imageset
swift "$TMP_RUNNER" menubar "$MENUICON_OUT"
# Render app icon set
swift "$TMP_RUNNER" appicon "$APPICON_OUT"

# Mirror direct copies into Resources/Identity/ — these are the PNGs the
# `IdentityImage` loader pulls via Bundle.module. SwiftPM ships .xcassets
# directories raw (no actool in non-Xcode builds), so a flat-file copy
# next to the catalog is what the runtime actually reads.
IDENTITY_OUT="$ROOT/Sources/AgentJobsMacUI/Resources/Identity"
cp "$MENUICON_OUT/menubar-glyph.png"     "$IDENTITY_OUT/MenuBarIcon@1x.png"
cp "$MENUICON_OUT/menubar-glyph@2x.png"  "$IDENTITY_OUT/MenuBarIcon@2x.png"
cp "$MENUICON_OUT/menubar-glyph@3x.png"  "$IDENTITY_OUT/MenuBarIcon@3x.png"
cp "$APPICON_OUT/icon_512@2x.png"        "$IDENTITY_OUT/AppIcon@1x.png"

# Build .icns from the iconset (uses a temp .iconset dir per Apple iconutil).
TMPSET_DIR="$(mktemp -d)"
TMPSET="$TMPSET_DIR/agent-jobs.iconset"
mkdir -p "$TMPSET"
# iconutil expects icon_Nx N filenames; map our names accordingly.
cp "$APPICON_OUT/icon_16.png"     "$TMPSET/icon_16x16.png"
cp "$APPICON_OUT/icon_16@2x.png"  "$TMPSET/icon_16x16@2x.png"
cp "$APPICON_OUT/icon_32.png"     "$TMPSET/icon_32x32.png"
cp "$APPICON_OUT/icon_32@2x.png"  "$TMPSET/icon_32x32@2x.png"
cp "$APPICON_OUT/icon_128.png"    "$TMPSET/icon_128x128.png"
cp "$APPICON_OUT/icon_128@2x.png" "$TMPSET/icon_128x128@2x.png"
cp "$APPICON_OUT/icon_256.png"    "$TMPSET/icon_256x256.png"
cp "$APPICON_OUT/icon_256@2x.png" "$TMPSET/icon_256x256@2x.png"
cp "$APPICON_OUT/icon_512.png"    "$TMPSET/icon_512x512.png"
cp "$APPICON_OUT/icon_512@2x.png" "$TMPSET/icon_512x512@2x.png"
iconutil --convert icns "$TMPSET" --output "$ICNS_OUT"
rm -rf "$TMPSET_DIR"

echo "wrote menubar PNGs → $MENUICON_OUT"
echo "wrote app PNGs     → $APPICON_OUT"
echo "wrote icns         → $ICNS_OUT"
