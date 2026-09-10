import XCTest
@testable import FocusGarden

final class StudyPlannerTests: XCTestCase {
    let planner = StudyPlanner()
    let config = SchedulingFixtures.config()

    func testWeeklyStudyScalesWithClassTime() {
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120), 180)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 0), 0)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 400), 600)
    }

    func testWeeklyStudyIsStrictlyOnePointFiveTimesLectureHours() {
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 60), 90)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 120), 180)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 180), 270)
        XCTAssertEqual(planner.weeklyStudyMinutes(classMinutes: 240), 360)
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

    func testWeeklyStudySplitIntoOneHourChunks() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let config = SchedulingFixtures.config(horizon: 7)
        // 180 class minutes -> 270 study minutes (4.5 hours)
        let items = planner.plan(
            courses: [CourseWorkload(code: "MAT223", weeklyClassMinutes: 180)],
            assessments: [],
            now: now,
            configuration: config
        )

        let studyItems = items.filter { $0.kind == .study && $0.courseCode == "MAT223" }
        XCTAssertFalse(studyItems.isEmpty)
        // Verify all chunks are at most 60 minutes (1 hour)
        XCTAssertTrue(studyItems.allSatisfy { $0.minutes <= 60 })
        // Expected chunks for each week: 60, 60, 60, 60, 30 = 270 minutes
        let week1Chunks = Array(studyItems.prefix(5)).map(\.minutes)
        XCTAssertEqual(week1Chunks, [60, 60, 60, 60, 30])
        XCTAssertEqual(week1Chunks.reduce(0, +), 270)
    }
}
