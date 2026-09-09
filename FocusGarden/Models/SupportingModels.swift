import Foundation
import SwiftData

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
    }
}
