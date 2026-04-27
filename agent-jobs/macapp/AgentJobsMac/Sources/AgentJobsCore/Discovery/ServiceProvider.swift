import Foundation

public enum ServiceAction: String, Sendable, Hashable {
    case start
    case stop
    case restart
    case runNow
    case enable
    case disable
    case delete
}

public struct ServiceEvent: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case added, updated, removed, statusChanged
    }
    public let kind: Kind
    public let serviceId: String
    public let at: Date

    public init(kind: Kind, serviceId: String, at: Date = Date()) {
        self.kind = kind
        self.serviceId = serviceId
        self.at = at
    }
}

public protocol ServiceProvider: Sendable {
    static var providerId: String { get }
    static var displayName: String { get }
    static var category: ServiceSource.Category { get }

    func discover() async throws -> [Service]
    func watch() -> AsyncStream<ServiceEvent>?
    func control(_ action: ServiceAction, on service: Service) async throws
}

public extension ServiceProvider {
    func watch() -> AsyncStream<ServiceEvent>? { nil }
    func control(_ action: ServiceAction, on service: Service) async throws {
        throw ProviderError.unsupported("\(Self.providerId) does not support control")
    }
}

/// Internal-only marker for providers that record per-file failures or
/// transient I/O errors during `discover()`. Surfaced by
/// `ServiceRegistry.discoverAllDetailed()` as `[ProviderHealth]` so the
/// view model can render bucket-chip tooltips. Closes T-004.
///
/// M06 / WL-3 (AC-F-18): kept internal so `ProviderDiagnostics` stays out
/// of the public ABI — only `ProviderHealth` is exported. Pure providers
/// that already throw on failure simply don't conform.
internal protocol DiagnosticsBearing {
    var diagnostics: ProviderDiagnostics? { get }
}

public enum ProviderError: Error, Sendable, Equatable, Hashable {
    case unsupported(String)
    case invalidInput(String)
    case ioError(String)
    case timeout
}

/// Per-provider health snapshot reported alongside discovery results.
/// Surfaced by the view model in source-bucket-chip tooltips so the user
/// can tell "0 because nothing scheduled" from "0 because the provider
/// failed". Closes T-004.
public struct ProviderHealth: Sendable, Hashable {
    public let providerId: String
    public let lastError: ProviderError?
    public let lastSuccessAt: Date?
    /// Optional per-file failure breakdown (filename → short error string).
    /// Empty when the provider doesn't track this granularity.
    public let perFileFailures: [String: String]

    public init(
        providerId: String,
        lastError: ProviderError? = nil,
        lastSuccessAt: Date? = nil,
        perFileFailures: [String: String] = [:]
    ) {
        self.providerId = providerId
        self.lastError = lastError
        self.lastSuccessAt = lastSuccessAt
        self.perFileFailures = perFileFailures
    }
}

/// Internal mutable diagnostics box for non-actor providers (struct
/// providers stay struct so existing call sites don't need to suspend just
/// to read). Each provider owns one instance and writes to it during
/// `discover()`. Snapshotted into `ProviderHealth` when the registry
/// collects results.
///
/// M06 / WL-3 (AC-F-18): demoted to internal so the type stops appearing
/// in the published symbol graph. Tests reach it via `@testable import`.
internal actor ProviderDiagnostics {
    internal private(set) var lastError: ProviderError?
    internal private(set) var lastSuccessAt: Date?
    internal private(set) var perFileFailures: [String: String] = [:]

    internal init() {}

    internal func recordSuccess(at date: Date) {
        lastError = nil
        lastSuccessAt = date
        perFileFailures.removeAll()
    }

    internal func recordFileFailure(_ filename: String, _ description: String) {
        perFileFailures[filename] = description
        lastError = .ioError("\(perFileFailures.count) source file(s) failed to parse")
    }

    internal func recordIOError(_ description: String) {
        lastError = .ioError(description)
    }

    internal func snapshot() -> (ProviderError?, Date?, [String: String]) {
        (lastError, lastSuccessAt, perFileFailures)
    }
}
