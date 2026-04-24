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
        /// Modification time of the plist file on disk, when available.
        /// Surfaced as `Service.createdAt` to give the UI a real timestamp
        /// instead of a synthetic `Date()` (M01 / spec L4).
        public let mtime: Date?
        public init(command: String?, schedule: Schedule?, isScheduled: Bool, mtime: Date? = nil) {
            self.command = command
            self.schedule = schedule
            self.isScheduled = isScheduled
            self.mtime = mtime
        }
        public static let empty = Enrichment(command: nil, schedule: nil, isScheduled: false, mtime: nil)
    }

    /// Optional injection seam for tests. When `nil`, the real filesystem is
    /// scanned. The closure receives the label and returns plist bytes — or
    /// `nil` if not found (caller treats as "no enrichment").
    public typealias Loader = @Sendable (_ label: String) -> Data?
    /// Optional secondary seam for the on-disk modification timestamp. When
    /// `nil`, defaults to a closure that returns `nil` for every label.
    /// The production filesystem loader provides a real mtime via the
    /// internal `defaultFilesystemLoader` path.
    public typealias MtimeLoader = @Sendable (_ label: String) -> Date?
    private let loader: Loader
    private let mtimeLoader: MtimeLoader

    public init(loader: Loader? = nil) {
        if let loader {
            self.loader = loader
            self.mtimeLoader = { _ in nil }
        } else {
            let fs = Self.defaultFilesystemLoaders()
            self.loader = fs.data
            self.mtimeLoader = fs.mtime
        }
    }

    /// Additive overload that supplies an explicit mtime loader without
    /// changing the existing single-arg `init(loader:)` callers. Tests use
    /// this to pin both data and mtime for a label.
    public init(loader: @escaping Loader, mtimeLoader: @escaping MtimeLoader) {
        self.loader = loader
        self.mtimeLoader = mtimeLoader
    }

    public func enrich(label: String) -> Enrichment {
        guard let data = loader(label) else { return .empty }
        let parsed = Self.parse(data)
        return Enrichment(
            command: parsed.command,
            schedule: parsed.schedule,
            isScheduled: parsed.isScheduled,
            mtime: mtimeLoader(label)
        )
    }

    // MARK: - Public URL helper (M03)

    /// Returns the URL of the first existing `<label>.plist` under the
    /// user/admin LaunchAgents search path, or `nil` if neither exists.
    /// Used by `RealStopExecutor` to build a `launchctl unload` argv and by
    /// the `Service.canStop` refusal predicate for `.launchdUser` rows.
    /// Mirrors the candidate list used by `defaultFilesystemLoaders()`.
    public static func plistURL(forLabel label: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Library/LaunchAgents")
                .appendingPathComponent("\(label).plist"),
            URL(fileURLWithPath: "/Library/LaunchAgents")
                .appendingPathComponent("\(label).plist")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    // MARK: - Filesystem loader

    /// Build a (data, mtime) pair of loaders that share the same candidate
    /// directories. Production callers want the mtime to come from the
    /// same URL that yielded the data — bundling them avoids walking the
    /// filesystem twice.
    private static func defaultFilesystemLoaders() -> (data: Loader, mtime: MtimeLoader) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [URL] = [
            home.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents")
        ]
        let dataLoader: Loader = { label in
            for dir in candidates {
                let url = dir.appendingPathComponent("\(label).plist")
                if let data = try? Data(contentsOf: url) {
                    return data
                }
            }
            return nil
        }
        let mtimeLoader: MtimeLoader = { label in
            let fm = FileManager.default
            for dir in candidates {
                let url = dir.appendingPathComponent("\(label).plist")
                if let attrs = try? fm.attributesOfItem(atPath: url.path),
                   let date = attrs[.modificationDate] as? Date {
                    return date
                }
            }
            return nil
        }
        return (dataLoader, mtimeLoader)
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
