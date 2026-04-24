import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-06 (periodic tick), AC-F-07 (immediate resume), AC-F-12 (cancel),
/// AC-P-03 (gated: zero ticks while paused).
@Suite("PeriodicTicker + FakeVisibilityProvider")
struct PeriodicTickerTests {

    actor Counter {
        private(set) var count: Int = 0
        func tick() { count += 1 }
    }

    private static let perfEnabled =
        ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1"

    private static func waitUntil(_ ms: Int, _ p: () async -> Bool) async -> Bool {
        let step = 25
        for _ in 0..<(ms/step) {
            if await p() { return true }
            try? await Task.sleep(for: .milliseconds(step))
        }
        return await p()
    }

    @Test("start fires multiple ticks at the configured interval")
    func startFiresTicks() async {
        let counter = Counter()
        let ticker = PeriodicTicker(intervalSeconds: 0.1, keepaliveSeconds: 60.0) {
            await counter.tick()
        }
        await ticker.start()
        let observed = await Self.waitUntil(800) { await counter.count >= 2 }
        await ticker.cancel()
        let n = await counter.count
        #expect(observed, "expected ≥ 2 ticks within 800ms, got \(n)")
    }

    @Test("pause stops periodic ticks; resume fires immediate catch-up")
    func pauseResume() async {
        let counter = Counter()
        let ticker = PeriodicTicker(intervalSeconds: 0.1, keepaliveSeconds: 60.0) {
            await counter.tick()
        }
        await ticker.start()
        _ = await Self.waitUntil(500) { await counter.count >= 1 }
        await ticker.pause()
        let baseline = await counter.count
        try? await Task.sleep(for: .milliseconds(600))
        let afterPause = await counter.count
        #expect(afterPause == baseline, "pause should stop ticks, baseline=\(baseline) after=\(afterPause)")
        await ticker.resume()
        // resume() awaits the immediate catch-up directly → at least baseline+1.
        let n = await counter.count
        #expect(n >= baseline + 1, "resume should immediately tick, got \(n) (baseline=\(baseline))")
        await ticker.cancel()
    }

    @Test("cancel stops the loop; no further ticks")
    func cancelStopsLoop() async {
        let counter = Counter()
        let ticker = PeriodicTicker(intervalSeconds: 0.05, keepaliveSeconds: 60.0) {
            await counter.tick()
        }
        await ticker.start()
        try? await Task.sleep(for: .milliseconds(200))
        await ticker.cancel()
        let mark = await counter.count
        try? await Task.sleep(for: .milliseconds(300))
        let after = await counter.count
        #expect(after == mark, "expected no ticks after cancel, got \(mark) → \(after)")
    }

    actor BoolList {
        private(set) var values: [Bool] = []
        func append(_ v: Bool) { values.append(v) }
    }

    @Test("FakeVisibilityProvider.set() emits to active stream")
    func fakeVisibilityEmits() async {
        let provider = FakeVisibilityProvider(initial: true)
        let received = BoolList()
        let task = Task {
            for await v in provider.changes() {
                await received.append(v)
                if await received.values.count >= 3 { break }
            }
        }
        try? await Task.sleep(for: .milliseconds(50))
        provider.set(false)
        try? await Task.sleep(for: .milliseconds(50))
        provider.set(true)
        _ = await task.value
        let v = await received.values
        #expect(v == [true, false, true])
    }

    // MARK: - AC-P-03 (gated): zero periodic ticks across a long paused window

    @Test("AC-P-03: zero periodic ticks during 1.5s of paused state",
          .enabled(if: PeriodicTickerTests.perfEnabled))
    func zeroTicksWhilePaused() async {
        let counter = Counter()
        let ticker = PeriodicTicker(intervalSeconds: 0.1, keepaliveSeconds: 60.0) {
            await counter.tick()
        }
        await ticker.start()
        await ticker.pause()
        try? await Task.sleep(for: .milliseconds(1_500))
        let n = await counter.count
        await ticker.cancel()
        #expect(n == 0, "expected zero ticks while paused, got \(n)")
    }
}
