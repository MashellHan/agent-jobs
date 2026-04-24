import Testing
import Foundation
import SwiftUI
import AppKit

@Suite("ScreenshotHarness self-test")
@MainActor
struct ScreenshotHarnessTests {

    @Test("capture returns non-empty PNG bytes")
    func captureProducesPNG() throws {
        let data = try ScreenshotHarness.capture(
            Color.red.frame(width: 100, height: 100),
            size: CGSize(width: 100, height: 100)
        )
        #expect(data.count > 0)
        // PNG magic header: 89 50 4E 47 0D 0A 1A 0A
        let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        #expect(Array(data.prefix(4)) == magic)
    }

    @Test("center pixel of red view is reddish")
    func centerPixelIsRed() throws {
        let data = try ScreenshotHarness.capture(
            Color.red,
            size: CGSize(width: 50, height: 50)
        )
        let img = NSImage(data: data)
        #expect(img != nil)
        guard let image = img,
              let rep = image.representations.first as? NSBitmapImageRep else {
            Issue.record("could not decode bitmap")
            return
        }
        let mid = (x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)
        guard let color = rep.colorAt(x: mid.x, y: mid.y) else {
            Issue.record("nil color at center")
            return
        }
        // Red ≫ blue and red ≫ green for a "Color.red" capture.
        #expect(color.redComponent > 0.7,
                "expected dominant red, got r=\(color.redComponent) g=\(color.greenComponent) b=\(color.blueComponent)")
        #expect(color.greenComponent < 0.3)
        #expect(color.blueComponent  < 0.3)
    }

    @Test("write places PNG at the given URL")
    func writeToURL() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ah-shot-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmp) }
        _ = try ScreenshotHarness.write(
            Color.blue,
            size: CGSize(width: 32, height: 32),
            to: tmp
        )
        #expect(FileManager.default.fileExists(atPath: tmp.path))
        let stat = try FileManager.default.attributesOfItem(atPath: tmp.path)
        let size = stat[.size] as? Int ?? 0
        #expect(size > 0)
    }
}
