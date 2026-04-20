import Testing
import Foundation
@testable import AgentJobsCore

@Suite("AgentJobsJsonProvider")
struct AgentJobsJsonProviderTests {

    @Test func discover_returnsEmpty_whenFileMissing() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).json")
        let provider = AgentJobsJsonProvider(jobsPath: tmp)
        let services = try await provider.discover()
        #expect(services.isEmpty)
    }

    @Test func discover_returnsEmpty_whenFileMalformed() async throws {
        let url = try writeFixture(contents: "{ this is not json")
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        #expect(services.isEmpty)
    }

    @Test func discover_parsesValidJob() async throws {
        let json = """
        {"schemaVersion":1,"jobs":[{"id":"abc","name":"scanner","project":"foo","command":"node ./scan.js",
        "status":"running","pid":1234,"createdAt":"2026-04-19T11:55:00Z",
        "startedAt":"2026-04-19T12:00:00Z","schedule":"*/5 * * * *","origin":"claude-session"}]}
        """
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        try #require(services.count == 1)
        let s = services[0]
        #expect(s.id == "agent-jobs:abc")
        #expect(s.status == .running)
        #expect(s.kind == .scheduled)
        #expect(s.pid == 1234)
        #expect(s.command == "node ./scan.js")
        #expect(s.origin != nil)
        if case .cron(let expr) = s.schedule {
            #expect(expr == "*/5 * * * *")
        } else {
            Issue.record("expected cron schedule, got \(s.schedule)")
        }
    }

    @Test func statusMapping_isLenient() async throws {
        let json = """
        {"jobs":[{"id":"a","name":"X","status":"COMPLETED"},
                 {"id":"b","name":"Y","status":"failed"},
                 {"id":"c","name":"Z","status":"weird-thing"}]}
        """
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        #expect(services.map(\.status) == [.done, .failed, .unknown])
    }

    @Test func commandIsEmptyString_whenSourceOmitsIt() async throws {
        let json = #"{"jobs":[{"id":"x","name":"y","status":"running"}]}"#
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        #expect(services.first?.command == "")
    }

    @Test func createdAt_fallbackChain() async throws {
        let json = """
        {"jobs":[
          {"id":"a","name":"A","status":"running","createdAt":"2026-04-19T10:00:00Z"},
          {"id":"b","name":"B","status":"running","startedAt":"2026-04-19T11:00:00Z"},
          {"id":"c","name":"C","status":"running"}
        ]}
        """
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        // AgentJobsJsonProvider always synthesizes a non-nil createdAt
        // (createdAt ?? startedAt ?? Date()), so unwrap is safe here.
        // M-006 made the field optional at the Domain layer for sources
        // (e.g. launchd) that genuinely lack a registration time.
        #expect(abs(services[0].createdAt!.timeIntervalSince1970 - 1776592800) < 1)
        #expect(abs(services[1].createdAt!.timeIntervalSince1970 - 1776596400) < 1)
        #expect(abs(services[2].createdAt!.timeIntervalSinceNow) < 5)
    }

    private func writeFixture(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("jobs-\(UUID().uuidString).json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
