import Testing
import Foundation
@testable import AgentJobsCore

/// AC-F-06 / AC-F-07 / AC-F-08 / AC-P-01: ServiceFormatter table-driven
/// rules + length invariant + id stability + perf gate.
@Suite("ServiceFormatter (M05 T03 / closes T-005)")
struct ServiceFormatterTests {

    // MARK: - AC-F-06: friendlyTitle table (≥12 cases)

    @Test("AC-F-06: launchd vendor-bundle → mapped friendly name")
    func launchdMappedNames() {
        let cases: [(String, String)] = [
            ("com.apple.MobileSMS",       "iMessage"),
            ("com.apple.Mail",            "Mail"),
            ("com.apple.Safari",          "Safari"),
            ("com.microsoft.VSCode",      "VS Code"),
            ("com.google.Chrome",         "Chrome"),
            ("com.docker.docker",         "Docker"),
        ]
        for (label, want) in cases {
            let s = launchdSvc(label)
            #expect(ServiceFormatter.friendlyTitle(s) == want, "label=\(label)")
        }
    }

    @Test("AC-F-06: launchd numeric tail stripped before lookup")
    func launchdNumericTail() {
        let s = launchdSvc("com.apple.MobileSMS.115")
        #expect(ServiceFormatter.friendlyTitle(s) == "iMessage")
    }

    @Test("AC-F-06: launchd unmapped → camel-split last segment")
    func launchdUnmapped() {
        let s = launchdSvc("com.acme.MyDaemonService")
        let title = ServiceFormatter.friendlyTitle(s)
        #expect(title == "My Daemon Service")
    }

    @Test("AC-F-06: process basename from command preferred over short name")
    func processBasename() {
        let s = Service(id: "p1", source: .process(matched: "node"),
                        kind: .daemon, name: "n",
                        command: "/usr/local/bin/npm run dev")
        let title = ServiceFormatter.friendlyTitle(s)
        #expect(title == "npm")
    }

    @Test("AC-F-06: claude-loop / claude-scheduled / agent-jobs pass through")
    func passthroughSources() {
        let loop = Service(id: "x", source: .claudeLoop(sessionId: "abc12345"),
                           kind: .scheduled, name: "Nightly digest")
        let sched = Service(id: "y", source: .claudeScheduledTask(durable: true),
                            kind: .scheduled, name: "Backup db")
        let json = Service(id: "z", source: .agentJobsJson, kind: .oneshot,
                           name: "Build images")
        #expect(ServiceFormatter.friendlyTitle(loop) == "Nightly digest")
        #expect(ServiceFormatter.friendlyTitle(sched) == "Backup db")
        #expect(ServiceFormatter.friendlyTitle(json) == "Build images")
    }

    @Test("AC-F-06: very long name truncates to ≤ 60 with ellipsis")
    func veryLongTruncates() {
        let long = String(repeating: "a", count: 200)
        let s = Service(id: "L", source: .agentJobsJson, kind: .daemon, name: long)
        let title = ServiceFormatter.friendlyTitle(s)
        #expect(title.count <= ServiceFormatter.titleLimit)
        #expect(title.hasSuffix("…"))
    }

    @Test("AC-F-06: empty name falls back to bucket + id suffix")
    func emptyNameFallback() {
        let s = Service(id: "abc123def456", source: .launchdUser, kind: .daemon, name: "")
        let title = ServiceFormatter.friendlyTitle(s)
        #expect(title.contains("launchd"))
        #expect(title.contains("ef456") || title.contains("def456"))
    }

    @Test("AC-F-06: numeric-only name falls back to bucket + id suffix")
    func numericOnlyFallback() {
        let s = Service(id: "ID987654", source: .process(matched: "x"),
                        kind: .daemon, name: "12345", command: "")
        let title = ServiceFormatter.friendlyTitle(s)
        #expect(title.contains("live-proc"))
    }

    // MARK: - AC-F-07: summary length invariant

    @Test("AC-F-07: summary ≤ 80 chars and contains no newlines for fixtures")
    func summaryLengthInvariant() {
        let probes = sampleFixtures()
        for s in probes {
            let out = ServiceFormatter.summary(s)
            #expect(out.count <= ServiceFormatter.summaryLimit, "name=\(s.name)")
            #expect(!out.contains("\n"))
        }
    }

    @Test("AC-F-07: process summary includes pid and memory when present")
    func processSummaryFormat() {
        let metrics = ResourceMetrics(pid: 1234, cpuPercent: 12.0,
                                      memoryRSS: 24 * 1024 * 1024,
                                      startTime: Date())
        let s = Service(id: "p", source: .process(matched: "ruby"),
                        kind: .daemon, name: "ruby",
                        command: "ruby /usr/local/bin/foo",
                        pid: 1234, metrics: metrics)
        let out = ServiceFormatter.summary(s)
        #expect(out.contains("pid 1234"))
        #expect(out.contains("MB") || out.contains("KB") || out.contains("B"))
    }

    // MARK: - AC-F-08: id stability across formatter

    @Test("AC-F-08: format() does not mutate Service.id")
    func idStability() {
        let svcs = sampleFixtures()
        let beforeIds = svcs.map(\.id)
        for s in svcs {
            _ = ServiceFormatter.format(s)
        }
        let afterIds = svcs.map(\.id)
        #expect(beforeIds == afterIds)
    }

    // MARK: - AC-P-01: < 50µs per call (gated)

    @Test("AC-P-01: friendlyTitle median < 50µs over 1000 invocations (AGENTJOBS_PERF=1)")
    func perfGate() throws {
        guard ProcessInfo.processInfo.environment["AGENTJOBS_PERF"] == "1" else {
            // Gated per E001 — preserve strict spec budget for opt-in.
            return
        }
        let s = launchdSvc("com.apple.MobileSMS.115")
        var samples: [UInt64] = []
        samples.reserveCapacity(1000)
        for _ in 0..<1000 {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = ServiceFormatter.friendlyTitle(s)
            samples.append(DispatchTime.now().uptimeNanoseconds - start)
        }
        samples.sort()
        let medianNs = samples[samples.count / 2]
        #expect(medianNs < 50_000, "median \(medianNs)ns ≥ 50µs spec budget")
    }

    // MARK: - helpers

    private func launchdSvc(_ label: String) -> Service {
        Service(id: "id-" + label, source: .launchdUser,
                kind: .daemon, name: label, command: "/usr/bin/\(label)")
    }

    private func sampleFixtures() -> [Service] {
        [
            launchdSvc("com.apple.MobileSMS"),
            launchdSvc("com.acme.SomeService"),
            Service(id: "loop1", source: .claudeLoop(sessionId: "deadbeef-0000"),
                    kind: .scheduled, name: "tail logs",
                    schedule: .interval(seconds: 30)),
            Service(id: "sched1", source: .claudeScheduledTask(durable: true),
                    kind: .scheduled, name: "Daily report",
                    schedule: .cron("0 9 * * *")),
            Service(id: "json1", source: .agentJobsJson, kind: .oneshot,
                    name: "Run nightly", schedule: .cron("0 2 * * *")),
            Service(id: "p1", source: .process(matched: "node"),
                    kind: .daemon, name: "node", command: "/usr/bin/node app.js",
                    pid: 4242),
        ]
    }
}
