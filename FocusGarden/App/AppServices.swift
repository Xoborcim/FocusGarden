import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct FocusTimerResult: @unchecked Sendable {
    var title: String
    var category: ActivityCategory
    var course: Course?
    var durationMinutes: Int
    var startTime: Date
    var endTime: Date

    init(
        title: String,
        category: ActivityCategory,
        course: Course? = nil,
        durationMinutes: Int,
        startTime: Date,
        endTime: Date
    ) {
        self.title = title
        self.category = category
        self.course = course
        self.durationMinutes = durationMinutes
        self.startTime = startTime
        self.endTime = endTime
    }
}

final class AppServicesInternalCache: @unchecked Sendable {
    var didBootstrap = false
    var cachedAppState: AppStateRecord? = nil
    var cachedRecentTitles: [String]? = nil
    var cachedDefaultActivities: [String]? = nil
}

#if !SKIP
import Observation
#endif

@Observable
@MainActor
final class AppServices {
    static let shared: AppServices = AppServices(container: PersistenceController.sharedContainer)

    #if !SKIP
    @ObservationIgnored
    #endif
    let container: ModelContainer
    #if !SKIP
    @ObservationIgnored
    #endif
    let clock: any Clock
    var configuration: AppConfiguration
    #if !SKIP
    @ObservationIgnored
    #endif
    let icsParser: ICSParser
    #if !SKIP
    @ObservationIgnored
    #endif
    let reminderService: StudyReminderService

    static let remindersEnabledKey = "remindersEnabled"

    var selectedDate: Date
    var selectedTab: Int = 0
    var activeSessionTaskID: UUID?
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    var remindersEnabled: Bool = (UserDefaults.standard.object(forKey: "remindersEnabled") as? Bool) ?? false
    var isReady = true

    #if !SKIP
    @ObservationIgnored
    #endif
    private let cache = AppServicesInternalCache()

    private var didBootstrap: Bool {
        get { cache.didBootstrap }
        set { cache.didBootstrap = newValue }
    }

    private var cachedAppState: AppStateRecord? {
        get { cache.cachedAppState }
        set { cache.cachedAppState = newValue }
    }

    private var cachedRecentTitles: [String]? {
        get { cache.cachedRecentTitles }
        set { cache.cachedRecentTitles = newValue }
    }

    private var cachedDefaultActivities: [String]? {
        get { cache.cachedDefaultActivities }
        set { cache.cachedDefaultActivities = newValue }
    }

    init(
        container: ModelContainer,
        clock: any Clock = SystemClock(),
        configuration: AppConfiguration = .userDefault
    ) {
        self.container = container
        self.clock = clock
        self.configuration = configuration
        self.icsParser = ICSParser(defaultTimeZone: configuration.timeZone)
        self.reminderService = StudyReminderService()
        self.selectedDate = clock.now
        self.isReady = true

        bootstrapSync()
    }

    var context: ModelContext { container.mainContext }

    var activeSessionTask: FocusTask? {
        guard let activeSessionTaskID else { return nil }
        return try? context.fetch(FetchDescriptor<FocusTask>()).first { $0.id == activeSessionTaskID && !$0.isCompleted }
    }

