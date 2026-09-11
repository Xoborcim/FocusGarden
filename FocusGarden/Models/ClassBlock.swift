import Foundation
#if !SKIP
import SwiftData
#endif

@Model
final class ClassBlock {
    var id: UUID = UUID()
    var dayOfWeek: Int = 1
    var startTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    var cognitiveWeight: Double = 1.0
    @Relationship var course: Course?

    var meetingType: String = ""
    var location: String = ""
    var fingerprint: String = ""
    var timeZoneIdentifier: String = "America/Toronto"
    var summary: String = ""
    var validFrom: Date = Date.distantPast
    var validUntil: Date = Date.distantFuture

    init(
        dayOfWeek: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        cognitiveWeight: Double = 1.0,
        course: Course? = nil,
        meetingType: String = "",
        location: String = "",
        fingerprint: String = "",
        timeZoneIdentifier: String = "America/Toronto",
        summary: String = "",
        validFrom: Date = Date.distantPast,
        validUntil: Date = Date.distantFuture
    ) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.duration = duration
        self.cognitiveWeight = cognitiveWeight
        self.course = course
        self.meetingType = meetingType
        self.location = location
        self.fingerprint = fingerprint
        self.timeZoneIdentifier = timeZoneIdentifier
        self.summary = summary
        self.validFrom = validFrom
        self.validUntil = validUntil
    }

    var endTime: TimeInterval { startTime + duration }

    func isActive(on day: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: day)
        return start >= calendar.startOfDay(for: validFrom) && start <= calendar.startOfDay(for: validUntil)
    }

    func term(now: Date, calendar: Calendar) -> AcademicTerm {
        let year = calendar.component(.year, from: validFrom)
        if year < 1990 {
            return AcademicTerm.containing(now, calendar: calendar)
        }
        return AcademicTerm.containing(validFrom, calendar: calendar)
    }

    func belongs(to term: AcademicTerm, now: Date, calendar: Calendar) -> Bool {
        self.term(now: now, calendar: calendar) == term
    }
}
