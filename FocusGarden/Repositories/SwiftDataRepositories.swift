import Foundation
import SwiftData

@MainActor
protocol TaskRepository {
    func all() throws -> [FocusTask]
    func save() throws
}

@MainActor
protocol CourseRepository {
    func all() throws -> [Course]
    func classBlocks() throws -> [ClassBlock]
    func save() throws
}

@MainActor
protocol AppStateRepository {
    func record() throws -> AppStateRecord
    func save() throws
}

@MainActor
struct SwiftDataTaskRepository: TaskRepository {
    var context: ModelContext

    func all() throws -> [FocusTask] {
        try context.fetch(FetchDescriptor<FocusTask>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func save() throws {
        try context.save()
    }
}

@MainActor
struct SwiftDataCourseRepository: CourseRepository {
    var context: ModelContext

    func all() throws -> [Course] {
        try context.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\.code)]))
    }

    func classBlocks() throws -> [ClassBlock] {
        try context.fetch(FetchDescriptor<ClassBlock>())
    }

    func save() throws {
        try context.save()
    }
}

@MainActor
struct SwiftDataAppStateRepository: AppStateRepository {
    var context: ModelContext

    func record() throws -> AppStateRecord {
        let existing = try context.fetch(FetchDescriptor<AppStateRecord>())
        if let first = existing.first {
            for extra in existing.dropFirst() {
                context.delete(extra)
            }
            return first
        }
        let record = AppStateRecord()
        context.insert(record)
        try context.save()
        return record
    }

    func save() throws {
        try context.save()
    }
}
