import Foundation

struct OccupiedInterval: Equatable, Sendable {
    enum Kind: String, Sendable {
        case schoolClass
        case locked
        case reserved
        case buffer
    }

    var start: Date
    var end: Date
    var kind: Kind
    var cognitiveWeight: Double
    var label: String

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func overlaps(_ otherStart: Date, _ otherEnd: Date) -> Bool {
        start < otherEnd && otherStart < end
    }
}

struct PlannableTask: Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var priority: Int
    var remainingMinutes: Int
    var deadline: Date?
    var taskKind: String
    var isSpacedReview: Bool
    var isSoftLocked: Bool
    var lockedStart: Date?
    var lockedEnd: Date?
    var intensity: Double
    var courseCode: String
    var earliestStart: Date? = nil
    var latestEnd: Date? = nil
    var masteryRating: Int = 2
    var errorNotes: String = ""

    var isReview: Bool {
        isSpacedReview
    }

    var subjectCluster: SubjectCluster {
        SubjectCluster.cluster(for: courseCode.isEmpty ? title : courseCode)
    }
}

struct ScheduledPlacement: Equatable, Sendable, Identifiable {
    var id: UUID { chunkID }
    var taskID: UUID
    var chunkID: UUID
    var start: Date
    var end: Date
    var reason: String
    var chunkMinutes: Int
}

struct UnscheduledWork: Equatable, Sendable, Identifiable {
    var id: UUID { taskID }
    var taskID: UUID
    var title: String
    var reason: String
}

struct SchedulePlan: Equatable, Sendable {
    var placements: [ScheduledPlacement]
    var unscheduled: [UnscheduledWork]
}

struct SchedulingRequest: Sendable {
    var now: Date
    var configuration: AppConfiguration
    var tasks: [PlannableTask]
    var classBlocks: [ExpandedClassBlock]
}

struct ExpandedClassBlock: Equatable, Sendable {
    var start: Date
    var end: Date
    var cognitiveWeight: Double
    var courseCode: String
    var meetingType: String

    var subjectCluster: SubjectCluster {
        SubjectCluster.cluster(for: courseCode)
    }
}

struct RecurringClassTemplate: Equatable, Sendable {
    var dayOfWeek: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var cognitiveWeight: Double
    var courseCode: String
    var meetingType: String
    var validFrom: Date = .distantPast
    var validUntil: Date = .distantFuture
}
