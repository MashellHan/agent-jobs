import Testing
@testable import EyesCareCore

@Suite("ActivityState Tests")
struct ActivityStateTests {

    @Test("zero idle seconds returns active")
    func zeroIdleIsActive() {
        #expect(ActivityState.from(idleSeconds: 0) == .active)
    }

    @Test("29 seconds idle returns active (below threshold)")
    func belowThresholdIsActive() {
        #expect(ActivityState.from(idleSeconds: 29) == .active)
    }

    @Test("30 seconds idle returns idle (exactly at threshold)")
    func atIdleThresholdIsIdle() {
        #expect(ActivityState.from(idleSeconds: 30) == .idle)
    }

    @Test("60 seconds idle returns idle")
    func midRangeIsIdle() {
        #expect(ActivityState.from(idleSeconds: 60) == .idle)
    }

    @Test("119 seconds idle returns idle (just below away threshold)")
    func belowAwayThresholdIsIdle() {
        #expect(ActivityState.from(idleSeconds: 119) == .idle)
    }

    @Test("120 seconds idle returns away (exactly at natural break threshold)")
    func atNaturalBreakThresholdIsAway() {
        #expect(ActivityState.from(idleSeconds: 120) == .away)
    }

    @Test("500 seconds idle returns away")
    func wellAboveThresholdIsAway() {
        #expect(ActivityState.from(idleSeconds: 500) == .away)
    }

    @Test("custom thresholds work correctly")
    func customThresholds() {
        let state = ActivityState.from(
            idleSeconds: 10,
            idleThreshold: 5,
            naturalBreakThreshold: 15
        )
        #expect(state == .idle)
    }

    @Test("custom thresholds — below idle threshold")
    func customThresholdsBelowIdle() {
        let state = ActivityState.from(
            idleSeconds: 3,
            idleThreshold: 5,
            naturalBreakThreshold: 15
        )
        #expect(state == .active)
    }

    @Test("custom thresholds — at natural break threshold")
    func customThresholdsAtNaturalBreak() {
        let state = ActivityState.from(
            idleSeconds: 15,
            idleThreshold: 5,
            naturalBreakThreshold: 15
        )
        #expect(state == .away)
    }

    @Test("conforms to CaseIterable with 3 cases")
    func caseIterable() {
        #expect(ActivityState.allCases.count == 3)
        #expect(ActivityState.allCases.contains(.active))
        #expect(ActivityState.allCases.contains(.idle))
        #expect(ActivityState.allCases.contains(.away))
    }

    @Test("raw values are correct strings")
    func rawValues() {
        #expect(ActivityState.active.rawValue == "active")
        #expect(ActivityState.idle.rawValue == "idle")
        #expect(ActivityState.away.rawValue == "away")
    }
}
