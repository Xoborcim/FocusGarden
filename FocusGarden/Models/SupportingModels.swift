import Foundation
#if !SKIP
import SwiftData
#endif

public enum Chronotype: String, CaseIterable, Identifiable, Codable, Sendable {
    case morningLark = "morningLark"
    case balanced = "balanced"
    case nightOwl = "nightOwl"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .morningLark: return "Morning Lark"
        case .balanced: return "Balanced"
        case .nightOwl: return "Night Owl"
        }
    }

    public var description: String {
        switch self {
        case .morningLark: return "Peak focus 8:00 AM – 12:00 PM; winds down earlier."
        case .balanced: return "Steady focus 10:00 AM – 4:00 PM throughout the day."
        case .nightOwl: return "Peak focus 5:00 PM – 10:00 PM; gentler morning start."
        }
    }

    public var icon: String {
        switch self {
        case .morningLark: return "sun.max.fill"
        case .balanced: return "scale.3d"
        case .nightOwl: return "moon.stars.fill"
        }
    }
}

@Model
final class AppStateRecord {
    var id: UUID = UUID()
    var hasCompletedOnboarding: Bool = false
    var lastPlanGeneratedAt: Date?
    var studyStartHour: Int = 9
    var studyStartMinute: Int = 0
    var studyEndHour: Int = 23
    var studyEndMinute: Int = 0
    var allowBeforeFirstClass: Bool = false
    var allowBetweenClasses: Bool = true
    var remindersEnabled: Bool = false
    var assessmentLeadWeeks: Int = 2
    var commuteMinutesAfterLastClass: Int = 30
    var breakMinutesBetweenSessions: Int = 15
    var timerFocusMinutes: Int = 25
    var timerBreakMinutes: Int = 5
    var chronotypeRaw: String = Chronotype.balanced.rawValue
    var totalFocusXP: Int = 0
    var currentStreakDays: Int = 0
    var longestStreakDays: Int = 0
    var lastFocusDate: Date? = nil
    var hasResetStudySessionsFor1HourChunks: Bool = false

    var chronotype: Chronotype {
        get { Chronotype(rawValue: chronotypeRaw) ?? .balanced }
        set { chronotypeRaw = newValue.rawValue }
    }

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
        self.studyStartHour = 9
        self.studyStartMinute = 0
        self.studyEndHour = 23
        self.studyEndMinute = 0
        self.allowBeforeFirstClass = false
        self.allowBetweenClasses = true
        self.remindersEnabled = false
        self.assessmentLeadWeeks = 2
        self.commuteMinutesAfterLastClass = 30
        self.breakMinutesBetweenSessions = 15
        self.timerFocusMinutes = 25
        self.timerBreakMinutes = 5
        self.chronotypeRaw = Chronotype.balanced.rawValue
        self.totalFocusXP = 0
        self.currentStreakDays = 0
        self.longestStreakDays = 0
        self.lastFocusDate = nil
        self.hasResetStudySessionsFor1HourChunks = false
    }
}

public enum MasteryRating: Int, CaseIterable, Identifiable, Codable, Sendable {
    case hard = 1      // Quality 1: Struggled / Incorrect (reset interval, next review in 1d)
    case good = 2      // Quality 2: Good retention (standard expanding interval x2.2)
    case mastered = 3  // Quality 3: Easy / Flawless (expanded interval x3.5)

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .hard: return "Struggled"
        case .good: return "Good"
        case .mastered: return "Mastered"
        }
    }

    public var icon: String {
        switch self {
        case .hard: return "flame.fill"
        case .good: return "checkmark.circle.fill"
        case .mastered: return "star.fill"
        }
    }

    public var description: String {
        switch self {
        case .hard: return "Review in 24–48h · Targets error log"
        case .good: return "Expanding spacing (2.2× interval)"
        case .mastered: return "Longer interval (3.5×) · Mastered"
        }
    }
}

public enum WeekdayLabel {
    public static let short = ["", "S", "M", "T", "W", "T", "F", "S"]
    public static let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
}
