import Foundation

/// Cancellable periodic tick driver with pause/resume + a hard-bound
/// keepalive interval so visibility-pause can never cause infinite
/// staleness.
///
/// AC-F-06 (10 s tick), AC-F-07 (immediate catch-up on resume),
/// AC-F-12 (cancel cleanly), AC-P-03 (zero ticks while paused).
public actor PeriodicTicker {
    public typealias OnTick = @Sendable () async -> Void

    private let intervalNanos: UInt64
    private let keepaliveNanos: UInt64
    private let onTick: OnTick
    private var task: Task<Void, Never>?
    private var isPaused: Bool = false

    public init(intervalSeconds: Double = 10.0,
                keepaliveSeconds: Double = 300.0,
                onTick: @escaping OnTick) {
        self.intervalNanos = UInt64(max(0.001, intervalSeconds) * 1_000_000_000)
        self.keepaliveNanos = UInt64(max(0.001, keepaliveSeconds) * 1_000_000_000)
        self.onTick = onTick
    }

    /// Starts the loop. Idempotent — second call is a no-op.
    public func start() {
        guard task == nil else { return }
        let interval = intervalNanos
        let keepalive = keepaliveNanos
        let onTick = self.onTick
        task = Task { [weak self] in
            while !Task.isCancelled {
                let paused = await self?.isPaused ?? false
                let sleep = paused ? keepalive : interval
                try? await Task.sleep(nanoseconds: sleep)
                if Task.isCancelled { break }
                if await self?.isPaused == true && !paused {
                    // pause flipped during sleep — skip this tick
                    continue
                }
                await onTick()
            }
            _ = interval; _ = keepalive  // capture suppression
        }
    }

    /// Stop firing the periodic tick. Keepalive still fires.
    public func pause() { isPaused = true }

    /// Resume periodic ticking. Fires an immediate catch-up tick first
    /// (AC-F-07) so visibility-return shows fresh data without waiting
    /// a full interval.
    public func resume() async {
        let wasPaused = isPaused
        isPaused = false
        if wasPaused {
            await onTick()
        }
    }

    /// Tear down: cancel the loop task entirely.
    public func cancel() {
        task?.cancel()
        task = nil
    }

    /// Test-only inspector.
    public var isRunning: Bool { task != nil && !(task?.isCancelled ?? true) }
}