    func bootstrapSync() {
        guard !didBootstrap else { return }
        didBootstrap = true
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            cachedAppState = state
            applyStudyPreferences(from: state)
            if let saved = UserDefaults.standard.object(forKey: Self.remindersEnabledKey) as? Bool {
                remindersEnabled = saved
                if state.remindersEnabled != saved {
                    state.remindersEnabled = saved
                    try? context.save()
                }
            } else {
                remindersEnabled = state.remindersEnabled
                UserDefaults.standard.set(remindersEnabled, forKey: Self.remindersEnabledKey)
            }
            if !remindersEnabled {
                reminderService.cancelAll()
            }
            if state.hasCompletedOnboarding {
                hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            } else if hasCompletedOnboarding {
                state.hasCompletedOnboarding = true
                try? context.save()
            }
            if !state.hasResetStudySessionsFor1HourChunks {
                resetStudySessionsInternal()
                state.hasResetStudySessionsFor1HourChunks = true
                try? context.save()
            }
            if let active = try context.fetch(FetchDescriptor<FocusTask>()).first(where: { $0.isInSession }) {
                activeSessionTaskID = active.id
            }

            Task { await setupReminders() }
        } catch {}
    }

    func bootstrap() async {
        bootstrapSync()
    }

    func applyStudyPreferences(from state: AppStateRecord) {
        configuration.applyStudyPreferences(from: state)
    }

    func setStudyWindow(start: Date, end: Date) {
        let calendar = configuration.calendar()
        var startTotal = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        var endTotal = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)
        if startTotal >= endTotal {
            endTotal = min(startTotal + 60, 23 * 60 + 45)
            if endTotal <= startTotal {
                startTotal = max(0, endTotal - 60)
            }
        }
        persistStudyPreferences(
            startHour: startTotal / 60,
            startMinute: startTotal % 60,
            endHour: endTotal / 60,
            endMinute: endTotal % 60,
            allowBeforeFirstClass: configuration.allowBeforeFirstClass,
            allowBetweenClasses: configuration.allowBetweenClasses
        )
    }

    func setAllowBeforeFirstClass(_ value: Bool) {
        persistStudyPreferences(
            startHour: configuration.windowStartHour,
            startMinute: configuration.windowStartMinute,
            endHour: configuration.windowEndHour,
            endMinute: configuration.windowEndMinute,
            allowBeforeFirstClass: value,
            allowBetweenClasses: configuration.allowBetweenClasses
        )
    }

    func setAllowBetweenClasses(_ value: Bool) {
        persistStudyPreferences(
            startHour: configuration.windowStartHour,
            startMinute: configuration.windowStartMinute,
            endHour: configuration.windowEndHour,
            endMinute: configuration.windowEndMinute,
            allowBeforeFirstClass: configuration.allowBeforeFirstClass,
            allowBetweenClasses: value
        )
    }

    func updateRemindersEnabled(_ value: Bool) {
        remindersEnabled = value
        UserDefaults.standard.set(value, forKey: Self.remindersEnabledKey)
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            cachedAppState = state
            state.remindersEnabled = value
            try context.save()
        } catch {}
        if !value {
            reminderService.cancelAll()
        }
        Task { await setupReminders() }
    }

    func setAssessmentLeadWeeks(_ weeks: Int) {
        let clamped = max(1, min(8, weeks))
        guard configuration.assessmentLeadWeeks != clamped else { return }
        configuration.assessmentLeadWeeks = clamped
        configuration.horizonDays = max(21, clamped * 7 + 14)
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.assessmentLeadWeeks = clamped
            try context.save()
        } catch {}
        regenerate()
    }

    func setCommuteMinutesAfterLastClass(_ minutes: Int) {
        let clamped = max(0, min(180, minutes))
        guard configuration.commuteMinutesAfterLastClass != clamped else { return }
        configuration.commuteMinutesAfterLastClass = clamped
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.commuteMinutesAfterLastClass = clamped
            try context.save()
        } catch {}
        regenerate()
    }

    func setBreakMinutesBetweenSessions(_ minutes: Int) {
        let clamped = max(0, min(60, minutes))
        guard configuration.bufferMinutes != clamped else { return }
        configuration.bufferMinutes = clamped
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.breakMinutesBetweenSessions = clamped
            try context.save()
        } catch {}
        regenerate()
    }

    func setTimerIntervals(focus: Int, breakMinutes: Int) {
        let clampedFocus = max(5, min(120, focus))
        let clampedBreak = max(1, min(60, breakMinutes))
        guard configuration.timerFocusMinutes != clampedFocus || configuration.timerBreakMinutes != clampedBreak else { return }
        configuration.timerFocusMinutes = clampedFocus
        configuration.timerBreakMinutes = clampedBreak
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.timerFocusMinutes = clampedFocus
            state.timerBreakMinutes = clampedBreak
            try context.save()
        } catch {}
    }

    func setChronotype(_ chronotype: Chronotype) {
        guard configuration.chronotype != chronotype else { return }
        configuration.chronotype = chronotype
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.chronotype = chronotype
            try context.save()
        } catch {}
        regenerate()
    }

    func setExtraStudyMinutes(for assessment: Assessment, minutes: Int) {
        let clamped = max(0, min(600, minutes))
        guard assessment.extraStudyMinutes != clamped else { return }
        assessment.extraStudyMinutes = clamped
        try? context.save()
        regenerate()
    }

    func setCourseDifficulty(_ course: Course, difficulty: Int) {
        let clamped = Course.clampedDifficulty(difficulty)
        guard course.difficulty != clamped else { return }
        course.difficulty = clamped
        try? context.save()
        regenerate()
    }

    func updateClassBlock(
        _ block: ClassBlock,
        dayOfWeek: Int,
        startTime: TimeInterval,
        durationMinutes: Int,
        meetingType: String,
        location: String
    ) {
        let day = min(7, max(1, dayOfWeek))
        let duration = TimeInterval(max(15, durationMinutes) * 60)
        let type = meetingType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        block.dayOfWeek = day
        block.startTime = max(0.0, startTime)
        block.duration = duration
        block.meetingType = type.isEmpty ? block.meetingType : type
        block.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        block.cognitiveWeight = MeetingTypeWeight.cognitiveWeight(for: block.meetingType)
        let calendar = configuration.calendar()
        let term = block.term(now: clock.now, calendar: calendar)
        let code = block.course?.code ?? "CLASS"
        let startMinutes = Int(block.startTime / 60)
        let durationMinutesRounded = Int((block.duration / 60).rounded())
        block.fingerprint = "\(code.uppercased())|\(block.dayOfWeek)|\(startMinutes)|\(durationMinutesRounded)|\(MeetingTypeWeight.normalized(block.meetingType))|\(term.id)|manual"
        try? context.save()
        regenerate()
    }

    func deleteClassBlock(_ block: ClassBlock) {
        context.delete(block)
        try? context.save()
        regenerate()
    }

    func addClassBlock(
        course: Course,
        dayOfWeek: Int,
        startTime: TimeInterval,
        durationMinutes: Int,
        meetingType: String,
        location: String
    ) {
        let calendar = configuration.calendar()
        let now = clock.now
        let term = AcademicTerm.containing(now, calendar: calendar)
        let duration = TimeInterval(max(15, durationMinutes) * 60)
        let type = meetingType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedType = type.isEmpty ? "CLASS" : type
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = course.code.uppercased()
        let startMinutes = Int(startTime / 60)
        let durationMinutesRounded = Int((duration / 60).rounded())
        let fingerprint = "\(code)|\(dayOfWeek)|\(startMinutes)|\(durationMinutesRounded)|\(MeetingTypeWeight.normalized(normalizedType))|\(term.id)|manual"

        let block = ClassBlock(
            dayOfWeek: dayOfWeek,
            startTime: max(0.0, startTime),
            duration: duration,
            cognitiveWeight: MeetingTypeWeight.cognitiveWeight(for: normalizedType),
            course: course,
            meetingType: normalizedType,
            location: loc,
            fingerprint: fingerprint,
            timeZoneIdentifier: configuration.timeZone.identifier,
            summary: "\(course.displayName) (\(normalizedType))",
            validFrom: term.start(calendar: calendar),
            validUntil: term.end(calendar: calendar)
        )
        context.insert(block)
        if course.classBlocks == nil {
            course.classBlocks = []
        }
        course.classBlocks?.append(block)
        try? context.save()
        regenerate()
    }

    func updateCourse(_ course: Course, code: String, title: String) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCode.isEmpty {
            course.code = trimmedCode
        }
        course.title = trimmedTitle
        try? context.save()
        regenerate()
    }

    func addAssessments(_ items: [ParsedSyllabusItem], to course: Course) {
        for item in items where item.isSelected {
            let assessment = Assessment(
                title: item.title,
                kind: item.kind,
                start: item.date,
                end: item.endDate,
                isAllDay: item.isAllDay,
                fingerprint: "\(course.code.uppercased())|\(item.title)|\(item.date.timeIntervalSince1970)|syllabus",
                course: course,
                extraStudyMinutes: item.extraStudyMinutes
            )
            context.insert(assessment)
            if course.assessments == nil {
                course.assessments = []
            }
            course.assessments?.append(assessment)
        }
        try? context.save()
        regenerate()
    }

    func clockTime(hour: Int, minute: Int) -> Date {
        let calendar = configuration.calendar()
        var components = calendar.dateComponents([.year, .month, .day], from: clock.now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? clock.now
    }

    private func persistStudyPreferences(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        allowBeforeFirstClass: Bool,
        allowBetweenClasses: Bool
    ) {
        let unchanged =
            configuration.windowStartHour == startHour
            && configuration.windowStartMinute == startMinute
            && configuration.windowEndHour == endHour
            && configuration.windowEndMinute == endMinute
            && configuration.allowBeforeFirstClass == allowBeforeFirstClass
            && configuration.allowBetweenClasses == allowBetweenClasses
        guard !unchanged else { return }

        configuration.windowStartHour = startHour
        configuration.windowStartMinute = startMinute
        configuration.windowEndHour = endHour
        configuration.windowEndMinute = endMinute
        configuration.allowBeforeFirstClass = allowBeforeFirstClass
        configuration.allowBetweenClasses = allowBetweenClasses
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.studyStartHour = startHour
            state.studyStartMinute = startMinute
            state.studyEndHour = endHour
            state.studyEndMinute = endMinute
            state.allowBeforeFirstClass = allowBeforeFirstClass
            state.allowBetweenClasses = allowBetweenClasses
            try context.save()
        } catch {}
        regenerate()
    }

    func regenerate() {
        // Sprout does not automatically regenerate or rearrange schedules.
    }

    @discardableResult
    func logActivity(
        title: String,
        category: ActivityCategory = .study,
        durationMinutes: Int,
        timestamp: Date = Date(),
        startTime: Date? = nil,
        focusRating: Int = 0,
        energyRating: Int = 0,
        aiUsage: AIUsageLevel = .none,
        independentAttemptFirst: Bool = true,
        notes: String = "",
        isTimerGenerated: Bool = false,
        linkedCourse: Course? = nil
    ) -> ActivityLog {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? (linkedCourse?.code ?? category.displayName) : trimmed
        let log = ActivityLog(
            title: name,
            category: category,
            durationMinutes: durationMinutes,
            timestamp: timestamp,
            startTime: startTime,
            focusRating: focusRating,
            energyRating: energyRating,
            aiUsage: aiUsage,
            independentAttemptFirst: independentAttemptFirst,
            notes: notes,
            isTimerGenerated: isTimerGenerated,
            linkedCourse: linkedCourse
        )
        context.insert(log)
        #if !SKIP
        GardenService.recordActivityLogGrowth(log: log, in: context, saveContext: false)
        #endif
        cachedRecentTitles = nil
        cachedDefaultActivities = nil
        try? context.save()
        return log
    }

    func deleteActivityLog(_ log: ActivityLog) {
        context.delete(log)
        cachedRecentTitles = nil
        cachedDefaultActivities = nil
        try? context.save()
    }

    func recentActivityTitles(limit: Int = 8) -> [String] {
        if let cachedRecentTitles {
            return cachedRecentTitles
        }
        #if !SKIP
        var descriptor = FetchDescriptor<ActivityLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = max(24, limit * 3)
        guard let logs = try? context.fetch(descriptor) else {
            let def = defaultRecentActivities
            cachedRecentTitles = def
            return def
        }
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(limit)
        for log in logs {
            let t = log.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && seen.insert(t.uppercased()).inserted {
                result.append(t)
                if result.count >= limit { break }
            }
        }
        let finalResult = result.isEmpty ? defaultRecentActivities : result
        cachedRecentTitles = finalResult
        return finalResult
        #else
        let def = defaultRecentActivities
        cachedRecentTitles = def
        return def
        #endif
    }

    var defaultRecentActivities: [String] {
        if let cachedDefaultActivities {
            return cachedDefaultActivities
        }
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        var seen = Set<String>()
        var titles: [String] = []
        for course in courses {
            let code = course.code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty && seen.insert(code.uppercased()).inserted {
                titles.append(code)
                if titles.count >= 8 { break }
            }
        }
        let standard = ["Study", "Problem Set", "Reading", "Gym", "Leisure", "Personal Project"]
        for s in standard where seen.insert(s.uppercased()).inserted {
            titles.append(s)
            if titles.count >= 8 { break }
        }
        let result = Array(titles.prefix(8))
        cachedDefaultActivities = result
        return result
    }

    // Live Timer state
    var activeTimerTitle: String = ""
    var activeTimerCategory: ActivityCategory = .study
    var activeTimerCourse: Course? = nil
    var activeTimerStartedAt: Date? = nil
    var isTimerRunning: Bool { activeTimerStartedAt != nil }

    func startTimer(title: String, category: ActivityCategory, course: Course? = nil) {
        activeTimerTitle = title
        activeTimerCategory = category
        activeTimerCourse = course
        activeTimerStartedAt = clock.now
    }

    func stopTimer() -> FocusTimerResult? {
        guard let started = activeTimerStartedAt else { return nil }
        let now = clock.now
        let duration = max(1, Int(now.timeIntervalSince(started) / 60))
        let result = FocusTimerResult(
            title: activeTimerTitle,
            category: activeTimerCategory,
            course: activeTimerCourse,
            durationMinutes: duration,
            startTime: started,
            endTime: now
        )
        activeTimerStartedAt = nil
        return result
    }

    func cancelTimer() {
        activeTimerStartedAt = nil
    }

    private func appStateRecord() -> AppStateRecord? {
        if let cachedAppState { return cachedAppState }
        let record = try? SwiftDataAppStateRepository(context: context).record()
        cachedAppState = record
        return record
    }

    var totalFocusXP: Int {
        appStateRecord()?.totalFocusXP ?? 0
    }

    var currentStreakDays: Int {
        guard let state = appStateRecord(),
              let lastFocus = state.lastFocusDate else { return 0 }
        let cal = configuration.calendar()
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date.distantPast
        if cal.isDateInToday(lastFocus) || cal.isDate(lastFocus, inSameDayAs: yesterday) {
            return state.currentStreakDays
        }
        return 0
    }

    var longestStreakDays: Int {
        appStateRecord()?.longestStreakDays ?? 0
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            cachedAppState = state
            state.hasCompletedOnboarding = true
            try context.save()
        } catch {}
    }

    func addAssessment(
        to course: Course,
        kind: AssessmentKind,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        extraStudyMinutes: Int = 0
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let assessment = Assessment(
            title: trimmed.isEmpty ? course.code : trimmed,
            kind: kind,
            start: start,
            end: end > start ? end : start.addingTimeInterval(3600),
            isAllDay: isAllDay,
            fingerprint: "manual|\(course.id.uuidString)|\(UUID().uuidString)",
            course: course,
            extraStudyMinutes: extraStudyMinutes
        )
        context.insert(assessment)
        try? context.save()
        regenerate()
    }

    func deleteAssessment(_ assessment: Assessment) {
        context.delete(assessment)
        try? context.save()
        regenerate()
    }

    func importCalendar(data: Data) async throws -> ICSImportCommit {
        let parsed = icsParser.parse(data: data)
        let calendar = configuration.calendar()
        let filtered: ICSParseResult
        if let term = parsed.preferredTerm(now: clock.now, calendar: calendar) {
            filtered = parsed.filtered(to: term, calendar: calendar)
        } else {
            filtered = parsed
        }
        #if !SKIP
        let importer = ICSImportService(parser: icsParser, container: container)
        let commit = try await importer.commit(result: filtered)
        await MainActor.run {
            completeOnboarding()
            regenerate()
        }
        return commit
        #else
        return ICSImportCommit(classBlocks: 0, assessments: 0)
        #endif
    }

    func previewCalendar(data: Data) -> ICSParseResult {
        icsParser.parse(data: data)
    }

    func commitPreview(_ result: ICSParseResult) async {
        #if !SKIP
        let importer = ICSImportService(parser: icsParser, container: container)
        _ = try? await importer.commit(result: result)
        #endif
        await MainActor.run {
            completeOnboarding()
            regenerate()
        }
    }

    func clearAllActivityLogs() {
        if let logs = try? context.fetch(FetchDescriptor<ActivityLog>()) {
            for log in logs {
                context.delete(log)
            }
            cachedRecentTitles = nil
            try? context.save()
        }
    }

    private func resetTimetableEntities() {
        if let tasks = try? context.fetch(FetchDescriptor<FocusTask>()) { for t in tasks { context.delete(t) } }
        if let assessments = try? context.fetch(FetchDescriptor<Assessment>()) { for a in assessments { context.delete(a) } }
        if let blocks = try? context.fetch(FetchDescriptor<ClassBlock>()) { for b in blocks { context.delete(b) } }
        if let courses = try? context.fetch(FetchDescriptor<Course>()) { for c in courses { context.delete(c) } }
    }

    func resetTimetable() {
        resetTimetableEntities()
        activeSessionTaskID = nil
        try? context.save()
        Task { await refreshReminders() }
    }

    func resetAll() {
        resetTimetableEntities()
        clearAllActivityLogs()
        activeSessionTaskID = nil
        try? context.save()
        Task { await refreshReminders() }
    }

    func markTaskDone(_ task: FocusTask) {
        guard !task.isCompleted else { return }
        task.isCompleted = true
        task.completedAt = clock.now
        let elapsedMinutes: Int
        if let sessionStartedAt = task.sessionStartedAt {
            elapsedMinutes = max(1, Int(clock.now.timeIntervalSince(sessionStartedAt) / 60))
        } else {
            elapsedMinutes = 0
        }
        #if !SKIP
        let plant = GardenService.fetchPlant(for: task.id, in: context)
        let plantMinutes = plant?.focusedMinutes ?? 0
        let focusedMinutes = max(plantMinutes, max(elapsedMinutes, 1))
        if let plant {
            _ = GardenService.completeHarvest(
                plant: plant,
                task: task,
                focusedMinutes: focusedMinutes,
                now: clock.now,
                calendar: configuration.calendar(),
                context: context
            )
        }
        #endif
        task.sessionStartedAt = nil
        if activeSessionTaskID == task.id {
            activeSessionTaskID = nil
        }
        reminderService.cancel(taskID: task.id)
        try? context.save()
        Task { await refreshReminders() }
    }

    func unmarkTaskDone(_ task: FocusTask) {
        guard task.isCompleted else { return }
        task.isCompleted = false
        task.completedAt = nil
        try? context.save()
        regenerate()
        Task { await refreshReminders() }
    }

    func recordSessionFeedback(for task: FocusTask, rating: MasteryRating, errorNotes: String = "") {
        task.masteryRating = rating
        task.errorNotes = errorNotes
        try? context.save()
        regenerate()
    }

    func resetStudySessions() {
        resetStudySessionsInternal()
        try? context.save()
        regenerate()
        Task { await refreshReminders() }
    }

    private func resetStudySessionsInternal() {
        guard let allTasks = try? context.fetch(FetchDescriptor<FocusTask>()) else { return }
        let studyTasks = allTasks.filter { $0.taskKind == TaskKind.study.rawValue }
        for task in studyTasks {
            if activeSessionTaskID == task.id {
                activeSessionTaskID = nil
            }
            reminderService.cancel(taskID: task.id)
            #if !SKIP
            if let plant = GardenService.fetchPlant(for: task.id, in: context), !plant.isHarvested {
                context.delete(plant)
            }
            #endif
            context.delete(task)
        }
    }

    func deleteCourse(_ course: Course) {
        for block in course.classBlocks ?? [] {
            context.delete(block)
        }
        for task in course.tasks ?? [] {
            deleteTask(task)
        }
        for assessment in course.assessments ?? [] {
            context.delete(assessment)
        }
        context.delete(course)
        try? context.save()
        regenerate()
    }

    func deleteTask(_ task: FocusTask) {
        if activeSessionTaskID == task.id {
            activeSessionTaskID = nil
        }
        reminderService.cancel(taskID: task.id)
        #if !SKIP
        if let plant = GardenService.fetchPlant(for: task.id, in: context), !plant.isHarvested {
            context.delete(plant)
        }
        #endif
        context.delete(task)
        try? context.save()
        regenerate()
    }

    func addTask(
        title: String,
        course: Course? = nil,
        priority: Int = 2,
        estimatedMinutes: Int = 45,
        kind: TaskKind = .study,
        deadline: Date? = nil
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? (course?.code ?? "Study block") : trimmed
        let task = FocusTask(
            title: name,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            taskKind: kind.rawValue,
            linkedCourse: course,
            deadline: deadline
        )
        context.insert(task)
        try? context.save()
        regenerate()
    }

    func startFocusSession(_ task: FocusTask) {
        guard !task.isCompleted else { return }
        if let other = try? context.fetch(FetchDescriptor<FocusTask>()) {
            for item in other where item.id != task.id && item.sessionStartedAt != nil {
                item.sessionStartedAt = nil
            }
        }
        if task.sessionStartedAt == nil {
            task.sessionStartedAt = clock.now
        }
        activeSessionTaskID = task.id
        reminderService.cancel(taskID: task.id)
        #if !SKIP
        if GardenService.fetchPlant(for: task.id, in: context) == nil {
            GardenService.plantSeed(for: task, in: context)
        }
        #endif
        try? context.save()
    }

    func endFocusSession(clearStart: Bool) {
        if clearStart, let task = activeSessionTask {
            task.sessionStartedAt = nil
            try? context.save()
        }
        activeSessionTaskID = nil
    }

    func resumeFocusSession(_ task: FocusTask) {
        guard task.isInSession else { return }
        activeSessionTaskID = task.id
    }

    func cancelAllReminders() {
        reminderService.cancelAll()
    }

    private func setupReminders() async {
        guard remindersEnabled else {
            reminderService.cancelAll()
            return
        }
        _ = await reminderService.requestAuthorization()
        await refreshReminders()
    }

    private func refreshReminders() async {
        guard remindersEnabled else {
            reminderService.cancelAll()
            return
        }
        let tasks = (try? SwiftDataTaskRepository(context: context).all()) ?? []
        await reminderService.refresh(tasks: tasks, now: clock.now)
    }
}
