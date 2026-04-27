// M05 T09: pin the registry-health → bucket-error collapse rule used by
// SourceBucketChip's tooltip. AC-F-14.

import Testing
import Foundation
@testable import AgentJobsCore
@testable import AgentJobsMacUI

@Suite("ServiceRegistryViewModel.collapseHealth (M05 T09 / AC-F-14)")
@MainActor
struct CollapseHealthTests {

    @Test("provider id maps to its canonical bucket")
    func bucketMapping() {
        #expect(ServiceRegistryViewModel.bucket(
            forProviderId: AgentJobsJsonProvider.providerId) == .registered)
        #expect(ServiceRegistryViewModel.bucket(
            forProviderId: ClaudeScheduledTasksProvider.providerId) == .claudeScheduled)
        #expect(ServiceRegistryViewModel.bucket(
            forProviderId: ClaudeSessionCronProvider.providerId) == .claudeSession)
        #expect(ServiceRegistryViewModel.bucket(
            forProviderId: LaunchdUserProvider.providerId) == .launchd)
        #expect(ServiceRegistryViewModel.bucket(
            forProviderId: LsofProcessProvider.providerId) == .liveProcess)
        #expect(ServiceRegistryViewModel.bucket(forProviderId: "unknown") == nil)
    }

    @Test("clean health collapses to empty dictionary")
    func cleanCollapses() {
        let h = [
            ProviderHealth(providerId: AgentJobsJsonProvider.providerId,
                           lastError: nil,
                           lastSuccessAt: Date(),
                           perFileFailures: [:]),
        ]
        let out = ServiceRegistryViewModel.collapseHealth(h)
        #expect(out.isEmpty)
    }

    @Test("lastError surfaces under the right bucket")
    func lastErrorSurface() {
        let h = [
            ProviderHealth(providerId: ClaudeSessionCronProvider.providerId,
                           lastError: .ioError("disk read failed"),
                           lastSuccessAt: nil,
                           perFileFailures: [:]),
        ]
        let out = ServiceRegistryViewModel.collapseHealth(h)
        let msg = out[.claudeSession] ?? ""
        #expect(!msg.isEmpty)
        #expect(msg.contains("disk read failed"))
    }

    @Test("perFileFailures without lastError reports a count")
    func perFileFallback() {
        let h = [
            ProviderHealth(providerId: ClaudeScheduledTasksProvider.providerId,
                           lastError: nil,
                           lastSuccessAt: nil,
                           perFileFailures: ["a.json": "boom", "b.json": "boom"]),
        ]
        let out = ServiceRegistryViewModel.collapseHealth(h)
        let msg = out[.claudeScheduled] ?? ""
        #expect(msg.contains("2"))
    }

    @Test("unknown provider id is skipped, not crashed")
    func unknownProviderSkipped() {
        let h = [
            ProviderHealth(providerId: "definitely-not-a-real-provider",
                           lastError: .ioError("ignored"),
                           lastSuccessAt: nil,
                           perFileFailures: [:]),
        ]
        let out = ServiceRegistryViewModel.collapseHealth(h)
        #expect(out.isEmpty)
    }
}
