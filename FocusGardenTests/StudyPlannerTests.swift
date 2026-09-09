import XCTest
@testable import FocusGarden

final class StudyPlannerTests: XCTestCase {
    let planner = StudyPlanner()
    let config = SchedulingFixtures.config()

    func testWeeklyStudyScalesWithClassTime() {
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120), 180)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 0), 90)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 400), 480)
    }

    func testWeeklyStudyScalesWithDifficulty() {
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120, difficulty: 1), 126)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120, difficulty: 3), 180)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120, difficulty: 5), 270)
    }

    func testPlanCreatesWeeklyStudyAndSpecialSlots() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let examStart = SchedulingFixtures.date(2026, 9, 18, 14, 0)
        let homeworkDue = SchedulingFixtures.date(2026, 9, 16, 0, 0)
        let items = planner.plan(
            courses: [CourseWorkload(code: "CSC148", weeklyClassMinutes: 120)],
            assessments: [
                AssessmentEvent(
                    fingerprint: "test|CSC148|1",
                    title: "CSC148 Midterm",
                    kind: .test,
                    start: examStart,
                    end: examStart.addingTimeInterval(2 * 3600),
                    isAllDay: false,
                    courseCode: "CSC148"
                ),
                AssessmentEvent(
                    fingerprint: "hw|CSC148|1",
                    title: "CSC148 Assignment 1",
                    kind: .homework,
                    start: homeworkDue,
                    end: homeworkDue.addingTimeInterval(24 * 3600),
                    isAllDay: true,
                    courseCode: "CSC148"
                )
            ],
            now: now,
            configuration: config
        )

        XCTAssertFalse(items.filter { $0.kind == .study }.isEmpty)
        XCTAssertEqual(items.filter { $0.kind == .study }.map(\.minutes).reduce(0, +) >= 180, true)

        let prep = items.filter { $0.kind == .testPrep }
        XCTAssertEqual(prep.map(\.minutes).reduce(0, +), 180)
        XCTAssertTrue(prep.allSatisfy { $0.deadline == examStart })
        XCTAssertTrue(prep.allSatisfy { $0.priority == 3 })
        XCTAssertTrue(prep.allSatisfy { ($0.earliestStart ?? .distantPast) >= SchedulingFixtures.date(2026, 9, 4, 0, 0) })
        XCTAssertTrue(prep.allSatisfy { ($0.latestEnd ?? .distantFuture) <= examStart })

        let homework = items.filter { $0.kind == .homework }
        XCTAssertEqual(homework.map(\.minutes).reduce(0, +), 90)
        XCTAssertTrue(homework.allSatisfy { $0.priority == 3 })
    }

    func testAssessmentPrepUsesLeadWindowAndExtraMinutes() {
        var config = SchedulingFixtures.config(horizon: 28)
        config.assessmentLeadWeeks = 2
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        let examStart = SchedulingFixtures.date(2026, 9, 30, 14, 0)
        let items = planner.plan(
            courses: [CourseWorkload(code: "CSC148", weeklyClassMinutes: 120)],
            assessments: [
                AssessmentEvent(
                    fingerprint: "test|CSC148|2",
                    title: "CSC148 Term Test",
                    kind: .test,
                    start: examStart,
                    end: examStart.addingTimeInterval(2 * 3600),
                    isAllDay: false,
                    courseCode: "CSC148",
                    extraStudyMinutes: 60
                )
            ],
            now: now,
            configuration: config
        )
        let prep = items.filter { $0.kind == .testPrep }
        XCTAssertEqual(prep.map(\.minutes).reduce(0, +), 240)
        let windowStart = SchedulingFixtures.date(2026, 9, 16, 0, 0)
        XCTAssertTrue(prep.allSatisfy { ($0.earliestStart ?? .distantPast) >= windowStart })
        XCTAssertTrue(prep.allSatisfy { ($0.latestEnd ?? .distantFuture) <= examStart })
        if prep.count >= 2 {
            let starts = prep.compactMap(\.earliestStart).sorted()
            XCTAssertGreaterThan(starts.last!, starts.first!)
        }
    }

    func testPastAssessmentsAreIgnored() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let items = planner.plan(
            courses: [],
            assessments: [
                AssessmentEvent(
                    fingerprint: "old",
                    title: "Old midterm",
                    kind: .test,
                    start: SchedulingFixtures.date(2026, 9, 1, 14, 0),
                    end: SchedulingFixtures.date(2026, 9, 1, 16, 0),
                    isAllDay: false,
                    courseCode: "CSC148"
                )
            ],
            now: now,
            configuration: config
        )
        XCTAssertTrue(items.isEmpty)
    }

    func testStudyDoesNotStartBeforeSchoolStart() {
        let now = SchedulingFixtures.date(2026, 9, 6, 12, 0)
        let schoolStart = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let firstClassEnd = SchedulingFixtures.date(2026, 9, 9, 14, 0)
        let items = planner.plan(
            courses: [CourseWorkload(code: "CSC148", weeklyClassMinutes: 120, firstClassEnd: firstClassEnd)],
            assessments: [],
            now: now,
            configuration: config,
            schoolStart: schoolStart
        )
        let study = items.filter { $0.kind == .study }
        XCTAssertFalse(study.isEmpty)
        XCTAssertTrue(study.allSatisfy { ($0.earliestStart ?? .distantPast) >= schoolStart })
    }

    func testHomeworkBeforeSchoolStartIsSkipped() {
        let now = SchedulingFixtures.date(2026, 9, 6, 12, 0)
        let schoolStart = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let items = planner.plan(
            courses: [],
            assessments: [
                AssessmentEvent(
                    fingerprint: "early",
                    title: "CSC148 Assignment 0",
                    kind: .homework,
                    start: SchedulingFixtures.date(2026, 9, 7, 0, 0),
                    end: SchedulingFixtures.date(2026, 9, 8, 0, 0),
                    isAllDay: true,
                    courseCode: "CSC148"
                )
            ],
            now: now,
            configuration: config,
            schoolStart: schoolStart
        )
        XCTAssertTrue(items.isEmpty)
    }
}
