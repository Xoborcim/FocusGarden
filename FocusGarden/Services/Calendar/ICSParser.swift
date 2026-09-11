import Foundation

struct ParsedICSEvent: Equatable, Sendable {
    var summary: String
    var start: Date
    var end: Date
    var timeZoneIdentifier: String
    var recurrenceWeekdays: [Int]
    var hasWeeklyRecurrence: Bool
    var recurrenceUntil: Date?
    var isAllDay: Bool
    var location: String
}

struct ICSWarning: Equatable, Sendable {
    var message: String
}

struct InferredCourse: Equatable, Sendable {
    var code: String
    var titleHint: String
    var meetingType: String
}

struct ICSClassPreview: Equatable, Sendable, Identifiable {
    var id: String { fingerprint }
    var courseCode: String
    var courseTitle: String
    var meetingType: String
    var dayOfWeek: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var cognitiveWeight: Double
    var fingerprint: String
    var sampleSummary: String
    var validFrom: Date
    var validUntil: Date
    var termID: String
}

public enum AssessmentKind: String, CaseIterable, Sendable {
    case test
    case homework

    public var displayName: String {
        switch self {
        case .test: "Test"
        case .homework: "Homework"
        }
    }
}

struct ICSAssessmentPreview: Equatable, Sendable, Identifiable {
    var id: String { fingerprint }
    var courseCode: String
    var courseTitle: String
    var kind: AssessmentKind
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var fingerprint: String
}

struct ICSParseResult: Equatable, Sendable {
    var previews: [ICSClassPreview]
    var assessments: [ICSAssessmentPreview]
    var warnings: [ICSWarning]

    func terms(calendar: Calendar) -> [AcademicTerm] {
        var seen = Set<AcademicTerm>()
        var result: [AcademicTerm] = []
        for preview in previews {
            let term = AcademicTerm.containing(preview.validFrom, calendar: calendar)
            if seen.insert(term).inserted { result.append(term) }
        }
        for assessment in assessments {
            let term = AcademicTerm.containing(assessment.start, calendar: calendar)
            if seen.insert(term).inserted { result.append(term) }
        }
        return result.sorted { $0.start(calendar: calendar) < $1.start(calendar: calendar) }
    }

    func filtered(to term: AcademicTerm, calendar: Calendar) -> ICSParseResult {
        ICSParseResult(
            previews: previews.filter { AcademicTerm.containing($0.validFrom, calendar: calendar) == term },
            assessments: assessments.filter { term.contains($0.start, calendar: calendar) },
            warnings: warnings
        )
    }

    func preferredTerm(now: Date, calendar: Calendar) -> AcademicTerm? {
        let available = terms(calendar: calendar)
        guard !available.isEmpty else { return nil }
        let current = AcademicTerm.containing(now, calendar: calendar)
        let overlapping = available.filter { term in
            previews.contains {
                AcademicTerm.containing($0.validFrom, calendar: calendar) == term
                    && $0.validFrom <= now
                    && $0.validUntil >= now
            } || assessments.contains {
                term.contains($0.start, calendar: calendar) && $0.start >= now
            }
        }
        if overlapping.contains(current) { return current }
        if let hit = overlapping.first { return hit }
        if available.contains(current) { return current }
        return available.first { $0.start(calendar: calendar) > now } ?? available.last
    }
}

struct ICSParser: Sendable {
    var defaultTimeZone: TimeZone

    init(defaultTimeZone: TimeZone = TimeZone(identifier: "America/Toronto") ?? .current) {
        self.defaultTimeZone = defaultTimeZone
    }

    func parse(data: Data) -> ICSParseResult {
        guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return ICSParseResult(
                previews: [],
                assessments: [],
                warnings: [ICSWarning(message: "Could not read that calendar file.")]
            )
        }

        let unfolded = unfold(raw)
        let chunks = eventChunks(in: unfolded)
        var events: [ParsedICSEvent] = []
        var warnings: [ICSWarning] = []

        for chunk in chunks {
            if let event = parseEvent(chunk, warnings: &warnings) {
                events.append(event)
            }
        }

