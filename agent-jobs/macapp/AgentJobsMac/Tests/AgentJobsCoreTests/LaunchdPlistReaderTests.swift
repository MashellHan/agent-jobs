import Testing
import Foundation
@testable import AgentJobsCore

/// Unit tests for `LaunchdPlistReader` — the bit that promotes
/// `launchctl list` rows from "name + PID" into "name + command + real
/// schedule". Closes strict L-007 / L-008.
@Suite("LaunchdPlistReader")
struct LaunchdPlistReaderTests {

    // MARK: - parse() (no FS)

    @Test("ProgramArguments → joined command string")
    func programArgumentsBecomeCommand() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key><string>com.example.runner</string>
          <key>ProgramArguments</key>
          <array>
            <string>/usr/local/bin/runner</string>
            <string>--config</string>
            <string>/etc/runner.toml</string>
          </array>
        </dict>
        </plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        #expect(e.command == "/usr/local/bin/runner --config /etc/runner.toml")
        #expect(e.schedule == nil)
        #expect(e.isScheduled == false)
    }

    @Test("Program (string) becomes command when no ProgramArguments")
    func programStringFallback() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>Program</key><string>/opt/foo/bin/foo</string>
        </dict></plist>
        """
        #expect(LaunchdPlistReader.parse(Data(xml.utf8)).command == "/opt/foo/bin/foo")
    }

    @Test("StartInterval → .interval(seconds:)")
    func startIntervalToSchedule() {
        let xml = """
        <plist version="1.0"><dict>
          <key>StartInterval</key><integer>3600</integer>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        #expect(e.schedule == .interval(seconds: 3600))
        #expect(e.isScheduled == true)
    }

    @Test("StartCalendarInterval (single dict) → .calendar with one entry")
    func calendarSingleDict() {
        let xml = """
        <plist version="1.0"><dict>
          <key>StartCalendarInterval</key>
          <dict>
            <key>Hour</key><integer>9</integer>
            <key>Minute</key><integer>0</integer>
          </dict>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        guard case .calendar(let comps) = e.schedule else {
            Issue.record("expected .calendar, got \(String(describing: e.schedule))")
            return
        }
        #expect(comps.count == 1)
        #expect(comps[0].hour == 9)
        #expect(comps[0].minute == 0)
        #expect(e.isScheduled == true)
    }

    @Test("StartCalendarInterval (array of dicts) → .calendar with N entries")
    func calendarArrayOfDicts() {
        let xml = """
        <plist version="1.0"><dict>
          <key>StartCalendarInterval</key>
          <array>
            <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
            <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>30</integer></dict>
          </array>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        guard case .calendar(let comps) = e.schedule else {
            Issue.record("expected .calendar")
            return
        }
        #expect(comps.count == 2)
        #expect(comps[0].hour == 9 && comps[1].hour == 17)
    }

    @Test("Weekday is translated from launchd (Sun=0) to Cocoa (Sun=1)")
    func weekdayTranslation() {
        let xml = """
        <plist version="1.0"><dict>
          <key>StartCalendarInterval</key>
          <dict>
            <key>Weekday</key><integer>1</integer>
            <key>Hour</key><integer>3</integer>
          </dict>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        guard case .calendar(let comps) = e.schedule else {
            Issue.record("expected .calendar"); return
        }
        // launchd Weekday=1 (Mon) → Cocoa weekday=2
        #expect(comps[0].weekday == 2)
    }

    @Test("WatchPaths only → .eventTrigger('watch'), isScheduled=true")
    func watchPathsBecomeEventTrigger() {
        let xml = """
        <plist version="1.0"><dict>
          <key>WatchPaths</key>
          <array><string>/etc/foo</string></array>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        if case .eventTrigger(let t) = e.schedule {
            #expect(t == "watch")
        } else {
            Issue.record("expected .eventTrigger")
        }
        #expect(e.isScheduled == true)
    }

    @Test("malformed plist returns .empty (does not throw)")
    func malformedPlistTolerated() {
        let e = LaunchdPlistReader.parse(Data("not a plist".utf8))
        #expect(e.command == nil)
        #expect(e.schedule == nil)
        #expect(e.isScheduled == false)
    }

    @Test("plist with no recognized keys → .empty")
    func unrelatedPlistEmpty() {
        let xml = """
        <plist version="1.0"><dict>
          <key>Label</key><string>com.example.bare</string>
        </dict></plist>
        """
        let e = LaunchdPlistReader.parse(Data(xml.utf8))
        #expect(e.command == nil)
        #expect(e.schedule == nil)
        #expect(e.isScheduled == false)
    }

    // MARK: - enrich() with injected loader

    @Test("enrich() returns .empty when loader has no plist for label")
    func enrichMissingFile() {
        let reader = LaunchdPlistReader(loader: { _ in nil })
        let e = reader.enrich(label: "com.example.unknown")
        #expect(e.command == nil)
        #expect(e.schedule == nil)
    }

    @Test("LaunchdUserProvider.parse with reader enriches command + schedule")
    func providerParseUsesEnrichment() {
        let xml = """
        <plist version="1.0"><dict>
          <key>ProgramArguments</key>
          <array><string>/bin/sh</string><string>-c</string><string>echo hi</string></array>
          <key>StartInterval</key><integer>60</integer>
        </dict></plist>
        """
        let reader = LaunchdPlistReader(loader: { label in
            label == "com.example.tick" ? Data(xml.utf8) : nil
        })
        let raw = """
        PID	Status	Label
        -	0	com.example.tick
        """
        let services = LaunchdUserProvider.parse(raw, enrichWith: reader)
        #expect(services.count == 1)
        #expect(services[0].command == "/bin/sh -c echo hi")
        #expect(services[0].schedule == .interval(seconds: 60))
        #expect(services[0].kind == .scheduled)
    }
}

