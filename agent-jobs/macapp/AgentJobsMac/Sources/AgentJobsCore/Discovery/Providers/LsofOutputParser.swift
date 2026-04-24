import Foundation

/// Pure parser for `lsof -i -P -n -sTCP:LISTEN` output.
///
/// Parity with the legacy TS scanner (`src/scanner.ts:parseLsofOutput`):
///   - skip the header line (column titles)
///   - require ≥ 9 whitespace-split fields
///   - lower-case the COMMAND field, filter through `relevantCommands`
///   - dedup on PID (an IPv4 + IPv6 listener on the same process collapses
///     to one entry)
///   - parse the port from the last `:`-separated segment of field 8 (NAME)
///
/// No I/O, no subprocess — feed it a `String` and get `[Entry]` back. The
/// provider layer handles spawning `lsof`.
enum LsofOutputParser {

    struct Entry: Equatable, Sendable {
        let pid: Int32
        /// Lower-cased command from the COMMAND column.
        let command: String
        /// 0 when the port could not be parsed from the NAME column.
        let port: Int
    }

    /// Allow-list mirrored from TS `RELEVANT_CMDS`. Anything else is dropped.
    static let relevantCommands: Set<String> = [
        "node", "python", "python3", "go", "ruby", "java",
        "deno", "bun", "uvicorn", "gunicorn", "tsx"
    ]

    /// Parse the captured stdout of `lsof`. Tolerates leading/trailing
    /// whitespace, blank lines, and the conventional header line.
    static func parse(_ output: String) -> [Entry] {
        var seenPids: Set<Int32> = []
        var result: [Entry] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let cols = trimmed.split(whereSeparator: \.isWhitespace)
            // Need at least 9 fields: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
            if cols.count < 9 { continue }

            let cmd = cols[0].lowercased()
            // Header line: COMMAND first → drop.
            if cmd == "command" { continue }
            if !relevantCommands.contains(cmd) { continue }

            guard let pid = Int32(cols[1]) else { continue }
            if seenPids.contains(pid) { continue }
            seenPids.insert(pid)

            let port = parsePort(nameField: String(cols[8]))
            result.append(Entry(pid: pid, command: cmd, port: port))
        }
        return result
    }

    /// Extract the trailing port from a NAME column entry such as `*:3000`,
    /// `127.0.0.1:8080`, or `[::1]:5000`. Returns 0 when not parseable.
    private static func parsePort(nameField: String) -> Int {
        // Strip a trailing `(LISTEN)` token if it survived the split (it
        // shouldn't because of the whitespace, but defend anyway).
        let core = nameField.split(separator: " ").first.map(String.init) ?? nameField
        guard let lastColon = core.lastIndex(of: ":") else { return 0 }
        let portStr = core[core.index(after: lastColon)...]
        return Int(portStr) ?? 0
    }
}
