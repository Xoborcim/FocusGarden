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

enum AssessmentKind: String, CaseIterable, Sendable {
    case test
    case homework

    var displayName: String {
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
            let key = (keyPart.split(separator: ";").first.map(String.init) ?? keyPart).uppercased()
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = defaultTimeZone

        for event in events {
            let tz = TimeZone(identifier: event.timeZoneIdentifier) ?? defaultTimeZone
            calendar.timeZone = tz
            let term = AcademicTerm.containing(event.start, calendar: calendar)
            let startMinutes = calendar.component(.hour, from: event.start) * 60 + calendar.component(.minute, from: event.start)
            let duration = max(60, event.end.timeIntervalSince(event.start))
            let inferred = inferCourse(from: event.summary)
            let days = event.recurrenceWeekdays.isEmpty ? [calendar.component(.weekday, from: event.start)] : event.recurrenceWeekdays
            let until = event.recurrenceUntil ?? event.start
            for day in days {
                let startTime = TimeInterval(startMinutes * 60)
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
        if hasZ { raw.removeLast() }

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
        guard let params, let match = params.range(of: "TZID=", options: .caseInsensitive) else { return nil }
        let after = params[match.upperBound...]
        let tzid = (after.split(separator: ";").first.map(String.init) ?? String(after))
            .trimmingCharacters(in: .whitespaces)
        if let zone = TimeZone(identifier: tzid) { return zone }
        if tzid.uppercased() == "AMERICA/TORONTO" {
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
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.count == 8 && raw.allSatisfy(\.isNumber)
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
        var calendar = Calendar(identifier: .gregorian)
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
        upper.range(of: #"\b(EXAM|MIDTERM|FINAL|TEST|QUIZ|TERM TEST)\b"#, options: .regularExpression) != nil
    }

    static func isHomework(_ upper: String) -> Bool {
        let tokens = [
            "ASSIGNMENT", "HOMEWORK", "HW ", " HW", "PROBLEM SET", "PROBLEMSET",
            "ESSAY", "PROJECT", "LAB REPORT", "SUBMISSION", "DUE", "PS1", "PS2", "PS3", "PS4"
        ]
        if tokens.contains(where: { upper.contains($0) }) { return true }
        if upper.range(of: #"\bHW\d+\b"#, options: .regularExpression) != nil { return true }
        if upper.range(of: #"\bPS\d+\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func isNoise(_ upper: String) -> Bool {
        let tokens = ["OFFICE HOUR", "READING WEEK", "HOLIDAY", "UNIVERSITY CLOSED", "CANCELLED", "CANCELED"]
        return tokens.contains { upper.contains($0) }
    }
}

enum CourseCodeParser {
    private static let compactCodePattern = #/(?i)\b([A-Z]{2,5}\d{3}[A-Z]?\d?[A-Z]?)\b/#
    private static let spacedCodePattern = #/(?i)\b([A-Z]{2,5})\s+(\d{3}[A-Z]?)(?:\s+(\d{3}))?\b/#

    struct ParsedCourseBlock: Equatable {
        var code: String
        var nameHint: String?
    }

    static func parse(title: String) -> ParsedCourseBlock? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaced = trimmed.firstMatch(of: spacedCodePattern) {
            let subject = String(spaced.output.1).uppercased()
            let number = String(spaced.output.2).uppercased()
            return ParsedCourseBlock(
                code: "\(subject)\(number)",
                nameHint: cleanedName(from: trimmed, matchedSpan: String(spaced.output.0))
            )
        }
        guard let match = trimmed.firstMatch(of: compactCodePattern) else { return nil }
        let code = String(match.output.1).uppercased()
        return ParsedCourseBlock(code: code, nameHint: cleanedName(from: trimmed, matchedSpan: code))
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
        var cleaned = title.replacingOccurrences(of: matchedSpan, with: " ", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(
            of: #"\b(LEC|TUT|PRA|LAB|SEM|EXAM|MIDTERM|FINAL|TEST|QUIZ|ASSIGNMENT|HOMEWORK|HW|DUE|\d{3})\b"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count >= 3 ? cleaned : nil
    }
}
