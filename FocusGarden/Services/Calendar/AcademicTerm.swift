import Foundation

struct AcademicTerm: Hashable, Sendable, Identifiable {
    enum Season: String, Sendable {
        case fall
        case winter
        case summer

        var displayName: String {
            switch self {
            case .fall: "Fall"
            case .winter: "Winter"
            case .summer: "Summer"
            }
        }
    }

    var season: Season
    var year: Int

    var id: String { "\(season.rawValue)-\(year)" }

    var displayName: String { "\(season.displayName) \(year)" }

    static func containing(_ date: Date, calendar: Calendar) -> AcademicTerm {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        switch month {
        case 9...12: return AcademicTerm(season: .fall, year: year)
        case 1...4: return AcademicTerm(season: .winter, year: year)
        default: return AcademicTerm(season: .summer, year: year)
        }
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        Self.containing(date, calendar: calendar) == self
    }

    func start(calendar: Calendar) -> Date {
        switch season {
        case .fall:
            return calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? Date.distantPast
        case .winter:
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.distantPast
        case .summer:
            return calendar.date(from: DateComponents(year: year, month: 5, day: 1)) ?? Date.distantPast
        }
    }

    func end(calendar: Calendar) -> Date {
        switch season {
        case .fall:
            return calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59)) ?? Date.distantFuture
        case .winter:
            return calendar.date(from: DateComponents(year: year, month: 4, day: 30, hour: 23, minute: 59)) ?? Date.distantFuture
        case .summer:
            return calendar.date(from: DateComponents(year: year, month: 8, day: 31, hour: 23, minute: 59)) ?? Date.distantFuture
        }
    }
}
