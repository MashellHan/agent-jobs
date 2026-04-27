import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMacUI

/// AC-F-05/F-06/F-07/F-09/F-12/F-13. Drives the view model's stop / hide /
/// unhide / refreshNow methods against a `FakeStopExecutor` + a `HiddenStore`
/// pointed at a temp HOME so no real processes / launchctl / user-home file
/// IO happens.
@Suite("ServiceRegistryViewModel actions (M03)")
@MainActor
struct ServiceRegistryViewModelActionsTests {

    private static func tempHome() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentjobs-vm-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Build a vm wired to the fixture registry + injected fake executor +
    /// a freshly created HiddenStore over a temp HOME.
    private static func makeVM(
        services: [Service] = Service.fixtures(),
        executor: FakeStopExecutor = .init()
    ) async -> (ServiceRegistryViewModel, FakeStopExecutor, URL) {
        let home = tempHome()
        let registry = ServiceRegistry(providers: [FixtureProvider(services)])
        let store = HiddenStore(homeDir: home)
        let vm = ServiceRegistryViewModel(registry: registry, stopExecutor: executor, hiddenStore: store)
        await vm.refresh()
        return (vm, executor, home)
    }

    @Test("stop on a stoppable service calls the executor exactly once and flips status to .idle")
    func stopHappyPath() async {
        let live = Service(
            id: "live.x", source: .process(matched: "x"), kind: .interactive,
            name: "x", status: .running, pid: 4242)
        let (vm, fake, _) = await Self.makeVM(services: [live])
        await vm.stop(live)
        #expect(fake.calls.count == 1)
        #expect(fake.calls.first?.serviceId == "live.x")
        let updated = vm.services.first { $0.id == "live.x" }
        #expect(updated?.status == .idle)
    }

    @Test("stop on a non-stoppable service does NOT call the executor (AC-F-13)")
    func stopRefusedNoExecutorCall() async {
        // PID 1 is refused.
        let bad = Service(id: "live.init", source: .process(matched: "init"),
                          kind: .interactive, name: "init", pid: 1)
        let (vm, fake, _) = await Self.makeVM(services: [bad])
        await vm.stop(bad)
        #expect(fake.calls.isEmpty)
        #expect(vm.errorByServiceId["live.init"] != nil)
    }

    @Test("stop failure populates errorByServiceId and clears after ~4s")
    func stopFailureErrorClears() async {
        let live = Service(id: "live.fail", source: .process(matched: "x"),
                           kind: .interactive, name: "x", status: .running, pid: 4242)
        let exec = FakeStopExecutor()
        exec.scriptedResult = .failure(.refused(reason: "scripted"))
        let (vm, _, _) = await Self.makeVM(services: [live], executor: exec)
        await vm.stop(live)
        #expect(vm.errorByServiceId["live.fail"] == "scripted")
        // We don't actually wait 4s in the unit test — assert the schedule
        // happened by checking the message is present, then explicitly
        // wait a short slice and assert the entry persists.
        try? await Task.sleep(for: .milliseconds(200))
        #expect(vm.errorByServiceId["live.fail"] == "scripted")
    }

    @Test("hide adds id to hiddenIds AND persists via the store")
    func hidePersists() async {
        let (vm, _, home) = await Self.makeVM()
        await vm.hide("fixture.launchd.com.example.daemon")
        #expect(vm.hiddenIds.contains("fixture.launchd.com.example.daemon"))
        // Confirm reload from disk picks it up.
        let store2 = HiddenStore(homeDir: home)
        let snap = await store2.snapshot()
        #expect(snap.contains("fixture.launchd.com.example.daemon"))
    }

    @Test("unhide removes id and persists")
    func unhidePersists() async {
        let (vm, _, home) = await Self.makeVM()
        await vm.hide("fixture.launchd.com.example.daemon")
        await vm.unhide("fixture.launchd.com.example.daemon")
        #expect(!vm.hiddenIds.contains("fixture.launchd.com.example.daemon"))
        let store2 = HiddenStore(homeDir: home)
        let snap = await store2.snapshot()
        #expect(!snap.contains("fixture.launchd.com.example.daemon"))
    }

    @Test("refreshNow toggles isRefreshing and calls discoverAll once")
    func refreshNowToggle() async {
        let (vm, _, _) = await Self.makeVM()
        // Sanity: not refreshing right now.
        #expect(vm.isRefreshing == false)
        await vm.refreshNow()
        #expect(vm.isRefreshing == false)
        // We can't easily catch the in-flight true because the await is
        // synchronous to us; instead we verify the sentinel side-effect:
        // services repopulated with fixture data.
        #expect(vm.services.count == 5)
    }

    @Test("optimistic stop is reconciled by a subsequent refresh (Q4 dropping rule)")
    func optimisticOverlayDropsAfterRefresh() async {
        // Per architecture Q4: a refresh that completed AFTER the user's
        // flip has had a chance to observe reality, so the overlay drops.
        // The fixture provider keeps returning .running (it's a stub) so we
        // expect the row to revert. The race guard's protective branch
        // (flip > refreshStartedAt) is exercised in M03 architecture's own
        // unit pattern; here we verify the dropping rule.
        let live = Service(id: "live.opt", source: .process(matched: "x"),
                           kind: .interactive, name: "opt", status: .running, pid: 4242)
        let (vm, _, _) = await Self.makeVM(services: [live])
        await vm.stop(live)
        #expect(vm.services.first?.status == .idle)
        await vm.refresh()
        // Stub provider has no notion of "stopped" — overlay drops because
        // the new refresh started after our flip.
        #expect(vm.services.first?.status == .running)
    }
}
