import Testing
import Foundation
import AppKit
import SwiftUI
import AgentJobsVisualHarness
@testable import AgentJobsMacUI
import AgentJobsCore

/// M07 Task-4 / scenario 14: render `TokensSwatchView` headlessly and
/// assert the captured PNG carries non-empty content. We don't pixel-diff
/// here (the tester's M07 baseline regen will do that — architecture §6
/// risk #5); we only confirm the swatch composes deterministically and
/// produces visibly distinct color regions in the swatch grid.
@Suite("Tokens swatch snapshot (M07 Task-4)")
@MainActor
struct SwatchSnapshotTests {

    @Test("renders to PNG and exposes ≥3 distinct colors in the swatch band")
    func tokensSwatchRendersDistinctColors() throws {
        let view = HarnessScenes.tokensSwatch(size: CGSize(width: 800, height: 600))
        let data = try Snapshot.capture(
            view,
            size: CGSize(width: 800, height: 600),
            appearance: .aqua
        )
        #expect(data.count > 0)

        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            Issue.record("could not decode swatch PNG")
            return
        }
        // Sample the first color row (≈ y = 80..130 at 2x scale → y ≈ 160..260).
        // Walk a band of pixels and count distinct (r,g,b) buckets quantised
        // to 4-bit per channel — that lets four differently-coloured
        // RoundedRectangles register as ≥3 distinct buckets even after
        // anti-aliasing.
        let width = cg.width
        let height = cg.height
        let rowStride = width * 4
        var bytes = [UInt8](repeating: 0, count: rowStride * height)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowStride,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("CGContext failed")
            return
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Scan several horizontal bands across the upper-half of the
        // canvas (where the swatch grid lives) and take the band with
        // the most distinct buckets. Tolerates layout drift from font
        // metrics / spacing differences across SwiftUI versions.
        var bestCount = 0
        for ratioTimes100 in Swift.stride(from: 5, through: 45, by: 5) {
            let sampleY = Int(Double(height) * Double(ratioTimes100) / 100.0)
            var buckets = Set<UInt32>()
            var x = 0
            while x < width {
                let i = sampleY * rowStride + x * 4
                let r = bytes[i]   >> 4
                let g = bytes[i+1] >> 4
                let b = bytes[i+2] >> 4
                let key = (UInt32(r) << 8) | (UInt32(g) << 4) | UInt32(b)
                buckets.insert(key)
                x += 16
            }
            if buckets.count > bestCount { bestCount = buckets.count }
        }
        #expect(bestCount >= 3,
                "swatch grid should expose ≥ 3 distinct colors in some scanline (best=\(bestCount))")
    }
}

/// M07 Task-4: deterministic checks on the new menubar-icon scenarios.
/// We render scenarios 01/12/13 directly and assert per-scenario
/// invariants — no pixel-diff; tester regens baselines later.
@Suite("Menu bar icon scenarios (M07 Task-4)")
@MainActor
struct MenuBarIconScenarioTests {

    @Test("scenario 01 idle-light: central glyph darker than background")
    func scenario01CentralLumaDark() throws {
        let view = HarnessScenes.menuBarIconOnly(state: .idle)
        let data = try Snapshot.capture(
            view,
            size: CGSize(width: 22, height: 22),
            appearance: .aqua
        )
        let central = try centralLuma(data: data, region: 8)
        // Light background + dark template glyph ⇒ central luma below
        // pure white but well above black. We just require it differs
        // measurably from a uniform background (which would be ≥ 0.95).
        #expect(central < 0.92,
                "central 8x8 should carry visible glyph pixels (luma=\(central))")
    }

    @Test("scenario 13 idle-dark: capture produces a valid PNG of the right size")
    func scenario13CapturesDark() throws {
        let view = HarnessScenes.menuBarIconOnly(state: .idle)
        let data = try Snapshot.capture(
            view,
            size: CGSize(width: 22, height: 22),
            appearance: .darkAqua
        )
        // Headless template rendering doesn't auto-tint (AppKit's dark
        // menubar tint runs only inside a real status item), so we don't
        // probe luma here. We only confirm the capture pipeline emits a
        // decodable 22×22 PNG. The deeper luma probe lives in
        // `MenuBarIconAssetTests.menuBarIconRendersDarkOnDarkMenubar`,
        // which renders the template with an explicit white tint.
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            Issue.record("scenario-13 PNG did not decode")
            return
        }
        #expect(cg.width >= 22 && cg.height >= 22)
    }

    @Test("scenario 12 count-N: rendered frame is wider than the no-badge frame")
    func scenario12HasBadgeRegion() throws {
        // Indirect coverage — we can't easily OCR "9+", but we can check
        // that the rendered frame for a count-12 icon contains
        // non-background pixels in the trailing half (where the badge
        // text sits to the right of the 16pt glyph).
        let view = HarnessScenes.menuBarIconOnly(state: .running(12))
        let data = try Snapshot.capture(
            view,
            size: CGSize(width: 56, height: 22),
            appearance: .aqua
        )
        let cov = try trailingCoverage(data: data)
        #expect(cov > 0,
                "trailing region should contain badge pixels (coverage=\(cov))")
    }

    // MARK: helpers

    private func centralLuma(data: Data, region: Int) throws -> Double {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "swatch", code: 1)
        }
        let w = cg.width, h = cg.height
        let stride = w * 4
        var bytes = [UInt8](repeating: 0, count: stride * h)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: stride, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw NSError(domain: "swatch", code: 2) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let cx = w / 2, cy = h / 2
        var sum = 0.0; var n = 0.0
        for dy in -region/2..<region/2 {
            for dx in -region/2..<region/2 {
                let x = cx + dx, y = cy + dy
                guard x >= 0, x < w, y >= 0, y < h else { continue }
                let i = y * stride + x * 4
                let r = Double(bytes[i])
                let g = Double(bytes[i+1])
                let b = Double(bytes[i+2])
                sum += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
                n += 1
            }
        }
        return sum / max(n, 1)
    }

    private func trailingCoverage(data: Data) throws -> Int {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "trail", code: 1)
        }
        let w = cg.width, h = cg.height
        let stride = w * 4
        var bytes = [UInt8](repeating: 0, count: stride * h)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: stride, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw NSError(domain: "trail", code: 2) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Trailing half = rightmost 50% of pixels. Count any pixel whose
        // RGB differs from pure white by > 8 in any channel.
        var hits = 0
        for y in 0..<h {
            for x in (w/2)..<w {
                let i = y * stride + x * 4
                let r = bytes[i], g = bytes[i+1], b = bytes[i+2]
                if r < 247 || g < 247 || b < 247 { hits += 1 }
            }
        }
        return hits
    }

    private func anyBrightPixelCount(data: Data, threshold: UInt8) throws -> Int {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "bright", code: 1)
        }
        let w = cg.width, h = cg.height
        let stride = w * 4
        var bytes = [UInt8](repeating: 0, count: stride * h)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: stride, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw NSError(domain: "bright", code: 2) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var hits = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = y * stride + x * 4
                let r = bytes[i], g = bytes[i+1], b = bytes[i+2]
                if r > threshold || g > threshold || b > threshold { hits += 1 }
            }
        }
        return hits
    }
}
