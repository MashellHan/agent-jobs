import Foundation
import AppKit
import SwiftUI
import AgentJobsCore
import AgentJobsMacUI
import AgentJobsVisualHarness

/// Table-driven definition of the 10 scenarios `capture-all` produces.
/// Adding a scenario is a one-row append — the runner in `main.swift`
/// stays unchanged.
@MainActor
enum Scenarios {

    struct Scenario {
        let name: String
        let kind: Critique.Kind
        let appearance: NSAppearance.Name
        let size: CGSize
        let datasetTag: String
        /// Builds a fresh view model for the scenario. Pass `nil` to use
        /// the default fixture set.
        let buildViewModel: @MainActor () -> ServiceRegistryViewModel
        let buildView: @MainActor (ServiceRegistryViewModel) -> AnyView
    }

    static let all: [Scenario] = [
        // 1. Menubar popover, light, populated
        Scenario(
            name: "01-menubar-popover-light",
            kind: .popover,
            appearance: .aqua,
            size: CGSize(width: 480, height: 520),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 2. Menubar popover, dark
        Scenario(
            name: "02-menubar-popover-dark",
            kind: .popover,
            appearance: .darkAqua,
            size: CGSize(width: 480, height: 520),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 3. Menubar popover, light, empty
        Scenario(
            name: "03-menubar-popover-empty-light",
            kind: .popover,
            appearance: .aqua,
            size: CGSize(width: 480, height: 360),
            datasetTag: "fixtures.empty.v1",
            buildViewModel: { emptyViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 4. Dashboard, light, populated
        Scenario(
            name: "04-dashboard-populated-light",
            kind: .dashboard,
            appearance: .aqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 5. Dashboard, dark, populated
        Scenario(
            name: "05-dashboard-populated-dark",
            kind: .dashboard,
            appearance: .darkAqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 6. Dashboard, light, empty
        Scenario(
            name: "06-dashboard-empty-light",
            kind: .dashboard,
            appearance: .aqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.empty.v1",
            buildViewModel: { emptyViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 7. Dashboard with inspector open
        Scenario(
            name: "07-dashboard-inspector-light",
            kind: .inspector,
            appearance: .aqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in
                let firstId = Service.fixtures().first?.id
                return HarnessScenes.dashboard(viewModel: vm, initialSelection: firstId)
            }
        ),
        // 8. Dashboard with inspector, dark
        Scenario(
            name: "08-dashboard-inspector-dark",
            kind: .inspector,
            appearance: .darkAqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in
                let firstId = Service.fixtures().first?.id
                return HarnessScenes.dashboard(viewModel: vm, initialSelection: firstId)
            }
        ),
        // 9. Dashboard, narrow width (responsive layout check)
        Scenario(
            name: "09-dashboard-narrow-light",
            kind: .dashboard,
            appearance: .aqua,
            size: CGSize(width: 1024, height: 700),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in
                HarnessScenes.dashboard(
                    viewModel: vm,
                    size: CGSize(width: 1024, height: 700)
                )
            }
        ),
        // 10. Menubar popover, with a failed service in the mix (alert UX)
        Scenario(
            name: "10-menubar-popover-with-failure-light",
            kind: .popover,
            appearance: .aqua,
            size: CGSize(width: 480, height: 520),
            datasetTag: "fixtures.with-failure.v1",
            buildViewModel: { populatedViewModelWithFailure() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
    ]

    // MARK: - View model factories

    static func populatedViewModel() -> ServiceRegistryViewModel {
        let vm = ServiceRegistryViewModel(registry: .emptyRegistry())
        vm.applyCaptureSeed(services: Service.fixtures())
        return vm
    }

    static func emptyViewModel() -> ServiceRegistryViewModel {
        let vm = ServiceRegistryViewModel(registry: .emptyRegistry())
        vm.applyCaptureSeed(services: [])
        return vm
    }

    static func populatedViewModelWithFailure() -> ServiceRegistryViewModel {
        let vm = ServiceRegistryViewModel(registry: .emptyRegistry())
        var svcs = Service.fixtures()
        if !svcs.isEmpty {
            svcs[0] = svcs[0].withForcedStatus(.failed)
        }
        vm.applyCaptureSeed(services: svcs)
        return vm
    }
}

private extension Service {
    /// Local helper — same shape as the view model's internal `withStatus`
    /// but kept here so the scenarios file doesn't depend on internals.
    func withForcedStatus(_ s: ServiceStatus) -> Service {
        Service(
            id: id, source: source, kind: kind, name: name, project: project,
            command: command, schedule: schedule, status: s, createdAt: createdAt,
            lastRun: lastRun, nextRun: nextRun, pid: pid, metrics: metrics,
            logsPath: logsPath, owner: owner, history: history, origin: origin
        )
    }
}
