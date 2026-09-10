import Foundation
import SwiftData

@MainActor
struct ScheduleManager {
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

        let activeCodes = Set(activeBlocks.compactMap { block -> String? in
            let code = block.course?.code ?? ""
            return code.isEmpty ? nil : code
        })
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

        let boundsByKey = Dictionary(uniqueKeysWithValues: desired.map {
            ($0.generationKey, (earliest: $0.earliestStart, latest: $0.latestEnd))
        })
        let plannable = allTasksToSchedule.compactMap { task -> PlannableTask? in
            guard !task.isCompleted else { return nil }
            let locked = task.isSoftLocked
                && task.scheduledStart != nil
                && task.scheduledEnd != nil
                && (task.scheduledEnd ?? .distantPast) > (task.scheduledStart ?? .distantFuture)
            let bounds = boundsByKey[task.generationKey]
            return PlannableTask(
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
        }

        let plan = engine.generate(
            request: SchedulingRequest(
                now: now,
                configuration: configuration,
                tasks: plannable,
                classBlocks: expanded
            )
        )

        let placementsByTask = Dictionary(grouping: plan.placements, by: \.taskID)
        let unscheduledReasons = Dictionary(uniqueKeysWithValues: plan.unscheduled.map { ($0.taskID, $0.reason) })
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
        blocks.compactMap { block -> Date? in
            guard calendar.component(.year, from: block.validFrom) >= 1990 else { return nil }
            return calendar.startOfDay(for: block.validFrom)
        }.min()
    }

    private func firstClassEnd(for code: String, blocks: [ClassBlock], calendar: Calendar) -> Date? {
        var best: Date?
        for block in blocks where (block.course?.code ?? "").caseInsensitiveCompare(code) == .orderedSame {
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
        return assessments.compactMap { assessment in
            guard !assessment.isAllDay, assessment.end > assessment.start else { return nil }
            let dayStart = calendar.startOfDay(for: assessment.start)
            guard dayStart >= todayStart else { return nil }
            return ExpandedClassBlock(
                start: assessment.start,
                end: assessment.end,
                cognitiveWeight: assessment.assessmentKind == .test ? 3.0 : 1.0,
                courseCode: assessment.course?.code ?? "",
                meetingType: assessment.assessmentKind == .test ? "EXAM" : "HW"
            )
        }
    }

    private func syncGeneratedTasks(
        desired: [GeneratedStudyItem],
        existing: [FocusTask],
        courses: [Course],
        context: ModelContext
    ) throws -> [FocusTask] {
        var coursesByCode: [String: Course] = [:]
        for course in courses {
            coursesByCode[course.code.uppercased()] = course
        }
        var existingByKey = Dictionary(uniqueKeysWithValues: existing.filter { !$0.generationKey.isEmpty }.map { ($0.generationKey, $0) })
        var result: [FocusTask] = []

        for item in desired {
            let course = coursesByCode[item.courseCode.uppercased()]
            if let task = existingByKey.removeValue(forKey: item.generationKey) {
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

        for (_, task) in existingByKey where !task.isCompleted {
            context.delete(task)
        }

        return result
    }
}
