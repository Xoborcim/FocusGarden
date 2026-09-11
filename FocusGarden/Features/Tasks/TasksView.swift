import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "TODAY"
    case upcoming = "UPCOMING"
    case all = "ALL"
    case completed = "DONE"

    var id: String { rawValue }
}

enum TaskGroupMode: String, CaseIterable, Identifiable {
    case byDate = "BY DATE"
    case byCluster = "BY CLUSTER"

    var id: String { rawValue }
}

struct TasksView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \FocusTask.scheduledStart) var tasks: [FocusTask]
    @Query(sort: \Course.code) var courses: [Course]

    @State var filter: TaskFilter = .today
    @State var groupMode: TaskGroupMode = .byDate
    @State var showingNewTask = false
    @State var editorTarget: CalendarEditorTarget?

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    init() {}

    var body: some View {
        FGScreen(
            title: "TASKS",
            trailing: AnyView(toolbarTrailing)
        ) {
            VStack(spacing: 0) {
                statsStrip
                filterBar
                groupModeBar
                taskList
            }
        }
        .sheet(item: $editorTarget) { target in
            CalendarEventEditor(target: target)
        }
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet()
        }
    }

    private var toolbarTrailing: some View {
        HStack(spacing: 12) {
            Button {
                showingNewTask = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Task")
                }
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)
            }
        }
    }

    private var statsStrip: some View {
        let todayCount = todayTasks.count
        let todayMinutes = todayTasks.reduce(0) { $0 + max(15, $1.estimatedMinutes) }
        let upcomingCount = upcomingTasks.count

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
                Text("\(todayCount) tasks · \(todayMinutes.durationFormatted)")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(todayCount > 0 ? FGTheme.green : .white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("UPCOMING")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
                Text("\(upcomingCount) scheduled")
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FGTheme.surface, FGTheme.surface.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FGTheme.green.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(TaskFilter.allCases) { item in
                let selected = filter == item
                Button {
                    filter = item
                } label: {
                    Text(item.rawValue)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(selected ? FGTheme.ink : FGTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? FGTheme.green : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(FGTheme.green.opacity(selected ? 0.4 : 0.18), lineWidth: 1)
                        )
                        .shadow(color: selected ? FGTheme.green.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var groupModeBar: some View {
        HStack(spacing: 8) {
            Text("GROUP:")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            ForEach(TaskGroupMode.allCases) { mode in
                let selected = groupMode == mode
                Button {
                    groupMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode == .byDate ? "calendar" : "square.grid.2x2")
                            .font(.system(size: 9))
                        Text(mode.rawValue)
                    }
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(selected ? FGTheme.ink : FGTheme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? FGTheme.amber : FGTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selected ? FGTheme.amber.opacity(0.5) : FGTheme.muted.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: selected ? FGTheme.amber.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if groupMode == .byCluster {
                    clusterSection
                } else {
                    switch filter {
                    case .today:
                        todaySection
                        if !unscheduledTasks.isEmpty {
                            unscheduledSection
                        }
                    case .upcoming:
                        upcomingSection
                    case .all:
                        todaySection
                        upcomingSection
                        if !unscheduledTasks.isEmpty {
                            unscheduledSection
                        }
                        if !completedTasks.isEmpty {
                            completedSection
                        }
                    case .completed:
                        completedSection
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Sections

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "TODAY'S TASKS", count: todayTasks.count, accent: FGTheme.green)

            if todayTasks.isEmpty {
                FGCard(accent: FGTheme.green.opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NO TASKS SCHEDULED TODAY")
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(FGTheme.green)
                        Text("You're all caught up for today! Enjoy your free time or add a custom study block.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                }
            } else {
                ForEach(Array(todayTasks.enumerated()), id: \.element.id) { index, task in
                    VStack(alignment: .leading, spacing: 6) {
                        // Smart Grouping connector banner between consecutive tasks today
                        if index > 0 {
                            let prev = todayTasks[index - 1]
                            let sameCluster = prev.subjectCluster == task.subjectCluster && task.subjectCluster != .general
                            let relatedCluster = !sameCluster && prev.subjectCluster.isRelated(to: task.subjectCluster) && prev.subjectCluster != .general && task.subjectCluster != .general

                            if sameCluster {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.system(size: 9))
                                    Text("SMART GROUPING: Clustered \(task.subjectCluster.shortTag) block (context affinity)")
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                }
                                .foregroundStyle(task.subjectCluster.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FGTheme.surface)
                                .overlay(Rectangle().stroke(task.subjectCluster.accentColor.opacity(0.4), lineWidth: 1))
                                .padding(.leading, 6)
                            } else if relatedCluster {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.merge")
                                        .font(.system(size: 9))
                                    Text("SMART GROUPING: Related fields (\(prev.subjectCluster.shortTag) + \(task.subjectCluster.shortTag))")
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                }
                                .foregroundStyle(Color(red: 0.45, green: 0.85, blue: 1.0))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FGTheme.surface)
                                .overlay(Rectangle().stroke(Color(red: 0.45, green: 0.85, blue: 1.0).opacity(0.4), lineWidth: 1))
                                .padding(.leading, 6)
                            }
                        }

                        TaskCard(
                            task: task,
                            isToday: true,
                            onTap: { editorTarget = .task(task.id) },
                            onToggleDone: { services.markTaskDone(task) },
                            onStartSession: { services.startFocusSession(task) },
                            onResumeSession: { services.resumeFocusSession(task) }
                        )

                        if index < todayTasks.count - 1,
                           let currentEnd = task.scheduledEnd,
                           let nextStart = todayTasks[index + 1].scheduledStart,
                           nextStart > currentEnd {
                            let gapMins = max(1, Int(nextStart.timeIntervalSince(currentEnd) / 60))
                            HStack(spacing: 6) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FGTheme.amber)
                                Text("\(gapMins)m break before next block at \(nextStart.formatted(date: .omitted, time: .shortened))")
                                    .font(FGTheme.mono(.caption2, weight: .bold))
                                    .foregroundStyle(FGTheme.amber)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(FGTheme.surface)
                            .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.3), lineWidth: 1))
                            .padding(.leading, 8)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "UPCOMING SCHEDULED TASKS", count: upcomingTasks.count, accent: FGTheme.amber)

            if upcomingTasks.isEmpty {
                FGCard(accent: FGTheme.amber.opacity(0.4)) {
                    Text("NO UPCOMING SCHEDULED TASKS")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                }
            } else {
                let grouped = groupedUpcomingTasks
                let sortedDays = grouped.keys.sorted()

                ForEach(sortedDays, id: \.self) { day in
                    let dayTasks = (grouped[day] ?? []).sorted { ($0.scheduledStart ?? .distantPast) < ($1.scheduledStart ?? .distantPast) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayHeader(for: day))
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(FGTheme.amber)
                            .padding(.top, 4)

                        ForEach(dayTasks) { task in
                            TaskCard(
                                task: task,
                                isToday: false,
                                onTap: { editorTarget = .task(task.id) },
                                onToggleDone: { services.markTaskDone(task) },
                                onStartSession: { services.startFocusSession(task) },
                                onResumeSession: { services.resumeFocusSession(task) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var groupedUpcomingTasks: [Date: [FocusTask]] {
        var grouped: [Date: [FocusTask]] = [:]
        for task in upcomingTasks {
            let day = task.scheduledStart.map { calendar.startOfDay(for: $0) } ?? Date.distantFuture
            grouped[day, default: []].append(task)
        }
        return grouped
    }

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "UNSCHEDULED TASKS", count: unscheduledTasks.count, accent: FGTheme.danger)

            ForEach(unscheduledTasks) { task in
                FGCard(accent: FGTheme.danger) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(task.kind.displayName.uppercased())
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(FGTheme.danger)
                            if let code = task.linkedCourse?.code, !code.isEmpty {
                                Text("· \(code)")
                                    .font(FGTheme.mono(.caption2, weight: .bold))
                                    .foregroundStyle(FGTheme.muted)
                            }

                            // Subject Cluster badge
                            HStack(spacing: 3) {
                                Image(systemName: task.subjectCluster.icon)
                                    .font(.system(size: 8))
                                Text(task.subjectCluster.shortTag)
                                    .font(FGTheme.mono(.caption2, weight: .bold))
                            }
                            .foregroundStyle(task.subjectCluster.accentColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(task.subjectCluster.accentColor.opacity(0.12))
                            .overlay(Rectangle().stroke(task.subjectCluster.accentColor.opacity(0.3), lineWidth: 1))

                            Spacer()
                            Text("\(task.estimatedMinutes)m")
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(task.title)
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(.white)

                        if !task.scheduleReason.isEmpty {
                            Text(task.scheduleReason)
                                .font(FGTheme.mono(.caption2))
                                .foregroundStyle(FGTheme.muted)
                        }

                        HStack(spacing: 10) {
                            Button("SCHEDULE MANUALLY") {
                                editorTarget = .task(task.id)
                            }
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.amber)

                            Spacer()

                            Button("DELETE") {
                                services.deleteTask(task)
                            }
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.danger)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "COMPLETED", count: completedTasks.count, accent: FGTheme.muted)

            if completedTasks.isEmpty {
                Text("No completed tasks yet.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            } else {
                ForEach(completedTasks) { task in
                    FGCard(accent: FGTheme.muted.opacity(0.4)) {
                        HStack(spacing: 12) {
                            Button {
                                services.unmarkTaskDone(task)
                            } label: {
                                Image(systemName: "checkmark.square.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(FGTheme.green)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(FGTheme.mono(.subheadline))
                                    .strikethrough()
                                    .foregroundStyle(FGTheme.muted)
                                if let completedAt = task.completedAt {
                                    Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(FGTheme.mono(.caption2))
                                        .foregroundStyle(FGTheme.muted.opacity(0.8))
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var clusterSection: some View {
        let candidateTasks: [FocusTask] = {
            switch filter {
            case .today: return todayTasks
            case .upcoming: return upcomingTasks
            case .all: return tasks.filter { !$0.isCompleted }
            case .completed: return completedTasks
            }
        }()

        var grouped: [SubjectCluster: [FocusTask]] = [:]
        for task in candidateTasks {
            grouped[task.subjectCluster, default: []].append(task)
        }
        let presentClusters = SubjectCluster.allCases.filter { !(grouped[$0] ?? []).isEmpty }

        return VStack(alignment: .leading, spacing: 16) {
            if presentClusters.isEmpty {
                FGCard(accent: FGTheme.muted) {
                    Text("NO TASKS IN THIS VIEW")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                }
            } else {
                ForEach(presentClusters) { cluster in
                    let clusterTasks = (grouped[cluster] ?? []).sorted {
                        ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture)
                    }
                    let totalMins = clusterTasks.reduce(0) { $0 + max(15, $1.estimatedMinutes) }
                    let coursesInCluster = Set(clusterTasks.compactMap { $0.linkedCourse?.code }).filter { !$0.isEmpty }

                    VStack(alignment: .leading, spacing: 8) {
                        // Cluster Header Card
                        HStack(spacing: 8) {
                            Image(systemName: cluster.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(cluster.accentColor)

                            Text(cluster.rawValue.uppercased())
                                .font(FGTheme.mono(.subheadline, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(clusterTasks.count) tasks · \(totalMins.durationFormatted)")
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(cluster.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(cluster.accentColor.opacity(0.15))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(FGTheme.surface)
                        .overlay(Rectangle().stroke(cluster.accentColor.opacity(0.55), lineWidth: 1.5))

                        // Smart Grouping Clump Banner if multiple courses exist in cluster
                        if coursesInCluster.count > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FGTheme.green)
                                Text("SMART GROUPING: \(coursesInCluster.count) courses clumped (\(coursesInCluster.sorted().joined(separator: ", ")))")
                                    .font(FGTheme.mono(.caption2, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(FGTheme.surface)
                            .overlay(Rectangle().stroke(FGTheme.green.opacity(0.4), lineWidth: 1))
                        }

                        // Tasks in this cluster
                        ForEach(clusterTasks) { task in
                            TaskCard(
                                task: task,
                                isToday: task.scheduledStart.map { calendar.isDateInToday($0) } ?? false,
                                onTap: { editorTarget = .task(task.id) },
                                onToggleDone: { services.markTaskDone(task) },
                                onStartSession: { services.startFocusSession(task) },
                                onResumeSession: { services.resumeFocusSession(task) }
                            )
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func sectionHeader(title: String, count: Int, accent: Color) -> some View {
        HStack {
            Text(title)
                .font(FGTheme.mono(.subheadline, weight: .bold))
                .foregroundStyle(accent)
            Spacer()
            Text("\(count)")
                .font(FGTheme.mono(.caption, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(accent.opacity(0.18))
                .foregroundStyle(accent)
        }
    }

    private func dayHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let formattedDate = formatter.string(from: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date.distantPast
        if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "TOMORROW · \(formattedDate)"
        }
        let weekday = WeekdayLabel.names[safe: calendar.component(.weekday, from: date)]?.uppercased() ?? ""
        return "\(weekday) · \(formattedDate)"
    }

    // MARK: - Filtered Queries

    private var todayTasks: [FocusTask] {
        tasks.filter { task in
            guard !task.isCompleted, let start = task.scheduledStart else { return false }
            return calendar.isDateInToday(start)
        }
        .sorted { ($0.scheduledStart ?? .distantPast) < ($1.scheduledStart ?? .distantPast) }
    }

    private var upcomingTasks: [FocusTask] {
        tasks.filter { task in
            guard !task.isCompleted, let start = task.scheduledStart else { return false }
            return !calendar.isDateInToday(start) && start > now
        }
        .sorted { ($0.scheduledStart ?? .distantPast) < ($1.scheduledStart ?? .distantPast) }
    }

    private var unscheduledTasks: [FocusTask] {
        tasks.filter { task in
            !task.isCompleted && task.scheduledStart == nil
        }
    }

    private var completedTasks: [FocusTask] {
        tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
}

// MARK: - Task Card

struct TaskCard: View {
    let task: FocusTask
    let isToday: Bool
    let onTap: () -> Void
    let onToggleDone: () -> Void
    let onStartSession: () -> Void
    let onResumeSession: () -> Void

    private var accent: Color {
        switch task.kind {
        case .testPrep: return FGTheme.danger
        case .homework: return Color(red: 0.45, green: 0.75, blue: 1.0)
        case .study: return FGTheme.green
        }
    }

    private var durationLabel: String {
        if let start = task.scheduledStart, let end = task.scheduledEnd, end > start {
            let mins = Int(end.timeIntervalSince(start) / 60)
            return "\(mins)m"
        }
        return "\(task.estimatedMinutes)m"
    }

    private var timeRangeString: String {
        guard let start = task.scheduledStart, let end = task.scheduledEnd else { return "" }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        FGCard(accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                // Header tags
                HStack(spacing: 6) {
                    Text(task.kind.displayName.uppercased())
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(accent)

                    if let code = task.linkedCourse?.code, !code.isEmpty {
                        Text("· \(code)")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.amber)
                    }

                    // Subject Cluster Badge
                    HStack(spacing: 3) {
                        Image(systemName: task.subjectCluster.icon)
                            .font(.system(size: 8))
                        Text(task.subjectCluster.shortTag)
                            .font(FGTheme.mono(.caption2, weight: .bold))
                    }
                    .foregroundStyle(task.subjectCluster.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(task.subjectCluster.accentColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(task.subjectCluster.accentColor.opacity(0.35), lineWidth: 1)
                    )

                    if task.masteryRating == .hard {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7))
                            Text("REVIEW")
                                .font(FGTheme.mono(.caption2, weight: .bold))
                        }
                        .foregroundStyle(FGTheme.danger)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(FGTheme.danger.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(FGTheme.danger.opacity(0.4), lineWidth: 1)
                        )
                    }

                    if task.isSoftLocked {
                        Text("· PINNED")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.amber)
                    }

                    Spacer()

                    Text(durationLabel)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(FGTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(accent.opacity(0.3), lineWidth: 1)
                        )
                }

                // Title & timing
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(FGTheme.mono(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !timeRangeString.isEmpty {
                        Text(timeRangeString)
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(accent)
                    }

                    if !task.scheduleReason.isEmpty {
                        Text(task.scheduleReason)
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                            .lineLimit(1)
                    }
                }

                // Action Bar
                HStack(spacing: 10) {
                    Button(action: onToggleDone) {
                        HStack(spacing: 4) {
                            Image(systemName: "square")
                            Text("DONE")
                        }
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if isToday {
                        if task.isInSession {
                            Button(action: onResumeSession) {
                                HStack(spacing: 4) {
                                    Circle().fill(FGTheme.green).frame(width: 6, height: 6)
                                    Text("RESUME")
                                }
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(FGTheme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(FGTheme.green)
                                )
                                .shadow(color: FGTheme.green.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: onStartSession) {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                    Text("START")
                                }
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(FGTheme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(accent)
                                )
                                .shadow(color: accent.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: onTap) {
                        Text("EDIT")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        #if !SKIP
        .contentShape(Rectangle())
        #endif
        .onTapGesture { onTap() }
    }
}

// MARK: - New Task Sheet

struct NewTaskSheet: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Course.code) var courses: [Course]

    @State var title = ""
    @State var selectedCourseID: UUID?
    @State var selectedKind: TaskKind = .study
    @State var durationMinutes: Int = 45
    @State var priority: Int = 2
    @State var hasDeadline = false
    @State var deadline: Date = Date().addingTimeInterval(24 * 3600)

    private let presetDurations = [15, 30, 45, 60, 90, 120]

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TASK TITLE")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.green)
                            TextField("e.g. Read chapter 4, Problem set 2", text: $title)
                                .font(FGTheme.mono(.body))
                                .padding(10)
                                .background(FGTheme.surface)
                                .overlay(Rectangle().stroke(FGTheme.green, lineWidth: 1.5))
                                .foregroundStyle(.white)
                        }

                        // Course Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("COURSE")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.amber)
                            Picker("Course", selection: $selectedCourseID) {
                                Text("None / General").tag(nil as UUID?)
                                ForEach(courses) { course in
                                    Text(course.displayName).tag(course.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(FGTheme.amber)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(FGTheme.surface)
                            .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.6), lineWidth: 1))
                        }

                        // Task Kind
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TYPE")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.green)
                            HStack(spacing: 8) {
                                ForEach(TaskKind.allCases) { kind in
                                    let selected = selectedKind == kind
                                    Button {
                                        selectedKind = kind
                                    } label: {
                                        Text(kind.displayName.uppercased())
                                            .font(FGTheme.mono(.caption2, weight: .bold))
                                            .foregroundStyle(selected ? FGTheme.ink : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? FGTheme.green : FGTheme.surface)
                                            .overlay(Rectangle().stroke(FGTheme.green, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DURATION (\(durationMinutes)m)")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.green)
                            HStack(spacing: 6) {
                                ForEach(presetDurations, id: \.self) { mins in
                                    let selected = durationMinutes == mins
                                    Button {
                                        durationMinutes = mins
                                    } label: {
                                        Text("\(mins)m")
                                            .font(FGTheme.mono(.caption2, weight: .bold))
                                            .foregroundStyle(selected ? FGTheme.ink : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? FGTheme.green : FGTheme.surface)
                                            .overlay(Rectangle().stroke(FGTheme.green.opacity(0.5), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PRIORITY")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.amber)
                            HStack(spacing: 8) {
                                ForEach([(1, "LOW"), (2, "NORMAL"), (3, "HIGH")], id: \.0) { level, name in
                                    let selected = priority == level
                                    Button {
                                        priority = level
                                    } label: {
                                        Text(name)
                                            .font(FGTheme.mono(.caption2, weight: .bold))
                                            .foregroundStyle(selected ? FGTheme.ink : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? FGTheme.amber : FGTheme.surface)
                                            .overlay(Rectangle().stroke(FGTheme.amber, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Set Deadline", isOn: $hasDeadline)
                                .font(FGTheme.mono(.subheadline, weight: .bold))
                                .tint(FGTheme.amber)
                            if hasDeadline {
                                DatePicker(
                                    "Deadline",
                                    selection: $deadline,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .colorScheme(.dark)
                                .labelsHidden()
                            }
                        }
                        .padding(10)
                        .background(FGTheme.surface)
                        .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.4), lineWidth: 1))

                        // Submit
                        FGButton(title: "CREATE TASK") {
                            let course = courses.first { $0.id == selectedCourseID }
                            services.addTask(
                                title: title,
                                course: course,
                                priority: priority,
                                estimatedMinutes: durationMinutes,
                                kind: selectedKind,
                                deadline: hasDeadline ? deadline : nil
                            )
                            dismiss()
                        }
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("NEW TASK")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FGTheme.muted)
                }
            }
        }
    }
}
