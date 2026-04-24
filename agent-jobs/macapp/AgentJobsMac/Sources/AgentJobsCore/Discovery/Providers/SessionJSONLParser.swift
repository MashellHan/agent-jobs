import Foundation

/// Parsed cron task derived from a Claude session JSONL log.
/// Mirrors the TS `SessionCronTask` interface (src/scanner.ts:419-430).
public struct SessionCronTask: Equatable, Sendable {
    public let cronJobId: String
    public let cron: String
    public let prompt: String
    public let recurring: Bool
    public let durable: Bool
    public let timestamp: String
    public let sessionId: String
    public let cwd: String
    public let projectDir: String

    public init(
        cronJobId: String,
        cron: String,
        prompt: String,
        recurring: Bool,
        durable: Bool,
        timestamp: String,
        sessionId: String,
        cwd: String,
        projectDir: String
    ) {
        self.cronJobId = cronJobId
        self.cron = cron
        self.prompt = prompt
        self.recurring = recurring
        self.durable = durable
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.cwd = cwd
        self.projectDir = projectDir
    }
}

/// Pure streaming parser for a single Claude session JSONL file. Reads lines
/// from any `AsyncSequence<String>` and computes the net cron-task set.
///
/// Mirrors `parseSessionJsonl` in src/scanner.ts:454-535:
/// - fast pre-filter on the substrings `CronCreate` / `CronDelete` /
///   `tool_result` (the latter only when there are pending tool_uses).
/// - matches `CronCreate` `tool_use` entries to their `tool_result` by
///   `tool_use_id`; the cron job id comes from the result's `id` field.
/// - records `CronDelete` `tool_use.input.id` into a delete set.
/// - swallows malformed lines.
public enum SessionJSONLParser {

    public struct Output: Equatable, Sendable {
        public var creates: [String: SessionCronTask]
        public var deletes: Set<String>
        public init(creates: [String: SessionCronTask] = [:], deletes: Set<String> = []) {
            self.creates = creates
            self.deletes = deletes
        }
    }

    /// Parse an async stream of lines.
    public static func parse<S: AsyncSequence>(
        lines: S,
        projectDir: String
    ) async throws -> Output where S.Element == String {
        var state = ParseState()
        for try await line in lines {
            ingest(line: line, state: &state, projectDir: projectDir)
        }
        return Output(creates: state.creates, deletes: state.deletes)
    }

    /// Synchronous helper for unit tests / tiny in-memory inputs.
    public static func parse(text: String, projectDir: String) -> Output {
        var state = ParseState()
        text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" })
            .forEach { ingest(line: String($0), state: &state, projectDir: projectDir) }
        return Output(creates: state.creates, deletes: state.deletes)
    }

    // MARK: - internals

    private struct PendingToolUse {
        let cron: String
        let prompt: String
        let recurring: Bool
        let durable: Bool
    }

    private struct ParseState {
        var creates: [String: SessionCronTask] = [:]
        var deletes: Set<String> = []
        var pending: [String: PendingToolUse] = [:]
    }

    private static func ingest(line: String, state: inout ParseState, projectDir: String) {
        let hasCronOp = line.contains("CronCreate") || line.contains("CronDelete")
        let hasPending = !state.pending.isEmpty && line.contains("tool_result")
        if !hasCronOp && !hasPending { return }

        guard let data = line.data(using: .utf8),
              let any = try? JSONSerialization.jsonObject(with: data),
              let obj = any as? [String: Any]
        else { return }

        guard let msg = obj["message"] as? [String: Any],
              let content = msg["content"] as? [[String: Any]]
        else { return }

        for block in content {
            handleBlock(block, parent: obj, state: &state, projectDir: projectDir)
        }
    }

    private static func handleBlock(
        _ block: [String: Any],
        parent obj: [String: Any],
        state: inout ParseState,
        projectDir: String
    ) {
        let type = block["type"] as? String
        let name = block["name"] as? String

        if name == "CronCreate", type == "tool_use",
           let id = block["id"] as? String {
            let inp = block["input"] as? [String: Any] ?? [:]
            state.pending[id] = PendingToolUse(
                cron: inp["cron"] as? String ?? "",
                prompt: inp["prompt"] as? String ?? "",
                recurring: inp["recurring"] as? Bool ?? true,
                durable: inp["durable"] as? Bool ?? false
            )
        }

        if type == "tool_result",
           let toolUseResult = obj["toolUseResult"] as? [String: Any],
           toolUseResult["id"] != nil,
           let toolUseId = block["tool_use_id"] as? String,
           let pending = state.pending.removeValue(forKey: toolUseId),
           let cronJobId = toolUseResult["id"] as? String {
            let durable = (toolUseResult["durable"] as? Bool) ?? pending.durable
            let timestamp = (obj["timestamp"] as? String) ?? ""
            let sessionId = (obj["sessionId"] as? String) ?? ""
            let cwd = (obj["cwd"] as? String) ?? ""
            state.creates[cronJobId] = SessionCronTask(
                cronJobId: cronJobId,
                cron: pending.cron,
                prompt: pending.prompt,
                recurring: pending.recurring,
                durable: durable,
                timestamp: timestamp,
                sessionId: sessionId,
                cwd: cwd,
                projectDir: projectDir
            )
        }

        if name == "CronDelete", type == "tool_use" {
            let inp = block["input"] as? [String: Any] ?? [:]
            if let deleteId = inp["id"] as? String, !deleteId.isEmpty {
                state.deletes.insert(deleteId)
            }
        }
    }
}
