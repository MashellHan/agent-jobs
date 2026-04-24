import Testing
import Foundation
@testable import AgentJobsCore

@Suite("CronTaskDeduper")
struct CronTaskDeduperTests {

    private static func task(
        cron: String, prompt: String, id: String = UUID().uuidString
    ) -> SessionCronTask {
        SessionCronTask(
            cronJobId: id, cron: cron, prompt: prompt,
            recurring: true, durable: false,
            timestamp: "2026-04-23T00:00:00Z",
            sessionId: "sess",
            cwd: "/tmp", projectDir: "tmp"
        )
    }

    @Test("empty durable list returns input unchanged")
    func emptyDurable() {
        let a = Self.task(cron: "0 9 * * *", prompt: "hello")
        let out = CronTaskDeduper.dedup(sessionCreates: [a], durable: [])
        #expect(out.count == 1)
        #expect(out[0].cronJobId == a.cronJobId)
    }

    @Test("exact (cron, prompt) match drops session entry")
    func exactMatch() {
        let a = Self.task(cron: "0 9 * * *", prompt: "summarize")
        let out = CronTaskDeduper.dedup(
            sessionCreates: [a],
            durable: [.init(cron: "0 9 * * *", prompt: "summarize")]
        )
        #expect(out.isEmpty)
    }

    @Test("dedup uses prompt prefix of 50 chars only")
    func prefix50Match() {
        let longPrompt = String(repeating: "x", count: 200)
        let alternatePrompt = String(repeating: "x", count: 50) + " DIFFERENT TAIL"
        let a = Self.task(cron: "* * * * *", prompt: longPrompt)
        // Only the first 50 chars are compared → these collide.
        let out = CronTaskDeduper.dedup(
            sessionCreates: [a],
            durable: [.init(cron: "* * * * *", prompt: alternatePrompt)]
        )
        #expect(out.isEmpty)
    }

    @Test("different cron with same prompt is NOT deduped")
    func differentCronKept() {
        let a = Self.task(cron: "0 9 * * *", prompt: "hi")
        let out = CronTaskDeduper.dedup(
            sessionCreates: [a],
            durable: [.init(cron: "0 10 * * *", prompt: "hi")]
        )
        #expect(out.count == 1)
    }

    @Test("preserves order of surviving entries")
    func preservesOrder() {
        let a = Self.task(cron: "1 * * * *", prompt: "a", id: "id-a")
        let b = Self.task(cron: "2 * * * *", prompt: "b", id: "id-b") // dropped
        let c = Self.task(cron: "3 * * * *", prompt: "c", id: "id-c")
        let out = CronTaskDeduper.dedup(
            sessionCreates: [a, b, c],
            durable: [.init(cron: "2 * * * *", prompt: "b")]
        )
        #expect(out.map(\.cronJobId) == ["id-a", "id-c"])
    }

    @Test("key() helpers return matching strings for equivalent inputs")
    func keyHelpersAgree() {
        let t = Self.task(cron: "0 0 * * *", prompt: "p")
        let d = CronTaskDeduper.DurableKey(cron: "0 0 * * *", prompt: "p")
        #expect(CronTaskDeduper.key(for: t) == CronTaskDeduper.key(d))
    }

    @Test("prompt under 50 chars is compared in full")
    func shortPromptFullCompare() {
        let a = Self.task(cron: "5 * * * *", prompt: "abc")
        let out = CronTaskDeduper.dedup(
            sessionCreates: [a],
            durable: [.init(cron: "5 * * * *", prompt: "abd")]
        )
        #expect(out.count == 1) // not collided
    }
}
