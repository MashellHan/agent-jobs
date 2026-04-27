import Foundation
import AgentJobsCore

/// Pure helper that groups a `[Service]` list into status-priority sections
/// for the menu-bar popover. Lives in the view layer (architecture §4)
/// because no other surface needs grouped rows; keeping the helper free
/// of view-model state makes it directly unit-testable.
///
/// AC-F-05: deterministic ordering — running, scheduled, failed, then other.
enum PopoverGrouping {

    enum StatusGroup: Int, CaseIterable, Identifiable, Hashable {
        case running   = 0
        case scheduled = 1
        case failed    = 2
        case other     = 3

        var id: Int { rawValue }

        /// Uppercase section caption (Things 3 / Linear flavor).
        var displayName: String {
            switch self {
            case .running:   return "RUNNING"
            case .scheduled: return "SCHEDULED"
            case .failed:    return "FAILED"
            case .other:     return "OTHER"
            }
        }
    }

    /// Group a service list by status, preserving the input order within
    /// each group. Returns groups in the canonical priority order (running,
    /// scheduled, failed, other).
    ///
    /// - Parameters:
    ///   - services: the input list (pre-sorted by name upstream).
    ///   - includeEmpty: when `true`, groups with zero services are still
    ///     emitted (drives the empty-state scenario where the popover shows
    ///     section headers + 0-count chips). Default `false` — empty groups
    ///     are dropped.
    static func groupByStatus(_ services: [Service], includeEmpty: Bool = false)
        -> [(group: StatusGroup, services: [Service])]
    {
        var buckets: [StatusGroup: [Service]] = [:]
        for svc in services {
            let group = bucket(for: svc.status)
            buckets[group, default: []].append(svc)
        }
        return StatusGroup.allCases.compactMap { group in
            let list = buckets[group] ?? []
            guard includeEmpty || !list.isEmpty else { return nil }
            return (group, list)
        }
    }

    /// Maps a service status to its grouping bucket. `.idle`, `.paused`,
    /// `.done`, `.unknown` all collapse to `.other`.
    static func bucket(for status: ServiceStatus) -> StatusGroup {
        switch status {
        case .running:   return .running
        case .scheduled: return .scheduled
        case .failed:    return .failed
        default:         return .other
        }
    }
}
