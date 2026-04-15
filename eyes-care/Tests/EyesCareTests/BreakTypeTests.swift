import Testing
@testable import EyesCareCore

@Suite("BreakType Tests")
struct BreakTypeTests {

    @Test("micro break interval is 20 minutes (1200 seconds)")
    func microInterval() {
        #expect(BreakType.micro.interval == 1200)
    }

    @Test("micro break duration is 20 seconds")
    func microDuration() {
        #expect(BreakType.micro.duration == 20)
    }

    @Test("macro break interval is 60 minutes (3600 seconds)")
    func macroInterval() {
        #expect(BreakType.macro.interval == 3600)
    }

    @Test("macro break duration is 5 minutes (300 seconds)")
    func macroDuration() {
        #expect(BreakType.macro.duration == 300)
    }

    @Test("mandatory break interval is 120 minutes (7200 seconds)")
    func mandatoryInterval() {
        #expect(BreakType.mandatory.interval == 7200)
    }

    @Test("mandatory break duration is 15 minutes (900 seconds)")
    func mandatoryDuration() {
        #expect(BreakType.mandatory.duration == 900)
    }

    @Test("display names are non-empty")
    func displayNames() {
        for breakType in [BreakType.micro, .macro, .mandatory] {
            #expect(!breakType.displayName.isEmpty)
        }
    }

    @Test("medical sources are non-empty")
    func medicalSources() {
        for breakType in [BreakType.micro, .macro, .mandatory] {
            #expect(!breakType.medicalSource.isEmpty)
        }
    }
}
