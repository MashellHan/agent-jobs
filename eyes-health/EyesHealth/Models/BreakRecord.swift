import Foundation

struct BreakRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let durationSeconds: TimeInterval

    init(id: UUID = UUID(), timestamp: Date = .now, durationSeconds: TimeInterval = 0) {
        self.id = id
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}
