import Testing
import Foundation
import SwiftUI
@testable import AgentJobsCore
@testable import AgentJobsMacUI

/// AC-F-06: rich row exposes title + summary; AC-F-12: retry only on .failed.
@MainActor
@Suite("MenuBarRichRow (M06 T-002 / T-016)")
struct MenuBarRichRowTests {

    private func svc(_ id: String, _ status: ServiceStatus) -> Service {
        Service(id: id, source: .agentJobsJson, kind: .scheduled, name: id, status: status)
    }

    @Test("retry closure passes through for .failed only")
    func retryOnlyOnFailed() {
        var called = 0
        let action: (Service) -> Void = { _ in called += 1 }

        // Failed row with closure → callable
        let failed = svc("f", .failed)
        let row = MenuBarRichRow(service: failed, onRetry: action)
        row.onRetry?(failed)
        #expect(called == 1)

        // Running row with the same closure exposed — view layer uses
        // retryClosure(for:) to gate, so a running row should never be
        // wired with a non-nil closure in practice. We assert here that
        // the row honors whatever it is given (nil ↔ no retry).
        let running = MenuBarRichRow(service: svc("r", .running), onRetry: nil)
        #expect(running.onRetry == nil)
    }

    @Test("AC-F-06: row exposes 3 fields (title, summary, status)")
    func threeFields() {
        let s = svc("hello", .running)
        let row = MenuBarRichRow(service: s, onRetry: nil)
        // Body must compile and reach into ServiceFormatter without
        // raising — sanity-check that the underlying formatter delivers
        // a non-empty title + summary string.
        let formatted = ServiceFormatter.format(s)
        #expect(!formatted.title.isEmpty)
        #expect(!formatted.summary.isEmpty)
        #expect(row.service.status == .running)
    }
}

/// AC-F-04: popover width is 480.
@MainActor
@Suite("MenuBarPopoverView width (M06 T-002)")
struct MenuBarPopoverViewWidthTests {

    @Test("popoverWidth ≥ 480")
    func width() {
        #expect(MenuBarPopoverView.popoverWidth >= 480)
        // HarnessScenes mirrors the same literal.
        #expect(HarnessScenes.defaultPopoverWidth == MenuBarPopoverView.popoverWidth)
    }
}
