import XCTest
@testable import AgentJobsCore

final class AgentJobsJsonProviderTests: XCTestCase {

    func test_discover_returnsEmpty_whenFileMissing() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).json")
        let provider = AgentJobsJsonProvider(jobsPath: tmp)
        let services = try await provider.discover()
        XCTAssertEqual(services, [])
    }

    func test_discover_returnsEmpty_whenFileMalformed() async throws {
        let url = try writeFixture(contents: "{ this is not json")
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = AgentJobsJsonProvider(jobsPath: url)
        let services = try await provider.discover()
        XCTAssertEqual(services, [])
    }

    func test_discover_parsesValidJob() async throws {
        let json = """
        {"jobs":[{"id":"abc","name":"scanner","project":"foo","command":"node ./scan.js",
        "status":"running","pid":1234,"startedAt":"2026-04-19T12:00:00Z","schedule":"*/5 * * * *"}]}
        """
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = AgentJobsJsonProvider(jobsPath: url)
        let services = try await provider.discover()
        XCTAssertEqual(services.count, 1)
        let s = services[0]
        XCTAssertEqual(s.id, "agent-jobs:abc")
        XCTAssertEqual(s.status, .running)
        XCTAssertEqual(s.kind, .scheduled)
        XCTAssertEqual(s.pid, 1234)
        if case .cron(let expr) = s.schedule {
            XCTAssertEqual(expr, "*/5 * * * *")
        } else {
            XCTFail("expected cron schedule, got \(s.schedule)")
        }
    }

    func test_statusMapping_isLenient() async throws {
        let json = """
        {"jobs":[{"id":"a","name":"X","status":"COMPLETED"},
                 {"id":"b","name":"Y","status":"failed"},
                 {"id":"c","name":"Z","status":"weird-thing"}]}
        """
        let url = try writeFixture(contents: json)
        defer { try? FileManager.default.removeItem(at: url) }
        let services = try await AgentJobsJsonProvider(jobsPath: url).discover()
        XCTAssertEqual(services.map(\.status), [.done, .failed, .unknown])
    }

    private func writeFixture(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("jobs-\(UUID().uuidString).json")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
