import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-01 (funnel), AC-F-14 (in-flight guard), AC-P-02 (debounce).
/// Perf-sensitive timing assertions are gated behind AGENTJOBS_PERF=1
/// per E001; functional tests run unconditionally.
@Suite("RefreshScheduler debounce + in-flight guard")
struct RefreshSchedulerTests {

    /// Counting sink. Records each invocation and the time it ran.
    actor CallCounter {
        private(set) var count: Int = 0
        private(set) var times: [Date] = []
        private var pendingContinuation: CheckedContinuation<Void, Never>?
        private var blocking: Bool = false

        func tick() {
            count += 1
            times.append(Date())
        }
        /// Make the next sink call await a continuation, blocking until
        /// `release()` is called. Used to drive AC-F-14.
        func blockNext() { blocking = true }
        func await_blocking() async {
            guard blocking else { return }
            blocking = false
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                pendingContinuation = c
            }
        }
        func release() {
            pendingContinuation?.resume()
            pendingContinuation = nil
        }
        func reset() { count = 0; times = [] }
    }

    private static let perfEnabled: Bool =
        ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1"

    // MARK: - AC-F-01: 5 triggers within 100 ms → exactly 1 sink call

    @Test("5 triggers in 100 ms collapse to one sink call")
    func collapsesStorm() async {
        let counter = CallCounter()
        let scheduler = RefreshScheduler(debounceMilliseconds: 50) {
            await counter.tick()
        }
        for src in [
            RefreshTrigger.fileEvent(.jobsJson),
            .fileEvent(.scheduledTasks),
            .fileEvent(.claudeProjects),
            .periodic,
            .manual,
        ] {
            await scheduler.trigger(src)
            try? await Task.sleep(for: .milliseconds(5))
        }
        try? await Task.sleep(for: .milliseconds(200))
        let n = await counter.count
        #expect(n == 1, "expected exactly 1 sink call, got \(n)")
        let triggers = await scheduler.lastTriggers
        #expect(triggers.count == 5, "all 5 triggers recorded for trace")
        await scheduler.cancel()
    }

    // MARK: - AC-F-14: in-flight guard — second trigger fires once after current

    @Test("trigger arriving during sink await fires exactly one follow-up")
    func inFlightGuard() async {
        let counter = CallCounter()
        await counter.blockNext()
        let scheduler = RefreshScheduler(debounceMilliseconds: 20) {
            await counter.tick()
            await counter.await_blocking()
        }
        await scheduler.trigger(.fileEvent(.jobsJson))
        // Wait for the first sink to start (it will block awaiting release).
        // Poll up to 2s — actor + dispatch scheduling under load can vary.
        var firstStarted = false
        for _ in 0..<200 {
            if await counter.count == 1 { firstStarted = true; break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(firstStarted, "first sink never observed")

        // Fire 3 more triggers while the first sink is blocked.
        await scheduler.trigger(.periodic)
        await scheduler.trigger(.manual)
        await scheduler.trigger(.fileEvent(.scheduledTasks))

        // Release the first sink — exactly ONE follow-up should run.
        await counter.release()
        // Poll up to 2s for the follow-up to fire.
        var observedTwo = false
        for _ in 0..<200 {
            if await counter.count == 2 { observedTwo = true; break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        // Give a little extra dwell to ensure no spurious THIRD fire.
        try? await Task.sleep(for: .milliseconds(150))
        let n = await counter.count
        #expect(observedTwo, "follow-up sink never fired")
        #expect(n == 2, "expected exactly 2 sink calls (1 in-flight + 1 follow-up), got \(n)")
        await scheduler.cancel()
    }

    // MARK: - flushNow skips debounce + respects in-flight

    @Test("flushNow runs the sink without waiting for the debounce window")
    func flushNowSkipsDebounce() async {
        let counter = CallCounter()
        let scheduler = RefreshScheduler(debounceMilliseconds: 5_000) {
            await counter.tick()
        }
        let start = Date()
        await scheduler.trigger(.manual)
        await scheduler.flushNow()
        let elapsed = Date().timeIntervalSince(start) * 1000
        let n = await counter.count
        #expect(n == 1)
        #expect(elapsed < 250, "flushNow took \(elapsed)ms")
        await scheduler.cancel()
    }

    // MARK: - cancel drops a pending fire

    @Test("cancel drops a pending work item without firing the sink")
    func cancelDropsPending() async {
        let counter = CallCounter()
        let scheduler = RefreshScheduler(debounceMilliseconds: 100) {
            await counter.tick()
        }
        await scheduler.trigger(.manual)
        await scheduler.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        let n = await counter.count
        #expect(n == 0, "cancel should drop pending fire, got \(n) sink calls")
    }

    // MARK: - lastTriggers cap

    @Test("lastTriggers caps at 32 entries")
    func lastTriggersCap() async {
        let counter = CallCounter()
        let scheduler = RefreshScheduler(debounceMilliseconds: 1_000) {
            await counter.tick()
        }
        for _ in 0..<50 { await scheduler.trigger(.periodic) }
        let triggers = await scheduler.lastTriggers
        #expect(triggers.count == 32)
        await scheduler.cancel()
    }

    // MARK: - AC-P-02 (gated): exactly 1 fire within debounce + 50 ms

    @Test("AC-P-02: 5 triggers in 100ms → 1 fire within 250+50ms of last",
          .enabled(if: RefreshSchedulerTests.perfEnabled))
    func debounceTimingBound() async {
        let counter = CallCounter()
        let scheduler = RefreshScheduler(debounceMilliseconds: 250) {
            await counter.tick()
        }
        for _ in 0..<5 {
            await scheduler.trigger(.periodic)
            try? await Task.sleep(for: .milliseconds(20))
        }
        let lastTriggerAt = Date()
        try? await Task.sleep(for: .milliseconds(400))
        let n = await counter.count
        let times = await counter.times
        #expect(n == 1)
        if let fired = times.first {
            let delta = fired.timeIntervalSince(lastTriggerAt) * 1000
            #expect(delta <= 300, "fired \(delta)ms after last trigger; budget 250+50")
        }
        await scheduler.cancel()
    }
}
