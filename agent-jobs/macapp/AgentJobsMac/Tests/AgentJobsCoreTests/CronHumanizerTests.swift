import Testing
import Foundation
@testable import AgentJobsCore

@Suite("CronHumanizer")
struct CronHumanizerTests {

    @Test("every-N-minutes pattern")
    func everyNMinutes() {
        #expect(CronHumanizer.humanize("*/5 * * * *") == "every 5 minutes")
        #expect(CronHumanizer.humanize("*/1 * * * *") == "every 1 minute")
    }

    @Test("hourly pattern")
    func hourly() {
        #expect(CronHumanizer.humanize("0 * * * *") == "every hour")
        #expect(CronHumanizer.humanize("15 * * * *") == "hourly at :15")
    }

    @Test("every-N-hours pattern")
    func everyNHours() {
        #expect(CronHumanizer.humanize("0 */3 * * *") == "every 3 hours")
    }

    @Test("daily at time")
    func dailyAt() {
        #expect(CronHumanizer.humanize("0 9 * * *") == "daily at 9am")
        #expect(CronHumanizer.humanize("30 14 * * *") == "daily at 2:30pm")
        #expect(CronHumanizer.humanize("0 0 * * *") == "daily at 12am")
    }

    @Test("weekdays at time")
    func weekdaysAt() {
        #expect(CronHumanizer.humanize("0 9 * * 1-5") == "weekdays at 9am")
    }

    @Test("specific weekday")
    func specificWeekday() {
        #expect(CronHumanizer.humanize("0 10 * * 1") == "every Monday at 10am")
    }

    @Test("monthly day")
    func monthly() {
        #expect(CronHumanizer.humanize("0 0 1 * *") == "monthly on the 1st at 12am")
        #expect(CronHumanizer.humanize("0 0 22 * *") == "monthly on the 22nd at 12am")
    }

    @Test("falls back to raw expression when unrecognized")
    func fallback() {
        #expect(CronHumanizer.humanize("5,15,25 * * * *") == "cron: 5,15,25 * * * *")
        #expect(CronHumanizer.humanize("not a cron") == "cron: not a cron")
    }
}
