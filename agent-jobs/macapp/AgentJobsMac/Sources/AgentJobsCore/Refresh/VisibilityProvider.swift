import Foundation

/// Lightweight visibility predicate. Production reads NSApplication +
/// MenuBarExtra popover state; tests pass `FakeVisibilityProvider`.
///
/// Used by the view model to pause the `PeriodicTicker` when no
/// user-visible surface is open (AC-F-07).
public protocol VisibilityProvider: Sendable {
    /// Snapshot of the current visibility predicate.
    var isVisible: Bool { get async }
    /// Stream of visibility changes. The view model awaits this and
    /// pauses/resumes the ticker accordingly.
    func changes() -> AsyncStream<Bool>
}

/// Test-only fake driving the predicate from the test thread.
/// `set(_:)` flips the value and emits to all active streams.
public final class FakeVisibilityProvider: VisibilityProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init(initial: Bool = true) { self.current = initial }

    public var isVisible: Bool {
        get async {
            return readCurrent()
        }
    }

    private func readCurrent() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func set(_ visible: Bool) {
        lock.lock()
        current = visible
        let conts = continuations.values
        lock.unlock()
        for c in conts { c.yield(visible) }
    }

    public func changes() -> AsyncStream<Bool> {
        let id = UUID()
        return AsyncStream<Bool> { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            self.lock.lock()
            self.continuations[id] = continuation
            let initial = self.current
            self.lock.unlock()
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations[id] = nil
                self?.lock.unlock()
            }
        }
    }
}
