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
}
