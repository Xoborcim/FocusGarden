import Foundation
#if !SKIP
import SwiftData
#endif

@Model
final class Assessment {
    var id: UUID = UUID()
    var title: String = ""
    var kind: String = AssessmentKind.homework.rawValue
    var start: Date = Date()
    var end: Date = Date()
    var isAllDay: Bool = false
    var fingerprint: String = ""
    var extraStudyMinutes: Int = 0
    @Relationship var course: Course?

    init(
        title: String,
        kind: AssessmentKind,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        fingerprint: String = "",
        course: Course? = nil,
        extraStudyMinutes: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.kind = kind.rawValue
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.fingerprint = fingerprint
        self.course = course
        self.extraStudyMinutes = max(0, extraStudyMinutes)
    }

    var assessmentKind: AssessmentKind {
        AssessmentKind(rawValue: kind) ?? .homework
    }
}
