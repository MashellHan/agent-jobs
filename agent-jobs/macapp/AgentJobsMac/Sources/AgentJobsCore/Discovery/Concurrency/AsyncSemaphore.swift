import Foundation

/// Bounded counting semaphore for `async` code. Used by
/// `LsofProcessProvider` to throttle the per-PID `ps` fan-out so we never
/// spawn more than N subprocesses concurrently.
///
/// Cancellation-safe: a cancelled waiter resumes immediately and does not
/// hold a permit, so other waiters keep making progress.
///
/// Introduced in M01 (Discovery audit + gap fill); reusable across any
/// future provider that needs a bounded `async` fan-out.
actor AsyncSemaphore {

    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        precondition(value >= 0, "AsyncSemaphore value must be ≥ 0")
        self.available = value
    }

    /// Acquire one permit. If none are available, suspends until `signal()`
    /// is called or the calling task is cancelled.
    func wait() async {
        if Task.isCancelled { return }
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
    }

    /// Release one permit. Wakes the longest-waiting `wait()` if any are
    /// pending, otherwise increments the available count.
    func signal() {
        if waiters.isEmpty {
            available += 1
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
