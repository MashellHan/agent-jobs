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

    /// Heuristic: detect rows by counting horizontal scanlines that contain
    /// saturated color (status pills) or non-trivial content. A blank list
    /// region is mostly white/gray with low saturation; rendered rows
    /// contain colored status badges (green Running, blue Scheduled, red
    /// Failed) which give a strong saturation signal.
    private static func saturatedRowCount(bytes: [UInt8], width: Int, height: Int, stride: Int, region: CGRect) -> Int {
        let xStart = max(0, Int(region.origin.x))
        let xEnd   = min(width - 1, xStart + Int(region.size.width))
        let yStart = max(0, Int(region.origin.y))
        let yEnd   = min(height - 1, yStart + Int(region.size.height))
        guard xEnd > xStart, yEnd > yStart else { return 0 }
        var saturatedScanlines: [Bool] = []
        saturatedScanlines.reserveCapacity(yEnd - yStart)
        for y in yStart..<yEnd {
            var hasSaturation = false
            var x = xStart
            while x < xEnd {
                let i = y * stride + x * 4
                let r = Int(bytes[i]), g = Int(bytes[i + 1]), b = Int(bytes[i + 2])
                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                // Saturation > ~25% AND not too dim/bright (avoid pure
                // white/black).
                if maxC > 80 && (maxC - minC) > 60 {
                    hasSaturation = true
                    break
                }
                x += 2
            }
            saturatedScanlines.append(hasSaturation)
        }
        // Count contiguous saturated runs (each run ≈ one row's status pill).
        var runs = 0
        var inRun = false
        for sat in saturatedScanlines {
            if sat && !inRun { runs += 1; inRun = true }
            if !sat { inRun = false }
        }
        return runs
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

        // The list region: middle-column rows (status pills are colored).
        // x: skip sidebar (~220) and inspector area; y: above the toolbar
        // and above the bottom of the realized rows.
        let listRegion = CGRect(
            x: Double(w) * 0.20,
            y: Double(h) * 0.06,
            width: Double(w) * 0.55,
            height: Double(h) * 0.40
        )
        let rows = Self.saturatedRowCount(
            bytes: bytes, width: w, height: h, stride: stride,
            region: listRegion
        )
        #expect(rows >= 3,
                Comment(rawValue: "Dashboard table must render ≥3 rows with colored status pills; got \(rows). " +
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
