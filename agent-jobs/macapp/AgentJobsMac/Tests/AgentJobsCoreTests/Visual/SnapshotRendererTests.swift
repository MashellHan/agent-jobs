import Testing
import Foundation
import AppKit
import SwiftUI
import AgentJobsVisualHarness
@testable import AgentJobsCore
@testable import AgentJobsMacUI

/// T-014 regression tests. Pin the rendering invariants the M05 ui-review
/// flagged: dashboard `Table` rows must actually render in `capture-all`
/// PNGs (AC-F-13), and dark-scheme dashboard PNGs must be fully dark
/// edge-to-edge (AC-F-14, no white bleed).
@Suite("Snapshot renderer T-014 (AC-F-13/F-14)")
@MainActor
struct SnapshotRendererTests {

    // MARK: helpers

    /// Read RGBA8 pixel data out of a PNG `Data` buffer.
    private static func pixels(of data: Data) throws -> (cg: CGImage, width: Int, height: Int, bytes: [UInt8], stride: Int) {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw RenderTestError.decodeFailed
        }
        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let stride = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: stride * height)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: stride,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RenderTestError.contextFailed
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (cg, width, height, bytes, stride)
    }

    private enum RenderTestError: Error { case decodeFailed, contextFailed }

    private static func luminance(r: UInt8, g: UInt8, b: UInt8) -> Double {
        // Rec. 601 luma, normalized.
        (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255.0
    }

    private static func cornerMeanLuminance(bytes: [UInt8], width: Int, height: Int, stride: Int, region: Int = 8) -> [Double] {
        let corners = [
            (0, 0),
            (width - region, 0),
            (0, height - region),
            (width - region, height - region),
        ]
        return corners.map { (x, y) in
            var total = 0.0
            var count = 0
            for dy in 0..<region {
                for dx in 0..<region {
                    let px = x + dx, py = y + dy
                    let i = py * stride + px * 4
                    total += luminance(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2])
                    count += 1
                }
            }
            return total / Double(count)
        }
    }

    /// Heuristic: count distinct horizontal rows by run-length scanning the
    /// list region for alternating-luminance bands. The `tableStyle(.inset(
    /// alternatesRowBackgrounds: true))` lays out distinguishable bands; if
    /// rows aren't realized at all, the region is single-tone and we count 0.
    private static func countRowBands(bytes: [UInt8], width: Int, height: Int, stride: Int, region: CGRect) -> Int {
        let xStart = max(0, Int(region.origin.x))
        let xEnd   = min(width - 1, xStart + Int(region.size.width))
        let yStart = max(0, Int(region.origin.y))
        let yEnd   = min(height - 1, yStart + Int(region.size.height))
        guard xEnd > xStart, yEnd > yStart else { return 0 }
        // Compute mean luminance for each scanline within the region.
        var scanlineLuma: [Double] = []
        scanlineLuma.reserveCapacity(yEnd - yStart)
        for y in yStart..<yEnd {
            var sum = 0.0
            var n = 0
            // Sample every 4th pixel for speed.
            var x = xStart
            while x < xEnd {
                let i = y * stride + x * 4
                sum += luminance(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2])
                n += 1
                x += 4
            }
            scanlineLuma.append(sum / Double(max(n, 1)))
        }
        // Bin scanlines into bands by quantizing luma into buckets, then
        // count run-length transitions.
        let buckets = scanlineLuma.map { Int(($0 * 20.0).rounded()) }
        var transitions = 0
        for i in 1..<buckets.count {
            if buckets[i] != buckets[i - 1] { transitions += 1 }
        }
        // Each row contributes ~2 transitions (top + bottom edge); estimate.
        return max(0, transitions / 2)
    }

    // MARK: - AC-F-13: dashboard rows actually render

    @Test("AC-F-13: dashboard populated capture contains row bands (≥3)")
    func dashboardPopulatedRendersRows() async throws {
        let vm = ServiceRegistryViewModel(registry: .emptyRegistry())
        vm.applyCaptureSeed(services: Service.fixtures())
        let view = HarnessScenes.dashboard(
            viewModel: vm,
            size: CGSize(width: 1280, height: 800)
        )
        let data = try Snapshot.capture(view, size: CGSize(width: 1280, height: 800))
        let (_, w, h, bytes, stride) = try Self.pixels(of: data)

        // The list region sits roughly in the right two-thirds of the
        // window, below the toolbar/header strip and above the bottom edge.
        // Use a generous box so the heuristic doesn't depend on exact
        // pixel-level layout.
        let listRegion = CGRect(
            x: Double(w) * 0.30,
            y: Double(h) * 0.25,
            width: Double(w) * 0.55,
            height: Double(h) * 0.55
        )
        let bands = Self.countRowBands(
            bytes: bytes, width: w, height: h, stride: stride,
            region: listRegion
        )
        #expect(bands >= 3,
                Comment(rawValue: "Dashboard table must render ≥3 distinguishable row bands; got \(bands). " +
                "If this fails, NSTableView row realization regressed (T-014)."))
    }

    // MARK: - AC-F-14: dark dashboard has no white bleed

    @Test("AC-F-14: dashboard dark capture is full-frame dark (corner luma < 0.3)")
    func dashboardDarkSchemeNoBleed() async throws {
        let vm = ServiceRegistryViewModel(registry: .emptyRegistry())
        vm.applyCaptureSeed(services: Service.fixtures())
        let view = HarnessScenes.dashboard(
            viewModel: vm,
            size: CGSize(width: 1280, height: 800)
        )
        let data = try Snapshot.capture(
            view,
            size: CGSize(width: 1280, height: 800),
            appearance: .darkAqua
        )
        let (_, w, h, bytes, stride) = try Self.pixels(of: data)
        let lumas = Self.cornerMeanLuminance(
            bytes: bytes, width: w, height: h, stride: stride, region: 8
        )
        for (i, l) in lumas.enumerated() {
            #expect(l < 0.3,
                    Comment(rawValue: "Corner #\(i) luma \(l) ≥ 0.3 — dark frame not propagating " +
                    "(T-014 regression: NSWindow appearance not inherited)."))
        }
    }

    // MARK: - Determinism guard (window-backed renderer must stay deterministic)

    @Test("Snapshot.capture remains byte-deterministic post window-backed change")
    func deterministicAfterFix() throws {
        let view = Color.gray.frame(width: 32, height: 32)
        let a = try Snapshot.capture(view, size: CGSize(width: 32, height: 32))
        let b = try Snapshot.capture(view, size: CGSize(width: 32, height: 32))
        #expect(a == b)
    }
}
