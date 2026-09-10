import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AppServices {
    let container: ModelContainer
    let clock: any Clock
    var configuration: AppConfiguration
    let engine: AutoSchedulingEngine
    let planner: StudyPlanner
    var scheduleManager: ScheduleManager
    let widgetService: WidgetSnapshotService
    let icsParser: ICSParser
    let reminderService: StudyReminderService

    var selectedDate: Date
    var lastPlan: SchedulePlan?
    var activeSessionTaskID: UUID?
    var remindersEnabled: Bool = true
    private var didBootstrap = false

    init(
        container: ModelContainer,
        clock: any Clock = SystemClock(),
        configuration: AppConfiguration = .userDefault
    ) {
        self.container = container
        self.clock = clock
        self.configuration = configuration
        self.engine = AutoSchedulingEngine()
        self.planner = StudyPlanner()
        self.scheduleManager = ScheduleManager(engine: engine, planner: planner, configuration: configuration)
        self.widgetService = WidgetSnapshotService()
        self.icsParser = ICSParser(defaultTimeZone: configuration.timeZone)
        self.reminderService = StudyReminderService()
        self.selectedDate = clock.now
    }

    var context: ModelContext { container.mainContext }

    var activeSessionTask: FocusTask? {
        guard let activeSessionTaskID else { return nil }
        return try? context.fetch(FetchDescriptor<FocusTask>()).first { $0.id == activeSessionTaskID && !$0.isCompleted }
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            applyStudyPreferences(from: state)
            remindersEnabled = state.remindersEnabled
            lastPlan = try scheduleManager.regenerate(context: context, now: clock.now)
            if let active = try context.fetch(FetchDescriptor<FocusTask>()).first(where: { $0.isInSession }) {
                activeSessionTaskID = active.id
            }
            refreshWidget()
            Task { await setupReminders() }
        } catch {
            lastPlan = nil
        }
    }

    func applyStudyPreferences(from state: AppStateRecord) {
        configuration.applyStudyPreferences(from: state)
        scheduleManager.configuration = configuration
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

    func setRemindersEnabled(_ value: Bool) {
        remindersEnabled = value
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
            state.remindersEnabled = value
            try context.save()
        } catch {}
        Task { await setupReminders() }
    }

    func setAssessmentLeadWeeks(_ weeks: Int) {
        let clamped = max(1, min(8, weeks))
        guard configuration.assessmentLeadWeeks != clamped else { return }
        configuration.assessmentLeadWeeks = clamped
        configuration.horizonDays = max(21, clamped * 7 + 14)
        scheduleManager.configuration = configuration
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
        scheduleManager.configuration = configuration
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
        scheduleManager.configuration = configuration
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
        scheduleManager.configuration = configuration
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
        block.startTime = max(0, startTime)
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
        scheduleManager.configuration = configuration

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
        do {
            lastPlan = try scheduleManager.regenerate(context: context, now: clock.now)
            refreshWidget()
            Task { await refreshReminders() }
        } catch {
            lastPlan = nil
        }
    }

    var hasCompletedOnboarding: Bool {
        (try? SwiftDataAppStateRepository(context: context).record().hasCompletedOnboarding) ?? false
    }

    func completeOnboarding() {
        do {
            let state = try SwiftDataAppStateRepository(context: context).record()
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
        let importer = ICSImportService(parser: icsParser, container: container)
        let commit = try await importer.commit(result: filtered)
        await MainActor.run {
            completeOnboarding()
            regenerate()
        }
        return commit
    }

    func previewCalendar(data: Data) -> ICSParseResult {
        icsParser.parse(data: data)
    }

    func commitPreview(_ result: ICSParseResult) async {
        let importer = ICSImportService(parser: icsParser, container: container)
        _ = try? await importer.commit(result: result)
        await MainActor.run {
            completeOnboarding()
            regenerate()
        }
    }

    func resetAll() {
        do {
            try scheduleManager.resetAll(context: context)
            lastPlan = nil
            activeSessionTaskID = nil
            refreshWidget()
            Task { await refreshReminders() }
        } catch {}
    }

    func markTaskDone(_ task: FocusTask) {
        guard !task.isCompleted else { return }
        task.isCompleted = true
        task.completedAt = clock.now
        task.sessionStartedAt = nil
        if activeSessionTaskID == task.id {
            activeSessionTaskID = nil
        }
        reminderService.cancel(taskID: task.id)
        try? context.save()
        refreshWidget()
        Task { await refreshReminders() }
    }

    func unmarkTaskDone(_ task: FocusTask) {
        guard task.isCompleted else { return }
        task.isCompleted = false
        task.completedAt = nil
        try? context.save()
        regenerate()
        refreshWidget()
        Task { await refreshReminders() }
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
        refreshWidget()
    }

    func deleteTask(_ task: FocusTask) {
        if activeSessionTaskID == task.id {
            activeSessionTaskID = nil
        }
        reminderService.cancel(taskID: task.id)
        context.delete(task)
        try? context.save()
        regenerate()
        refreshWidget()
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

    func rescheduleTask(_ task: FocusTask, to start: Date) {
        guard !task.isCompleted else { return }
        let existingMinutes: Int = {
            if let scheduledStart = task.scheduledStart, let scheduledEnd = task.scheduledEnd, scheduledEnd > scheduledStart {
                return Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60)
            }
            if task.remainingMinutes > 0 { return task.remainingMinutes }
            return task.estimatedMinutes
        }()
        let minutes = max(configuration.minChunkMinutes, existingMinutes)
        let duration = TimeInterval(minutes * 60)
        task.scheduledStart = start
        task.scheduledEnd = start.addingTimeInterval(duration)
        task.isSoftLocked = true
        task.scheduleReason = "Pinned where you put it."
        try? context.save()
        regenerate()
        refreshWidget()
    }

    func unlockTaskSchedule(_ task: FocusTask) {
        guard !task.isCompleted else { return }
        task.isSoftLocked = false
        try? context.save()
        regenerate()
        refreshWidget()
    }

    func refreshWidget() {
        do {
            let tasks = try SwiftDataTaskRepository(context: context).all()
            let pending = tasks.filter { !$0.isCompleted }
            let next = pending
                .filter { $0.scheduledStart != nil }
                .sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
                .first
            widgetService.publish(nextTask: next, pendingCount: pending.count)
        } catch {}
    }

    private func setupReminders() async {
        guard remindersEnabled else {
            await reminderService.refresh(tasks: [], now: clock.now)
            return
        }
        _ = await reminderService.requestAuthorization()
        await refreshReminders()
    }

    private func refreshReminders() async {
        guard remindersEnabled else {
            await reminderService.refresh(tasks: [], now: clock.now)
            return
        }
        let tasks = (try? SwiftDataTaskRepository(context: context).all()) ?? []
        await reminderService.refresh(tasks: tasks, now: clock.now)
    }
}
