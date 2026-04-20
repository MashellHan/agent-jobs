import Foundation

/// Reads launchd job plists and extracts the bits we surface in the UI:
/// the program/argv (so users see what actually runs) and the schedule
/// (real `.calendar`/`.interval`, not a synthetic `.onDemand`).
///
/// `launchctl list` only reports current PID + last-exit; the schedule and
/// program live in the plist on disk. Standard search paths for user-domain
/// agents:
///
///   - `~/Library/LaunchAgents`              — installed by user / brew services
///   - `/Library/LaunchAgents`               — installed by admin for all users
///   - `/Library/LaunchDaemons`              — system daemons (root only; not us)
///
/// The reader is intentionally tolerant: missing file, malformed plist, and
/// missing keys all degrade to "no enrichment" rather than throwing — the
/// `launchctl list` row still surfaces, just without schedule/command. This
/// matches the failure-isolation contract the rest of the discovery layer
/// already follows (strict-iter-007 spirit).
public struct LaunchdPlistReader: Sendable {

    /// What we managed to extract from a single plist. All optional — none
    /// is "we didn't have this on disk", which the UI should render as `—`.
    public struct Enrichment: Sendable {
        public let command: String?
        public let schedule: Schedule?
        /// Whether the job has any schedule trigger. Used by the provider
        /// to flip `kind` from `.daemon` → `.scheduled` when appropriate.
        public let isScheduled: Bool
        public init(command: String?, schedule: Schedule?, isScheduled: Bool) {
            self.command = command
            self.schedule = schedule
            self.isScheduled = isScheduled
        }
        public static let empty = Enrichment(command: nil, schedule: nil, isScheduled: false)
    }

    /// Optional injection seam for tests. When `nil`, the real filesystem is
    /// scanned. The closure receives the label and returns plist bytes — or
    /// `nil` if not found (caller treats as "no enrichment").
    public typealias Loader = @Sendable (_ label: String) -> Data?
    private let loader: Loader

    public init(loader: Loader? = nil) {
        if let loader {
            self.loader = loader
        } else {
            self.loader = Self.defaultFilesystemLoader()
        }
    }

    public func enrich(label: String) -> Enrichment {
        guard let data = loader(label) else { return .empty }
        return Self.parse(data)
    }

    // MARK: - Filesystem loader

    private static func defaultFilesystemLoader() -> Loader {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents")
        ]
        return { label in
            for dir in candidates {
                let url = dir.appendingPathComponent("\(label).plist")
                if let data = try? Data(contentsOf: url) {
                    return data
                }
            }
            return nil
        }
    }

    // MARK: - Parsing

    /// Decode a launchd plist (binary or XML) and project to `Enrichment`.
    /// Tolerant of unexpected types — anything we don't understand becomes
    /// nil rather than throwing.
    static func parse(_ data: Data) -> Enrichment {
        guard let raw = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return .empty
        }

        let command = extractCommand(from: raw)
        let (schedule, hasTrigger) = extractSchedule(from: raw)

        return Enrichment(
            command: command,
            schedule: schedule,
            isScheduled: hasTrigger
        )
    }

    private static func extractCommand(from plist: [String: Any]) -> String? {
        if let argv = plist["ProgramArguments"] as? [String], !argv.isEmpty {
            return argv.joined(separator: " ")
        }
        if let prog = plist["Program"] as? String, !prog.isEmpty {
            return prog
        }
        return nil
    }

    /// Returns `(schedule, hasAnyTrigger)`. `hasAnyTrigger` is true if ANY
    /// of `StartInterval`, `StartCalendarInterval`, or one of the watch-path
    /// keys is present — used by the provider to call this a `.scheduled`
    /// kind instead of a `.daemon`. We only model the first two in
    /// `Schedule`; watch-path triggers map to "scheduled" without a precise
    /// `Schedule` (returns `.eventTrigger("watch")`).
    private static func extractSchedule(from plist: [String: Any]) -> (Schedule?, Bool) {
        if let secs = plist["StartInterval"] as? Int, secs > 0 {
            return (.interval(seconds: secs), true)
        }
        // `StartCalendarInterval` may be a single dict or an array of dicts.
        if let single = plist["StartCalendarInterval"] as? [String: Any] {
            if let comps = calendarComponents(from: single) {
                return (.calendar(components: [comps]), true)
            }
            return (nil, true)
        }
        if let many = plist["StartCalendarInterval"] as? [[String: Any]] {
            let comps = many.compactMap(calendarComponents(from:))
            if !comps.isEmpty {
                return (.calendar(components: comps), true)
            }
            return (nil, true)
        }
        // Path/file triggers don't carry a real Schedule but should mark
        // the job as event-driven.
        if plist["WatchPaths"] != nil
            || plist["QueueDirectories"] != nil
            || plist["KeepAlive"] != nil {
            return (.eventTrigger("watch"), true)
        }
        return (nil, false)
    }

    /// Map a single launchd CalendarInterval dict (`Hour`, `Minute`, `Day`,
    /// `Weekday`, `Month`) to `DateComponents`. launchd uses Sunday = 0,
    /// which differs from Cocoa's Sunday = 1 — we translate.
    private static func calendarComponents(from dict: [String: Any]) -> DateComponents? {
        var comps = DateComponents()
        var any = false
        if let m = dict["Minute"] as? Int   { comps.minute = m;  any = true }
        if let h = dict["Hour"] as? Int     { comps.hour = h;    any = true }
        if let d = dict["Day"] as? Int      { comps.day = d;     any = true }
        if let mo = dict["Month"] as? Int   { comps.month = mo;  any = true }
        if let w = dict["Weekday"] as? Int {
            // launchd: Sunday=0; Cocoa: Sunday=1. 7 also means Sunday in launchd.
            let cocoaWeekday = (w % 7) + 1
            comps.weekday = cocoaWeekday
            any = true
        }
        return any ? comps : nil
    }
}