/// Tests the new calendar humanization in `Schedule.humanDescription`
/// (per `feedback_schedule_display`).
@Suite("Schedule.humanDescription calendar cases")
struct ScheduleCalendarHumanizationTests {

    @Test("daily at HH:MM (only hour set)")
    func dailyAt() {
        let s = Schedule.calendar(components: [DateComponents(hour: 9, minute: 0)])
        #expect(s.humanDescription == "daily at 09:00")
    }

    @Test("weekly Mon at HH:MM (weekday + time)")
    func weeklyAt() {
        var c = DateComponents(); c.weekday = 2; c.hour = 3; c.minute = 30
        let s = Schedule.calendar(components: [c])
        #expect(s.humanDescription == "weekly Mon at 03:30")
    }

    @Test("monthly on day N at HH:MM")
    func monthlyAt() {
        var c = DateComponents(); c.day = 15; c.hour = 12; c.minute = 0
        let s = Schedule.calendar(components: [c])
        #expect(s.humanDescription == "monthly on day 15 at 12:00")
    }

    @Test("hourly at :MM (only minute set)")
    func hourlyAt() {
        let s = Schedule.calendar(components: [DateComponents(minute: 5)])
        #expect(s.humanDescription == "hourly at :05")
    }

    @Test("multiple entries with same time-of-day → 'N× HH:MM'")
    func multipleSameTime() {
        let s = Schedule.calendar(components: [
            DateComponents(hour: 9, minute: 0),
            DateComponents(hour: 9, minute: 0)
        ])
        #expect(s.humanDescription == "2× 09:00")
    }

    @Test("multiple entries with different times → 'N calendar triggers'")
    func multipleDifferentTimes() {
        let s = Schedule.calendar(components: [
            DateComponents(hour: 9, minute: 0),
            DateComponents(hour: 17, minute: 0)
        ])
        #expect(s.humanDescription == "2 calendar triggers")
    }
}
