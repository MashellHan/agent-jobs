import Foundation
import os.log

/// Trailing debounce + in-flight guard for refresh triggers. All five
/// trigger sources (3 file watchers, periodic ticker, manual button)
/// funnel through one instance.
///
/// Concurrency: `actor` provides mutual-exclusion for the debounce
/// state; the timer fire posts back into the actor via `Task`.
///
/// Behavior contract (AC-F-01, AC-F-14, AC-P-02):
/// - Multiple `trigger(_:)` calls inside one `debounce` window collapse
///   to ONE `sink()` call, which fires within `debounce + ~50 ms` of
///   the LAST trigger in the window.
/// - If a trigger arrives while a `sink()` call is already awaiting,
///   it is queued; exactly one additional `sink()` fires after the
///   in-flight call resolves (no concurrent sinks).
/// - `flushNow()` skips the debounce timer (still respects in-flight).
/// - `cancel()` drops a pending fire without invoking the sink.
public actor RefreshScheduler {
    public typealias Sink = @Sendable () async -> Void

    private let debounceMs: Int
    private let sink: Sink
    private var pendingItem: DispatchWorkItem?
    private var isFlushing: Bool = false
    private var coalescedQueued: Bool = false
    private var triggers: [RefreshTrigger] = []
    private let triggerCap: Int = 32
    private let timerQueue: DispatchQueue
    private let logger = Logger(subsystem: "dev.agentjobs", category: "RefreshScheduler")

    public init(debounceMilliseconds: Int = 250,
                queue: DispatchQueue = .global(qos: .utility),
                sink: @escaping Sink) {
        self.debounceMs = max(0, debounceMilliseconds)
        self.timerQueue = queue
        self.sink = sink
    }

    /// Recent trigger trace (capped). Useful for debug logs + tests.
    public var lastTriggers: [RefreshTrigger] { triggers }

    /// Record a trigger. Schedules a debounced `sink()` if not already
    /// in flight; otherwise marks the slot for a tail-fire after the
    /// current sink resolves.
    public func trigger(_ reason: RefreshTrigger) {
        triggers.append(reason)
        if triggers.count > triggerCap {
            triggers.removeFirst(triggers.count - triggerCap)
        }
        logger.debug("trigger \(String(describing: reason), privacy: .public)")
        if isFlushing {
            coalescedQueued = true
            return
        }
        scheduleFire()
    }

    /// Skip the debounce window and run the sink immediately. Used by
    /// `vm.refreshNow()` (manual Refresh button) + tests.
    public func flushNow() async {
        pendingItem?.cancel()
        pendingItem = nil
        if isFlushing {
            // A run is already mid-flight — make sure a follow-up fires
            // after it resolves so the manual press is observable.
            coalescedQueued = true
            return
        }
        await fire()
    }

    /// Tear-down: drops any pending work item without invoking the sink.
    /// Idempotent.
    public func cancel() {
        pendingItem?.cancel()
        pendingItem = nil
        coalescedQueued = false
    }

    // MARK: - private

    private func scheduleFire() {
        pendingItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.fire() }
        }
        pendingItem = work
        if debounceMs == 0 {
            timerQueue.async(execute: work)
        } else {
            timerQueue.asyncAfter(
                deadline: .now() + .milliseconds(debounceMs),
                execute: work)
        }
    }

    private func fire() async {
        pendingItem = nil
        isFlushing = true
        coalescedQueued = false
        await sink()
        isFlushing = false
        if coalescedQueued {
            coalescedQueued = false
            scheduleFire()
        }
    }
}
