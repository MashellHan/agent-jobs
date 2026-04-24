import SwiftUI
import AgentJobsCore

/// Action affordance shared by the dashboard row hover state and the
/// inspector action bar. `iconOnly` for compact rows; `withLabels` for the
/// inspector. Disables Stop when `service.canStop == false` and surfaces the
/// refusal reason via `.help(_:)`.
struct RowActionStack: View {
    let service: Service
    let isHidden: Bool
    let style: Style
    let onStop: () -> Void
    let onHide: () -> Void
    let onUnhide: () -> Void

    enum Style { case iconOnly, withLabels }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            stopButton
            hideOrUnhideButton
        }
    }

    @ViewBuilder
    private var stopButton: some View {
        let canStop = service.canStop
        Button(action: onStop) {
            Label("Stop", systemImage: "xmark.octagon")
                .labelStyle(style == .iconOnly ? AnyLabelStyle(IconOnly()) : AnyLabelStyle(TitleAndIcon()))
                .foregroundStyle(canStop ? Color.red : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canStop)
        .help(canStop ? "Stop this service" : (stopRefusalReason ?? "Stop unavailable"))
        .accessibilityLabel("Stop \(service.name)")
    }

    @ViewBuilder
    private var hideOrUnhideButton: some View {
        let symbol = isHidden ? "eye" : "eye.slash"
        let title  = isHidden ? "Unhide" : "Hide"
        Button(action: { isHidden ? onUnhide() : onHide() }) {
            Label(title, systemImage: symbol)
                .labelStyle(style == .iconOnly ? AnyLabelStyle(IconOnly()) : AnyLabelStyle(TitleAndIcon()))
        }
        .buttonStyle(.plain)
        .help(isHidden ? "Show this service again" : "Hide this service from the list")
        .accessibilityLabel("\(title) \(service.name)")
    }

    /// Mirrors the executor's refusal predicate so the tooltip matches what
    /// the executor would have thrown. Pure read.
    private var stopRefusalReason: String? {
        RealStopExecutor.refusalReason(
            for: service,
            selfPid: ProcessInfo.processInfo.processIdentifier,
            plistURL: LaunchdPlistReader.plistURL(forLabel:)
        )
    }

    /// SwiftUI `LabelStyle` doesn't expose a single existential, so we wrap
    /// the two we want behind a tiny `AnyLabelStyle` shim to keep the call
    /// sites flat. Lighter than splitting `RowActionStack` into two views.
    private struct IconOnly: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.icon.imageScale(.medium)
        }
    }
    private struct TitleAndIcon: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: DesignTokens.Spacing.xs) {
                configuration.icon
                configuration.title
            }
        }
    }
    private struct AnyLabelStyle: LabelStyle {
        let make: (Configuration) -> AnyView
        init<S: LabelStyle>(_ s: S) {
            self.make = { conf in AnyView(s.makeBody(configuration: conf)) }
        }
        func makeBody(configuration: Configuration) -> some View { make(configuration) }
    }
}