        var classEvents: [ParsedICSEvent] = []
        var assessments: [ICSAssessmentPreview] = []
        var seenAssessment = Set<String>()

        for event in events {
            switch ICSEventClassifier.classify(event) {
            case .skip:
                continue
            case .assessment(let kind):
                let preview = assessmentPreview(from: event, kind: kind)
                if seenAssessment.insert(preview.fingerprint).inserted {
                    assessments.append(preview)
                }
            case .classMeeting:
                classEvents.append(event)
            }
        }

        return ICSParseResult(
            previews: groupWeeklyEquivalents(classEvents),
            assessments: assessments.sorted { $0.start < $1.start },
            warnings: warnings
        )
    }

    func unfold(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    func inferCourse(from summary: String) -> InferredCourse {
        let parsed = CourseCodeParser.parse(title: summary)
        let meeting = CourseCodeParser.meetingType(in: summary)
        return InferredCourse(
            code: parsed?.code ?? "",
            titleHint: parsed?.nameHint ?? summary,
            meetingType: meeting
        )
    }

    func fingerprint(code: String, dayOfWeek: Int, startTime: TimeInterval, duration: TimeInterval, meetingType: String, termID: String) -> String {
        let startMinutes = Int((startTime / 60).rounded())
        let durationMinutes = Int((duration / 60).rounded())
        return "\(code.uppercased())|\(dayOfWeek)|\(startMinutes)|\(durationMinutes)|\(MeetingTypeWeight.normalized(meetingType))|\(termID)"
    }

    private func assessmentPreview(from event: ParsedICSEvent, kind: AssessmentKind) -> ICSAssessmentPreview {
        let inferred = inferCourse(from: event.summary)
        let code = inferred.code.isEmpty ? "COURSE" : inferred.code
        let startStamp = Int(event.start.timeIntervalSince1970)
        return ICSAssessmentPreview(
            courseCode: code,
            courseTitle: inferred.titleHint,
            kind: kind,
            title: event.summary,
            start: event.start,
            end: event.end,
            isAllDay: event.isAllDay,
            fingerprint: "\(kind.rawValue)|\(code)|\(startStamp)|\(event.summary.uppercased())"
        )
    }

    private func eventChunks(in text: String) -> [[String: String]] {
        var events: [[String: String]] = []
        var current: [String: String] = [:]
        var inside = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "BEGIN:VEVENT" {
                inside = true
                current = [:]
                continue
            }
            if trimmed == "END:VEVENT" {
                if inside { events.append(current) }
                inside = false
                continue
            }
            guard inside, let colon = trimmed.firstIndex(of: ":") else { continue }
            let keyPart = String(trimmed[..<colon])
            let value = String(trimmed[trimmed.index(after: colon)...])
            let key = (keyPart.split(separator: ";").first.map { String($0) } ?? keyPart).uppercased()
            current[key] = unescape(value)
            current["\(key)_PARAMS"] = keyPart
        }
        return events
    }

    private func parseEvent(_ chunk: [String: String], warnings: inout [ICSWarning]) -> ParsedICSEvent? {
        let summary = chunk["SUMMARY"] ?? "Class"
        let startParams = chunk["DTSTART_PARAMS"]
        let isAllDay = isDateOnly(chunk["DTSTART"], params: startParams)
        guard let start = parseICSDate(chunk["DTSTART"], params: startParams, isAllDay: isAllDay) else {
            warnings.append(ICSWarning(message: "Skipped “\(summary)” because DTSTART was missing or invalid."))
            return nil
        }
        let parsedEnd = parseICSDate(chunk["DTEND"], params: chunk["DTEND_PARAMS"], isAllDay: isAllDay)
        let end: Date
        if let parsedEnd, parsedEnd > start {
            end = parsedEnd
        } else if isAllDay {
            end = start.addingTimeInterval(24 * 3600)
        } else {
            end = start.addingTimeInterval(3600)
            if parsedEnd != nil {
                warnings.append(ICSWarning(message: "“\(summary)” had an inverted end time; used a 1-hour duration."))
            }
        }
        let tzid = timeZone(from: startParams)?.identifier ?? defaultTimeZone.identifier
        let weekly = hasWeeklyRule(chunk["RRULE"])
        let weekdays = weekdays(from: chunk["RRULE"], fallback: weekday(of: start, tzid: tzid))
        return ParsedICSEvent(
            summary: summary,
            start: start,
            end: end,
            timeZoneIdentifier: tzid,
            recurrenceWeekdays: weekdays,
            hasWeeklyRecurrence: weekly,
            recurrenceUntil: recurrenceUntil(from: chunk["RRULE"]),
            isAllDay: isAllDay,
            location: chunk["LOCATION"] ?? ""
        )
    }

    private func groupWeeklyEquivalents(_ events: [ParsedICSEvent]) -> [ICSClassPreview] {
        var grouped: [String: ICSClassPreview] = [:]
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = defaultTimeZone

        for event in events {
            let tz = TimeZone(identifier: event.timeZoneIdentifier) ?? defaultTimeZone
            calendar.timeZone = tz
            let term = AcademicTerm.containing(event.start, calendar: calendar)
            let startMinutes = calendar.component(.hour, from: event.start) * 60 + calendar.component(.minute, from: event.start)
            let duration = max(60.0, event.end.timeIntervalSince(event.start))
            let inferred = inferCourse(from: event.summary)
            let days = event.recurrenceWeekdays.isEmpty ? [calendar.component(.weekday, from: event.start)] : event.recurrenceWeekdays
            let until = event.recurrenceUntil ?? event.start
            for day in days {
                let startTime = Double(startMinutes * 60)
                let code = inferred.code.isEmpty ? event.summary : inferred.code
                let key = fingerprint(
                    code: code,
                    dayOfWeek: day,
                    startTime: startTime,
                    duration: duration,
                    meetingType: inferred.meetingType,
                    termID: term.id
                )
                if var existing = grouped[key] {
                    existing.validFrom = min(existing.validFrom, event.start)
                    existing.validUntil = max(existing.validUntil, until)
                    grouped[key] = existing
                } else {
                    grouped[key] = ICSClassPreview(
                        courseCode: inferred.code.isEmpty ? code : inferred.code,
                        courseTitle: inferred.titleHint,
                        meetingType: inferred.meetingType,
                        dayOfWeek: day,
                        startTime: startTime,
                        duration: duration,
                        cognitiveWeight: MeetingTypeWeight.cognitiveWeight(for: inferred.meetingType),
                        fingerprint: key,
                        sampleSummary: event.summary,
                        validFrom: event.start,
                        validUntil: until,
                        termID: term.id
                    )
                }
            }
        }

        return grouped.values.sorted {
            if $0.termID != $1.termID { return $0.termID < $1.termID }
            if $0.dayOfWeek != $1.dayOfWeek { return $0.dayOfWeek < $1.dayOfWeek }
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.courseCode < $1.courseCode
        }
    }

    func parseICSDate(_ value: String?, params: String? = nil, isAllDay: Bool = false) -> Date? {
        guard var raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let declared = timeZone(from: params)
        let hasZ = raw.hasSuffix("Z")
        if hasZ { raw = String(raw.dropLast()) }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = isAllDay ? defaultTimeZone : (declared ?? (hasZ ? TimeZone(secondsFromGMT: 0) : defaultTimeZone))

        for format in ["yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    func timeZone(from params: String?) -> TimeZone? {
        guard let params else { return nil }
        let upper = params.uppercased()
        guard let match = upper.range(of: "TZID=") else { return nil }
        let after = upper[match.upperBound...]
        let tzid = (after.split(separator: ";").first.map { String($0) } ?? String(after))
            .trimmingCharacters(in: CharacterSet.whitespaces)
        if let zone = TimeZone(identifier: tzid) { return zone }
        if tzid == "AMERICA/TORONTO" {
            return TimeZone(identifier: "America/Toronto")
        }
        if let slash = tzid.firstIndex(of: "/") {
            let region = tzid[..<slash].lowercased().capitalized
            let city = tzid[tzid.index(after: slash)...]
                .split(separator: "_")
                .map { $0.lowercased().capitalized }
                .joined(separator: "_")
            return TimeZone(identifier: "\(region)/\(city)")
        }
        return nil
    }

    private func isDateOnly(_ value: String?, params: String?) -> Bool {
        let paramsUpper = params?.uppercased() ?? ""
        if paramsUpper.contains("VALUE=DATE") && !paramsUpper.contains("DATE-TIME") { return true }
        guard let value else { return false }
        let raw = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if raw.count != 8 { return false }
        for ch in raw {
            if ch < "0" || ch > "9" { return false }
        }
        return true
    }

    private func hasWeeklyRule(_ rrule: String?) -> Bool {
        rrule?.uppercased().contains("FREQ=WEEKLY") == true
    }

    private func recurrenceUntil(from rrule: String?) -> Date? {
        guard let rrule else { return nil }
        guard let part = rrule.split(separator: ";").first(where: { $0.uppercased().hasPrefix("UNTIL=") }) else {
            return nil
        }
        let raw = String(part.dropFirst(6))
        return parseICSDate(raw, isAllDay: !raw.contains("T"))
    }

    private func weekdays(from rrule: String?, fallback: Int) -> [Int] {
        let mapping: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
        guard let rrule, rrule.uppercased().contains("FREQ=WEEKLY") else { return [fallback] }
        guard let byDay = rrule.split(separator: ";").first(where: { $0.uppercased().hasPrefix("BYDAY=") }) else {
            return [fallback]
        }
        let codes = byDay.dropFirst(6).split(separator: ",")
        let days = codes.compactMap { mapping[String($0).uppercased()] }
        return days.isEmpty ? [fallback] : days
    }

    private func weekday(of date: Date, tzid: String) -> Int {
        var calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: tzid) ?? defaultTimeZone
        return calendar.component(.weekday, from: date)
    }

    private func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

