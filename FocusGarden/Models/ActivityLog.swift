import Foundation
#if !SKIP
import SwiftData
#endif

public enum ActivityCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case study = "study"
    case classMeeting = "class"
    case exercise = "exercise"
    case leisure = "leisure"
    case project = "project"
    case life = "life"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .study: return "Study"
        case .classMeeting: return "Class"
        case .exercise: return "Exercise"
        case .leisure: return "Leisure"
        case .project: return "Project"
        case .life: return "Life"
        }
    }

    public var icon: String {
        switch self {
        case .study: return "book.fill"
        case .classMeeting: return "graduationcap.fill"
        case .exercise: return "figure.run"
        case .leisure: return "cup.and.saucer.fill"
        case .project: return "hammer.fill"
        case .life: return "heart.fill"
        }
    }
}

public enum AIUsageLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "none"
    case hint = "hint"
    case moderate = "moderate"
    case heavy = "heavy"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "No AI"
        case .hint: return "Hint only"
        case .moderate: return "Moderate help"
        case .heavy: return "Heavy help"
        }
    }

    public var isAIAssisted: Bool {
        self != .none
    }
}

@Model
final class ActivityLog {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = ActivityCategory.study.rawValue
    var durationMinutes: Int = 0
    var timestamp: Date = Date()
    var startTime: Date?
    var focusRating: Int = 0       // 0 = unrated, 1...5
    var energyRating: Int = 0      // 0 = unrated, 1...5
    var aiUsageRaw: String = AIUsageLevel.none.rawValue
    var independentAttemptFirst: Bool = true
    var notes: String = ""
    var isTimerGenerated: Bool = false
    @Relationship var linkedCourse: Course?
    var createdAt: Date = Date()

    init(
        title: String,
        category: ActivityCategory = .study,
        durationMinutes: Int = 0,
        timestamp: Date = Date(),
        startTime: Date? = nil,
        focusRating: Int = 0,
        energyRating: Int = 0,
        aiUsage: AIUsageLevel = .none,
        independentAttemptFirst: Bool = true,
        notes: String = "",
        isTimerGenerated: Bool = false,
        linkedCourse: Course? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.durationMinutes = max(0, durationMinutes)
        self.timestamp = timestamp
        self.startTime = startTime ?? timestamp.addingTimeInterval(-TimeInterval(max(0, durationMinutes) * 60))
        self.focusRating = min(5, max(0, focusRating))
        self.energyRating = min(5, max(0, energyRating))
        self.aiUsageRaw = aiUsage.rawValue
        self.independentAttemptFirst = independentAttemptFirst
        self.notes = notes
        self.isTimerGenerated = isTimerGenerated
        self.linkedCourse = linkedCourse
        self.createdAt = Date()
    }

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .study }
        set { categoryRaw = newValue.rawValue }
    }

    var aiUsage: AIUsageLevel {
        get { AIUsageLevel(rawValue: aiUsageRaw) ?? .none }
        set { aiUsageRaw = newValue.rawValue }
    }

    var isFocusedStudy: Bool {
        category == .study || category == .project
    }

    var isIndependent: Bool {
        aiUsage == .none && independentAttemptFirst
    }
}
