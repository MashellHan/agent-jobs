import Testing
import Foundation
@testable import AgentJobsCore

@Suite("Shell")
struct ShellTests {

    @Test("/usr/bin/true returns 0 with empty output")
    func runTrue() async throws {
        let result = try await Shell.run("/usr/bin/true", args: [])
        #expect(result.exitCode == 0)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.isEmpty)
        #expect(result.succeeded)
    }

    @Test("/bin/echo emits argv joined by space")
    func runEcho() async throws {
        let result = try await Shell.run("/bin/echo", args: ["hello", "world"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello world")
    }

    @Test("argv with spaces is preserved as one entry, not shell-parsed")
    func argvNotShellParsed() async throws {
        // If we were going through a shell, "a b" would split into two argv.
        // Through Shell.run it stays one arg → echo prints it intact.
        let result = try await Shell.run("/bin/echo", args: ["a b"])
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "a b")
    }

    @Test("/usr/bin/false returns nonzero")
    func runFalse() async throws {
        let result = try await Shell.run("/usr/bin/false", args: [])
        #expect(result.exitCode != 0)
        #expect(!result.succeeded)
    }

    @Test("timeout fires before slow process exits")
    func timeoutFires() async throws {
        do {
            _ = try await Shell.run("/bin/sleep", args: ["10"], timeout: 0.3)
            Issue.record("expected timeout")
        } catch let Shell.Failure.timeout(seconds) {
            #expect(seconds == 0.3)
        }
    }
}
