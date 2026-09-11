import Foundation
import XCTest
@testable import FocusGarden

final class ICSImportServiceTests: XCTestCase {
    let parser = ICSParser(defaultTimeZone: TimeZone(identifier: "America/Toronto")!)

    func testTorontoTimezoneWallClock() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:MGT225H5 LEC0101
        DTSTART;TZID=America/Toronto:20260908T103000
        DTEND;TZID=America/Toronto:20260908T123000
        RRULE:FREQ=WEEKLY;BYDAY=TU
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 1)
        XCTAssertEqual(result.previews[0].dayOfWeek, 3)
        XCTAssertEqual(Int(result.previews[0].startTime / 60), 10 * 60 + 30)
        XCTAssertEqual(result.previews[0].cognitiveWeight, 1.5, accuracy: 0.01)
        XCTAssertTrue(result.assessments.isEmpty)
    }

    func testCompactAndSpacedCourseCodes() {
        XCTAssertEqual(CourseCodeParser.parse(title: "MGT225H5 LEC")?.code, "MGT225H5")
        XCTAssertEqual(CourseCodeParser.parse(title: "CHEM 112A 001 Tutorial")?.code, "CHEM112A")
        XCTAssertEqual(CourseCodeParser.meetingType(in: "CHEM 112A 001 Tutorial"), "TUT")
        XCTAssertEqual(MeetingTypeWeight.cognitiveWeight(for: "TUT"), 1.0)
        XCTAssertEqual(MeetingTypeWeight.cognitiveWeight(for: "EXAM"), 3.0)
        XCTAssertEqual(MeetingTypeWeight.cognitiveWeight(for: "mystery"), 1.0)
    }

    func testPartialParseResilience() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:Broken
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:CSC148H5 LEC
        DTSTART;TZID=America/Toronto:20260909T130000
        DTEND;TZID=America/Toronto:20260909T140000
        RRULE:FREQ=WEEKLY;BYDAY=WE
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 1)
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertEqual(result.previews[0].courseCode, "CSC148H5")
    }

    func testLogicalDeduplication() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:MGT225H5 LEC
        DTSTART;TZID=America/Toronto:20260908T103000
        DTEND;TZID=America/Toronto:20260908T123000
        RRULE:FREQ=WEEKLY;BYDAY=TU
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:MGT225H5 LEC
        DTSTART;TZID=America/Toronto:20260915T103000
        DTEND;TZID=America/Toronto:20260915T123000
        RRULE:FREQ=WEEKLY;BYDAY=TU
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 1)
    }

    func testExamsAndHomeworkAreSeparatedFromClasses() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:CSC148H5 LEC
        DTSTART;TZID=America/Toronto:20260909T130000
        DTEND;TZID=America/Toronto:20260909T140000
        RRULE:FREQ=WEEKLY;BYDAY=WE
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:CSC148H5 Midterm
        DTSTART;TZID=America/Toronto:20261020T140000
        DTEND;TZID=America/Toronto:20261020T160000
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:CSC148H5 Assignment 1
        DTSTART;VALUE=DATE:20261003
        DTEND;VALUE=DATE:20261004
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 1)
        XCTAssertEqual(result.previews[0].meetingType, "LEC")
        XCTAssertEqual(result.assessments.count, 2)
        XCTAssertEqual(result.assessments.filter { $0.kind == AssessmentKind.test }.count, 1)
        XCTAssertEqual(result.assessments.filter { $0.kind == AssessmentKind.homework }.count, 1)
        XCTAssertTrue(result.assessments.first { $0.kind == AssessmentKind.homework }?.isAllDay == true)
    }

    func testFallAndWinterStaySeparate() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:CSC148H5 LEC
        DTSTART;TZID=America/Toronto:20260909T130000
        DTEND;TZID=America/Toronto:20260909T140000
        RRULE:FREQ=WEEKLY;BYDAY=WE;UNTIL=20261209T235959
        END:VEVENT
        BEGIN:VEVENT
        SUMMARY:CSC148H5 LEC
        DTSTART;TZID=America/Toronto:20270113T130000
        DTEND;TZID=America/Toronto:20270113T140000
        RRULE:FREQ=WEEKLY;BYDAY=WE;UNTIL=20270414T235959
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 2)
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let terms = result.terms(calendar: calendar)
        XCTAssertEqual(terms.map(\.displayName), ["Fall 2026", "Winter 2027"])

        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 8))!
        let preferred = result.preferredTerm(now: now, calendar: calendar)
        XCTAssertEqual(preferred?.displayName, "Fall 2026")
        let filtered = result.filtered(to: preferred!, calendar: calendar)
        XCTAssertEqual(filtered.previews.count, 1)
        XCTAssertEqual(filtered.previews[0].termID, "fall-2026")
    }

    func testClassRangeUsesUntil() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:MGT225H5 LEC
        DTSTART;TZID=America/Toronto:20260908T103000
        DTEND;TZID=America/Toronto:20260908T123000
        RRULE:FREQ=WEEKLY;BYDAY=TU;UNTIL=20261208T235959
        END:VEVENT
        END:VCALENDAR
        """
        let result = parser.parse(data: Data(ics.utf8))
        XCTAssertEqual(result.previews.count, 1)
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let until = calendar.date(from: DateComponents(year: 2026, month: 12, day: 8, hour: 23, minute: 59, second: 59))!
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: result.previews[0].validUntil), 12)
        XCTAssertLessThanOrEqual(abs(result.previews[0].validUntil.timeIntervalSince(until)), 2)
    }
}
