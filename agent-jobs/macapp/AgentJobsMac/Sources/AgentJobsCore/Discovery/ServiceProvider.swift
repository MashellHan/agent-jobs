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

public enum ProviderError: Error, Sendable, Equatable {
    case unsupported(String)
    case invalidInput(String)
    case ioError(String)
    case timeout
}
