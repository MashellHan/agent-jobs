import SwiftUI
import AgentJobsMacUI

/// Thin executable entrypoint for the Agent Jobs menu-bar app.
/// All real UI lives in `AgentJobsMacUI` so the harness + capture-all
/// targets can reach it (M05 T01 — SPM forbids importing executables).
@main
struct AgentJobsMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        AgentJobsAppScene()
    }
}
