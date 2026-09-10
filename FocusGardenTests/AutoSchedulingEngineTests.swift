import XCTest
@testable import FocusGarden

final class AutoSchedulingEngineTests: XCTestCase {
    let engine = AutoSchedulingEngine()

    func testNeverOverlapsClassBlocks() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let classes = [SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 2)]
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [SchedulingFixtures.task(title: "Essay", priority: 3, minutes: 60)],
                classBlocks: classes
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        for placement in plan.placements {
            for block in classes {
                XCTAssertFalse(placement.start < block.end && block.start < placement.end, "Placement overlapped a class")
            }
        }
    }

    func testPreferredWindowCompliance() {
        let now = SchedulingFixtures.date(2026, 9, 8, 6, 0)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [SchedulingFixtures.task(title: "Read", priority: 2, minutes: 45)],
                classBlocks: []
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        for placement in plan.placements {
            let hour = calendar.component(.hour, from: placement.start)
            XCTAssertGreaterThanOrEqual(hour, 7)
            XCTAssertLessThan(hour, 23)
        }
    }

    func testChunksAreAlignedAndBounded() {
        let chunks = engine.chunkMinutes(200, config: SchedulingFixtures.config())
        XCTAssertEqual(chunks, [90, 90, 20])
        XCTAssertTrue(chunks.allSatisfy { $0 >= 15 && $0 <= 90 })
        let aligned = engine.chunkMinutes(15, config: SchedulingFixtures.config())
        XCTAssertEqual(aligned, [15])
    }

    func testDailyCapLimitsNonReviewBlocks() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let tasks = (0..<6).map { index in
            SchedulingFixtures.task(title: "Block \(index)", priority: 2, minutes: 60)
        }
        var config = SchedulingFixtures.config(horizon: 1, maxBlocks: 4)
        config.horizonDays = 1
        let plan = engine.generate(
            request: SchedulingRequest(now: now, configuration: config, tasks: tasks, classBlocks: [])
        )
        let calendar = config.calendar()
        let counts = Dictionary(grouping: plan.placements) { calendar.startOfDay(for: $0.start) }.mapValues(\.count)
        XCTAssertTrue(counts.values.allSatisfy { $0 <= 4 })
        XCTAssertFalse(plan.unscheduled.isEmpty)
    }

    func testHighPriorityPrefersSlotAfterFinalClass() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let classes = [SchedulingFixtures.classBlock(day: day, startHour: 9, durationHours: 3, weight: 1.5)]
        let high = SchedulingFixtures.task(title: "Problem set", priority: 3, minutes: 60)
        let low = SchedulingFixtures.task(title: "Busywork", priority: 1, minutes: 60)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [low, high],
                classBlocks: classes
            )
        )
        let highPlacement = plan.placements.first { $0.taskID == high.id }
        XCTAssertNotNil(highPlacement)
        XCTAssertGreaterThanOrEqual(highPlacement!.start, classes[0].end)
    }

    func testSpacedReviewPrefersLaterDay() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let review = SchedulingFixtures.task(title: "Anki", priority: 2, minutes: 30, review: true)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [review],
                classBlocks: []
            )
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let hour = calendar.component(.hour, from: plan.placements.first!.start)
        XCTAssertGreaterThanOrEqual(hour, 15)
    }

    func testUnschedulableReturnsReason() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let packed = (7..<23).map { hour in
            SchedulingFixtures.classBlock(day: day, startHour: hour, durationHours: 1, code: "PACK")
        }
        var config = SchedulingFixtures.config(horizon: 1)
        config.horizonDays = 1
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [SchedulingFixtures.task(title: "Impossible", priority: 3, minutes: 90)],
                classBlocks: packed
            )
        )
        XCTAssertTrue(plan.placements.isEmpty)
        XCTAssertEqual(plan.unscheduled.count, 1)
        XCTAssertTrue(plan.unscheduled[0].reason.contains("No free") || plan.unscheduled[0].reason.contains("Could not place"))
    }

    func testLockedBlocksArePreserved() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let lockStart = SchedulingFixtures.date(2026, 9, 8, 19, 0)
        let lockEnd = SchedulingFixtures.date(2026, 9, 8, 20, 0)
        let locked = SchedulingFixtures.task(title: "Manual", priority: 2, minutes: 60, locked: (lockStart, lockEnd))
        let extra = SchedulingFixtures.task(title: "Other", priority: 3, minutes: 60)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [locked, extra],
                classBlocks: []
            )
        )
        let kept = plan.placements.first { $0.taskID == locked.id }
        XCTAssertEqual(kept?.start, lockStart)
        XCTAssertEqual(kept?.end, lockEnd)
        if let other = plan.placements.first(where: { $0.taskID == extra.id }) {
            XCTAssertFalse(other.start < lockEnd && lockStart < other.end)
        }
    }

    func testDeterministicOutputs() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let request = SchedulingRequest(
            now: now,
            configuration: SchedulingFixtures.config(),
            tasks: [SchedulingFixtures.task(id: id, title: "Stable", priority: 2, minutes: 45)],
            classBlocks: [SchedulingFixtures.classBlock(day: now, startHour: 11, durationHours: 1)]
        )
        let first = engine.generate(request: request)
        let second = engine.generate(request: request)
        XCTAssertEqual(first, second)
    }

    func testTorontoDSTSpringForwardDoesNotOverlap() {
        // America/Toronto 2026-03-08 02:00 -> 03:00
        let now = SchedulingFixtures.date(2026, 3, 8, 0, 30)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(horizon: 2),
                tasks: [SchedulingFixtures.task(title: "DST work", priority: 2, minutes: 90)],
                classBlocks: []
            )
        )
        for placement in plan.placements {
            XCTAssertLessThan(placement.start, placement.end)
            XCTAssertEqual(Int(placement.end.timeIntervalSince(placement.start)) % (15 * 60), 0)
        }
    }

    func testTorontoDSTFallBackDurationsStayValid() {
        let now = SchedulingFixtures.date(2026, 11, 1, 0, 30)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(horizon: 2),
                tasks: [SchedulingFixtures.task(title: "Fall back", priority: 2, minutes: 60)],
                classBlocks: []
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        XCTAssertEqual(plan.placements[0].chunkMinutes % 15, 0)
    }

    func testScenarioLightDayPlacesWork() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [SchedulingFixtures.task(title: "Read", priority: 2, minutes: 30)],
                classBlocks: []
            )
        )
        XCTAssertEqual(plan.unscheduled.count, 0)
        XCTAssertEqual(plan.placements.count, 1)
    }

    func testScenarioExamDayAvoidsExamBlock() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let exam = SchedulingFixtures.classBlock(day: now, startHour: 9, durationHours: 3, weight: 3.0, code: "ECO206")
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [SchedulingFixtures.task(title: "Study", priority: 3, minutes: 45)],
                classBlocks: [exam]
            )
        )
        for placement in plan.placements {
            XCTAssertFalse(placement.start < exam.end && exam.start < placement.end)
        }
    }

    func testPropertyRandomizedNoOverlapOrDuplicates() {
        var generator = SeededGenerator(seed: 42)
        for _ in 0..<40 {
            let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
            let classCount = Int.random(in: 0...4, using: &generator)
            let classes: [ExpandedClassBlock] = (0..<classCount).map { index in
                let hour = [8, 10, 13, 16][index % 4]
                return SchedulingFixtures.classBlock(day: now, startHour: hour, durationHours: 1, code: "C\(index)")
            }
            let taskCount = Int.random(in: 1...6, using: &generator)
            let tasks: [PlannableTask] = (0..<taskCount).map { index in
                SchedulingFixtures.task(
                    title: "T\(index)",
                    priority: Int.random(in: 1...3, using: &generator),
                    minutes: [15, 30, 45, 60, 90][Int.random(in: 0...4, using: &generator)],
                    review: Bool.random(using: &generator)
                )
            }
            let plan = engine.generate(
                request: SchedulingRequest(now: now, configuration: SchedulingFixtures.config(horizon: 7), tasks: tasks, classBlocks: classes)
            )
            var seen = Set<UUID>()
            for placement in plan.placements {
                XCTAssertTrue(placement.start < placement.end)
                XCTAssertGreaterThanOrEqual(placement.chunkMinutes, 15)
                XCTAssertLessThanOrEqual(placement.chunkMinutes, 90)
                XCTAssertTrue(seen.insert(placement.chunkID).inserted)
                for block in classes {
                    XCTAssertFalse(placement.start < block.end && block.start < placement.end)
                }
                for other in plan.placements where other.chunkID != placement.chunkID {
                    XCTAssertFalse(placement.start < other.end && other.start < placement.end)
                }
            }
        }
    }

    func testExpandClassBlocksSkipsDatesOutsideRange() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let validUntil = SchedulingFixtures.date(2026, 9, 10, 23, 59)
        let template = RecurringClassTemplate(
            dayOfWeek: 3,
            startTime: 13 * 3600,
            duration: 3600,
            cognitiveWeight: 1.5,
            courseCode: "CSC148",
            meetingType: "LEC",
            validFrom: SchedulingFixtures.date(2026, 9, 1, 0, 0),
            validUntil: validUntil
        )
        let expanded = engine.expandClassBlocks(
            templates: [template],
            now: now,
            configuration: SchedulingFixtures.config(horizon: 21)
        )
        XCTAssertFalse(expanded.isEmpty)
        XCTAssertTrue(expanded.allSatisfy { $0.start <= validUntil })
        XCTAssertFalse(expanded.contains { $0.start > validUntil })
    }

    func testAssessmentPrepBeatsWeeklyStudyForSlots() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let classes = [SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 2)]
        var config = SchedulingFixtures.config(horizon: 1, maxBlocks: 2)
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = false
        config.windowStartHour = 12
        config.windowEndHour = 15
        config.bufferMinutes = 0

        let prep = SchedulingFixtures.task(title: "Test prep", priority: 3, minutes: 60, deadline: SchedulingFixtures.date(2026, 9, 30, 14, 0))
        var prepTask = prep
        prepTask.taskKind = TaskKind.testPrep.rawValue
        prepTask.earliestStart = SchedulingFixtures.date(2026, 9, 8, 12, 0)
        prepTask.latestEnd = SchedulingFixtures.date(2026, 9, 8, 15, 0)

        let weekly = SchedulingFixtures.task(title: "Weekly study", priority: 2, minutes: 60, deadline: SchedulingFixtures.date(2026, 9, 14, 0, 0))
        var weeklyTask = weekly
        weeklyTask.earliestStart = SchedulingFixtures.date(2026, 9, 8, 12, 0)
        weeklyTask.latestEnd = SchedulingFixtures.date(2026, 9, 8, 15, 0)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [weeklyTask, prepTask],
                classBlocks: classes
            )
        )
        let prepPlacement = plan.placements.first { $0.taskID == prepTask.id }
        XCTAssertNotNil(prepPlacement)
        XCTAssertTrue(plan.unscheduled.contains { $0.taskID == weeklyTask.id } || plan.placements.contains { $0.taskID == weeklyTask.id })
        if let weeklyPlacement = plan.placements.first(where: { $0.taskID == weeklyTask.id }), let prepPlacement {
            XCTAssertFalse(weeklyPlacement.start < prepPlacement.end && prepPlacement.start < weeklyPlacement.end)
        }
    }

    func testCommuteBlocksStudyOnlyAfterLastClass() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        var config = SchedulingFixtures.config()
        config.commuteMinutesAfterLastClass = 45
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = true
        let morning = SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 1)
        let afternoon = SchedulingFixtures.classBlock(day: day, startHour: 14, durationHours: 1)
        let calendar = config.calendar()
        let windows = engine.studyWindows(
            day: day,
            searchFrom: now,
            classes: [morning, afternoon],
            config: config,
            calendar: calendar
        )
        let between = windows.first { $0.start >= morning.end && $0.end <= afternoon.start }
        XCTAssertNotNil(between)
        let after = windows.first { $0.start >= afternoon.end }
        XCTAssertNotNil(after)
        XCTAssertEqual(after?.start, afternoon.end.addingTimeInterval(45 * 60))
    }

    func testCommuteRespectedWhenNowIsImmediatelyAfterLastClassToday() {
        // Tuesday Sept 8, 2026. Class was 13:00 - 15:00. Now is 15:05 (5 minutes after class ended).
        let now = SchedulingFixtures.date(2026, 9, 8, 15, 5)
        var config = SchedulingFixtures.config()
        config.commuteMinutesAfterLastClass = 45 // 45-minute commute
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = false

        let template = RecurringClassTemplate(
            dayOfWeek: 3, // Tuesday
            startTime: 13 * 3600, // 13:00
            duration: 2 * 3600,   // 2 hours -> ends 15:00
            cognitiveWeight: 1.5,
            courseCode: "CSC207",
            meetingType: "LEC",
            validFrom: SchedulingFixtures.date(2026, 9, 1, 0, 0),
            validUntil: SchedulingFixtures.date(2026, 12, 1, 0, 0)
        )

        let expanded = engine.expandClassBlocks(templates: [template], now: now, configuration: config)
        XCTAssertFalse(expanded.isEmpty, "Today's completed classes must be retained so commute time is known")

        let task = SchedulingFixtures.task(title: "Problem Set", priority: 2, minutes: 60, code: "CSC207")
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [task],
                classBlocks: expanded
            )
        )

        XCTAssertEqual(plan.placements.count, 1)
        let placement = plan.placements[0]
        let expectedEarliestStart = SchedulingFixtures.date(2026, 9, 8, 15, 45) // 15:00 + 45m commute
        XCTAssertGreaterThanOrEqual(placement.start, expectedEarliestStart, "Study placement must respect 45m commute time after last lecture")
    }

    func testNoClassDayUsesClockWindowOnly() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        var config = SchedulingFixtures.config()
        config.windowStartHour = 9
        config.windowStartMinute = 0
        config.windowEndHour = 23
        config.windowEndMinute = 0
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = false
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let calendar = config.calendar()
        let windows = engine.studyWindows(
            day: day,
            searchFrom: now,
            classes: [],
            config: config,
            calendar: calendar
        )
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(calendar.component(.hour, from: windows[0].start), 9)
        XCTAssertEqual(calendar.component(.hour, from: windows[0].end), 23)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [SchedulingFixtures.task(title: "Study", priority: 2, minutes: 60)],
                classBlocks: []
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        XCTAssertTrue(plan.placements.allSatisfy { calendar.component(.hour, from: $0.start) >= 9 })
        XCTAssertTrue(plan.placements.allSatisfy { $0.end <= windows[0].end })
    }

    func testDoesNotPlaceBeforeFirstClassWhenDisabled() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        var config = SchedulingFixtures.config()
        config.windowStartHour = 9
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = true
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let classes = [SchedulingFixtures.classBlock(day: day, startHour: 11, durationHours: 2)]
        let firstClass = classes[0]
        let calendar = config.calendar()
        let windows = engine.studyWindows(
            day: day,
            searchFrom: now,
            classes: classes,
            config: config,
            calendar: calendar
        )
        XCTAssertTrue(windows.allSatisfy { $0.start >= firstClass.end || $0.end <= firstClass.start })
        XCTAssertFalse(windows.contains { $0.start < firstClass.start && $0.end > now })

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [SchedulingFixtures.task(title: "Study", priority: 2, minutes: 60)],
                classBlocks: classes
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        XCTAssertTrue(plan.placements.allSatisfy { $0.start >= firstClass.end })
    }

    func testDoesNotPlaceBetweenClassesWhenDisabled() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        var config = SchedulingFixtures.config()
        config.windowStartHour = 9
        config.allowBeforeFirstClass = false
        config.allowBetweenClasses = false
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let morning = SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 1)
        let afternoon = SchedulingFixtures.classBlock(day: day, startHour: 14, durationHours: 1)
        let classes = [morning, afternoon]
        let calendar = config.calendar()
        let windows = engine.studyWindows(
            day: day,
            searchFrom: now,
            classes: classes,
            config: config,
            calendar: calendar
        )
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].start, afternoon.end)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [SchedulingFixtures.task(title: "Study", priority: 2, minutes: 60)],
                classBlocks: classes
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        for placement in plan.placements {
            XCTAssertFalse(placement.start >= morning.end && placement.end <= afternoon.start)
            XCTAssertGreaterThanOrEqual(placement.start, afternoon.end)
        }
    }

    func testStudyIsNotPlacedBeforeEarliestStart() {
        let now = SchedulingFixtures.date(2026, 9, 6, 12, 0)
        let firstClassEnd = SchedulingFixtures.date(2026, 9, 9, 14, 0)
        let task = SchedulingFixtures.task(title: "CSC148 study", priority: 2, minutes: 60)
        var work = task
        work.earliestStart = firstClassEnd
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(),
                tasks: [work],
                classBlocks: []
            )
        )
        XCTAssertFalse(plan.placements.isEmpty)
        XCTAssertTrue(plan.placements.allSatisfy { $0.start >= firstClassEnd })
    }

    func testOverlappingClassBlocksAreMergedWithoutInvalidWindows() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        var config = SchedulingFixtures.config()
        config.windowStartHour = 8
        config.windowEndHour = 22
        config.allowBeforeFirstClass = true
        config.allowBetweenClasses = true
        config.commuteMinutesAfterLastClass = 30

        // Class 1: 9:00 to 12:00. Class 2: 10:00 to 11:00 (inside Class 1). Class 3: 13:00 to 14:00.
        let c1 = SchedulingFixtures.classBlock(day: day, startHour: 9, durationHours: 3, code: "C1")
        let c2 = SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 1, code: "C2")
        let c3 = SchedulingFixtures.classBlock(day: day, startHour: 13, durationHours: 1, code: "C3")

        let calendar = config.calendar()
        let windows = engine.studyWindows(
            day: day,
            searchFrom: now,
            classes: [c1, c2, c3],
            config: config,
            calendar: calendar
        )

        // There should be no window overlapping 9:00 to 12:00
        for window in windows {
            XCTAssertFalse(window.start < c1.end && c1.start < window.end, "Window overlapped Class 1")
            XCTAssertFalse(window.start < c3.end && c3.start < window.end, "Window overlapped Class 3")
        }

        // Gap between classes must be between 12:00 and 13:00 (not 11:00 and 13:00)
        let between = windows.first { $0.start >= c1.end && $0.end <= c3.start }
        XCTAssertNotNil(between)
        XCTAssertEqual(calendar.component(.hour, from: between!.start), 12)
        XCTAssertEqual(calendar.component(.hour, from: between!.end), 13)

        // After last class must start at 14:30 (14:00 + 30m commute)
        let after = windows.first { $0.start >= c3.end }
        XCTAssertNotNil(after)
        XCTAssertEqual(after!.start, c3.end.addingTimeInterval(30 * 60))
    }

    func testSameCourseStudySpacedAcrossDays() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        var config = SchedulingFixtures.config(horizon: 4, maxBlocks: 4)
        config.windowStartHour = 9
        config.windowEndHour = 21

        let task1 = SchedulingFixtures.task(title: "CSC148 Block 1", priority: 2, minutes: 60)
        var t1 = task1
        t1.courseCode = "CSC148"

        let task2 = SchedulingFixtures.task(title: "CSC148 Block 2", priority: 2, minutes: 60)
        var t2 = task2
        t2.courseCode = "CSC148"

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [t1, t2],
                classBlocks: []
            )
        )

        XCTAssertEqual(plan.placements.count, 2)
        let p1 = plan.placements.first { $0.taskID == t1.id }!
        let p2 = plan.placements.first { $0.taskID == t2.id }!

        let calendar = config.calendar()
        let day1 = calendar.startOfDay(for: p1.start)
        let day2 = calendar.startOfDay(for: p2.start)

        // The two blocks for the same course should be spaced across different days
        XCTAssertNotEqual(day1, day2, "Same-course study blocks should be spaced onto different days")
    }

    func testBufferEnforcementBetweenTasks() {
        let now = SchedulingFixtures.date(2026, 9, 8, 8, 0)
        var config = SchedulingFixtures.config(horizon: 1)
        config.windowStartHour = 9
        config.windowEndHour = 13
        config.bufferMinutes = 15

        let t1 = SchedulingFixtures.task(title: "Task 1", priority: 2, minutes: 60)
        let t2 = SchedulingFixtures.task(title: "Task 2", priority: 2, minutes: 60)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [t1, t2],
                classBlocks: []
            )
        )

        XCTAssertEqual(plan.placements.count, 2)
        let sorted = plan.placements.sorted { $0.start < $1.start }
        let gapMinutes = sorted[1].start.timeIntervalSince(sorted[0].end) / 60
        XCTAssertGreaterThanOrEqual(gapMinutes, 15.0, "There should be at least 15 minutes of buffer between tasks")
    }

    func testSmartGroupingClumpsRelatedCourses() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let csClass = SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 2, code: "CSC108")
        let csTask = SchedulingFixtures.task(title: "CS Lab", priority: 2, minutes: 60, code: "CSC207")
        let hisTask = SchedulingFixtures.task(title: "History Essay", priority: 2, minutes: 60, code: "HIS101")

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(horizon: 5),
                tasks: [csTask, hisTask],
                classBlocks: [csClass]
            )
        )

        let csPlacement = plan.placements.first { $0.taskID == csTask.id }
        XCTAssertNotNil(csPlacement)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        XCTAssertTrue(calendar.isDate(csPlacement!.start, inSameDayAs: day), "CS task should clump with CS class day")
    }

    func testChronotypeMorningLarkPrefersMorning() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        var config = SchedulingFixtures.config(horizon: 1)
        config.windowStartHour = 7
        config.windowEndHour = 23
        config.chronotype = .morningLark

        let task = SchedulingFixtures.task(title: "Deep Work", priority: 2, minutes: 60)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [task],
                classBlocks: []
            )
        )

        XCTAssertFalse(plan.placements.isEmpty)
        let placement = plan.placements[0]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let hour = calendar.component(.hour, from: placement.start)
        XCTAssertGreaterThanOrEqual(hour, 8)
        XCTAssertLessThanOrEqual(hour, 12, "Morning Lark should place study in the morning hours")
    }

    func testChronotypeNightOwlPrefersEvening() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        var config = SchedulingFixtures.config(horizon: 1)
        config.windowStartHour = 7
        config.windowEndHour = 23
        config.chronotype = .nightOwl

        let task = SchedulingFixtures.task(title: "Late Deep Work", priority: 2, minutes: 60)
        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [task],
                classBlocks: []
            )
        )

        XCTAssertFalse(plan.placements.isEmpty)
        let placement = plan.placements[0]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let hour = calendar.component(.hour, from: placement.start)
        XCTAssertGreaterThanOrEqual(hour, 17, "Night Owl should place study in the evening hours")
    }

    func testDynamicChunkFlexingFitsTightGap() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)

        // Class 1: 07:00 to 11:00
        let c1 = SchedulingFixtures.classBlock(day: day, startHour: 7, durationHours: 4)
        // Class 2: 11:45 to 23:00 (leaving exactly a 45-minute window from 11:00 to 11:45)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let c2Start = calendar.date(bySettingHour: 11, minute: 45, second: 0, of: day)!
        let c2End = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        let c2 = ExpandedClassBlock(start: c2Start, end: c2End, cognitiveWeight: 1.0, courseCode: "C2", meetingType: "LEC")

        var config = SchedulingFixtures.config(horizon: 1)
        config.allowBetweenClasses = true
        config.allowBeforeFirstClass = false
        config.bufferMinutes = 0 // test pure gap sizing
        config.minChunkMinutes = 30

        // Task asks for 60m, which wouldn't fit the 45m gap without flexing
        let task = SchedulingFixtures.task(title: "Flexible Chunk", priority: 3, minutes: 60)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [task],
                classBlocks: [c1, c2]
            )
        )

        XCTAssertFalse(plan.placements.isEmpty, "Task should be placed thanks to dynamic chunk flexing")
        let placement = plan.placements[0]
        XCTAssertEqual(placement.chunkMinutes, 45, "Chunk should dynamically flex to 45m to fit the available window")
    }

    func testTestPrepSpacedAcrossMultipleDays() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day1 = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let day3 = SchedulingFixtures.date(2026, 9, 11, 14, 0)

        var config = SchedulingFixtures.config(horizon: 4)
        config.windowStartHour = 9
        config.windowEndHour = 20

        // 2 test prep sessions with 3-day window
        let prep1 = PlannableTask(
            id: UUID(),
            title: "Study for Exam Pt 1",
            priority: 3,
            remainingMinutes: 60,
            deadline: day3,
            taskKind: TaskKind.testPrep.rawValue,
            isSpacedReview: false,
            isSoftLocked: false,
            lockedStart: nil,
            lockedEnd: nil,
            intensity: 1.0,
            courseCode: "MAT137",
            earliestStart: day1,
            latestEnd: day3
        )
        let prep2 = PlannableTask(
            id: UUID(),
            title: "Study for Exam Pt 2",
            priority: 3,
            remainingMinutes: 60,
            deadline: day3,
            taskKind: TaskKind.testPrep.rawValue,
            isSpacedReview: false,
            isSoftLocked: false,
            lockedStart: nil,
            lockedEnd: nil,
            intensity: 1.0,
            courseCode: "MAT137",
            earliestStart: day1,
            latestEnd: day3
        )

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [prep1, prep2],
                classBlocks: []
            )
        )

        XCTAssertEqual(plan.placements.count, 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let start1 = plan.placements[0].start
        let start2 = plan.placements[1].start
        XCTAssertFalse(calendar.isDate(start1, inSameDayAs: start2), "Exam prep sessions should be spaced across distinct days")
    }

    func testStruggledTaskScheduledWithHighUrgency() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let config = SchedulingFixtures.config(horizon: 3)

        // Hard task (mastery 1) vs Mastered task (mastery 3), both priority 2
        let hardTask = SchedulingFixtures.task(title: "Struggled Topic", priority: 2, minutes: 60, code: "CSC207", mastery: 1)
        let masteredTask = SchedulingFixtures.task(title: "Mastered Topic", priority: 2, minutes: 60, code: "MAT137", mastery: 3)

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: config,
                tasks: [masteredTask, hardTask],
                classBlocks: []
            )
        )

        XCTAssertEqual(plan.placements.count, 2)
        let hardPlacement = plan.placements.first { $0.taskID == hardTask.id }!
        let masteredPlacement = plan.placements.first { $0.taskID == masteredTask.id }!
        XCTAssertLessThan(hardPlacement.start, masteredPlacement.start, "Struggled task should be scheduled before mastered task due to mastery spacing multiplier")
    }

    func testInterleavedPracticeClumpsComplementaryCoursesOnSameDay() {
        let now = SchedulingFixtures.date(2026, 9, 8, 7, 0)
        let day = SchedulingFixtures.date(2026, 9, 8, 0, 0)
        let csClass = SchedulingFixtures.classBlock(day: day, startHour: 10, durationHours: 2, code: "CSC108")

        // Two complementary courses: CSC207 (CS) and MAT137 (Math, related to CS)
        let csTask = SchedulingFixtures.task(title: "Data Structures", priority: 2, minutes: 60, code: "CSC207")
        let mathTask = SchedulingFixtures.task(title: "Calculus", priority: 2, minutes: 60, code: "MAT137")

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: SchedulingFixtures.config(horizon: 5),
                tasks: [csTask, mathTask],
                classBlocks: [csClass]
            )
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SchedulingFixtures.toronto
        let csPlacement = plan.placements.first { $0.taskID == csTask.id }!
        let mathPlacement = plan.placements.first { $0.taskID == mathTask.id }!
        XCTAssertTrue(calendar.isDate(csPlacement.start, inSameDayAs: day))
        XCTAssertTrue(calendar.isDate(mathPlacement.start, inSameDayAs: day), "Interleaving bonus should encourage complementary study on the same day")
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
