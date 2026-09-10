import Foundation
import XCTest
@testable import FocusGarden

enum SchedulingFixtures {
    static var toronto: TimeZone { TimeZone(identifier: "America/Toronto")! }

    static func config(
        nowZone: TimeZone = toronto,
        horizon: Int = 21,
        maxBlocks: Int = 4
    ) -> AppConfiguration {
        var config = AppConfiguration.prototype
        config.timeZone = nowZone
        config.horizonDays = horizon
        config.maxNonReviewBlocksPerDay = maxBlocks
        config.bufferMinutes = 10
        return config
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, zone: TimeZone = toronto) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func classBlock(
        day: Date,
        startHour: Int,
        durationHours: Double,
        weight: Double = 1.5,
        code: String = "CSC108"
    ) -> ExpandedClassBlock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = toronto
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
        return ExpandedClassBlock(
            start: start,
            end: start.addingTimeInterval(durationHours * 3600),
            cognitiveWeight: weight,
            courseCode: code,
            meetingType: "LEC"
        )
    }

    static func task(
        id: UUID = UUID(),
        title: String,
        priority: Int,
        minutes: Int,
        deadline: Date? = nil,
        review: Bool = false,
        locked: (Date, Date)? = nil,
        code: String = "CSC108",
        mastery: Int = 2
    ) -> PlannableTask {
        PlannableTask(
            id: id,
            title: title,
            priority: priority,
            remainingMinutes: minutes,
            deadline: deadline,
            taskKind: TaskKind.study.rawValue,
            isSpacedReview: review,
            isSoftLocked: locked != nil,
            lockedStart: locked?.0,
            lockedEnd: locked?.1,
            intensity: 1.0,
            courseCode: code,
            masteryRating: mastery
        )
    }
}
