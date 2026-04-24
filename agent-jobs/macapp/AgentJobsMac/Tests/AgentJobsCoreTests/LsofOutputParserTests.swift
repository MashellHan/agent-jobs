import Testing
import Foundation
@testable import AgentJobsCore

@Suite("LsofOutputParser")
struct LsofOutputParserTests {

    @Test("empty input returns []")
    func emptyInput() {
        #expect(LsofOutputParser.parse("").isEmpty)
    }

    @Test("header-only input returns []")
    func headerOnly() throws {
        let header = try FixtureLoader.text("lsof.listen.empty", ext: "txt")
        #expect(LsofOutputParser.parse(header).isEmpty)
    }

    @Test("canonical 3-row output: bash filtered, returns 2")
    func canonicalThreeRows() throws {
        let raw = try FixtureLoader.text("lsof.listen.canonical", ext: "txt")
        let entries = LsofOutputParser.parse(raw)
        #expect(entries.count == 2)
        let cmds = entries.map(\.command).sorted()
        #expect(cmds == ["node", "python3"])
        #expect(entries.contains(where: { $0.pid == 1234 && $0.port == 3000 }))
        #expect(entries.contains(where: { $0.pid == 2222 && $0.port == 8000 }))
    }

    @Test("duplicate PID rows collapse to a single entry")
    func dupPidCollapses() throws {
        let raw = try FixtureLoader.text("lsof.listen.dup-pid", ext: "txt")
        let entries = LsofOutputParser.parse(raw)
        #expect(entries.count == 1)
        #expect(entries[0].pid == 1234)
    }

    @Test("malformed line (too few fields) is skipped")
    func malformedLineSkipped() {
        let raw = """
        COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
        node 99
        node     5555   alice   23u  IPv4  0xabc      0t0  TCP *:4000 (LISTEN)
        """
        let entries = LsofOutputParser.parse(raw)
        #expect(entries.count == 1)
        #expect(entries[0].pid == 5555)
    }

    @Test("missing/unparseable port → port == 0")
    func missingPort() {
        let raw = """
        COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
        node     7777   alice   23u  IPv4  0xabc      0t0  TCP weirdname (LISTEN)
        """
        let entries = LsofOutputParser.parse(raw)
        #expect(entries.count == 1)
        #expect(entries[0].port == 0)
    }

    @Test("non-relevant commands dropped")
    func nonRelevantDropped() {
        let raw = """
        COMMAND   PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
        sshd     11    root    3u   IPv4  0x1        0t0  TCP *:22 (LISTEN)
        nginx    12    root    6u   IPv4  0x2        0t0  TCP *:80 (LISTEN)
        """
        #expect(LsofOutputParser.parse(raw).isEmpty)
    }
}
