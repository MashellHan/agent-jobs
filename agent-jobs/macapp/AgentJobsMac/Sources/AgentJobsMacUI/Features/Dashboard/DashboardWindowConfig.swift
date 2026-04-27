import Foundation
import CoreGraphics

/// Pinned defaults for the Dashboard window + its `NavigationSplitView`
/// columns. Values are referenced from `AgentJobsAppScene` (window scene),
/// `DashboardView` (column-width modifiers), `HarnessScenes.dashboard`
/// (capture-all default size), and the M06 dashboard tests.
///
/// AC-F-07 (defaultSize ≥ 1280×800), AC-F-08 (sidebar 220 / inspector 360),
/// AC-F-09 (list min-width 480 — inspector hides at narrower widths).
public enum DashboardWindowConfig {
    /// New M06 default size — earns the 3-pane layout's real estate.
    public static let defaultSize  = CGSize(width: 1280, height: 800)
    /// Window cannot be dragged smaller than this. Below 1024×700 the
    /// 3-pane geometry stops feeling intentional (architect call).
    public static let minSize      = CGSize(width: 1024, height: 700)

    public static let sidebarWidth: CGFloat   = 220
    public static let inspectorWidth: CGFloat = 360
    /// AC-F-09: middle list cannot collapse below this. Combined with
    /// sidebar.min (180) + detail.min (280) → detail collapses at < 940pt.
    public static let listMinWidth: CGFloat   = 480

    // MARK: - M07 T-019 / T-020 additions

    /// T-019 / AC-F-11: Name column claims ≥ 30% of the list pane at the
    /// 1280pt default (sidebar 220 + inspector 360 = list 700; 30% =
    /// 210pt). Pinned here so unit tests can assert directly against the
    /// constant without instantiating SwiftUI.
    public static let nameColumnMinWidth: CGFloat = 210
    /// Default ideal target for the Name column at 1280×800 — generous
    /// enough that "claude-t…" truncation doesn't appear with the
    /// fixture set.
    public static let nameColumnIdealWidth: CGFloat = 280
    /// T-020 / AC-F-12: sidebar `Filters` header band heightens to match
    /// the bucket-strip's intrinsic top edge (architect picked option
    /// (b): heighten the sidebar header instead of hoisting the bucket
    /// strip to a window toolbar).
    public static let sidebarHeaderHeight: CGFloat = 40
}
