import Foundation
import XCTest
@testable import FocusGarden

final class AcademicTermTests: XCTestCase {
    func testCourseBelongsToTermBeforeFirstClass() {
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12))!
        let firstClass = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 10))!
        let lastClass = calendar.date(from: DateComponents(year: 2026, month: 12, day: 8, hour: 23))!
        let block = ClassBlock(
            dayOfWeek: 3,
            startTime: 10.0 * 3600.0,
            duration: 3600.0,
            validFrom: firstClass,
            validUntil: lastClass
        )
        let term = AcademicTerm.containing(now, calendar: calendar)
        XCTAssertEqual(term.displayName, "Fall 2026")
        XCTAssertFalse(block.isActive(on: now, calendar: calendar))
        XCTAssertTrue(block.belongs(to: term, now: now, calendar: calendar))
    }

    func testWinterBlockIsHiddenDuringFall() {
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12))!
        let winterStart = calendar.date(from: DateComponents(year: 2027, month: 1, day: 13, hour: 13))!
        let winterEnd = calendar.date(from: DateComponents(year: 2027, month: 4, day: 14, hour: 23))!
        let block = ClassBlock(
            dayOfWeek: 4,
            startTime: 13.0 * 3600.0,
            duration: 3600.0,
            validFrom: winterStart,
            validUntil: winterEnd
        )
        let term = AcademicTerm.containing(now, calendar: calendar)
        XCTAssertFalse(block.belongs(to: term, now: now, calendar: calendar))
    }
}
