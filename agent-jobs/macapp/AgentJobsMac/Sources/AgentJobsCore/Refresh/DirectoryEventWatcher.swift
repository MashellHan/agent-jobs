import Foundation
import CoreServices
import os.log

/// Recursive `FSEventStream` watcher for directory trees with potentially
/// thousands of files (e.g. `~/.claude/projects/`). Used in lieu of one
/// kqueue per file (would exhaust the per-process fd budget).
///
/// AC-F-05: `kFSEventStreamEventIdSinceNow` ensures arm-time-forward only
/// (no historical replay storm on first install). `OnEvent` is debounced
/// upstream by `RefreshScheduler`; the FSEvents `latency` parameter is
/// purely the kernel coalescing window.
///
/// Concurrency: `@unchecked Sendable`. The C callback runs on the
/// configured `dispatch_queue`; mutable state (`stream`, `started`) is
/// touched only from there or from public start/stop while the stream
/// is quiescent.
public final class DirectoryEventWatcher: @unchecked Sendable {
    public typealias OnEvent = @Sendable () -> Void
    public typealias OnInstallFailure = @Sendable (Error) -> Void

    public enum WatcherError: Error, CustomStringConvertible {
        case streamCreateFailed(path: String)
        case directoryMissing(path: String)
        public var description: String {
            switch self {
            case .streamCreateFailed(let p): return "FSEventStreamCreate failed for \(p)"
            case .directoryMissing(let p): return "directory missing: \(p)"
            }
        }
    }

    private let directory: URL
    private let latency: CFTimeInterval
    private let pathFilterSuffix: String?
    private let queue: DispatchQueue
    private let onEvent: OnEvent
    private let onInstallFailure: OnInstallFailure
    private var stream: FSEventStreamRef?
    private var started: Bool = false
    private var stopped: Bool = false
    private let logger = Logger(subsystem: "dev.agentjobs", category: "DirectoryEventWatcher")

    /// - Parameters:
    ///   - directory: root directory to watch (recursive)
    ///   - latency: FSEvents kernel coalescing window (default 0.25 s)
    ///   - pathFilterSuffix: only fire `onEvent` if at least one event
    ///     path ends with this suffix (e.g. `".jsonl"`); pass `nil` for
    ///     no filtering.
    public init(directory: URL,
                latency: CFTimeInterval = 0.25,
                pathFilterSuffix: String? = ".jsonl",
                queue: DispatchQueue = DispatchQueue(label: "dev.agentjobs.dirwatch", qos: .utility),
                onEvent: @escaping OnEvent,
                onInstallFailure: @escaping OnInstallFailure) {
        self.directory = directory
        self.latency = latency
        self.pathFilterSuffix = pathFilterSuffix
        self.queue = queue
        self.onEvent = onEvent
        self.onInstallFailure = onInstallFailure
    }

    public func start() {
        queue.async { [weak self] in self?._install() }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self._teardown()
        }
    }

    // MARK: - private

    private func _install() {
        guard !stopped, stream == nil else { return }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir)
        if !exists || !isDir.boolValue {
            onInstallFailure(WatcherError.directoryMissing(path: directory.path))
            return
        }
        let pathsToWatch = [directory.path] as CFArray
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)
        let flags: UInt32 = UInt32(
            kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagUseCFTypes)
        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            { (_, info, count, eventPaths, _, _) in
                guard let info else { return }
                let me = Unmanaged<DirectoryEventWatcher>.fromOpaque(info).takeUnretainedValue()
                me._handle(count: count, paths: eventPaths)
            },
            &ctx,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            onInstallFailure(WatcherError.streamCreateFailed(path: directory.path))
            return
        }
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        stream = s
        started = true
    }

    private func _handle(count: Int, paths eventPaths: UnsafeRawPointer) {
        // eventPaths is a CFArray of CFStrings (we set kUseCFTypes).
        let arr = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as NSArray
        if let suffix = pathFilterSuffix {
            var matched = false
            for entry in arr {
                if let s = entry as? String, s.hasSuffix(suffix) {
                    matched = true
                    break
                }
            }
            guard matched else { return }
        } else {
            guard count > 0 else { return }
        }
        onEvent()
    }

    private func _teardown() {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
        }
        started = false
    }

    deinit {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
        }
    }
}
