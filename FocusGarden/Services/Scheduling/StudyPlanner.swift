import Foundation

struct CourseWorkload: Equatable, Sendable {
    var code: String
    var weeklyClassMinutes: Int
    var firstClassEnd: Date? = nil
    var difficulty: Int = 3
}

struct AssessmentEvent: Equatable, Sendable {
    var fingerprint: String
    var title: String
    var kind: AssessmentKind
    var start: Date
    var end: Date
    var isAllDay: Bool
    var courseCode: String
    var extraStudyMinutes: Int = 0
    var courseDifficulty: Int = 3
}

struct GeneratedStudyItem: Equatable, Sendable, Identifiable {
    var id: String { generationKey }
    var generationKey: String
    var title: String
    var minutes: Int
    var priority: Int
    var kind: TaskKind
    var deadline: Date?
    var courseCode: String
    var assessmentFingerprint: String
    var earliestStart: Date? = nil
    var latestEnd: Date? = nil
}

struct StudyPlanner: Sendable {
    func plan(
        courses: [CourseWorkload],
        assessments: [AssessmentEvent],
        now: Date,
        configuration: AppConfiguration,
        schoolStart: Date? = nil
    ) -> [GeneratedStudyItem] {
        let calendar = configuration.calendar()
        let horizonEnd = calendar.date(byAdding: .day, value: configuration.horizonDays, to: calendar.startOfDay(for: now)) ?? now
        var items: [GeneratedStudyItem] = []

        var seenCourseCodes = Set<String>()
        for course in courses {
            let code = course.code.uppercased()
            guard seenCourseCodes.insert(code).inserted else { continue }
            items.append(contentsOf: weeklyStudy(
                for: course,
                now: now,
                horizonEnd: horizonEnd,
                schoolStart: schoolStart,
                calendar: calendar,
                configuration: configuration
            ))
        }

        var seenFingerprints = Set<String>()
        for assessment in assessments {
            guard seenFingerprints.insert(assessment.fingerprint).inserted else { continue }
            let due = assessment.isAllDay ? assessment.end.addingTimeInterval(-60) : assessment.start
            guard due > now else { continue }
            if let schoolStart, due <= schoolStart { continue }
            items.append(contentsOf: specialStudy(
                for: assessment,
                due: due,
                now: now,
                schoolStart: schoolStart,
                configuration: configuration
            ))
        }

        return items.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture)
        }
    }

    func weeklyStudyMinutes(classMinutes: Int, difficulty: Int = 3) -> Int {
        guard classMinutes > 0 else { return 0 }
        return Int((Double(classMinutes) * 1.2).rounded())
    }

    func difficultyFactor(_ difficulty: Int) -> Double {
        switch Course.clampedDifficulty(difficulty) {
        case 1: return 0.7
        case 2: return 0.85
        case 3: return 1.0
        case 4: return 1.25
        default: return 1.5
        }
    }

    func prepMinutes(for assessment: AssessmentEvent) -> Int {
        let title = assessment.title.uppercased()
        let base: Int
        switch assessment.kind {
        case .test:
            if title.contains("FINAL") { base = 240 }
            else if title.contains("MIDTERM") || title.contains("TERM TEST") { base = 180 }
            else if assessment.isAllDay { base = 150 }
            else {
                let examMinutes = max(60, Int(assessment.end.timeIntervalSince(assessment.start) / 60))
                base = min(240, max(90, examMinutes * 2))
            }
        case .homework:
            if title.contains("PROJECT") || title.contains("ESSAY") || title.contains("PAPER") {
                base = 150
            } else {
                base = 90
            }
        }
        let scaled = Int((Double(base) * difficultyFactor(assessment.courseDifficulty)).rounded())
        return scaled + max(0, assessment.extraStudyMinutes)
    }

    private func weeklyStudy(
        for course: CourseWorkload,
        now: Date,
        horizonEnd: Date,
        schoolStart: Date?,
        calendar: Calendar,
        configuration: AppConfiguration
    ) -> [GeneratedStudyItem] {
        let weeklyMinutes = weeklyStudyMinutes(classMinutes: course.weeklyClassMinutes, difficulty: course.difficulty)
        guard weeklyMinutes > 0 else { return [] }

        // Split weekly lecture study strictly into 1-hour chunks (60 minutes each, with tail remainder)
        var remaining = weeklyMinutes
        var chunks: [Int] = []
        while remaining > 0 {
            let chunk = min(60, remaining)
            chunks.append(chunk)
            remaining -= chunk
        }

        let earliest = schoolStart
        let priority = course.difficulty <= 2 ? 1 : 2
        var items: [GeneratedStudyItem] = []
        var weekStart = calendar.startOfDay(for: now)
        weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)) ?? weekStart

        while weekStart < horizonEnd {
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            if let earliest, weekEnd <= earliest {
                guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
                weekStart = next
                continue
            }
            for (index, minutes) in chunks.enumerated() {
                items.append(
                    GeneratedStudyItem(
                        generationKey: "study|\(course.code.uppercased())|\(Int(weekStart.timeIntervalSince1970))|\(index)",
                        title: "\(course.code) study",
                        minutes: minutes,
                        priority: priority,
                        kind: .study,
                        deadline: min(weekEnd, horizonEnd),
                        courseCode: course.code,
                        assessmentFingerprint: "",
                        earliestStart: earliest,
                        latestEnd: weekEnd
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return items
    }

    private func specialStudy(
        for assessment: AssessmentEvent,
        due: Date,
        now: Date,
        schoolStart: Date?,
        configuration: AppConfiguration
    ) -> [GeneratedStudyItem] {
        let minutes = prepMinutes(for: assessment)
        let chunks = AutoSchedulingEngine().chunkMinutes(minutes, config: configuration)
        guard !chunks.isEmpty else { return [] }

        let calendar = configuration.calendar()
        let leadDays = max(1, configuration.assessmentLeadWeeks * 7)
        var windowStart = calendar.date(byAdding: .day, value: -leadDays, to: due).map { calendar.startOfDay(for: $0) } ?? due
        if let schoolStart {
            windowStart = max(windowStart, schoolStart)
        }
        windowStart = max(windowStart, calendar.startOfDay(for: now))
        guard windowStart < due else { return [] }

        let kind: TaskKind = assessment.kind == .test ? .testPrep : .homework
        let prefix = assessment.kind == .test ? "Study for" : "Work on"
        let title = shortTitle(assessment.title, fallback: assessment.courseCode)
        let span = due.timeIntervalSince(windowStart)
        let chunkCount = max(1, chunks.count)

        return chunks.enumerated().map { index, chunk in
            let fractions = spacedFraction(index: index, count: chunkCount, isTest: assessment.kind == .test)
            let fractionStart = fractions.start
            let fractionEnd = fractions.end
            var bucketStart = windowStart.addingTimeInterval(span * fractionStart)
            var bucketEnd = windowStart.addingTimeInterval(span * fractionEnd)
            let minimumSpan = TimeInterval(max(chunk * 60 + 60 * 60, 12 * 3600))
            if bucketEnd.timeIntervalSince(bucketStart) < minimumSpan {
                let center = bucketStart.addingTimeInterval(bucketEnd.timeIntervalSince(bucketStart) / 2)
                bucketStart = max(windowStart, center.addingTimeInterval(-minimumSpan / 2))
                bucketEnd = min(due, bucketStart.addingTimeInterval(minimumSpan))
                if bucketEnd.timeIntervalSince(bucketStart) < minimumSpan {
                    bucketStart = max(windowStart, bucketEnd.addingTimeInterval(-minimumSpan))
                }
            }
            if bucketEnd <= bucketStart {
                bucketStart = windowStart
                bucketEnd = due
            }

            return GeneratedStudyItem(
                generationKey: "\(kind.rawValue)|\(assessment.fingerprint)|\(index)",
                title: "\(prefix) \(title)",
                minutes: chunk,
                priority: 3,
                kind: kind,
                deadline: due,
                courseCode: assessment.courseCode,
                assessmentFingerprint: assessment.fingerprint,
                earliestStart: bucketStart,
                latestEnd: bucketEnd
            )
        }
    }

    private func shortTitle(_ summary: String, fallback: String) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 42 { return trimmed }
        if !fallback.isEmpty { return fallback }
        return String(trimmed.prefix(42))
    }

    private func spacedFraction(index: Int, count: Int, isTest: Bool) -> (start: Double, end: Double) {
        guard count > 1 else { return (0.0, 1.0) }
        if isTest {
            // Ebbinghaus spacing curve: early foundational review, progressive consolidation
            let fStart = pow(Double(index) / Double(count), 1.25)
            let fEnd = pow(Double(index + 1) / Double(count), 1.25)
            return (fStart, fEnd)
        } else {
            let fStart = Double(index) / Double(count)
            let fEnd = Double(index + 1) / Double(count)
            return (fStart, fEnd)
        }
    }
}
