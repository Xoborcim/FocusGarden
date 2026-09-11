import Foundation

struct AutoSchedulingEngine: Sendable {
    func generate(request: SchedulingRequest) -> SchedulePlan {
        let config = request.configuration
        let calendar = config.calendar()
        let horizonEnd = calendar.date(byAdding: .day, value: config.horizonDays, to: calendar.startOfDay(for: request.now)) ?? request.now

        var occupied: [OccupiedInterval] = request.classBlocks.map {
            OccupiedInterval(start: $0.start, end: $0.end, kind: .schoolClass, cognitiveWeight: $0.cognitiveWeight, label: $0.courseCode)
        }

        var placements: [ScheduledPlacement] = []
        var unscheduled: [UnscheduledWork] = []
        var dailyNonReviewCounts: [Date: Int] = [:]
        var dailyCourseBlockCounts: [Date: [String: Int]] = [:]
        var dailyStudyMinutes: [Date: Int] = [:]
        var lastEndByTask: [UUID: Date] = [:]

        // Place soft-locked tasks first
        for task in request.tasks where task.isSoftLocked {
            if let start = task.lockedStart, let end = task.lockedEnd, end > start {
                occupied.append(OccupiedInterval(start: start, end: end, kind: .locked, cognitiveWeight: 0, label: task.title))
                if config.bufferMinutes > 0 {
                    let breakInterval = TimeInterval(config.bufferMinutes * 60)
                    let bufferEnd = end.addingTimeInterval(breakInterval)
                    occupied.append(OccupiedInterval(start: end, end: bufferEnd, kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                    let bufferStart = start.addingTimeInterval(-breakInterval)
                    occupied.append(OccupiedInterval(start: bufferStart, end: start, kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                }
                placements.append(
                    ScheduledPlacement(
                        taskID: task.id,
                        chunkID: stableChunkID(taskID: task.id, index: 0),
                        start: start,
                        end: end,
                        reason: "Kept where you placed it.",
                        chunkMinutes: Int(end.timeIntervalSince(start) / 60)
                    )
                )
                let day = calendar.startOfDay(for: start)
                if !task.isReview {
                    dailyNonReviewCounts[day, default: 0] += 1
                }
                let courseCode = task.courseCode.uppercased()
                if !courseCode.isEmpty {
                    var counts = dailyCourseBlockCounts[day, default: [:]]
                    counts[courseCode, default: 0] += 1
                    dailyCourseBlockCounts[day] = counts
                }
                let durationMinutes = Int(end.timeIntervalSince(start) / 60)
                dailyStudyMinutes[day, default: 0] += durationMinutes
                lastEndByTask[task.id] = end
            }
        }

        let sortedTasks = request.tasks
            .filter { !$0.isSoftLocked && $0.remainingMinutes > 0 }
            .sorted { Self.taskSort($0, $1) }

        for task in sortedTasks {
            let initialChunks = chunkMinutes(task.remainingMinutes, config: config)
            var chunkQueue = initialChunks
            var chunkIndex = 0
            var placedAll = true

            // Snapshot state for atomic rollback if task cannot be completely placed
            let snapshotPlacementsCount = placements.count
            let snapshotOccupiedCount = occupied.count
            let snapshotDailyCounts = dailyNonReviewCounts
            let snapshotDailyCourseCounts = dailyCourseBlockCounts
            let snapshotDailyStudyMinutes = dailyStudyMinutes
            let snapshotLastEnd = lastEndByTask[task.id]

            while chunkIndex < chunkQueue.count {
                let minutes = chunkQueue[chunkIndex]
                var effectiveMinutes = minutes
                var duration = TimeInterval(effectiveMinutes * 60)

                var candidates = candidateStarts(
                    duration: duration,
                    now: request.now,
                    earliestStart: task.earliestStart,
                    latestEnd: task.latestEnd ?? task.deadline,
                    horizonEnd: horizonEnd,
                    occupied: occupied,
                    classBlocks: request.classBlocks,
                    config: config,
                    calendar: calendar,
                    isReview: task.isReview,
                    dailyNonReviewCounts: dailyNonReviewCounts
                )

                // Dynamic Chunk Flexing: If preferred chunk size has no slots, flex down to fit available gaps
                if candidates.isEmpty && effectiveMinutes > config.minChunkMinutes {
                    var testMinutes = effectiveMinutes - config.granularityMinutes
                    while testMinutes >= config.minChunkMinutes {
                        let testDur = TimeInterval(testMinutes * 60)
                        let testCandidates = candidateStarts(
                            duration: testDur,
                            now: request.now,
                            earliestStart: task.earliestStart,
                            latestEnd: task.latestEnd ?? task.deadline,
                            horizonEnd: horizonEnd,
                            occupied: occupied,
                            classBlocks: request.classBlocks,
                            config: config,
                            calendar: calendar,
                            isReview: task.isReview,
                            dailyNonReviewCounts: dailyNonReviewCounts
                        )
                        if !testCandidates.isEmpty {
                            candidates = testCandidates
                            effectiveMinutes = testMinutes
                            duration = testDur
                            break
                        }
                        testMinutes -= config.granularityMinutes
                    }
                }

                guard let best = bestCandidate(
                    task: task,
                    duration: duration,
                    candidates: candidates,
                    occupied: occupied,
                    classBlocks: request.classBlocks,
                    config: config,
                    calendar: calendar,
                    dailyNonReviewCounts: dailyNonReviewCounts,
                    dailyCourseBlockCounts: dailyCourseBlockCounts,
                    dailyStudyMinutes: dailyStudyMinutes,
                    lastEnd: lastEndByTask[task.id]
                ) else {
                    placedAll = false
                    unscheduled.append(
                        UnscheduledWork(
                            taskID: task.id,
                            title: task.title,
                            reason: unscheduledReason(task: task, minutes: minutes, candidatesEmpty: candidates.isEmpty, config: config)
                        )
                    )
                    break
                }

                let end = best.start.addingTimeInterval(duration)
                let reason = explain(
                    task: task,
                    start: best.start,
                    lastClassEnd: lastClassEnd(on: calendar.startOfDay(for: best.start), classes: request.classBlocks, calendar: calendar),
                    occupied: occupied,
                    calendar: calendar
                )
                placements.append(
                    ScheduledPlacement(
                        taskID: task.id,
                        chunkID: stableChunkID(taskID: task.id, index: chunkIndex),
                        start: best.start,
                        end: end,
                        reason: reason,
                        chunkMinutes: effectiveMinutes
                    )
                )

                let blockLabel = task.courseCode.isEmpty ? task.title : task.courseCode
                occupied.append(OccupiedInterval(start: best.start, end: end, kind: .reserved, cognitiveWeight: 0, label: blockLabel))
                if config.bufferMinutes > 0 {
                    let breakInterval = TimeInterval(config.bufferMinutes * 60)
                    let bufferEnd = end.addingTimeInterval(breakInterval)
                    occupied.append(OccupiedInterval(start: end, end: bufferEnd, kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                    let bufferStart = best.start.addingTimeInterval(-breakInterval)
                    occupied.append(OccupiedInterval(start: bufferStart, end: best.start, kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                }
                let day = calendar.startOfDay(for: best.start)
                if !task.isReview {
                    dailyNonReviewCounts[day, default: 0] += 1
                }
                let courseCode = task.courseCode.uppercased()
                if !courseCode.isEmpty {
                    var counts = dailyCourseBlockCounts[day, default: [:]]
                    counts[courseCode, default: 0] += 1
                    dailyCourseBlockCounts[day] = counts
                }
                dailyStudyMinutes[day, default: 0] += effectiveMinutes
                lastEndByTask[task.id] = end

                // If chunk was flexed down, queue the remainder if >= minChunkMinutes
                let leftover = minutes - effectiveMinutes
                if leftover >= config.minChunkMinutes {
                    chunkQueue.append(leftover)
                }

                chunkIndex += 1
            }

            if !placedAll {
                // Atomic, clean rollback of any partial placements for this task BEFORE swap attempt
                while placements.count > snapshotPlacementsCount {
                    placements.removeLast()
                }
                while occupied.count > snapshotOccupiedCount {
                    occupied.removeLast()
                }
                dailyNonReviewCounts = snapshotDailyCounts
                dailyCourseBlockCounts = snapshotDailyCourseCounts
                dailyStudyMinutes = snapshotDailyStudyMinutes
                lastEndByTask[task.id] = snapshotLastEnd

                // Cooperative Swap: If a high-priority task (>= 3) is blocked, attempt to unseat a lower-priority routine study block
                var swapped = false
                if task.priority >= 3 {
                    for pIdx in (0..<placements.count).reversed() {
                        let candidatePlacement = placements[pIdx]
                        guard let candidateTask = sortedTasks.first(where: { $0.id == candidatePlacement.taskID }),
                              candidateTask.priority < task.priority,
                              !candidateTask.isSoftLocked,
                              candidateTask.taskKind == TaskKind.study.rawValue
                        else { continue }

                        let searchFrom = max(request.now, task.earliestStart ?? request.now)
                        let searchUntil = min(horizonEnd, (task.latestEnd ?? task.deadline) ?? horizonEnd)
                        guard candidatePlacement.start >= searchFrom && candidatePlacement.end <= searchUntil else { continue }

                        var testOccupied = occupied
                        testOccupied.removeAll { $0.kind == .reserved && $0.start == candidatePlacement.start && $0.end == candidatePlacement.end }
                        let breakInterval = TimeInterval(config.bufferMinutes * 60)
                        if config.bufferMinutes > 0 {
                            testOccupied.removeAll { $0.kind == .buffer && ($0.start == candidatePlacement.end || $0.end == candidatePlacement.start) }
                        }

                        let testCandidates = candidateStarts(
                            duration: TimeInterval(task.remainingMinutes * 60),
                            now: request.now,
                            earliestStart: task.earliestStart,
                            latestEnd: task.latestEnd ?? task.deadline,
                            horizonEnd: horizonEnd,
                            occupied: testOccupied,
                            classBlocks: request.classBlocks,
                            config: config,
                            calendar: calendar,
                            isReview: task.isReview,
                            dailyNonReviewCounts: snapshotDailyCounts
                        )

                        if let testBest = bestCandidate(
                            task: task,
                            duration: TimeInterval(task.remainingMinutes * 60),
                            candidates: testCandidates,
                            occupied: testOccupied,
                            classBlocks: request.classBlocks,
                            config: config,
                            calendar: calendar,
                            dailyNonReviewCounts: snapshotDailyCounts,
                            dailyCourseBlockCounts: snapshotDailyCourseCounts,
                            dailyStudyMinutes: snapshotDailyStudyMinutes,
                            lastEnd: snapshotLastEnd
                        ) {
                            // Track the unseated task as unscheduled so its stale times get cleared
                            unscheduled.append(
                                UnscheduledWork(
                                    taskID: candidateTask.id,
                                    title: candidateTask.title,
                                    reason: "Unseated by higher priority task."
                                )
                            )
                            placements.remove(at: pIdx)
                            occupied = testOccupied
                            let end = testBest.start.addingTimeInterval(TimeInterval(task.remainingMinutes * 60))
                            let reason = explain(
                                task: task,
                                start: testBest.start,
                                lastClassEnd: lastClassEnd(on: calendar.startOfDay(for: testBest.start), classes: request.classBlocks, calendar: calendar),
                                occupied: occupied,
                                calendar: calendar
                            )
                            placements.append(
                                ScheduledPlacement(
                                    taskID: task.id,
                                    chunkID: stableChunkID(taskID: task.id, index: 0),
                                    start: testBest.start,
                                    end: end,
                                    reason: reason,
                                    chunkMinutes: task.remainingMinutes
                                )
                            )
                            let blockLabel = task.courseCode.isEmpty ? task.title : task.courseCode
                            occupied.append(OccupiedInterval(start: testBest.start, end: end, kind: .reserved, cognitiveWeight: 0, label: blockLabel))
                            if config.bufferMinutes > 0 {
                                occupied.append(OccupiedInterval(start: end, end: end.addingTimeInterval(breakInterval), kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                                occupied.append(OccupiedInterval(start: testBest.start.addingTimeInterval(-breakInterval), end: testBest.start, kind: .buffer, cognitiveWeight: 0, label: "buffer"))
                            }
                            swapped = true
                            unscheduled.removeAll { $0.taskID == task.id }
                            break
                        }
                    }
                }

                if !swapped {
                    // Task could not be placed even with cooperative swap
                    if !unscheduled.contains(where: { $0.taskID == task.id }) {
                        unscheduled.append(
                            UnscheduledWork(
                                taskID: task.id,
                                title: task.title,
                                reason: unscheduledReason(task: task, minutes: task.remainingMinutes, candidatesEmpty: true, config: config)
                            )
                        )
                    }
                }
            }
        }

        placements.sort { $0.start < $1.start }
        return SchedulePlan(placements: placements, unscheduled: uniqueUnscheduled(unscheduled))
    }

    func expandClassBlocks(
        templates: [RecurringClassTemplate],
        now: Date,
        configuration: AppConfiguration
    ) -> [ExpandedClassBlock] {
        let calendar = configuration.calendar()
        let startDay = calendar.startOfDay(for: now)
        var expanded: [ExpandedClassBlock] = []

        for offset in 0..<configuration.horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for template in templates where template.dayOfWeek == weekday {
                let start = day.addingTimeInterval(template.startTime)
                let end = start.addingTimeInterval(template.duration)
                let dayStart = calendar.startOfDay(for: day)
                if dayStart < calendar.startOfDay(for: template.validFrom) { continue }
                if dayStart > calendar.startOfDay(for: template.validUntil) { continue }
                expanded.append(
                    ExpandedClassBlock(
                        start: start,
                        end: end,
                        cognitiveWeight: template.cognitiveWeight,
                        courseCode: template.courseCode,
                        meetingType: template.meetingType
                    )
                )
            }
        }
        return expanded.sorted { $0.start < $1.start }
    }

    static func taskSort(_ lhs: PlannableTask, _ rhs: PlannableTask) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        let leftDeadline = lhs.deadline ?? .distantFuture
        let rightDeadline = rhs.deadline ?? .distantFuture
        if leftDeadline != rightDeadline { return leftDeadline < rightDeadline }
        if lhs.masteryRating != rhs.masteryRating { return lhs.masteryRating < rhs.masteryRating }
        if lhs.isReview != rhs.isReview { return !lhs.isReview && rhs.isReview }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    func chunkMinutes(_ remaining: Int, config: AppConfiguration) -> [Int] {
        var leftover = max(0, remaining)
        var chunks: [Int] = []
        while leftover > 0 {
            if leftover <= config.maxChunkMinutes {
                let sized = leftover < config.minChunkMinutes ? config.minChunkMinutes : leftover
                chunks.append(sized)
                break
            }
            chunks.append(config.maxChunkMinutes)
            leftover -= config.maxChunkMinutes
        }
        return chunks
    }

    private func candidateStarts(
        duration: TimeInterval,
        now: Date,
        earliestStart: Date?,
        latestEnd: Date?,
        horizonEnd: Date,
        occupied: [OccupiedInterval],
        classBlocks: [ExpandedClassBlock],
        config: AppConfiguration,
        calendar: Calendar,
        isReview: Bool,
        dailyNonReviewCounts: [Date: Int]
    ) -> [Date] {
        let step = TimeInterval(config.granularityMinutes * 60)
        let searchFrom = max(now, earliestStart ?? now)
        let searchUntil = min(horizonEnd, latestEnd ?? horizonEnd)
        guard searchFrom < searchUntil else { return [] }

        var starts: [Date] = []
        var day = calendar.startOfDay(for: searchFrom)

        while day < searchUntil {
            let capReached = !isReview && (dailyNonReviewCounts[day] ?? 0) >= config.maxNonReviewBlocksPerDay
            if !capReached {
                let windows = studyWindows(
                    day: day,
                    searchFrom: searchFrom,
                    classes: classBlocks,
                    config: config,
                    calendar: calendar
                )
                for window in windows {
                    let windowStart = max(window.start, searchFrom)
                    let windowEnd = min(window.end, searchUntil)
                    guard windowStart < windowEnd, windowEnd.timeIntervalSince(windowStart) >= duration else { continue }

                    let intersectingOccupied = occupied.filter { $0.overlaps(windowStart, windowEnd) }

                    if intersectingOccupied.isEmpty {
                        var cursor = aligned(windowStart, granularity: config.granularityMinutes, calendar: calendar)
                        if cursor < windowStart {
                            cursor = cursor.addingTimeInterval(step)
                        }
                        while cursor.addingTimeInterval(duration) <= windowEnd {
                            starts.append(cursor)
                            cursor = cursor.addingTimeInterval(step)
                        }
                    } else {
                        var clamped: [(start: Date, end: Date)] = []
                        for occ in intersectingOccupied {
                            let cStart = max(windowStart, occ.start)
                            let cEnd = min(windowEnd, occ.end)
                            if cStart < cEnd {
                                clamped.append((cStart, cEnd))
                            }
                        }
                        clamped.sort { $0.start < $1.start }

                        var merged: [(start: Date, end: Date)] = []
                        for interval in clamped {
                            if let last = merged.last {
                                if interval.start <= last.end {
                                    let newEnd = max(last.end, interval.end)
                                    merged.removeLast()
                                    merged.append((start: last.start, end: newEnd))
                                } else {
                                    merged.append(interval)
                                }
                            } else {
                                merged.append(interval)
                            }
                        }

                        var freeIntervals: [(start: Date, end: Date)] = []
                        var current = windowStart
                        for occ in merged {
                            if occ.start > current {
                                freeIntervals.append((current, occ.start))
                            }
                            current = max(current, occ.end)
                        }
                        if current < windowEnd {
                            freeIntervals.append((current, windowEnd))
                        }

                        for free in freeIntervals where free.end.timeIntervalSince(free.start) >= duration {
                            var cursor = aligned(free.start, granularity: config.granularityMinutes, calendar: calendar)
                            if cursor < free.start {
                                cursor = cursor.addingTimeInterval(step)
                            }
                            while cursor.addingTimeInterval(duration) <= free.end {
                                starts.append(cursor)
                                cursor = cursor.addingTimeInterval(step)
                            }
                        }
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return starts
    }

    func studyWindows(
        day: Date,
        searchFrom: Date,
        classes: [ExpandedClassBlock],
        config: AppConfiguration,
        calendar: Calendar
    ) -> [(start: Date, end: Date)] {
        guard let clock = clockWindow(day, config: config, calendar: calendar) else { return [] }
        var floor = clock.start
        if calendar.isDate(day, inSameDayAs: searchFrom) || day < calendar.startOfDay(for: searchFrom) {
            floor = max(floor, searchFrom)
        }
        if floor >= clock.end { return [] }

        // Find classes occurring on this day
        let classesToday = classes
            .filter { calendar.isDate($0.start, inSameDayAs: day) || calendar.isDate($0.end, inSameDayAs: day) }
            .sorted { $0.start < $1.start }

        if classesToday.isEmpty {
            return floor < clock.end ? [(floor, clock.end)] : []
        }

        let earliestClassStart = classesToday.map(\.start).min() ?? clock.start
        let latestClassEnd = classesToday.map(\.end).max() ?? clock.end

        // Merge contiguous or overlapping classes for between-class gap evaluation
        var mergedClasses: [(start: Date, end: Date)] = []
        for block in classesToday {
            guard block.end > block.start else { continue }
            if let last = mergedClasses.last {
                if block.start <= last.end {
                    let newEnd = max(last.end, block.end)
                    mergedClasses.removeLast()
                    mergedClasses.append((start: last.start, end: newEnd))
                } else {
                    mergedClasses.append((start: block.start, end: block.end))
                }
            } else {
                mergedClasses.append((start: block.start, end: block.end))
            }
        }

        var segments: [(start: Date, end: Date)] = []

        // 1. Before first class (if allowed)
        if config.allowBeforeFirstClass {
            let segStart = floor
            let segEnd = min(earliestClassStart, clock.end)
            if segStart < segEnd {
                segments.append((segStart, segEnd))
            }
        }

        // 2. Between classes (if allowed)
        if config.allowBetweenClasses && mergedClasses.count > 1 {
            for index in 0..<(mergedClasses.count - 1) {
                let gapStart = max(mergedClasses[index].end, max(floor, clock.start))
                let gapEnd = min(mergedClasses[index + 1].start, clock.end)
                if gapStart < gapEnd {
                    segments.append((gapStart, gapEnd))
                }
            }
        }

        // 3. After last class (always respects commute time)
        let commute = TimeInterval(max(0, config.commuteMinutesAfterLastClass) * 60)
        let afterStart = max(latestClassEnd.addingTimeInterval(commute), max(floor, clock.start))
        if afterStart < clock.end {
            segments.append((afterStart, clock.end))
        }

        return segments.filter { $0.start < $0.end }
    }

    private func clockWindow(_ day: Date, config: AppConfiguration, calendar: Calendar) -> (start: Date, end: Date)? {
        guard
            let windowStart = calendar.date(
                bySettingHour: config.windowStartHour,
                minute: config.windowStartMinute,
                second: 0,
                of: day
            ),
            let windowEnd = calendar.date(
                bySettingHour: config.windowEndHour,
                minute: config.windowEndMinute,
                second: 0,
                of: day
            ),
            windowStart < windowEnd
        else { return nil }
        return (windowStart, windowEnd)
    }

    private func bestCandidate(
        task: PlannableTask,
        duration: TimeInterval,
        candidates: [Date],
        occupied: [OccupiedInterval],
        classBlocks: [ExpandedClassBlock],
        config: AppConfiguration,
        calendar: Calendar,
        dailyNonReviewCounts: [Date: Int],
        dailyCourseBlockCounts: [Date: [String: Int]],
        dailyStudyMinutes: [Date: Int],
        lastEnd: Date?
    ) -> (start: Date, score: Double)? {
        var best: (start: Date, score: Double)?
        for start in candidates {
            let score = scoreSlot(
                task: task,
                start: start,
                duration: duration,
                occupied: occupied,
                classBlocks: classBlocks,
                config: config,
                calendar: calendar,
                dailyNonReviewCounts: dailyNonReviewCounts,
                dailyCourseBlockCounts: dailyCourseBlockCounts,
                dailyStudyMinutes: dailyStudyMinutes,
                lastEnd: lastEnd
            )
            if let current = best {
                if score > current.score || (score == current.score && start < current.start) {
                    best = (start, score)
                }
            } else {
                best = (start, score)
            }
        }
        return best
    }

    func scoreSlot(
        task: PlannableTask,
        start: Date,
        duration: TimeInterval,
        occupied: [OccupiedInterval],
        classBlocks: [ExpandedClassBlock],
        config: AppConfiguration,
        calendar: Calendar,
        dailyNonReviewCounts: [Date: Int],
        lastEnd: Date?
    ) -> Double {
        scoreSlot(
            task: task,
            start: start,
            duration: duration,
            occupied: occupied,
            classBlocks: classBlocks,
            config: config,
            calendar: calendar,
            dailyNonReviewCounts: dailyNonReviewCounts,
            dailyCourseBlockCounts: [:],
            dailyStudyMinutes: [:],
            lastEnd: lastEnd
        )
    }

    func scoreSlot(
        task: PlannableTask,
        start: Date,
        duration: TimeInterval,
        occupied: [OccupiedInterval],
        classBlocks: [ExpandedClassBlock],
        config: AppConfiguration,
        calendar: Calendar,
        dailyNonReviewCounts: [Date: Int],
        dailyCourseBlockCounts: [Date: [String: Int]],
        dailyStudyMinutes: [Date: Int],
        lastEnd: Date?
    ) -> Double {
        let end = start.addingTimeInterval(duration)
        let day = calendar.startOfDay(for: start)
        var score = Double(task.priority) * 14.0

        if let deadline = task.deadline {
            let hours = deadline.timeIntervalSince(start) / 3600
            if hours < 0 {
                score -= 80.0 + min(40.0, abs(hours))
            } else if task.priority >= 3, let earliest = task.earliestStart, let latest = task.latestEnd, latest > earliest {
                // Prefer the middle of the spaced bucket rather than dumping everything ASAP.
                let center = earliest.addingTimeInterval(latest.timeIntervalSince(earliest) / 2)
                let distanceHours = abs(start.timeIntervalSince(center)) / 3600
                score += max(0.0, 36.0 - distanceHours * 2.0)
                score += max(0.0, min(24.0, hours / 6.0))
            } else {
                score += max(0.0, 48.0 - hours)
                // Urgency gradient across the horizon
                score += max(0.0, 20.0 - hours / 24.0)
            }
        }

        if let lastClass = lastClassEnd(on: day, classes: classBlocks, calendar: calendar) {
            if task.priority >= 3 && start >= lastClass {
                score += 28
                let gapHours = start.timeIntervalSince(lastClass) / 3600
                if gapHours <= 1.5 {
                    score += 18
                }
            }
        }

        if task.isReview {
            let hour = calendar.component(.hour, from: start)
            if hour >= 18 {
                score += 24
            } else if hour >= 15 {
                score += 8
            }
        }

        // Personal Energy / Chronotype Affinity
        let startHour = calendar.component(.hour, from: start)
        switch config.chronotype {
        case .morningLark:
            if startHour >= 8 && startHour < 12 {
                score += 14.0
            } else if startHour >= 12 && startHour < 16 {
                score += 6.0
            } else if startHour >= 20 {
                score -= 12.0
            }
        case .nightOwl:
            if startHour >= 17 && startHour < 22 {
                score += 14.0
            } else if startHour >= 13 && startHour < 17 {
                score += 6.0
            } else if startHour < 10 {
                score -= 12.0
            }
        case .balanced:
            if startHour >= 10 && startHour < 17 {
                score += 6.0
            }
        }

        // Spaced Repetition for Exam Prep: distribute across distinct days rather than cramming
        if task.taskKind == TaskKind.testPrep.rawValue, let lastEnd {
            if calendar.isDate(start, inSameDayAs: lastEnd) {
                score -= 16.0
            } else {
                score += 12.0
            }
        }

        // Homework multi-chunk continuation bonus
        if task.taskKind == TaskKind.homework.rawValue, let lastEnd, start >= lastEnd {
            let gap = start.timeIntervalSince(lastEnd)
            if gap <= 30 * 60 {
                score += 10
            }
        }

        // Spaced Repetition Mastery Multiplier (Ebbinghaus / SuperMemo quality feedback):
        // If student struggled (Quality 1), schedule an early recovery session.
        // If mastered (Quality 3), relax urgency so harder subjects take priority.
        if task.masteryRating == 1 {
            score += 24.0
        } else if task.masteryRating == 3 {
            score -= 14.0
        }

        // Anti-clustering / Spaced distribution:
        // Heavily penalize scheduling multiple blocks of the same course on the same day.
        let courseCode = task.courseCode.uppercased()
        if !courseCode.isEmpty {
            let existingBlocksToday = dailyCourseBlockCounts[day]?[courseCode] ?? 0
            if existingBlocksToday > 0 {
                let penaltyPerBlock: Double = task.taskKind == TaskKind.testPrep.rawValue ? 45.0 : 22.0
                score -= Double(existingBlocksToday) * penaltyPerBlock
            }
        }

        // Smart Grouping & Interleaved Practice (Rohrer et al., 2020):
        // Clump related fields together, but interleave different courses on the same day
        // to force cognitive strategy selection!
        let cluster = task.subjectCluster
        if cluster != .general {
            // Affinity with classes of the same or related field on this day
            let classesToday = classBlocks.filter { calendar.isDate($0.start, inSameDayAs: day) }
            for block in classesToday {
                if block.subjectCluster == cluster {
                    score += 12.0
                    break
                } else if block.subjectCluster.isRelated(to: cluster) {
                    score += 6.0
                    break
                }
            }

            // Interleaved Practice Bonus:
            // Reward studying a complementary course of the same/related cluster on this day!
            if let countsToday = dailyCourseBlockCounts[day] {
                for (otherCode, count) in countsToday where count > 0 && otherCode != courseCode {
                    let otherCluster = SubjectCluster.cluster(for: otherCode)
                    if otherCluster == cluster {
                        score += 12.0 // Interleaving bonus within same field!
                        break
                    } else if otherCluster.isRelated(to: cluster) {
                        score += 6.0  // Interleaving bonus within related field!
                        break
                    }
                }
            }

            // Proximity clumping bonus: clump near another study block of the same/related cluster
            for item in occupied where item.kind == .reserved && calendar.isDate(item.start, inSameDayAs: day) {
                let itemCluster = SubjectCluster.cluster(for: item.label)
                guard itemCluster == cluster || itemCluster.isRelated(to: cluster) else { continue }
                let gapBefore = abs(start.timeIntervalSince(item.end))
                let gapAfter = abs(item.start.timeIntervalSince(end))
                let minGap = min(gapBefore, gapAfter)
                if minGap <= 60 * 60 {
                    score += itemCluster == cluster ? 12.0 : 6.0
                    break
                }
            }
        }

        let fatigue = cognitiveFatigue(at: start, classes: classBlocks, decay: config.cognitiveDecayPerHour)
        score -= fatigue * task.intensity * 10

        score -= fragmentationPenalty(start: start, end: end, occupied: occupied)

        if !task.isReview {
            let count = dailyNonReviewCounts[day] ?? 0
            score -= Double(count * count) * 4.0
        }

        let totalMins = dailyStudyMinutes[day] ?? 0
        if totalMins > 180 {
            score -= Double(totalMins - 180) / 20.0
        }

        return score
    }

    func cognitiveFatigue(at date: Date, classes: [ExpandedClassBlock], decay: Double) -> Double {
        classes.reduce(0.0) { partial, block in
            guard block.end <= date else { return partial }
            let hours = date.timeIntervalSince(block.end) / 3600
            return partial + block.cognitiveWeight * exp(-decay * hours)
        }
    }

    func lastClassEnd(on day: Date, classes: [ExpandedClassBlock], calendar: Calendar) -> Date? {
        classes
            .filter { calendar.isDate($0.start, inSameDayAs: day) || calendar.isDate($0.end, inSameDayAs: day) }
            .map(\.end)
            .max()
    }

    private func fragmentationPenalty(start: Date, end: Date, occupied: [OccupiedInterval]) -> Double {
        let next = occupied
            .filter { $0.start >= end && $0.kind != .buffer }
            .map(\.start)
            .min()
        guard let next else { return 0 }
        let leftover = next.timeIntervalSince(end) / 60
        if leftover > 0 && leftover < 30 {
            return (30 - leftover) / 5
        }
        return 0
    }

    private func aligned(_ date: Date, granularity: Int, calendar: Calendar) -> Date {
        let minute = calendar.component(.minute, from: date)
        let remainder = minute % granularity
        let delta = remainder == 0 ? 0 : (granularity - remainder)
        return calendar.date(byAdding: .minute, value: delta, to: calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)) ?? date) ?? date
    }

    private func explain(
        task: PlannableTask,
        start: Date,
        lastClassEnd: Date?,
        occupied: [OccupiedInterval] = [],
        calendar: Calendar
    ) -> String {
        let time = start.formatted(date: .omitted, time: .shortened)
        let cluster = task.subjectCluster

        // Check if placed near a study block in the same/related cluster
        let nearby = occupied.first { item in
            guard item.kind == .reserved, calendar.isDate(item.start, inSameDayAs: start) else { return false }
            let itemCluster = SubjectCluster.cluster(for: item.label)
            guard itemCluster == cluster || itemCluster.isRelated(to: cluster) else { return false }
            let gap = min(abs(start.timeIntervalSince(item.end)), abs(item.start.timeIntervalSince(start)))
            return gap <= 60 * 60
        }

        let clusterSuffix: String
        if let nearby, cluster != .general {
            clusterSuffix = " · Grouped with \(nearby.label)"
        } else {
            clusterSuffix = ""
        }

        if task.taskKind == TaskKind.testPrep.rawValue {
            if let deadline = task.deadline {
                return "Test prep at \(time), ahead of \(deadline.formatted(date: .abbreviated, time: .omitted))\(clusterSuffix)."
            }
            return "Test prep at \(time)\(clusterSuffix)."
        }
        if task.taskKind == TaskKind.homework.rawValue {
            if let deadline = task.deadline {
                return "Homework slot at \(time), due \(deadline.formatted(date: .abbreviated, time: .omitted))\(clusterSuffix)."
            }
            return "Homework slot at \(time)\(clusterSuffix)."
        }
        if task.isReview {
            let hour = calendar.component(.hour, from: start)
            if hour >= 18 {
                return "Spaced review later in the day at \(time)\(clusterSuffix)."
            }
            return "Review block at \(time)\(clusterSuffix)."
        }
        if task.priority >= 3, let lastClassEnd, start >= lastClassEnd {
            return "Study block after class at \(time)\(clusterSuffix)."
        }
        if let deadline = task.deadline {
            return "Study block at \(time) for the week of \(deadline.formatted(date: .abbreviated, time: .omitted))\(clusterSuffix)."
        }
        return "Study block at \(time)\(clusterSuffix)."
    }

    private func unscheduledReason(task: PlannableTask, minutes: Int, candidatesEmpty: Bool, config: AppConfiguration) -> String {
        if candidatesEmpty {
            return "No free \(minutes)-minute slot in the next \(config.horizonDays) days that avoids classes and locked blocks."
        }
        return "Could not place “\(task.title)” without overlapping a class or exceeding the daily focus cap."
    }

    private func uniqueUnscheduled(_ items: [UnscheduledWork]) -> [UnscheduledWork] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.taskID).inserted }
    }

    private func stableChunkID(taskID: UUID, index: Int) -> UUID {
        let base = taskID.uuidString
        let prefix = String(base.dropLast(4))
        let hexSuffix = String(format: "%04X", (index + 1) % 0xFFFF)
        return UUID(uuidString: "\(prefix)\(hexSuffix)") ?? UUID()
    }
}
