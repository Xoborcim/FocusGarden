import Foundation

protocol Clock: Sendable {
    var now: Date { get }
}

struct SystemClock: Clock {
    var now: Date { Date() }
}

struct FrozenClock: Clock {
    var now: Date
}

enum MeetingTypeWeight {
    static func cognitiveWeight(for raw: String) -> Double {
        switch normalized(raw) {
        case "LEC", "LECTURE": return 1.5
        case "TUT", "TUTORIAL": return 1.0
        case "EXAM", "MIDTERM", "FINAL", "TEST", "QUIZ": return 3.0
        default: return 1.0
        }
    }

    static func normalized(_ raw: String) -> String {
        let upper = raw.uppercased()
        if ICSEventClassifier.isTest(upper) { return "EXAM" }
        if ICSEventClassifier.isHomework(upper) { return "HW" }
        if upper.contains("LEC") || upper.contains("LECTURE") { return "LEC" }
        if upper.contains("TUT") || upper.contains("TUTORIAL") { return "TUT" }
        if upper.contains("LAB") || upper.contains("PRA") { return "LAB" }
        return upper
    }
}

struct AppConfiguration: Equatable, Sendable {
    var horizonDays: Int
    var windowStartHour: Int
    var windowStartMinute: Int
    var windowEndHour: Int
    var windowEndMinute: Int
    var allowBeforeFirstClass: Bool
    var allowBetweenClasses: Bool
    var granularityMinutes: Int
    var minChunkMinutes: Int
    var maxChunkMinutes: Int
    var bufferMinutes: Int
    var maxNonReviewBlocksPerDay: Int
    var cognitiveDecayPerHour: Double
    var timeZone: TimeZone
    var assessmentLeadWeeks: Int
    var commuteMinutesAfterLastClass: Int
    var timerFocusMinutes: Int = 25
    var timerBreakMinutes: Int = 5
    var chronotype: Chronotype = .balanced

    static let prototype = AppConfiguration(
        horizonDays: 28,
        windowStartHour: 7,
        windowStartMinute: 0,
        windowEndHour: 23,
        windowEndMinute: 0,
        allowBeforeFirstClass: true,
        allowBetweenClasses: true,
        granularityMinutes: 15,
        minChunkMinutes: 15,
        maxChunkMinutes: 90,
        bufferMinutes: 10,
        maxNonReviewBlocksPerDay: 6,
        cognitiveDecayPerHour: 0.35,
        timeZone: TimeZone(identifier: "America/Toronto") ?? .current,
        assessmentLeadWeeks: 2,
        commuteMinutesAfterLastClass: 0,
        timerFocusMinutes: 25,
        timerBreakMinutes: 5,
        chronotype: .balanced
    )

    static let userDefault = AppConfiguration(
        horizonDays: 28,
        windowStartHour: 9,
        windowStartMinute: 0,
        windowEndHour: 23,
        windowEndMinute: 0,
        allowBeforeFirstClass: false,
        allowBetweenClasses: true,
        granularityMinutes: 15,
        minChunkMinutes: 15,
        maxChunkMinutes: 90,
        bufferMinutes: 15,
        maxNonReviewBlocksPerDay: 6,
        cognitiveDecayPerHour: 0.35,
        timeZone: TimeZone(identifier: "America/Toronto") ?? .current,
        assessmentLeadWeeks: 2,
        commuteMinutesAfterLastClass: 30,
        timerFocusMinutes: 25,
        timerBreakMinutes: 5,
        chronotype: .balanced
    )

    mutating func applyStudyPreferences(from state: AppStateRecord) {
        windowStartHour = state.studyStartHour
        windowStartMinute = state.studyStartMinute
        windowEndHour = state.studyEndHour
        windowEndMinute = state.studyEndMinute
        allowBeforeFirstClass = state.allowBeforeFirstClass
        allowBetweenClasses = state.allowBetweenClasses
        assessmentLeadWeeks = max(1, min(8, state.assessmentLeadWeeks))
        commuteMinutesAfterLastClass = max(0, min(180, state.commuteMinutesAfterLastClass))
        horizonDays = max(21, assessmentLeadWeeks * 7 + 14)
        bufferMinutes = max(0, min(60, state.breakMinutesBetweenSessions))
        timerFocusMinutes = max(5, min(120, state.timerFocusMinutes))
        timerBreakMinutes = max(1, min(60, state.timerBreakMinutes))
        chronotype = state.chronotype
    }

    func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
