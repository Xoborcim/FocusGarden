import Foundation

public struct ParsedSyllabusItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: AssessmentKind
    public var date: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var extraStudyMinutes: Int
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        kind: AssessmentKind,
        date: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        extraStudyMinutes: Int = 0,
        isSelected: Bool = true
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.date = date
        self.endDate = endDate ?? (isAllDay ? date.addingTimeInterval(86400) : date.addingTimeInterval(7200))
        self.isAllDay = isAllDay
        self.extraStudyMinutes = extraStudyMinutes
        self.isSelected = isSelected
    }
}

public struct SyllabusParser: Sendable {
    public var calendar: Calendar
    public var referenceDate: Date

    public init(calendar: Calendar = Calendar.current, referenceDate: Date = Date()) {
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    private static let monthMap: [String: Int] = [
        "jan": 1, "january": 1,
        "feb": 2, "february": 2,
        "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "jun": 6, "june": 6,
        "jul": 7, "july": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dec": 12, "december": 12
    ]

    public func parse(text: String, courseCode: String? = nil) -> [ParsedSyllabusItem] {
        let lines = text.split(separator: "\n").map { String($0) }
        var items: [ParsedSyllabusItem] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if isHeaderLine(line) { continue }

            if let item = parseLine(line, courseCode: courseCode) {
                items.append(item)
            }
        }

        return items
    }