enum ICSEventClassifier {
    enum Result: Equatable {
        case classMeeting
        case assessment(AssessmentKind)
        case skip
    }

    static func classify(_ event: ParsedICSEvent) -> Result {
        let summary = event.summary
        let upper = summary.uppercased()
        if isNoise(upper) { return .skip }
        if isTest(upper) { return .assessment(.test) }
        if isHomework(upper) { return .assessment(.homework) }
        let meeting = CourseCodeParser.meetingType(in: summary)
        if event.isAllDay && meeting != "LEC" && meeting != "TUT" && meeting != "LAB" {
            return .assessment(.homework)
        }
        return .classMeeting
    }

    static func isTest(_ upper: String) -> Bool {
        let tokens = ["EXAM", "MIDTERM", "FINAL", "TEST", "QUIZ", "TERM TEST"]
        return tokens.contains { upper.contains($0) }
    }

    static func isHomework(_ upper: String) -> Bool {
        let tokens = [
            "ASSIGNMENT", "HOMEWORK", "HW ", " HW", "PROBLEM SET", "PROBLEMSET",
            "ESSAY", "PROJECT", "LAB REPORT", "SUBMISSION", "DUE",
            "PS1", "PS2", "PS3", "PS4", "PS5", "PS6", "PS7", "PS8", "PS9", "PS0",
            "HW1", "HW2", "HW3", "HW4", "HW5", "HW6", "HW7", "HW8", "HW9", "HW0"
        ]
        if tokens.contains(where: { upper.contains($0) }) { return true }
        return false
    }

