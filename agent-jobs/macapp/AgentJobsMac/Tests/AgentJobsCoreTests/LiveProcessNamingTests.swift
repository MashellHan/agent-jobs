import Testing
import Foundation
@testable import AgentJobsCore

@Suite("LiveProcessNaming.inferAgent")
struct LiveProcessNamingInferAgentTests {

    @Test("claude substring → .claude")
    func claudeMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "node /usr/local/bin/claude code") == .claude)
    }

    @Test("cursor substring → .custom('cursor')")
    func cursorMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "/Applications/Cursor.app/foo") == .custom("cursor"))
    }

    @Test("copilot substring → .custom('github-copilot')")
    func copilotMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "node copilot-server.js") == .custom("github-copilot"))
    }

    @Test("openclaw substring → .openclaw")
    func openclawMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "openclaw gateway") == .openclaw)
    }

    @Test("claw substring → .openclaw")
    func clawAliasMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "/usr/bin/claw daemon") == .openclaw)
    }

    @Test("no match → nil (TS manual)")
    func noMatch() {
        #expect(LiveProcessNaming.inferAgent(fullCommand: "node server.js") == nil)
    }
}

@Suite("LiveProcessNaming.friendlyName")
struct LiveProcessNamingFriendlyNameTests {

    @Test("script arg surfaces as filename + port")
    func scriptArg() {
        let n = LiveProcessNaming.friendlyName(
            command: "node",
            fullCommand: "node /Users/me/app/server.js",
            port: 3000,
            agent: nil
        )
        #expect(n == "server.js :3000")
    }

    @Test("generic script + agent → skip filename, prefer agent name")
    func genericScriptWithAgentSkipped() {
        let n = LiveProcessNaming.friendlyName(
            command: "node",
            fullCommand: "claude /opt/claude/entry.js",
            port: 4000,
            agent: .claude
        )
        // entry.js is generic and an agent is detected → fall through to
        // the agent-fallback branch.
        #expect(n == "claude :4000")
    }

    @Test("framework match: vite")
    func framework() {
        let n = LiveProcessNaming.friendlyName(
            command: "node",
            fullCommand: "node /usr/bin/vite --port 5173",
            port: 5173,
            agent: nil
        )
        #expect(n == "vite :5173")
    }

    @Test("framework token match is anchored: 'openssl-nextstep' is NOT 'next'")
    func frameworkTokenAnchored() {
        // Pre-fix this would label as `next :0` because `cmdLower.contains("next")`
        // matches the substring inside `openssl-nextstep`. Post-fix it must
        // fall through to the plain-command branch.
        let n = LiveProcessNaming.friendlyName(
            command: "node",
            fullCommand: "node /opt/openssl-nextstep/server",
            port: 0,
            agent: nil
        )
        #expect(n != "next")
        #expect(n != "next :0")
        #expect(n == "node")
    }

    @Test("agent fallback with subcommand → label-subcommand")
    func agentSubcommand() {
        let n = LiveProcessNaming.friendlyName(
            command: "openclaw",
            fullCommand: "openclaw gateway --listen 7000",
            port: 7000,
            agent: .openclaw
        )
        #expect(n == "openclaw-gateway :7000")
    }

    @Test("plain command + port when nothing matches")
    func plainFallback() {
        let n = LiveProcessNaming.friendlyName(
            command: "deno",
            fullCommand: "deno",
            port: 8080,
            agent: nil
        )
        #expect(n == "deno :8080")
    }

    @Test("port == 0 omits ' :<port>' suffix")
    func noPortSuffix() {
        let n = LiveProcessNaming.friendlyName(
            command: "deno",
            fullCommand: "deno",
            port: 0,
            agent: nil
        )
        #expect(n == "deno")
    }

    @Test("agent-only fallback (no subcommand) yields plain agent label")
    func agentOnlyNoSub() {
        let n = LiveProcessNaming.friendlyName(
            command: "node",
            fullCommand: "claude",
            port: 1234,
            agent: .claude
        )
        #expect(n == "claude :1234")
    }
}
