import Testing
import Foundation
@testable import AgentJobsCore

@Suite("LsofProcessProvider")
struct LsofProcessProviderTests {

    @Test("empty lsof output → []")
    func emptyOutput() async throws {
        let p = LsofProcessProvider(
            lsofRunner: { "" },
            psRunner: { _ in "" }
        )
        let services = try await p.discover()
        #expect(services.isEmpty)
    }

    @Test("lsof failure → throws ProviderError.ioError")
    func lsofFailureThrows() async {
        struct Boom: Error {}
        let p = LsofProcessProvider(
            lsofRunner: { throw Boom() },
            psRunner: { _ in "" }
        )
        do {
            _ = try await p.discover()
            Issue.record("expected throw")
        } catch let e as ProviderError {
            if case .ioError = e { /* ok */ } else {
                Issue.record("expected .ioError, got \(e)")
            }
        } catch {
            Issue.record("expected ProviderError, got \(error)")
        }
    }

    @Test("ps failure for one PID → service still surfaces with empty fullCmd")
    func psFailureSwallowed() async throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { pid in
                if pid == 1234 { throw NSError(domain: "ps", code: 1) }
                return "python3 -m http.server 8000"
            }
        )
        let services = try await p.discover()
        #expect(services.count == 2)
        let nodeSvc = services.first { $0.pid == 1234 }
        #expect(nodeSvc != nil)
        #expect(nodeSvc?.command == "")
    }

    @Test("services are deterministically sorted by PID")
    func deterministicOrder() async throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { _ in "fake" }
        )
        let services = try await p.discover()
        let pids = services.compactMap { $0.pid }
        #expect(pids == pids.sorted())
    }

    @Test("Service id format is 'lsof:<pid>'; kind/source/status correct")
    func serviceShape() async throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { _ in "node /opt/app/server.js" }
        )
        let services = try await p.discover()
        for svc in services {
            #expect(svc.id.hasPrefix("lsof:"))
            #expect(svc.kind == .interactive)
            #expect(svc.status == .running)
            if case .process(let matched) = svc.source {
                #expect(["node", "python3"].contains(matched))
            } else {
                Issue.record("expected .process source, got \(svc.source)")
            }
        }
    }

    @Test("name carries ' :<port>' when port > 0")
    func nameContainsPort() async throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { _ in "node /opt/app/server.js" }
        )
        let services = try await p.discover()
        let nodeSvc = services.first { $0.pid == 1234 }
        #expect(nodeSvc?.name.contains(":3000") == true)
    }

    @Test("agent inferred → owner is .agent(.claude) and origin set")
    func agentInferenceWiredIntoService() async throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { pid in pid == 1234 ? "claude code /opt/app/server.js" : "python3" }
        )
        let services = try await p.discover()
        let nodeSvc = services.first { $0.pid == 1234 }
        #expect(nodeSvc?.origin?.agent == .claude)
        if case .agent(let kind) = nodeSvc?.owner {
            #expect(kind == .claude)
        } else {
            Issue.record("expected owner .agent(.claude)")
        }
    }

    @Test("ps concurrency cap: 200 PIDs, max in-flight ≤ 8")
    func concurrencyCap() async throws {
        // Build 200 unique-PID rows.
        var lines = ["COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME"]
        for i in 0..<200 {
            let pid = 10_000 + i
            let port = 20_000 + i
            lines.append("node     \(pid)   alice   23u  IPv4  0xabc      0t0  TCP *:\(port) (LISTEN)")
        }
        let raw = lines.joined(separator: "\n")

        actor Counter {
            private(set) var current = 0
            private(set) var highWater = 0
            func enter() {
                current += 1
                if current > highWater { highWater = current }
            }
            func leave() { current -= 1 }
        }
        let counter = Counter()

        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { _ in
                await counter.enter()
                try? await Task.sleep(for: .milliseconds(2))
                await counter.leave()
                return "node server.js"
            },
            psConcurrency: 8
        )
        let services = try await p.discover()
        #expect(services.count == 200)
        let high = await counter.highWater
        #expect(high <= 8)
        #expect(high > 0)
    }

    // MARK: - M01 T10 perf gate (AC-P-03)

    @Test("AC-P-03: 200 PIDs through stubbed lsof + ps complete in < 500 ms")
    func perfP03_200Pids() async throws {
        // Skip on CI where measurement is noisy.
        if ProcessInfo.processInfo.environment["AGENTJOBS_SKIP_PERF"] != nil {
            return
        }
        var lines = ["COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME"]
        for i in 0..<200 {
            let pid = 30_000 + i
            let port = 40_000 + i
            lines.append("node     \(pid)   alice   23u  IPv4  0xabc      0t0  TCP *:\(port) (LISTEN)")
        }
        let raw = lines.joined(separator: "\n")

        let p = LsofProcessProvider(
            lsofRunner: { raw },
            psRunner: { _ in "" },
            psConcurrency: 8
        )

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            _ = try await p.discover()
        }
        // 500 ms hard cap from AC-P-03.
        #expect(elapsed < .milliseconds(500))
    }
}