    private static func isNoise(_ upper: String) -> Bool {
        let tokens = ["OFFICE HOUR", "READING WEEK", "HOLIDAY", "UNIVERSITY CLOSED", "CANCELLED", "CANCELED"]
        return tokens.contains { upper.contains($0) }
    }
}

enum CourseCodeParser {
    struct ParsedCourseBlock: Equatable {
        var code: String
        var nameHint: String?
    }

    static func parse(title: String) -> ParsedCourseBlock? {
        let trimmed = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let words = trimmed.split(separator: " ").map { String($0) }
        guard !words.isEmpty else { return nil }

        // Try spaced: e.g. ["CHEM", "112A", "001", "Tutorial"]
        if words.count >= 2 {
            let first = words[0].uppercased()
            let second = words[1].uppercased()
            if isSubjectPrefix(first) && isCourseNumber(second) {
                let code = "\(first)\(second)"
                let matchedSpan = "\(words[0]) \(words[1])"
                return ParsedCourseBlock(
                    code: code,
                    nameHint: cleanedName(from: trimmed, matchedSpan: matchedSpan)
                )
            }
        }

        // Try compact: e.g. "MGT225H5" at words[0] or any word
        for word in words {
            let upper = word.uppercased()
            if let compactCode = extractCompactCode(upper) {
                return ParsedCourseBlock(
                    code: compactCode,
                    nameHint: cleanedName(from: trimmed, matchedSpan: word)
                )
            }
        }

        return nil
    }

