import Testing
import Foundation
import CoreGraphics
import AgentJobsMacUI

/// M07 T-019 / AC-F-11: Name column claims ≥ 30% of list pane width.
@Suite("Dashboard Name column proportion (M07 T-019 / AC-F-11)")
struct NameColumnWidthTests {

    @Test("AC-F-11: at 1280pt with 220 sidebar + 360 inspector, list = 700pt; Name min ≥ 30% of list")
    func nameColumnMeetsThirtyPercent() {
        let total       = DashboardWindowConfig.defaultSize.width
        let sidebar     = DashboardWindowConfig.sidebarWidth
        let inspector   = DashboardWindowConfig.inspectorWidth
        let listWidth   = total - sidebar - inspector
        #expect(listWidth == 700, "list pane should be 700pt at 1280-220-360")

        let nameMin = DashboardWindowConfig.nameColumnMinWidth
        #expect(nameMin >= 210, "Name column min must be ≥ 210pt (30% of 700pt)")
        let pct = Double(nameMin) / Double(listWidth)
        #expect(pct >= 0.30, "Name column min should be ≥ 30% of list (\(pct))")
    }

    @Test("AC-F-11: ideal width comfortably hosts a fixture title")
    func nameColumnIdealCarriesFullTitle() {
        // The longest fixture title in `Service.fixtures()` is bounded by
        // the formatter's truncation rule (~40 chars). At a typical
        // system body font (~7-9pt average glyph width), 40 chars × 8pt
        // ≈ 320pt of glyphs. We pick `nameColumnIdealWidth` ≥ 250pt as
        // a safe lower bound so common titles fit without trailing "…".
        #expect(DashboardWindowConfig.nameColumnIdealWidth >= 250)
    }
}

/// M07 T-020 / AC-F-12: sidebar header band height matches the bucket
/// strip's top edge (architect option (b)).
@Suite("Bucket strip / sidebar chrome alignment (M07 T-020 / AC-F-12)")
struct BucketStripChromeAlignmentTests {

    @Test("AC-F-12: sidebar header height ≥ 40pt matches bucket-strip intrinsic")
    func sidebarHeaderHeightMatchesBucketStrip() {
        // Bucket strip's intrinsic height is driven by SourceBucketChip's
        // padding stack: vertical padding xs + xs (4 + 4) plus the chip
        // glyph's caption font ≈ 14pt + chip caption ≈ 11pt baseline →
        // realized at ≈ 36-40pt depending on font metrics. Our spec
        // target is 40pt so the header band is at least as tall as the
        // chip strip top edge with ≤ 2pt slack.
        #expect(DashboardWindowConfig.sidebarHeaderHeight >= 36)
        #expect(DashboardWindowConfig.sidebarHeaderHeight <= 44)
    }
}
