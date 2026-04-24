import Testing
import Foundation
@testable import AgentJobsCore

@Suite("AsyncSemaphore")
struct AsyncSemaphoreTests {

    /// Atomic-ish in-flight counter (actor-isolated).
    private actor Counter {
        private(set) var current = 0
        private(set) var highWater = 0
        func enter() {
            current += 1
            if current > highWater { highWater = current }
        }
        func leave() { current -= 1 }
    }

    @Test("100 concurrent waiters with value=8 → high-water ≤ 8, all complete")
    func boundedFanOut() async {
        let sem = AsyncSemaphore(value: 8)
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await sem.wait()
                    await counter.enter()
                    // Tiny yield window so the scheduler can interleave others.
                    try? await Task.sleep(for: .milliseconds(1))
                    await counter.leave()
                    await sem.signal()
                }
            }
        }

        let high = await counter.highWater
        let curr = await counter.current
        #expect(high <= 8)
        #expect(high > 0)
        #expect(curr == 0)
    }

    @Test("cancelling half of pending waiters does not stall the rest")
    func cancellationDoesNotStall() async {
        let sem = AsyncSemaphore(value: 1)
        // Hold the permit so all subsequent waiters queue up.
        await sem.wait()

        // Spawn 4 waiters; we'll cancel two and complete two.
        var tasks: [Task<Void, Never>] = []
        let completed = Counter()
        for _ in 0..<4 {
            let t = Task {
                await sem.wait()
                await completed.enter()
                await sem.signal()
            }
            tasks.append(t)
        }

        // Give them a moment to enqueue.
        try? await Task.sleep(for: .milliseconds(20))

        // Cancel two; they should not consume permits.
        tasks[0].cancel()
        tasks[1].cancel()

        // Release the held permit so queued waiters can drain.
        await sem.signal()

        // Wait for all spawned tasks to finish.
        for t in tasks { _ = await t.value }

        let done = await completed.current
        // At least the two non-cancelled waiters must have run. Cancelled
        // waiters may or may not have entered before cancellation took
        // effect — what matters is no deadlock and `done > 0`.
        #expect(done >= 2)
    }
}
