import Testing
import Foundation
@testable import AgentJobsMacUI

/// AC-F-07/F-08/F-09 — pin the M06 dashboard window/split-view defaults so
/// later edits can't silently regress the layout (M05 P0 condition).
@Suite("DashboardWindowConfig (M06 AC-F-07/F-08/F-09)")
struct DashboardWindowConfigTests {

    @Test("AC-F-07: defaultSize is at least 1280×800")
    func defaultSize() {
        #expect(DashboardWindowConfig.defaultSize.width  >= 1280)
        #expect(DashboardWindowConfig.defaultSize.height >= 800)
    }

    @Test("AC-F-08: sidebar 220, inspector 360 (preferred)")
    func splitColumnPreferredWidths() {
        #expect(DashboardWindowConfig.sidebarWidth   == 220)
        #expect(DashboardWindowConfig.inspectorWidth == 360)
    }

    @Test("AC-F-09: list min-width 480, minSize 1024×700")
    func listMinAndMinSize() {
        #expect(DashboardWindowConfig.listMinWidth == 480)
        #expect(DashboardWindowConfig.minSize.width  >= 1024)
        #expect(DashboardWindowConfig.minSize.height >= 700)
        // Inspector collapse arithmetic: sidebar.min (180) + list.min
        // (480) + detail.min (280) = 940 — narrower than minSize so the
        // min-window guarantees the 3-pane layout fits.
        #expect(DashboardWindowConfig.minSize.width >= 180 + DashboardWindowConfig.listMinWidth + 280)
    }
}
