import Foundation
import SwiftData

@Model
final class FocusTask {
    var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    var priority: Int = 2
    var estimatedMinutes: Int = 0
    var scheduledStart: Date?
    var scheduledEnd: Date?
    var taskKind: String = TaskKind.study.rawValue
    var isSpacedReview: Bool = false
    @Relationship var linkedCourse: Course?

    var deadline: Date?
    var createdAt: Date = Date()
    var completedAt: Date?
    var isSoftLocked: Bool = false
    var scheduleReason: String = ""
    var remainingMinutes: Int = 0
    var intensity: Double = 1.0
    var generationKey: String = ""
    var linkedAssessmentFingerprint: String = ""
    var sessionStartedAt: Date?

    init(
        title: String,
        priority: Int = 2,
        estimatedMinutes: Int = 45,
        taskKind: String = TaskKind.study.rawValue,
        linkedCourse: Course? = nil,
        deadline: Date? = nil,
        createdAt: Date = Date(),
        generationKey: String = "",
        linkedAssessmentFingerprint: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.priority = min(3, max(1, priority))
        self.estimatedMinutes = max(0, estimatedMinutes)
        self.remainingMinutes = max(0, estimatedMinutes)
        self.taskKind = taskKind
        self.linkedCourse = linkedCourse
        self.deadline = deadline
        self.createdAt = createdAt
        self.generationKey = generationKey
        self.linkedAssessmentFingerprint = linkedAssessmentFingerprint
        self.intensity = Self.defaultIntensity(kind: taskKind, minutes: estimatedMinutes)
    }

    var kind: TaskKind {
        TaskKind(rawValue: taskKind) ?? .study
    }

    var isScheduled: Bool {
        scheduledStart != nil && scheduledEnd != nil
    }

    var isInSession: Bool {
        sessionStartedAt != nil && !isCompleted
    }

    var isReviewKind: Bool {
        kind == .study && isSpacedReview
    }

    var subjectCluster: SubjectCluster {
        if let course = linkedCourse {
            return course.subjectCluster
        }
        return SubjectCluster.cluster(for: title)
    }

    static func defaultIntensity(kind: String, minutes: Int) -> Double {
        let base: Double
        switch TaskKind(rawValue: kind) {
        case .testPrep: base = 1.3
        case .homework: base = 1.1
        default: base = 1.0
        }
        return base + min(0.4, Double(max(0, minutes - 30)) / 180.0)
    }
}

enum TaskKind: String, CaseIterable, Identifiable {
    case study
    case testPrep
    case homework

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .study: "Study"
        case .testPrep: "Test prep"
        case .homework: "Homework"
        }
    }
}
