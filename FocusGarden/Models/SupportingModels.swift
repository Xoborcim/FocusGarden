import Foundation
import SwiftData

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
    var remindersEnabled: Bool = true
    var assessmentLeadWeeks: Int = 2
    var commuteMinutesAfterLastClass: Int = 30
    var breakMinutesBetweenSessions: Int = 15
    var timerFocusMinutes: Int = 25
    var timerBreakMinutes: Int = 5
    var chronotypeRaw: String = Chronotype.balanced.rawValue

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
        self.remindersEnabled = true
        self.assessmentLeadWeeks = 2
        self.commuteMinutesAfterLastClass = 30
        self.breakMinutesBetweenSessions = 15
        self.timerFocusMinutes = 25
        self.timerBreakMinutes = 5
        self.chronotypeRaw = Chronotype.balanced.rawValue
    }
}
