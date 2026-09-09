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
            .sorted(by: Self.taskSort)

        for task in sortedTasks {
            let chunks = chunkMinutes(task.remainingMinutes, config: config)
            var placedAll = true

            // Snapshot state for atomic rollback if task cannot be completely placed
            let snapshotPlacementsCount = placements.count
            let snapshotOccupiedCount = occupied.count
            let snapshotDailyCounts = dailyNonReviewCounts
            let snapshotDailyCourseCounts = dailyCourseBlockCounts
            let snapshotDailyStudyMinutes = dailyStudyMinutes
            let snapshotLastEnd = lastEndByTask[task.id]

            for (index, minutes) in chunks.enumerated() {
                let duration = TimeInterval(minutes * 60)
                let candidates = candidateStarts(
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
                        chunkID: stableChunkID(taskID: task.id, index: index),
                        start: best.start,
                        end: end,
                        reason: reason,
                        chunkMinutes: minutes
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
                dailyStudyMinutes[day, default: 0] += minutes
                lastEndByTask[task.id] = end
            }

            if !placedAll {
                // Atomic, clean rollback of any partial placements for this task
                placements.removeSubrange(snapshotPlacementsCount..<placements.count)
                occupied.removeSubrange(snapshotOccupiedCount..<occupied.count)
                dailyNonReviewCounts = snapshotDailyCounts
                dailyCourseBlockCounts = snapshotDailyCourseCounts
                dailyStudyMinutes = snapshotDailyStudyMinutes
                lastEndByTask[task.id] = snapshotLastEnd
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
                if end <= now { continue }
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
                    let windowEnd = min(window.end, searchUntil)
                    var cursor = aligned(window.start, granularity: config.granularityMinutes, calendar: calendar)
                    if cursor < window.start {
                        cursor = cursor.addingTimeInterval(step)
                    }
                    while cursor.addingTimeInterval(duration) <= windowEnd {
                        let end = cursor.addingTimeInterval(duration)
                        let hardOverlap = occupied.contains { interval in
                            interval.overlaps(cursor, end)
                        }
                        if !hardOverlap {
                            starts.append(cursor)
                        }
                        cursor = cursor.addingTimeInterval(step)
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

        // Find classes occurring on this day and clamp to clock boundaries
        let classesToday = classes
            .filter { calendar.isDate($0.start, inSameDayAs: day) || calendar.isDate($0.end, inSameDayAs: day) }
            .sorted { $0.start < $1.start }

        if classesToday.isEmpty {
            return floor < clock.end ? [(floor, clock.end)] : []
        }

        // Merge any overlapping or contiguous class blocks
        var merged: [(start: Date, end: Date)] = []
        for block in classesToday {
            let bStart = max(clock.start, block.start)
            let bEnd = min(clock.end, block.end)
            guard bStart < bEnd else { continue }
            if let last = merged.last {
                if bStart <= last.end {
                    merged[merged.count - 1].end = max(last.end, bEnd)
                } else {
                    merged.append((bStart, bEnd))
                }
            } else {
                merged.append((bStart, bEnd))
            }
        }

        guard !merged.isEmpty else {
            return floor < clock.end ? [(floor, clock.end)] : []
        }

        var segments: [(start: Date, end: Date)] = []
        let first = merged[0]
        let last = merged[merged.count - 1]

        if config.allowBeforeFirstClass {
            let end = min(first.start, clock.end)
            if floor < end {
                segments.append((floor, end))
            }
        }

        if config.allowBetweenClasses && merged.count > 1 {
            for index in 0..<(merged.count - 1) {
                let gapStart = max(merged[index].end, floor)
                let gapEnd = min(merged[index + 1].start, clock.end)
                if gapStart < gapEnd {
                    segments.append((gapStart, gapEnd))
                }
            }
        }

        let commute = TimeInterval(max(0, config.commuteMinutesAfterLastClass) * 60)
        let afterStart = max(last.end.addingTimeInterval(commute), floor)
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
                score -= 80 + min(40, abs(hours))
            } else if task.priority >= 3, let earliest = task.earliestStart, let latest = task.latestEnd, latest > earliest {
                // Prefer the middle of the spaced bucket rather than dumping everything ASAP.
                let center = earliest.addingTimeInterval(latest.timeIntervalSince(earliest) / 2)
                let distanceHours = abs(start.timeIntervalSince(center)) / 3600
                score += max(0, 36 - distanceHours * 2)
                score += max(0, min(24, hours / 6))
            } else {
                score += max(0, 48 - hours)
                // Urgency gradient across the horizon
                score += max(0, 20.0 - hours / 24.0)
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

        // Homework multi-chunk continuation bonus
        if task.taskKind == TaskKind.homework.rawValue, let lastEnd, start >= lastEnd {
            let gap = start.timeIntervalSince(lastEnd)
            if gap <= 30 * 60 {
                score += 10
            }
        }

        // Anti-clustering / Spaced distribution:
        // Heavily penalize scheduling multiple blocks of the same course on the same day.
        let courseCode = task.courseCode.uppercased()
        if !courseCode.isEmpty {
            let existingBlocksToday = dailyCourseBlockCounts[day]?[courseCode] ?? 0
            if existingBlocksToday > 0 {
                score -= Double(existingBlocksToday) * 22.0
            }
        }

        // Smart Grouping & Subject Affinity:
        // Clump similar courses together to minimize cognitive context switching!
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

            // Affinity with other study blocks of similar/related courses today
            if let countsToday = dailyCourseBlockCounts[day] {
                for (otherCode, count) in countsToday where count > 0 && otherCode != courseCode {
                    let otherCluster = SubjectCluster.cluster(for: otherCode)
                    if otherCluster == cluster {
                        score += 10.0
                        break
                    } else if otherCluster.isRelated(to: cluster) {
                        score += 5.0
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
        classes.reduce(0) { partial, block in
            guard block.end <= date else { return partial }
            let hours = date.timeIntervalSince(block.end) / 3600
            return partial + block.cognitiveWeight * exp(-decay * hours)
        }
    }

    func lastClassEnd(on day: Date, classes: [ExpandedClassBlock], calendar: Calendar) -> Date? {
        classes
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
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
        var bytes = taskID.uuid
        bytes.15 = UInt8(truncatingIfNeeded: index + 1)
        return UUID(uuid: bytes)
    }
}
