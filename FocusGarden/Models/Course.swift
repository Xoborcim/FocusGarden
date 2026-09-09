import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID = UUID()
    var code: String = ""
    var title: String = ""
    @Relationship(deleteRule: .cascade, inverse: \FocusTask.linkedCourse) var tasks: [FocusTask]?
    @Relationship(deleteRule: .cascade, inverse: \ClassBlock.course) var classBlocks: [ClassBlock]?
    @Relationship(deleteRule: .cascade, inverse: \Assessment.course) var assessments: [Assessment]?

    var colorIndex: Int = 0
    var createdAt: Date = Date()
    /// 1 = light … 3 = normal … 5 = heavy. Scales weekly study volume.
    var difficulty: Int = 3

    init(code: String, title: String, colorIndex: Int = 0, difficulty: Int = 3) {
        self.id = UUID()
        self.code = code
        self.title = title
        self.colorIndex = colorIndex
        self.tasks = []
        self.classBlocks = []
        self.assessments = []
        self.createdAt = Date()
        self.difficulty = Self.clampedDifficulty(difficulty)
    }

    static func clampedDifficulty(_ value: Int) -> Int {
        min(5, max(1, value))
    }

    var difficultyLabel: String {
        switch Self.clampedDifficulty(difficulty) {
        case 1: return "Easy"
        case 2: return "Light"
        case 3: return "Normal"
        case 4: return "Hard"
        default: return "Brutal"
        }
    }

    var displayName: String {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if trimmedCode.isEmpty { return trimmedTitle.isEmpty ? "Course" : trimmedTitle }
        if trimmedTitle.isEmpty { return trimmedCode }
        return "\(trimmedCode) · \(trimmedTitle)"
    }

    var incompleteTasks: [FocusTask] {
        (tasks ?? []).filter { !$0.isCompleted }
    }

    var tests: [Assessment] {
        (assessments ?? []).filter { $0.assessmentKind == .test }
    }

    var homeworks: [Assessment] {
        (assessments ?? []).filter { $0.assessmentKind == .homework }
    }

    var subjectCluster: SubjectCluster {
        SubjectCluster.cluster(for: code.isEmpty ? title : code)
    }
}