    private static func isSubjectPrefix(_ str: String) -> Bool {
        if str.count < 2 || str.count > 5 { return false }
        for ch in str {
            let isUpper = (ch >= "A" && ch <= "Z")
            let isLower = (ch >= "a" && ch <= "z")
            if !isUpper && !isLower { return false }
        }
        return true
    }

    private static func isCourseNumber(_ str: String) -> Bool {
        if str.count < 3 { return false }
        var count = 0
        for ch in str {
            if count < 3 {
                if ch < "0" || ch > "9" { return false }
                count += 1
            } else {
                break
            }
        }
        return count == 3
    }

    private static func extractCompactCode(_ str: String) -> String? {
        var letterCount = 0
        var digitCount = 0
        var suffixCount = 0
        var mode = 0 // 0: letters, 1: digits, 2: suffix
        var matched = ""

        for ch in str {
            let s = String(ch)
            if mode == 0 {
                if (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") {
                    letterCount += 1
                    matched += s
                } else if letterCount >= 2 && letterCount <= 5 && (ch >= "0" && ch <= "9") {
                    mode = 1
                    digitCount += 1
                    matched += s
                } else {
                    return nil
                }
            } else if mode == 1 {
                if ch >= "0" && ch <= "9" {
                    digitCount += 1
                    matched += s
                } else if digitCount >= 3 && ((ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z")) {
                    mode = 2
                    suffixCount += 1
                    matched += s
                } else if digitCount >= 3 {
                    break
                } else {
                    return nil
                }
            } else if mode == 2 {
                if (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") {
                    suffixCount += 1
                    matched += s
                } else {
                    break
                }
            }
        }
        guard letterCount >= 2 && letterCount <= 5 && digitCount >= 3 else { return nil }
        return matched.uppercased()
    }

    static func meetingType(in title: String) -> String {
        let upper = title.uppercased()
        if ICSEventClassifier.isTest(upper) { return "EXAM" }
        if ICSEventClassifier.isHomework(upper) { return "HW" }
        if upper.contains("TUT") || upper.contains("TUTORIAL") { return "TUT" }
        if upper.contains("LEC") || upper.contains("LECTURE") { return "LEC" }
        if upper.contains("LAB") || upper.contains("PRA") { return "LAB" }
        return ""
    }

    private static func cleanedName(from title: String, matchedSpan: String) -> String? {
        var cleaned = title.replacingOccurrences(of: matchedSpan, with: " ")
        let noiseWords: [String] = ["LEC", "TUT", "PRA", "LAB", "SEM", "EXAM", "MIDTERM", "FINAL", "TEST", "QUIZ", "ASSIGNMENT", "HOMEWORK", "HW", "DUE"]
        let parts = cleaned.split(separator: " ").map { String($0) }
        let filtered = parts.filter { part in
            let up = part.uppercased()
            if noiseWords.contains(up) { return false }
            if up.count == 3 {
                var allDigits = true
                for ch in up {
                    if ch < "0" || ch > "9" { allDigits = false; break }
                }
                if allDigits { return false }
            }
            return true
        }
        cleaned = filtered.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return cleaned.count >= 3 ? cleaned : nil
    }
}
