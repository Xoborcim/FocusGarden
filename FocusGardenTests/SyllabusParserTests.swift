import Foundation
import XCTest
@testable import FocusGarden

final class SyllabusParserTests: XCTestCase {
    var calendar: Calendar!
    var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: Calendar.Identifier.gregorian)
        cal.timeZone = TimeZone(identifier: "America/Toronto")!
        calendar = cal

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        components.hour = 12
        referenceDate = calendar.date(from: components)!
    }

    func testParseStandardList() {
        let text = """
        Course Schedule:
        - Assignment 1: Sept 22, 2026 at 11:59 PM (10%)
        - Quiz 1: Oct 5, 2026 from 10:00 AM to 11:00 AM
        - Midterm Exam: Oct 20, 2026, 2:00 PM - 4:00 PM (25%)
        - Assignment 2: Nov 10, 2026
        - Final Project: Dec 1, 2026 (20%)
        - Final Exam: Dec 14, 2026 at 9:00 AM (35%)
        """

        let parser = SyllabusParser(calendar: calendar, referenceDate: referenceDate)
        let items = parser.parse(text: text, courseCode: "CSC108")

        XCTAssertEqual(items.count, 6)

        // Assignment 1
        XCTAssertEqual(items[0].title, "Assignment 1")
        XCTAssertEqual(items[0].kind, AssessmentKind.homework)
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[0].date), 9)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[0].date), 22)
        XCTAssertEqual(calendar.component(Calendar.Component.hour, from: items[0].date), 23)
        XCTAssertEqual(calendar.component(Calendar.Component.minute, from: items[0].date), 59)

        // Quiz 1
        XCTAssertEqual(items[1].title, "Quiz 1")
        XCTAssertEqual(items[1].kind, AssessmentKind.test)
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[1].date), 10)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[1].date), 5)
        XCTAssertEqual(calendar.component(Calendar.Component.hour, from: items[1].date), 10)
        XCTAssertEqual(calendar.component(Calendar.Component.minute, from: items[1].date), 0)

        // Midterm Exam
        XCTAssertEqual(items[2].title, "Midterm Exam")
        XCTAssertEqual(items[2].kind, AssessmentKind.test)
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[2].date), 10)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[2].date), 20)
        XCTAssertEqual(calendar.component(Calendar.Component.hour, from: items[2].date), 14)
        XCTAssertEqual(calendar.component(Calendar.Component.minute, from: items[2].date), 0)
        XCTAssertEqual(calendar.component(Calendar.Component.hour, from: items[2].endDate), 16)

        // Assignment 2
        XCTAssertEqual(items[3].title, "Assignment 2")
        XCTAssertEqual(items[3].kind, AssessmentKind.homework)
        XCTAssertTrue(items[3].isAllDay)

        // Final Project
        XCTAssertEqual(items[4].title, "Final Project")
        XCTAssertEqual(items[4].kind, AssessmentKind.homework)

        // Final Exam
        XCTAssertEqual(items[5].title, "Final Exam")
        XCTAssertEqual(items[5].kind, AssessmentKind.test)
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[5].date), 12)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[5].date), 14)
    }

    func testParseMarkdownTable() {
        let table = """
        | Week | Date | Assessment | Weight |
        |---|---|---|---|
        | Week 3 | Sep 25, 2026 | Problem Set 1 | 5% |
        | Week 6 | Oct 16, 2026 | Midterm 1 | 20% |
        | Week 10 | Nov 13, 2026 | Essay Draft | 15% |
        | Exam Period | Dec 18, 2026 | Final Exam | 40% |
        """

        let parser = SyllabusParser(calendar: calendar, referenceDate: referenceDate)
        let items = parser.parse(text: table, courseCode: "MAT137")

        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].title, "Problem Set 1")
        XCTAssertEqual(items[0].kind, AssessmentKind.homework)
        XCTAssertEqual(items[1].title, "Midterm 1")
        XCTAssertEqual(items[1].kind, AssessmentKind.test)
        XCTAssertEqual(items[2].title, "Essay Draft")
        XCTAssertEqual(items[2].kind, AssessmentKind.homework)
        XCTAssertEqual(items[3].title, "Final Exam")
        XCTAssertEqual(items[3].kind, AssessmentKind.test)
    }

    func testParseIsoAndSlashDates() {
        let text = """
        Midterm: 2026-10-15
        Homework 3: 11/04/2026
        Final: 12/20
        """

        let parser = SyllabusParser(calendar: calendar, referenceDate: referenceDate)
        let items = parser.parse(text: text)

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[0].date), 10)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[0].date), 15)

        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[1].date), 11)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[1].date), 4)

        XCTAssertEqual(calendar.component(Calendar.Component.month, from: items[2].date), 12)
        XCTAssertEqual(calendar.component(Calendar.Component.day, from: items[2].date), 20)
    }

    func testClassification() {
        let parser = SyllabusParser(calendar: calendar, referenceDate: referenceDate)
        XCTAssertEqual(parser.detectKind(from: "Midterm Exam 1"), AssessmentKind.test)
        XCTAssertEqual(parser.detectKind(from: "Term Test 2"), AssessmentKind.test)
        XCTAssertEqual(parser.detectKind(from: "Weekly Quiz 4"), AssessmentKind.test)
        XCTAssertEqual(parser.detectKind(from: "Final Examination"), AssessmentKind.test)

        XCTAssertEqual(parser.detectKind(from: "Assignment 1"), AssessmentKind.homework)
        XCTAssertEqual(parser.detectKind(from: "Problem Set 3"), AssessmentKind.homework)
        XCTAssertEqual(parser.detectKind(from: "Term Project Submission"), AssessmentKind.homework)
        XCTAssertEqual(parser.detectKind(from: "Research Paper Draft"), AssessmentKind.homework)
        XCTAssertEqual(parser.detectKind(from: "Lab Report 2"), AssessmentKind.homework)
    }
}
