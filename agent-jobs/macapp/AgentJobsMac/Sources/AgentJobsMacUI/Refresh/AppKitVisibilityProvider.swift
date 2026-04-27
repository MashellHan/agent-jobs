import Foundation
import AppKit
import AgentJobsCore

/// Production `VisibilityProvider`. Combines:
///  - dashboard-window occlusion (NSApplication.didChangeOcclusionStateNotification),
///  - a `popoverOpen` boolean exposed by the view model and toggled by
///    `MenuBarPopoverView.task` / `.onDisappear`.
///
/// The combined predicate `dashboardVisible || popoverOpen` flips the
/// `AsyncStream<Bool>`. A 1 s polling timer covers the gap between
/// SwiftUI cancelling the popover's `.task` and our `.onDisappear`
/// callback (the spec's grace).
@MainActor
public final class AppKitVisibilityProvider: VisibilityProvider {
    private let popoverOpenProvider: @MainActor @Sendable () -> Bool
    private let dashboardWindowId: String
    private let pollIntervalSeconds: Double

    public init(
        dashboardWindowId: String = "dashboard",
        pollIntervalSeconds: Double = 1.0,
        popoverOpen: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.dashboardWindowId = dashboardWindowId
        self.pollIntervalSeconds = pollIntervalSeconds
        self.popoverOpenProvider = popoverOpen
    }

    nonisolated public var isVisible: Bool {
        get async { await snapshot() }
    }

    @MainActor
    private func snapshot() -> Bool {
        let dashVisible = NSApp.windows.contains { win in
            win.identifier?.rawValue == dashboardWindowId
                && win.occlusionState.contains(.visible)
        }
        return dashVisible || popoverOpenProvider()
    }

    nonisolated public func changes() -> AsyncStream<Bool> {
        let interval = pollIntervalSeconds
        return AsyncStream<Bool> { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else { continuation.finish(); return }
                var last = self.snapshot()
                continuation.yield(last)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                    if Task.isCancelled { break }
                    let now = self.snapshot()
                    if now != last {
                        last = now
                        continuation.yield(now)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
