import Foundation
import Darwin

/// Best-effort live process resource sampler. Closes T-006.
///
/// Uses `proc_pidinfo()` (libproc.h) to read CPU ticks + RSS for a pid the
/// current user can observe. Caches the previous (ticks, sampledAt) pair
/// per pid so CPU% is true-delta over wall time. Errors swallowed:
/// - `ESRCH` (process exited) → returns nil (no log).
/// - other errno → returns nil (no log noise; this is best-effort).
///
/// **Threading:** This is an `actor`. The actual `proc_pidinfo` syscall is
/// dispatched on a `Task.detached(.utility)` so the actor's serial executor
/// is not pinned during the (very short) syscall. Callers MUST never call
/// from `@MainActor`-isolated UI render paths — call from the refresh tick.
public actor LiveResourceSampler {

    private struct PrevSample {
        let totalTicks: UInt64   // user + system, in mach absolute units
        let sampledAt: Date
    }

    private var previous: [pid_t: PrevSample] = [:]
    private let now: @Sendable () -> Date

    public init(now: @Sendable @escaping () -> Date = { Date() }) {
        self.now = now
    }

    /// Clears the per-pid prev-sample cache (test seam).
    public func reset() { previous.removeAll() }

    /// Sample a single pid. Returns nil if the process is gone or
    /// inaccessible (EPERM for foreign-user procs is also nil).
    public func sample(pid: pid_t) async -> ResourceMetrics? {
        let ts = now()
        let raw = await Self.fetchTaskInfo(pid: pid)
        guard let info = raw else {
            previous[pid] = nil
            return nil
        }
        let totalTicks = info.pti_total_user &+ info.pti_total_system
        let prev = previous[pid]
        previous[pid] = PrevSample(totalTicks: totalTicks, sampledAt: ts)

        let cpu: Double
        if let p = prev {
            let dTicks = Double(totalTicks &- p.totalTicks)
            let dWall = max(ts.timeIntervalSince(p.sampledAt), 1e-6)
            cpu = (dTicks / Double(Self.ticksPerSecond())) / dWall * 100.0
        } else {
            cpu = 0
        }
        return ResourceMetrics(
            pid: pid,
            cpuPercent: max(0, cpu),
            memoryRSS: info.pti_resident_size,
            memoryVirtual: info.pti_virtual_size,
            threadCount: Int(info.pti_threadnum),
            startTime: ts.addingTimeInterval(-1),
            sampledAt: ts
        )
    }

    /// Sample every service that has a pid. Returns id → metrics, only
    /// for services where the syscall succeeded. Order-preserving merge
    /// happens at the caller site (the view model after `discoverAllDetailed`).
    public func sampleAll(_ services: [Service]) async -> [Service.ID: ResourceMetrics] {
        var out: [Service.ID: ResourceMetrics] = [:]
        for svc in services {
            guard let pid = svc.pid else { continue }
            if let m = await sample(pid: pid) {
                out[svc.id] = m
            }
        }
        return out
    }

    // MARK: - Syscall bridge

    private static func fetchTaskInfo(pid: pid_t) async -> proc_taskinfo? {
        await Task.detached(priority: .utility) {
            var info = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let written = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
            if written != Int32(size) { return nil }
            return info
        }.value
    }

    private static let cachedTicksPerSec: Int = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        // pti ticks ARE in mach absolute units. Convert to ns then to ticks/sec.
        // ticks/sec = 1e9 * denom / numer
        let nsPerTick = Double(info.numer) / Double(info.denom)
        return max(1, Int(1_000_000_000.0 / nsPerTick))
    }()
    private static func ticksPerSecond() -> Int { cachedTicksPerSec }
}