    private func isHeaderLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let countPipes = line.filter { $0 == "|" }.count
        if countPipes >= 2 {
            if lower.contains("date") && (lower.contains("topic") || lower.contains("assessment") || lower.contains("title") || lower.contains("week") || lower.contains("weight")) {
                return true
            }
            if line.contains("---") || line.contains("===") {
                return true
            }
        }
        return false
    }

    public func parseLine(_ line: String, courseCode: String? = nil) -> ParsedSyllabusItem? {
        guard let dateInfo = extractDate(from: line) else { return nil }

        let kind = detectKind(from: line)
        let title = extractTitle(from: line, kind: kind, courseCode: courseCode)

        let isAllDay = dateInfo.isAllDay
        let start = dateInfo.startDate
        let end = dateInfo.endDate ?? (isAllDay ? start.addingTimeInterval(86400) : start.addingTimeInterval(kind == AssessmentKind.test ? 7200 : 3600))
        let defaultExtra = (kind == AssessmentKind.test) ? 120 : 60

        return ParsedSyllabusItem(
            title: title,
            kind: kind,
            date: start,
            endDate: end,
            isAllDay: isAllDay,
            extraStudyMinutes: defaultExtra,
            isSelected: true
        )
    }

    private struct ExtractedDate {
        var startDate: Date
        var endDate: Date?
        var isAllDay: Bool
    }

    private func extractDate(from line: String) -> ExtractedDate? {
        let currentYear = calendar.component(Calendar.Component.year, from: referenceDate)

        // 1. Check ISO date or slash dates within line tokens
        let cleanTokens = line
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        for token in cleanTokens {
            // ISO date YYYY-MM-DD or YYYY/MM/DD
            let isHyphen = token.contains("-")
            let isSlash = token.contains("/")
            if isHyphen || isSlash {
                let parts = isHyphen ? token.components(separatedBy: "-") : token.components(separatedBy: "/")
                if parts.count == 3 && parts[0].count == 4,
                   let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
                   y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                    return constructDate(year: y, month: m, day: d, line: line)
                }
            }

            // Slash date MM/DD or MM/DD/YYYY
            if token.contains("/") {
                let parts = token.components(separatedBy: "/")
                if parts.count == 2,
                   let m = Int(parts[0]), let d = Int(parts[1]),
                   m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                    return constructDate(year: currentYear, month: m, day: d, line: line)
                } else if parts.count == 3,
                          let m = Int(parts[0]), let d = Int(parts[1]), var y = Int(parts[2]),
                          m >= 1 && m <= 12 && d >= 1 && d <= 31 {
                    if y < 100 { y += 2000 }
                    return constructDate(year: y, month: m, day: d, line: line)
                }
            }
        }

        // 2. Check Month Name + Day (e.g. "Sept 22, 2026", "Oct 5", "October 15th")
        // and Day + Month Name (e.g. "22 Sept 2026", "15th October")
        for i in 0..<cleanTokens.count {
            let word = cleanTokens[i].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".:;,"))
            if let monthNum = Self.monthMap[word] {
                // Month Name followed by Day
                if i + 1 < cleanTokens.count {
                    let nextClean = cleanDay(cleanTokens[i + 1])
                    if let dayNum = Int(nextClean), dayNum >= 1 && dayNum <= 31 {
                        var year = currentYear
                        if i + 2 < cleanTokens.count {
                            let candidateYearStr = cleanTokens[i + 2].trimmingCharacters(in: CharacterSet(charactersIn: ".:;,"))
                            if let candidateYear = Int(candidateYearStr), candidateYear >= 2000 && candidateYear <= 2100 {
                                year = candidateYear
                            }
                        }
                        return constructDate(year: year, month: monthNum, day: dayNum, line: line)
                    }
                }

                // Day followed by Month Name
                if i > 0 {
                    let prevClean = cleanDay(cleanTokens[i - 1])
                    if let dayNum = Int(prevClean), dayNum >= 1 && dayNum <= 31 {
                        var year = currentYear
                        if i + 1 < cleanTokens.count {
                            let candidateYearStr = cleanTokens[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: ".:;,"))
                            if let candidateYear = Int(candidateYearStr), candidateYear >= 2000 && candidateYear <= 2100 {
                                year = candidateYear
                            }
                        }
                        return constructDate(year: year, month: monthNum, day: dayNum, line: line)
                    }
                }
            }
        }

        return nil
    }

    private func cleanDay(_ str: String) -> String {
        var s = str.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".:;,"))
        for suffix in ["st", "nd", "rd", "th"] {
            if s.hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count))
                break
            }
        }
        return s
    }

    private func constructDate(year: Int, month: Int, day: Int, line: String) -> ExtractedDate? {
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = day

        // Check for time in line
        if let timeInfo = extractTime(from: line) {
            startComponents.hour = timeInfo.startHour
            startComponents.minute = timeInfo.startMinute
            startComponents.second = 0
            guard let startDate = calendar.date(from: startComponents) else { return nil }

            var endDate: Date?
            if let endH = timeInfo.endHour, let endM = timeInfo.endMinute {
                var endComponents = startComponents
                endComponents.hour = endH
                endComponents.minute = endM
                endDate = calendar.date(from: endComponents)
            }

            return ExtractedDate(startDate: startDate, endDate: endDate, isAllDay: false)
        } else {
            // Default all-day date
            startComponents.hour = 12
            startComponents.minute = 0
            startComponents.second = 0
            guard let startDate = calendar.date(from: startComponents) else { return nil }
            return ExtractedDate(startDate: startDate, endDate: nil, isAllDay: true)
        }
    }

    private struct ExtractedTime {
        var startHour: Int
        var startMinute: Int
        var endHour: Int?
        var endMinute: Int?
    }

    private func extractTime(from line: String) -> ExtractedTime? {
        let lower = line.lowercased()

        // 11:59 pm or midnight shortcut
        if lower.contains("11:59") || lower.contains("midnight") {
            return ExtractedTime(startHour: 23, startMinute: 59, endHour: nil, endMinute: nil)
        }

        // Find all time specifications in the line
        let times = findAllTimes(in: line)
        if times.count >= 2 {
            return ExtractedTime(startHour: times[0].hour, startMinute: times[0].minute, endHour: times[1].hour, endMinute: times[1].minute)
        } else if times.count == 1 {
            return ExtractedTime(startHour: times[0].hour, startMinute: times[0].minute, endHour: nil, endMinute: nil)
        }

        return nil
    }

    private func findAllTimes(in line: String) -> [(hour: Int, minute: Int)] {
        var results: [(hour: Int, minute: Int)] = []

        let tokens = line
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        for i in 0..<tokens.count {
            let raw = tokens[i].trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            let lower = raw.lowercased()

            // Check if token has colon, e.g. "2:00", "10:00", "11:00am", "2:00pm"
            if raw.contains(":") {
                let parts = raw.components(separatedBy: ":")
                if parts.count == 2, let h = Int(parts[0]) {
                    var mStr = parts[1].lowercased()
                    var amPm: String? = nil

                    if mStr.hasSuffix("am") {
                        amPm = "am"
                        mStr = String(mStr.dropLast(2))
                    } else if mStr.hasSuffix("pm") {
                        amPm = "pm"
                        mStr = String(mStr.dropLast(2))
                    }

                    if let m = Int(mStr), h >= 0 && h <= 23 && m >= 0 && m <= 59 {
                        var finalH = h
                        // Look ahead for AM/PM if not in token
                        if amPm == nil && i + 1 < tokens.count {
                            let nextLower = tokens[i + 1].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                            if nextLower == "am" || nextLower == "pm" {
                                amPm = nextLower
                            }
                        }

                        if amPm == "pm" && finalH < 12 { finalH += 12 }
                        if amPm == "am" && finalH == 12 { finalH = 0 }

                        results.append((hour: finalH, minute: m))
                    }
                }
            } else if lower.hasSuffix("am") || lower.hasSuffix("pm") {
                // e.g. "10am", "2pm"
                let isPm = lower.hasSuffix("pm")
                let numStr = String(lower.dropLast(2))
                if let h = Int(numStr), h >= 1 && h <= 12 {
                    var finalH = h
                    if isPm && finalH < 12 { finalH += 12 }
                    if !isPm && finalH == 12 { finalH = 0 }
                    results.append((hour: finalH, minute: 0))
                }
            }
        }

        return results
    }

    public func detectKind(from text: String) -> AssessmentKind {
        let lower = text.lowercased()
        let testKeywords = ["midterm", "exam", "quiz", "term test", "test", "final", "mid-term"]
        let hwKeywords = ["assignment", "problem set", "homework", "project", "paper", "essay", "lab report", "deliverable", "milestone", "submission", "writeup"]

        var testScore = 0
        var hwScore = 0

        for k in testKeywords {
            if lower.contains(k) { testScore += (k == "midterm" || k == "exam" || k == "quiz") ? 2 : 1 }
        }
        for k in hwKeywords {
            if lower.contains(k) { hwScore += (k == "assignment" || k == "homework" || k == "problem set" || k == "project") ? 2 : 1 }
        }

        if testScore > 0 && testScore >= hwScore {
            return AssessmentKind.test
        }
        return AssessmentKind.homework
    }

    public func extractTitle(from line: String, kind: AssessmentKind, courseCode: String? = nil) -> String {
        var raw = line

        // Handle table columns separated by |
        if raw.contains("|") {
            let cells = raw.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let candidateCells = cells.filter { cell in
                let lower = cell.lowercased()
                if lower.contains("week") || lower.contains("period") || lower.contains("schedule") {
                    return false
                }
                return lower.contains("midterm") || lower.contains("test") || lower.contains("exam")
                    || lower.contains("quiz") || lower.contains("assignment") || lower.contains("homework")
                    || lower.contains("project") || lower.contains("paper") || lower.contains("essay")
                    || lower.contains("problem set")
            }
            if let target = candidateCells.first {
                raw = target
            } else if let fallback = cells.first(where: { cell in
                let lower = cell.lowercased()
                return lower.contains("midterm") || lower.contains("test") || lower.contains("exam")
                    || lower.contains("quiz") || lower.contains("assignment") || lower.contains("homework")
            }) {
                raw = fallback
            }
        }

        // Clean leading bullets or numbering
        raw = raw.trimmingCharacters(in: .whitespaces)
        while let first = raw.first, first == "-" || first == "*" || first == "•" || first == "+" {
            raw = String(raw.dropFirst())
            raw = raw.trimmingCharacters(in: .whitespaces)
        }
        if let firstChar = raw.first, firstChar >= "0" && firstChar <= "9" {
            var idx = raw.startIndex
            while idx < raw.endIndex && raw[idx] >= "0" && raw[idx] <= "9" {
                idx = raw.index(after: idx)
            }
            if idx < raw.endIndex && (raw[idx] == "." || raw[idx] == ")") {
                raw = String(raw[raw.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // If line contains a colon separator (e.g., "Assignment 1: Sept 22..."), check if left side is the title
        if raw.contains(":") {
            let parts = raw.components(separatedBy: ":")
            let left = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: " -*•+ \t"))
            let lowerLeft = left.lowercased()
            let hasTitleKeyword = lowerLeft.contains("midterm") || lowerLeft.contains("exam") || lowerLeft.contains("quiz")
                || lowerLeft.contains("test") || lowerLeft.contains("final") || lowerLeft.contains("assignment")
                || lowerLeft.contains("homework") || lowerLeft.contains("project") || lowerLeft.contains("essay")
                || lowerLeft.contains("paper") || lowerLeft.contains("problem set") || lowerLeft.contains("lab")

            if hasTitleKeyword {
                raw = left
            }
        }

        // Strip percentages / weights e.g. "(10%)", "20%"
        let tokens = raw.split(separator: " ").map { String($0) }
        let filtered = tokens.filter { word in
            let cleaned = word.trimmingCharacters(in: CharacterSet(charactersIn: "()[]{}% \t"))
            if word.contains("%") && (Int(cleaned) != nil || cleaned.isEmpty) {
                return false
            }
            return true
        }
        raw = filtered.joined(separator: " ")

        // Clean extra colons, hyphens, and whitespace
        raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: " :-–—,.\t"))

        if raw.isEmpty {
            let prefix = courseCode.map { "\($0) " } ?? ""
            return kind == AssessmentKind.test ? "\(prefix)Test" : "\(prefix)Assignment"
        }

        return raw
    }
}
