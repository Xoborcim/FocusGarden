#if !SKIP
import Foundation
import XCTest
import SwiftData
@testable import FocusGarden

@MainActor
final class ScheduleManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var manager: ScheduleManager!

    override func setUp() {
        super.setUp()
        container = PersistenceController.inMemory()
        context = container.mainContext
        manager = ScheduleManager(
            engine: AutoSchedulingEngine(),
            planner: StudyPlanner(),
            configuration: SchedulingFixtures.config()
        )
    }

    override func tearDown() {
        context = nil
        container = nil
        manager = nil
        super.tearDown()
    }

    func testSyncGeneratedTasksHandlesDuplicateExistingGenerationKeysWithoutFatalError() throws {
        let duplicateKey = "testPrep|manual|5BFB2296-AA44-41A8-ADD9-6EBB9BC036C7|50DAA266-4695-426F-8F8B-276CC02A9124|0"

        // Insert duplicate tasks in context with identical generationKey
        let task1 = FocusTask(
            title: "Study for CSC148 Term Test",
            priority: 3,
            estimatedMinutes: 60,
            taskKind: TaskKind.testPrep.rawValue,
            generationKey: duplicateKey
        )
        let task2 = FocusTask(
            title: "Study for CSC148 Term Test (Duplicate)",
            priority: 3,
            estimatedMinutes: 60,
            taskKind: TaskKind.testPrep.rawValue,
            generationKey: duplicateKey
        )

        context.insert(task1)
        context.insert(task2)
        try context.save()

        let existingTasks = try context.fetch(FetchDescriptor<FocusTask>())
        XCTAssertEqual(existingTasks.count, 2)

        let desiredItem = GeneratedStudyItem(
            generationKey: duplicateKey,
            title: "Study for CSC148 Term Test",
            minutes: 60,
            priority: 3,
            kind: .testPrep,
            deadline: Date().addingTimeInterval(86400),
            courseCode: "CSC148",
            assessmentFingerprint: "manual|5BFB2296-AA44-41A8-ADD9-6EBB9BC036C7|50DAA266-4695-426F-8F8B-276CC02A9124"
        )

        // Must not crash with Fatal error: Duplicate values for key
        let synced = try manager.syncGeneratedTasks(
            desired: [desiredItem],
            existing: existingTasks,
            courses: [],
            context: context
        )

        XCTAssertEqual(synced.count, 1)
        XCTAssertEqual(synced.first?.generationKey, duplicateKey)

        try context.save()
        let remainingInContext = try context.fetch(FetchDescriptor<FocusTask>())
        XCTAssertEqual(remainingInContext.count, 1, "Duplicate uncompleted task should be deleted from context")
    }

    func testSyncGeneratedTasksPrefersCompletedTaskWhenDuplicateExists() throws {
        let duplicateKey = "testPrep|manual|course1|exam1|0"

        let completedTask = FocusTask(
            title: "Study for Exam",
            priority: 3,
            estimatedMinutes: 60,
            taskKind: TaskKind.testPrep.rawValue,
            generationKey: duplicateKey
        )
        completedTask.isCompleted = true

        let uncompletedTask = FocusTask(
            title: "Study for Exam (Duplicate)",
            priority: 3,
            estimatedMinutes: 60,
            taskKind: TaskKind.testPrep.rawValue,
            generationKey: duplicateKey
        )

        context.insert(completedTask)
        context.insert(uncompletedTask)
        try context.save()

        let existingTasks = try context.fetch(FetchDescriptor<FocusTask>())
        let desiredItem = GeneratedStudyItem(
            generationKey: duplicateKey,
            title: "Study for Exam",
            minutes: 60,
            priority: 3,
            kind: .testPrep,
            deadline: Date().addingTimeInterval(86400),
            courseCode: "CSC148",
            assessmentFingerprint: "manual|course1|exam1"
        )

        let synced = try manager.syncGeneratedTasks(
            desired: [desiredItem],
            existing: existingTasks,
            courses: [],
            context: context
        )

        XCTAssertEqual(synced.count, 1)
        XCTAssertTrue(synced.first?.isCompleted == true, "Completed task should be preferred")

        try context.save()
        let remaining = try context.fetch(FetchDescriptor<FocusTask>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertTrue(remaining.first?.isCompleted == true)
    }

    func testSyncGeneratedTasksHandlesDuplicateDesiredItemsWithoutInsertingDuplicates() throws {
        let duplicateKey = "testPrep|manual|course1|exam1|0"

        let item1 = GeneratedStudyItem(
            generationKey: duplicateKey,
            title: "Study for Exam",
            minutes: 60,
            priority: 3,
            kind: .testPrep,
            deadline: Date().addingTimeInterval(86400),
            courseCode: "CSC148",
            assessmentFingerprint: "manual|course1|exam1"
        )
        let item2 = GeneratedStudyItem(
            generationKey: duplicateKey,
            title: "Study for Exam Duplicate",
            minutes: 60,
            priority: 3,
            kind: .testPrep,
            deadline: Date().addingTimeInterval(86400),
            courseCode: "CSC148",
            assessmentFingerprint: "manual|course1|exam1"
        )

        let synced = try manager.syncGeneratedTasks(
            desired: [item1, item2],
            existing: [],
            courses: [],
            context: context
        )

        XCTAssertEqual(synced.count, 1)
        try context.save()
        let saved = try context.fetch(FetchDescriptor<FocusTask>())
        XCTAssertEqual(saved.count, 1, "Only one task should be created even if desired has duplicates")
    }
}
#endif
