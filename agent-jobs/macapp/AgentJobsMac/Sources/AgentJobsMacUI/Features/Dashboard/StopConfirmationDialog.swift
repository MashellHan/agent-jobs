import SwiftUI
import AgentJobsCore

/// Wraps a content view with a `.confirmationDialog` driven by a binding to
/// the pending Service?. Cancel / Stop are wired automatically; the parent
/// passes `onConfirm` to receive the user's positive choice. AC-F-05.
struct StopConfirmationDialog: ViewModifier {
    @Binding var pending: Service?
    let onConfirm: (Service) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            pending.map { "Stop \($0.name)?" } ?? "",
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                if let s = pending { onConfirm(s) }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            if let s = pending { Text(Self.body(for: s)) }
        }
    }

    /// Variant-aware body string. Live processes: SIGTERM + PID. launchd:
    /// launchctl unload + label. Other sources should never reach this
    /// dialog because `canStop == false` pre-disables the trigger.
    static func body(for s: Service) -> String {
        switch s.source {
        case .process:
            return "This will send SIGTERM to PID \(s.pid.map(String.init) ?? "?")."
        case .launchdUser:
            return "This will run `launchctl unload` on \(s.name)."
        default:
            return ""
        }
    }
}

extension View {
    /// Convenience wrapper so call sites read like `.stopConfirmation(pending: $x) { vm.stop($0) }`.
    func stopConfirmation(pending: Binding<Service?>, onConfirm: @escaping (Service) -> Void) -> some View {
        modifier(StopConfirmationDialog(pending: pending, onConfirm: onConfirm))
    }
}
