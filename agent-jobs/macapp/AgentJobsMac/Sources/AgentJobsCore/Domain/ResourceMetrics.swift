import Foundation

/// Per-process resource sample. Populated by `ProcessMetricsCollector` via
/// `proc_pidinfo()` (no entitlements needed for the user's own processes).
public struct ResourceMetrics: Codable, Hashable, Sendable {
    public let pid: Int32
    public let cpuPercent: Double      // 0...N (N = #cores * 100)
    public let memoryRSS: UInt64       // bytes resident
    public let memoryVirtual: UInt64
    public let threadCount: Int
    public let fileDescriptors: Int
    public let startTime: Date
    public let sampledAt: Date

    public init(
        pid: Int32,
        cpuPercent: Double,
        memoryRSS: UInt64,
        memoryVirtual: UInt64 = 0,
        threadCount: Int = 0,
        fileDescriptors: Int = 0,
        startTime: Date,
        sampledAt: Date = Date()
    ) {
        self.pid = pid
        self.cpuPercent = max(0, cpuPercent)
        self.memoryRSS = memoryRSS
        self.memoryVirtual = memoryVirtual
        self.threadCount = threadCount
        self.fileDescriptors = fileDescriptors
        self.startTime = startTime
        self.sampledAt = sampledAt
    }
}

public extension ResourceMetrics {
    /// "24 MB", "1.4 GB"
    var memoryRSSFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryRSS), countStyle: .memory)
    }

    /// "3.2%", clamped 0...100 for at-a-glance UI bars.
    var cpuPercentClampedFormatted: String {
        String(format: "%.1f%%", min(cpuPercent, 100))
    }
}
