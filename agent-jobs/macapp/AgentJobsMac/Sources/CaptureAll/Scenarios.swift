import Foundation
import AppKit
import SwiftUI
import AgentJobsCore
import AgentJobsMacUI
import AgentJobsVisualHarness

/// Table-driven definition of the 14 scenarios `capture-all` produces
/// (M07 expansion: +4 menubar-icon variants and +1 tokens-swatch; old
/// `10-menubar-popover-with-failure-light` dropped per architecture §3.1
/// — failure UX is implicitly sampled by the populated popover/dashboard
/// scenarios via the `failed > 0` overlay branch).
///
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
        // 01. Menubar icon, idle, light
        Scenario(
            name: "01-menubar-icon-idle-light",
            kind: .menubar,
            appearance: .aqua,
            size: CGSize(width: 22, height: 22),
            datasetTag: "fixtures.menubar.idle",
            buildViewModel: { emptyViewModel() },
            buildView: { _ in HarnessScenes.menuBarIconOnly(state: .idle) }
        ),
        // 02. Menubar popover, light, populated
        Scenario(
            name: "02-menubar-popover-light",
            kind: .popover,
            appearance: .aqua,
            size: CGSize(width: 480, height: 520),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 03. Menubar popover, dark
        Scenario(
            name: "03-menubar-popover-dark",
            kind: .popover,
            appearance: .darkAqua,
            size: CGSize(width: 480, height: 520),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 04. Menubar popover, light, empty
        Scenario(
            name: "04-menubar-popover-empty-light",
            kind: .popover,
            appearance: .aqua,
            size: CGSize(width: 480, height: 360),
            datasetTag: "fixtures.empty.v1",
            buildViewModel: { emptyViewModel() },
            buildView: { vm in HarnessScenes.menuBarPopover(viewModel: vm) }
        ),
        // 05. Dashboard, light, populated
        Scenario(
            name: "05-dashboard-populated-light",
            kind: .dashboard,
            appearance: .aqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 06. Dashboard, dark, populated
        Scenario(
            name: "06-dashboard-populated-dark",
            kind: .dashboard,
            appearance: .darkAqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.populated.v1",
            buildViewModel: { populatedViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 07. Dashboard, light, empty
        Scenario(
            name: "07-dashboard-empty-light",
            kind: .dashboard,
            appearance: .aqua,
            size: CGSize(width: 1280, height: 800),
            datasetTag: "fixtures.empty.v1",
            buildViewModel: { emptyViewModel() },
            buildView: { vm in HarnessScenes.dashboard(viewModel: vm) }
        ),
        // 08. Dashboard with inspector open, light
        Scenario(
            name: "08-dashboard-inspector-light",
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
        // 09. Dashboard with inspector, dark
        Scenario(
            name: "09-dashboard-inspector-dark",
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
        // 10. Dashboard, narrow width (responsive layout check)
        Scenario(
            name: "10-dashboard-narrow-light",
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
        // 11. Menubar icon, single-digit count, light
        Scenario(
            name: "11-menubar-icon-count-1-light",
            kind: .menubar,
            appearance: .aqua,
            size: CGSize(width: 44, height: 22),
            datasetTag: "fixtures.menubar.running1",
            buildViewModel: { emptyViewModel() },
            buildView: { _ in HarnessScenes.menuBarIconOnly(state: .running(1)) }
        ),
        // 12. Menubar icon, "9+" count, light
        Scenario(
            name: "12-menubar-icon-count-N-light",
            kind: .menubar,
            appearance: .aqua,
            size: CGSize(width: 56, height: 22),
            datasetTag: "fixtures.menubar.running12",
            buildViewModel: { emptyViewModel() },
            buildView: { _ in HarnessScenes.menuBarIconOnly(state: .running(12)) }
        ),
        // 13. Menubar icon, idle, dark (template-image inversion check)
        Scenario(
            name: "13-menubar-icon-idle-dark",
            kind: .menubar,
            appearance: .darkAqua,
            size: CGSize(width: 22, height: 22),
            datasetTag: "fixtures.menubar.idle",
            buildViewModel: { emptyViewModel() },
            buildView: { _ in HarnessScenes.menuBarIconOnly(state: .idle) }
        ),
        // 14. Tokens swatch (color + type + spacing specimen)
        Scenario(
            name: "14-tokens-swatches-light",
            kind: .dashboard,  // closest existing kind (no `swatch`)
            appearance: .aqua,
            size: CGSize(width: 800, height: 600),
            datasetTag: "fixtures.tokens.v1",
            buildViewModel: { emptyViewModel() },
            buildView: { _ in HarnessScenes.tokensSwatch() }
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
}
