import EyesCareCore
import Foundation

final class MockIdleDetector: IdleDetecting, @unchecked Sendable {
    var idleSeconds: TimeInterval = 0

    func secondsSinceLastEvent() -> TimeInterval {
        idleSeconds
    }
}
