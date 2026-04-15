import Testing
@testable import EyesCareCore

@Suite("TimeFormatter Tests")
struct TimeFormatterTests {

    @Test(
        "formatActiveTime produces correct output",
        arguments: [
            (0.0, "< 1m"),
            (59.0, "< 1m"),
            (60.0, "1m"),
            (300.0, "5m"),
            (3660.0, "1h 1m"),
            (7200.0, "2h 0m"),
            (90000.0, "1d 1h"),
        ] as [(Double, String)]
    )
    func formatActiveTime(interval: Double, expected: String) {
        #expect(TimeFormatter.formatActiveTime(interval) == expected)
    }

    @Test("formatActiveTime with negative value returns dash")
    func formatActiveTimeNegative() {
        #expect(TimeFormatter.formatActiveTime(-1) == "—")
    }

    @Test("formatSinceLastBreak when not idle delegates to formatActiveTime")
    func formatSinceLastBreakNotIdle() {
        #expect(TimeFormatter.formatSinceLastBreak(300, isIdle: false) == "5m")
    }

    @Test("formatSinceLastBreak when idle returns resting")
    func formatSinceLastBreakIdle() {
        #expect(
            TimeFormatter.formatSinceLastBreak(300, isIdle: true) == "0m (resting)"
        )
    }

    @Test("pausedPlaceholder is em dash")
    func pausedPlaceholder() {
        #expect(TimeFormatter.pausedPlaceholder == "—")
    }
}
