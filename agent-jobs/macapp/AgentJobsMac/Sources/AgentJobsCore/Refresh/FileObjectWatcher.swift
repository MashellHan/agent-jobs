import Foundation
import Darwin
import os.log

/// kqueue-backed file watcher (`DispatchSource.makeFileSystemObjectSource`)
/// with atomic-rename re-open. Designed for single-file targets like
/// `~/.agent-jobs/jobs.json` and `~/.claude/scheduled_tasks.json`.
///
/// Atomic-rename safety (AC-F-04): editors and `HiddenStore` write via
/// `tmp + rename(tmp, target)`; the kernel emits `.delete`/`.rename` on
/// the original fd. We `stop()`, then re-`open()` after a 50 ms grace,
/// fire one synthetic `onEvent`, and resume watching the new inode.
///
/// Concurrency: `@unchecked Sendable`. All mutable state (`fd`,
/// `source`, `attempts`) is touched only on the fixed `queue` passed at
/// init OR via lock-free atomic write from public `start`/`stop` calls
/// while the source is quiescent.
public final class FileObjectWatcher: @unchecked Sendable {
    public typealias OnEvent = @Sendable () -> Void
    public typealias OnInstallFailure = @Sendable (Error) -> Void

    public enum WatcherError: Error, CustomStringConvertible {
        case openFailed(path: String, errno: Int32)
        public var description: String {
            switch self {
            case .openFailed(let p, let e):
                return "FileObjectWatcher.open failed for \(p) (errno \(e))"
            }
        }
    }

    private let url: URL
    private let queue: DispatchQueue
    private let onEvent: OnEvent
    private let onInstallFailure: OnInstallFailure
    private let reopenDelayMs: Int
    private let maxAttempts: Int
    private var fd: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var attempts: Int = 0
    private var stopped: Bool = false
    private let logger = Logger(subsystem: "dev.agentjobs", category: "FileObjectWatcher")

    public init(url: URL,
                queue: DispatchQueue = DispatchQueue(label: "dev.agentjobs.fwatch", qos: .utility),
                reopenDelayMs: Int = 50,
                maxAttempts: Int = 3,
                onEvent: @escaping OnEvent,
                onInstallFailure: @escaping OnInstallFailure) {
        self.url = url
        self.queue = queue
        self.reopenDelayMs = reopenDelayMs
        self.maxAttempts = maxAttempts
        self.onEvent = onEvent
        self.onInstallFailure = onInstallFailure
    }

    /// Open the fd and arm the DispatchSource. Best-effort; failure
    /// surfaces via `onInstallFailure`. Idempotent.
    public func start() {
        queue.async { [weak self] in self?._install() }
    }

    /// Cancel the source and close the fd. Safe to call repeatedly.
    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self._teardown()
        }
    }

    // MARK: - private (queue-isolated)

    private func _install() {
        guard !stopped else { return }
        let path = url.path
        let opened = open(path, O_EVTONLY)
        if opened < 0 {
            let err = errno
            attempts += 1
            logger.error("open(O_EVTONLY) failed for \(path, privacy: .public) errno=\(err)")
            if attempts >= maxAttempts {
                onInstallFailure(WatcherError.openFailed(path: path, errno: err))
                return
            }
            let backoff = min(5_000, 100 * (1 << (attempts - 1)))
            queue.asyncAfter(deadline: .now() + .milliseconds(backoff)) { [weak self] in
                self?._install()
            }
            return
        }
        attempts = 0
        fd = opened
        let mask: DispatchSource.FileSystemEvent = [.write, .extend, .delete, .rename, .revoke]
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: opened, eventMask: mask, queue: queue)
        src.setEventHandler { [weak self] in self?._handle(src.data) }
        src.setCancelHandler { [opened] in close(opened) }
        source = src
        src.resume()
    }

    private func _handle(_ events: DispatchSource.FileSystemEvent) {
        if events.intersection([.delete, .rename, .revoke]).isEmpty == false {
            // Atomic-rename / unlink: tear down current fd, re-open on a
            // short delay, fire one synthetic event for the user.
            _teardown()
            queue.asyncAfter(deadline: .now() + .milliseconds(reopenDelayMs)) { [weak self] in
                guard let self else { return }
                if self.stopped { return }
                self._install()
                if self.fd >= 0 { self.onEvent() }
            }
            return
        }
        // Plain .write / .extend → user-visible event.
        onEvent()
    }

    private func _teardown() {
        if let src = source {
            src.cancel()  // cancel handler closes fd
            source = nil
            fd = -1
        } else if fd >= 0 {
            close(fd)
            fd = -1
        }
    }
}
