import Foundation

/// Pure naming/inference helpers for live (lsof-discovered) processes.
///
/// Mirrors the legacy TS scanner (`src/scanner.ts:inferAgent` and
/// `friendlyLiveName`) closely enough that the same input produces the
/// same user-visible name. Documented divergences:
///
/// - TS returns string `"manual"` for "no agent". Swift returns `nil` —
///   the registry/UI represents that as an absent `ServiceOrigin`.
/// - TS uses string agent ids; Swift maps them to typed `AgentKind`.
///   `cursor` and `github-copilot` have no dedicated enum case in M01,
///   so they ride on `AgentKind.custom(_:)` (avoids public-API growth).
/// - The agent-fallback regex (TS line 117) extracts the first
///   word-token after the agent binary; Swift replicates the *intent*
///   without trying to match the regex byte-for-byte.
enum LiveProcessNaming {

    /// Generic entry-point script names that should be ignored when an
    /// agent has been detected (so `claude … entry.js :3000` doesn't
    /// surface as `entry.js :3000` instead of the more useful
    /// `claude :3000`).
    private static let genericScripts: Set<String> = [
        "entry.js", "index.js", "main.js",
        "entry.mjs", "index.mjs", "main.mjs"
    ]

    /// Frameworks worth surfacing by name when no script arg is found.
    private static let frameworks: [String] = [
        "next", "nuxt", "vite", "uvicorn", "gunicorn", "flask", "fastapi"
    ]

    /// Maps a full command line to an `AgentKind` per the legacy TS rules.
    /// Returns `nil` when no agent can be inferred (TS `manual`).
    static func inferAgent(fullCommand: String) -> AgentKind? {
        let lower = fullCommand.lowercased()
        if lower.contains("claude")  { return .claude }
        if lower.contains("cursor")  { return .custom("cursor") }
        if lower.contains("copilot") { return .custom("github-copilot") }
        if lower.contains("openclaw") || lower.contains("claw") { return .openclaw }
        return nil
    }

    /// Build a friendly user-facing label for a live process. Output form
    /// is `"<name> :<port>"` when `port > 0`, else `"<name>"`.
    static func friendlyName(
        command: String,
        fullCommand: String,
        port: Int,
        agent: AgentKind?
    ) -> String {
        let parts = fullCommand
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        // 1) Look for a script argument like server.js / app.py.
        if let scriptArg = parts.first(where: { isScriptArg($0) }) {
            let filename = scriptArg.split(separator: "/").last.map(String.init) ?? scriptArg
            let isGeneric = genericScripts.contains(filename.lowercased())
            // Skip generic scripts only when an agent was detected.
            if !(agent != nil && isGeneric) {
                return formatWithPort(filename, port: port)
            }
        }

        // 2) Known frameworks. Match on whole tokens (or token basenames)
        //    rather than raw substring so e.g. `node /opt/openssl-nextstep`
        //    no longer mislabels as `next`.
        let cmdLower = fullCommand.lowercased()
        let tokenBasenames: [String] = cmdLower
            .split(whereSeparator: \.isWhitespace)
            .map { tok -> String in
                String(tok.split(separator: "/").last ?? tok)
            }
        for fw in frameworks where tokenBasenames.contains(fw) {
            return formatWithPort(fw, port: port)
        }

        // 3) Agent fallback: try to extract the first sub-command token after
        //    the agent name, e.g. `openclaw gateway` → "openclaw-gateway".
        if let agent {
            let label = agentLabel(for: agent)
            if let suffix = subcommand(after: label, in: cmdLower) {
                return formatWithPort("\(label)-\(suffix)", port: port)
            }
            return formatWithPort(label, port: port)
        }

        // 4) Plain command + port.
        return formatWithPort(command, port: port)
    }

    // MARK: - Helpers

    private static func isScriptArg(_ token: String) -> Bool {
        guard !token.hasPrefix("-") else { return false }
        let lower = token.lowercased()
        for ext in [".js", ".mjs", ".ts", ".jsx", ".tsx", ".py", ".rb", ".go"] {
            if lower.hasSuffix(ext) { return true }
        }
        return false
    }

    private static func formatWithPort(_ name: String, port: Int) -> String {
        port > 0 ? "\(name) :\(port)" : name
    }

    private static func agentLabel(for agent: AgentKind) -> String {
        switch agent {
        case .claude:           return "claude"
        case .codex:            return "codex"
        case .openclaw:         return "openclaw"
        case .custom(let s):    return s
        }
    }

    /// Find the first whitespace-delimited word that appears immediately
    /// after a token containing `label` in `cmdLower`. Returns `nil` when
    /// no such follow-up token exists.
    private static func subcommand(after label: String, in cmdLower: String) -> String? {
        let tokens = cmdLower
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        for (idx, tok) in tokens.enumerated() {
            if tok.contains(label), idx + 1 < tokens.count {
                let next = tokens[idx + 1]
                // First sub-token must look like a word (no leading dash, no path).
                if !next.hasPrefix("-"), !next.contains("/"), !next.isEmpty {
                    return next
                }
                return nil
            }
        }
        return nil
    }
}
