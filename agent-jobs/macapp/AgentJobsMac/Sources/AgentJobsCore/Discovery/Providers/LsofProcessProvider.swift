import Foundation
import os

/// Discovers live, locally-listening developer processes by parsing
/// `lsof -i -P -n -sTCP:LISTEN` and resolving each surviving PID's full
/// command line via `ps -p <pid> -o args=`.
///
/// Behavioral parity with the legacy TS scanner's `scanLiveProcesses`
/// (`src/scanner.ts`):
///   - allow-list of relevant commands (`node`, `python`, …) — see
///     `LsofOutputParser.relevantCommands`
///   - dedup on PID
///   - friendly name + agent inference per `LiveProcessNaming`
///
/// Failure model:
///   - The outer `lsof` call failing → the provider throws
///     `ProviderError.ioError` so the registry can isolate it.
///   - A per-PID `ps` failing is **swallowed** (full command becomes the
///     empty string). One bad `ps` must not poison the entire scan.
///
/// Concurrency: the per-PID `ps` fan-out is throttled by `AsyncSemaphore`
/// (default 8) so a machine with hundreds of listeners does not spawn
/// hundreds of subprocesses in parallel.
public struct LsofProcessProvider: ServiceProvider {
    public static let providerId = "lsof.process"
    public static let displayName = "Listening processes"
    public static let category = ServiceSource.Category.process

    public typealias LsofRunner = @Sendable () async throws -> String
    public typealias PsRunner   = @Sendable (Int32) async throws -> String

    private let lsofRunner: LsofRunner?
    private let psRunner: PsRunner?
    private let psConcurrency: Int
    private let logger = Logger(subsystem: "com.agentjobs.mac", category: "LsofProcessProvider")

    public init(
        lsofRunner: LsofRunner? = nil,
        psRunner: PsRunner? = nil,
        psConcurrency: Int = 8
    ) {
        precondition(psConcurrency > 0, "psConcurrency must be > 0")
        self.lsofRunner = lsofRunner
        self.psRunner = psRunner
        self.psConcurrency = psConcurrency
    }

    public func discover() async throws -> [Service] {
        let raw = try await runLsof()
        let entries = LsofOutputParser.parse(raw)
        if entries.isEmpty { return [] }
        let fullCmds = await resolveFullCommands(for: entries.map(\.pid))
        let services = entries
            .sorted { $0.pid < $1.pid }
            .map { entry in build(entry: entry, fullCmd: fullCmds[entry.pid] ?? "") }
        return services
    }

    // MARK: - Subprocess seams

    private func runLsof() async throws -> String {
        if let lsofRunner {
            do { return try await lsofRunner() } catch {
                throw ProviderError.ioError("lsof: \(error)")
            }
        }
        do {
            let result = try await Shell.run(
                "/usr/sbin/lsof",
                args: ["-i", "-P", "-n", "-sTCP:LISTEN"]
            )
            // lsof exits non-zero when nothing matches; that's fine — the
            // stdout is still authoritative. Only treat launch failures as
            // hard errors (those throw above).
            return result.stdout
        } catch let failure as Shell.Failure {
            throw ProviderError.ioError("lsof: \(failure)")
        } catch {
            throw ProviderError.ioError("lsof: \(error)")
        }
    }

    private func resolveFullCommands(for pids: [Int32]) async -> [Int32: String] {
        let semaphore = AsyncSemaphore(value: psConcurrency)
        let psRunner = self.psRunner
        return await withTaskGroup(of: (Int32, String).self) { group in
            for pid in pids {
                group.addTask {
                    await semaphore.wait()
                    let cmd = await Self.runPs(pid: pid, override: psRunner)
                    await semaphore.signal()
                    return (pid, cmd)
                }
            }
            var results: [Int32: String] = [:]
            for await (pid, cmd) in group { results[pid] = cmd }
            return results
        }
    }

    private static func runPs(pid: Int32, override: PsRunner?) async -> String {
        if let override {
            return (try? await override(pid)) ?? ""
        }
        do {
            let result = try await Shell.run(
                "/bin/ps",
                args: ["-p", "\(pid)", "-o", "args="]
            )
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    // MARK: - Service mapping

    private func build(entry: LsofOutputParser.Entry, fullCmd: String) -> Service {
        let agent = LiveProcessNaming.inferAgent(fullCommand: fullCmd)
        let name = LiveProcessNaming.friendlyName(
            command: entry.command,
            fullCommand: fullCmd,
            port: entry.port,
            agent: agent
        )
        let origin = agent.map { ServiceOrigin(agent: $0) }
        return Service(
            id: "lsof:\(entry.pid)",
            source: .process(matched: entry.command),
            kind: .interactive,
            name: name,
            command: fullCmd,
            schedule: .onDemand,
            status: .running,
            createdAt: nil,
            pid: entry.pid,
            owner: agent.map { .agent($0) } ?? .user,
            history: [],
            origin: origin
        )
    }
}
