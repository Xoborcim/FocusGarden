import Foundation
#if !SKIP
import SwiftData
#endif

struct StudyItemBounds: Sendable {
    var earliest: Date?
    var latest: Date?
}

struct ScheduleManager: Sendable {
    var engine: AutoSchedulingEngine
    var planner: StudyPlanner
    var configuration: AppConfiguration

    func regenerate(context: ModelContext, now: Date) throws -> SchedulePlan {
        let courses = try context.fetch(FetchDescriptor<Course>())
        let blocks = try context.fetch(FetchDescriptor<ClassBlock>())
        let assessments = try context.fetch(FetchDescriptor<Assessment>())
        let tasks = try context.fetch(FetchDescriptor<FocusTask>())
        let calendar = configuration.calendar()
        let horizonStart = calendar.startOfDay(for: now)
        let horizonEnd = calendar.date(byAdding: .day, value: configuration.horizonDays, to: horizonStart) ?? horizonStart

        // Include any class blocks whose validity range overlaps the scheduling horizon
        let activeBlocks = blocks.filter { block in
            let blockStart = calendar.startOfDay(for: block.validFrom)
            let blockEnd = calendar.startOfDay(for: block.validUntil)
            return blockStart <= horizonEnd && blockEnd >= horizonStart
        }

        let templates = activeBlocks.map { block in
            RecurringClassTemplate(
                dayOfWeek: block.dayOfWeek,
                startTime: block.startTime,
                duration: block.duration,
                cognitiveWeight: block.cognitiveWeight,
                courseCode: block.course?.code ?? block.summary,
                meetingType: block.meetingType,
                validFrom: block.validFrom,
                validUntil: block.validUntil
            )
        }
        var expanded = engine.expandClassBlocks(templates: templates, now: now, configuration: configuration)

        // Include any assessments occurring in the scheduling horizon
        let activeAssessments = assessments.filter { assessment in
            let aStart = calendar.startOfDay(for: assessment.start)
            let aEnd = calendar.startOfDay(for: assessment.end)
            return aStart <= horizonEnd && aEnd >= horizonStart
        }
        expanded.append(contentsOf: timedAssessments(activeAssessments, now: now))

        var activeCodes = Set<String>()
        for block in activeBlocks {
            let code = block.course?.code ?? ""
            if !code.isEmpty {
                activeCodes.insert(code)
            }
        }
        let desired = planner.plan(
            courses: courseWorkloads(courses: courses, blocks: activeBlocks, calendar: calendar)
                .filter { activeCodes.contains($0.code) },
            assessments: activeAssessments.map { assessment in
                AssessmentEvent(
                    fingerprint: assessment.fingerprint.isEmpty ? assessment.id.uuidString : assessment.fingerprint,
                    title: assessment.title,
                    kind: assessment.assessmentKind,
                    start: assessment.start,
                    end: assessment.end,
                    isAllDay: assessment.isAllDay,
                    courseCode: assessment.course?.code ?? "",
                    extraStudyMinutes: assessment.extraStudyMinutes,
                    courseDifficulty: assessment.course?.difficulty ?? 3
                )
            },
            now: now,
            configuration: configuration,
            schoolStart: schoolStart(from: activeBlocks, calendar: calendar)
        )

        let synced = try syncGeneratedTasks(
            desired: desired,
            existing: tasks,
            courses: courses,
            context: context
        )

        let manualTasks = tasks.filter { $0.generationKey.isEmpty }
        let allTasksToSchedule = synced + manualTasks

        var boundsByKey: [String: StudyItemBounds] = [:]
        for item in desired {
            boundsByKey[item.generationKey] = StudyItemBounds(earliest: item.earliestStart, latest: item.latestEnd)
        }
        var plannable: [PlannableTask] = []
        for task in allTasksToSchedule {
            guard !task.isCompleted else { continue }
            let locked = task.isSoftLocked
                && task.scheduledStart != nil
                && task.scheduledEnd != nil
                && (task.scheduledEnd ?? .distantPast) > (task.scheduledStart ?? .distantFuture)
            let bounds = boundsByKey[task.generationKey]
            plannable.append(
                PlannableTask(
                    id: task.id,
                    title: task.title,
                    priority: task.priority,
                    remainingMinutes: task.remainingMinutes > 0 ? task.remainingMinutes : task.estimatedMinutes,
                    deadline: task.deadline,
                    taskKind: task.taskKind,
                    isSpacedReview: task.isSpacedReview,
                    isSoftLocked: locked,
                    lockedStart: locked ? task.scheduledStart : nil,
                    lockedEnd: locked ? task.scheduledEnd : nil,
                    intensity: task.intensity,
                    courseCode: task.linkedCourse?.code ?? "",
                    earliestStart: bounds?.earliest,
                    latestEnd: bounds?.latest,
                    masteryRating: task.masteryRatingRaw,
                    errorNotes: task.errorNotes
                )
            )
        }

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: configuration,
                tasks: plannable,
                classBlocks: expanded
            )
        )

        var placementsByTask: [UUID: [ScheduledPlacement]] = [:]
        for placement in plan.placements {
            placementsByTask[placement.taskID, default: []].append(placement)
        }
        var unscheduledReasons: [UUID: String] = [:]
        for unscheduled in plan.unscheduled {
            unscheduledReasons[unscheduled.taskID] = unscheduled.reason
        }
        for task in allTasksToSchedule where !task.isCompleted {
            if task.isSoftLocked, let start = task.scheduledStart, let end = task.scheduledEnd, end > start {
                task.scheduleReason = "Pinned where you put it."
                continue
            }
            if let placement = placementsByTask[task.id]?.sorted(by: { $0.start < $1.start }).first {
                task.scheduledStart = placement.start
                task.scheduledEnd = placement.end
                task.scheduleReason = placement.reason
            } else if let reason = unscheduledReasons[task.id] {
                task.scheduledStart = nil
                task.scheduledEnd = nil
                task.scheduleReason = reason
            } else {
                task.scheduledStart = nil
                task.scheduledEnd = nil
                task.scheduleReason = "Dropped from schedule"
            }
        }

        if let state = try context.fetch(FetchDescriptor<AppStateRecord>()).first {
            state.lastPlanGeneratedAt = now
        }
        try context.save()
        return plan
    }

    func expandedClasses(context: ModelContext, now: Date) throws -> [ExpandedClassBlock] {
        let blocks = try context.fetch(FetchDescriptor<ClassBlock>())
        let calendar = configuration.calendar()
        let horizonStart = calendar.startOfDay(for: now)
        let horizonEnd = calendar.date(byAdding: .day, value: configuration.horizonDays, to: horizonStart) ?? horizonStart
        let activeBlocks = blocks.filter { block in
            let blockStart = calendar.startOfDay(for: block.validFrom)
            let blockEnd = calendar.startOfDay(for: block.validUntil)
            return blockStart <= horizonEnd && blockEnd >= horizonStart
        }
        let templates = activeBlocks.map {
            RecurringClassTemplate(
                dayOfWeek: $0.dayOfWeek,
                startTime: $0.startTime,
                duration: $0.duration,
                cognitiveWeight: $0.cognitiveWeight,
                courseCode: $0.course?.code ?? $0.summary,
                meetingType: $0.meetingType,
                validFrom: $0.validFrom,
                validUntil: $0.validUntil
            )
        }
        return engine.expandClassBlocks(templates: templates, now: now, configuration: configuration)
    }

    func resetAll(context: ModelContext) throws {
        for task in try context.fetch(FetchDescriptor<FocusTask>()) { context.delete(task) }
        for assessment in try context.fetch(FetchDescriptor<Assessment>()) { context.delete(assessment) }
        for block in try context.fetch(FetchDescriptor<ClassBlock>()) { context.delete(block) }
        for course in try context.fetch(FetchDescriptor<Course>()) { context.delete(course) }
        try context.save()
    }

    private func activeTerm(now: Date, blocks: [ClassBlock], calendar: Calendar) -> AcademicTerm {
        let current = AcademicTerm.containing(now, calendar: calendar)
        let overlapping = blocks.filter { $0.isActive(on: now, calendar: calendar) }
        if overlapping.contains(where: { termOf($0, now: now, calendar: calendar) == current }) {
            return current
        }
        if let sample = overlapping.first {
            return termOf(sample, now: now, calendar: calendar)
        }
        return current
    }

    private func termOf(_ block: ClassBlock, now: Date, calendar: Calendar) -> AcademicTerm {
        block.term(now: now, calendar: calendar)
    }

    private func courseWorkloads(courses: [Course], blocks: [ClassBlock], calendar: Calendar) -> [CourseWorkload] {
        var minutesByCode: [String: Int] = [:]
        for block in blocks {
            let code = block.course?.code ?? ""
            guard !code.isEmpty else { continue }
            minutesByCode[code, default: 0] += Int((block.duration / 60).rounded())
        }
        var seen = Set<String>()
        var workloads: [CourseWorkload] = []
        for course in courses where seen.insert(course.code.uppercased()).inserted {
            workloads.append(
                CourseWorkload(
                    code: course.code,
                    weeklyClassMinutes: minutesByCode[course.code] ?? minutesByCode[course.code.uppercased()] ?? 0,
                    firstClassEnd: firstClassEnd(for: course.code, blocks: blocks, calendar: calendar),
                    difficulty: course.difficulty
                )
            )
        }
        return workloads
    }

    private func schoolStart(from blocks: [ClassBlock], calendar: Calendar) -> Date? {
        var earliest: Date?
        for block in blocks {
            guard calendar.component(.year, from: block.validFrom) >= 1990 else { continue }
            let day = calendar.startOfDay(for: block.validFrom)
            if earliest == nil || day < earliest! {
                earliest = day
            }
        }
        return earliest
    }

    private func firstClassEnd(for code: String, blocks: [ClassBlock], calendar: Calendar) -> Date? {
        var best: Date?
        for block in blocks where (block.course?.code ?? "").uppercased() == code.uppercased() {
            guard calendar.component(.year, from: block.validFrom) >= 1990 else { continue }
            var day = calendar.startOfDay(for: block.validFrom)
            for _ in 0..<7 {
                if calendar.component(.weekday, from: day) == block.dayOfWeek {
                    let end = day.addingTimeInterval(block.startTime + block.duration)
                    if best == nil || end < best! { best = end }
                    break
                }
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            }
        }
        return best
    }

    private func timedAssessments(_ assessments: [Assessment], now: Date) -> [ExpandedClassBlock] {
        let calendar = configuration.calendar()
        let todayStart = calendar.startOfDay(for: now)
        var result: [ExpandedClassBlock] = []
        for assessment in assessments {
            guard !assessment.isAllDay, assessment.end > assessment.start else { continue }
            let dayStart = calendar.startOfDay(for: assessment.start)
            guard dayStart >= todayStart else { continue }
            result.append(
                ExpandedClassBlock(
                    start: assessment.start,
                    end: assessment.end,
                    cognitiveWeight: assessment.assessmentKind == .test ? 3.0 : 1.0,
                    courseCode: assessment.course?.code ?? "",
                    meetingType: assessment.assessmentKind == .test ? "EXAM" : "HW"
                )
            )
        }
        return result
    }

    func syncGeneratedTasks(
        desired: [GeneratedStudyItem],
        existing: [FocusTask],
        courses: [Course],
        context: ModelContext
    ) throws -> [FocusTask] {
        var coursesByCode: [String: Course] = [:]
        for course in courses {
            coursesByCode[course.code.uppercased()] = course
        }
        var existingByKey: [String: [FocusTask]] = [:]
        for task in existing where !task.generationKey.isEmpty {
            existingByKey[task.generationKey, default: []].append(task)
        }
        var result: [FocusTask] = []

        var seenDesired = Set<String>()
        var uniqueDesired: [GeneratedStudyItem] = []
        for item in desired {
            if seenDesired.insert(item.generationKey).inserted {
                uniqueDesired.append(item)
            }
        }

        for item in uniqueDesired {
            let course = coursesByCode[item.courseCode.uppercased()]
            if var matchingTasks = existingByKey.removeValue(forKey: item.generationKey), !matchingTasks.isEmpty {
                // If there are duplicate tasks in the database for this key, prefer a completed one, otherwise pick the first
                let task: FocusTask
                if let completedIndex = matchingTasks.firstIndex(where: { $0.isCompleted }) {
                    task = matchingTasks.remove(at: completedIndex)
                } else {
                    task = matchingTasks.removeFirst()
                }

                // Delete any remaining duplicate uncompleted tasks from context
                for duplicate in matchingTasks where !duplicate.isCompleted {
                    context.delete(duplicate)
                }

                if !task.isCompleted {
                    task.title = item.title
                    task.priority = item.priority
                    task.estimatedMinutes = item.minutes
                    task.remainingMinutes = item.minutes
                    task.taskKind = item.kind.rawValue
                    task.deadline = item.deadline
                    task.linkedCourse = course
                    task.linkedAssessmentFingerprint = item.assessmentFingerprint
                }
                result.append(task)
            } else {
                let task = FocusTask(
                    title: item.title,
                    priority: item.priority,
                    estimatedMinutes: item.minutes,
                    taskKind: item.kind.rawValue,
                    linkedCourse: course,
                    deadline: item.deadline,
                    generationKey: item.generationKey,
                    linkedAssessmentFingerprint: item.assessmentFingerprint
                )
                context.insert(task)
                result.append(task)
            }
        }

        for (_, remainingTasks) in existingByKey {
            for task in remainingTasks where !task.isCompleted {
                context.delete(task)
            }
        }

        return result
    }
}
