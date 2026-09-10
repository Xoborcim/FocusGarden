import Foundation
import SwiftData
import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    enum Kind: String {
        case schoolClass
        case study
        case testPrep
        case homework
        case exam
        case due
        case completed
        case studyBreak
    }

    enum Source: Equatable {
        case task(UUID)
        case classBlock(UUID)
        case assessment(UUID)
    }

    var id: UUID
    var start: Date
    var end: Date
    var title: String
    var subtitle: String
    var kind: Kind
    var source: Source
    var isAllDay: Bool
}

enum CalendarEditorTarget: Identifiable, Equatable {
    case task(UUID)
    case classBlock(UUID)
    case assessment(UUID)

    var id: String {
        switch self {
        case .task(let id): "task-\(id.uuidString)"
        case .classBlock(let id): "class-\(id.uuidString)"
        case .assessment(let id): "assessment-\(id.uuidString)"
        }
    }
}

enum WeekdayLabel {
    static let short = ["", "S", "M", "T", "W", "T", "F", "S"]
    static let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
}

struct ScheduleView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \FocusTask.scheduledStart) private var tasks: [FocusTask]
    @Query private var classBlocks: [ClassBlock]
    @Query private var assessments: [Assessment]
    @Query(sort: \Course.code) private var courses: [Course]

    @State private var editor: CalendarEditorTarget?
    @State private var showingImporter = false
    @State private var showingMonth = false

    private let hourHeight: CGFloat = 60
    private let gutter: CGFloat = 52

    private var calendar: Calendar { services.configuration.calendar() }

    var body: some View {
        FGScreen(
            title: "SCHEDULE",
            trailing: AnyView(toolbarButtons)
        ) {
            if courses.isEmpty && classBlocks.isEmpty && assessments.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    weekStrip
                    allDayStrip
                    dayGrid
                }
            }
        }
        .sheet(item: $editor) { target in
            CalendarEventEditor(target: target)
        }
        .sheet(isPresented: $showingMonth) {
            MonthCalendarSheet(month: services.selectedDate)
        }
        .calendarImporter(isPresented: $showingImporter)
    }

    private var toolbarButtons: some View {
        HStack(spacing: 14) {
            Button("Today") {
                services.selectedDate = services.clock.now
            }
            .font(FGTheme.mono(.caption, weight: .bold))
            .foregroundStyle(FGTheme.amber)

            Button {
                showingMonth = true
            } label: {
                Image(systemName: "calendar")
                    .foregroundStyle(FGTheme.green)
            }
            .accessibilityLabel("Open calendar")

            Button("Import") {
                showingImporter = true
            }
            .font(FGTheme.mono(.caption, weight: .bold))
            .foregroundStyle(FGTheme.green)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NO COURSES YET")
                .font(FGTheme.mono(.title3, weight: .bold))
                .foregroundStyle(FGTheme.green)
            Text("Import a .ics timetable. FocusGarden keeps the class times, then fills the gaps with study, plus extra blocks before tests and homework.")
                .font(FGTheme.mono(.body))
                .foregroundStyle(FGTheme.muted)
            FGButton(title: "IMPORT .ICS") {
                showingImporter = true
            }
            Spacer()
        }
        .padding(20)
    }

    private var weekStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    shiftWeek(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(FGTheme.green)
                }
                Spacer()
                Text(monthTitle)
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .onTapGesture { showingMonth = true }
                Spacer()
                Button {
                    shiftWeek(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(FGTheme.green)
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let selected = calendar.isDate(day, inSameDayAs: services.selectedDate)
                    let isToday = calendar.isDateInToday(day)
                    Button {
                        services.selectedDate = day
                    } label: {
                        VStack(spacing: 6) {
                            Text(WeekdayLabel.short[calendar.component(.weekday, from: day)])
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : FGTheme.muted)
                            Text("\(calendar.component(.day, from: day))")
                                .font(FGTheme.mono(.body, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? FGTheme.green : Color.clear)
                        .overlay(
                            Rectangle()
                                .stroke(isToday && !selected ? FGTheme.amber : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(Rectangle().stroke(FGTheme.green.opacity(0.4), lineWidth: 1), alignment: .bottom)
    }

    @ViewBuilder
    private var allDayStrip: some View {
        let items = allDayEvents
        if !items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("DUE")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                    ForEach(items) { event in
                        Button {
                            editor = target(for: event)
                        } label: {
                            Text(event.title)
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(event.kind == .exam ? FGTheme.danger : FGTheme.amber)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.5), lineWidth: 1), alignment: .bottom)
        }
    }

    private var dayGrid: some View {
        let events = timedEvents
        let range = visibleHours(for: events)
        let totalHeight = CGFloat(range.count) * hourHeight

        return ScrollView {
            ZStack(alignment: .topLeading) {
                hourLines(range: range, height: totalHeight)
                eventLayer(events: events, range: range, height: totalHeight)
                if calendar.isDateInToday(services.selectedDate) {
                    nowLine(range: range)
                }
            }
            .frame(height: totalHeight)
        }
    }

    private func hourLines(range: Range<Int>, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(range), id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourLabel(hour))
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                        .frame(width: gutter, alignment: .trailing)
                        .padding(.trailing, 8)
                    Rectangle()
                        .fill(FGTheme.green.opacity(0.18))
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .frame(height: height)
    }

    private func eventLayer(events: [CalendarEvent], range: Range<Int>, height: CGFloat) -> some View {
        let laidOut = laidOutEvents(events)
        return GeometryReader { geo in
            let usable = geo.size.width - gutter - 8
            ForEach(laidOut) { item in
                let top = yOffset(item.event.start, range: range)
                let bottom = yOffset(item.event.end, range: range)
                let widthFactor = 1 / CGFloat(max(1, item.columnCount))
                let blockWidth = max(44, usable * widthFactor - 4)
                let x = gutter + 6 + (blockWidth + 4) * CGFloat(item.column)
                let blockHeight = max(28, bottom - top - 2)
                Button {
                    editor = target(for: item.event)
                } label: {
                    eventBlock(item.event)
                }
                .buttonStyle(.plain)
                .frame(width: blockWidth, height: blockHeight, alignment: .topLeading)
                .offset(x: x, y: top + 1)
            }
        }
        .frame(height: height)
    }

    private func eventBlock(_ event: CalendarEvent) -> some View {
        let accent: Color = {
            switch event.kind {
            case .schoolClass: return FGTheme.amber
            case .study: return FGTheme.green
            case .testPrep: return FGTheme.danger
            case .homework: return Color(red: 0.52, green: 0.68, blue: 0.90)
            case .exam: return FGTheme.danger
            case .due: return FGTheme.amber
            case .completed: return FGTheme.muted
            case .studyBreak: return Color(red: 0.88, green: 0.72, blue: 0.35)
            }
        }()

        if event.kind == .studyBreak {
            return AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(FGTheme.amber)
                    Text(event.title)
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                    Text("· \(event.subtitle)")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(FGTheme.surface)
                .overlay(Rectangle().stroke(FGTheme.amber.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            )
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(timeRange(event))
                .font(FGTheme.mono(.caption2))
                .foregroundStyle(accent)
            if !event.subtitle.isEmpty {
                Text(event.subtitle)
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FGTheme.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 4)
        }
        .overlay(Rectangle().stroke(accent, lineWidth: 1.5))
        .opacity(event.kind == .completed ? 0.55 : 1)
        .drawingGroup()
        )
    }

    private func nowLine(range: Range<Int>) -> some View {
        let y = yOffset(services.clock.now, range: range)
        return HStack(spacing: 0) {
            Circle()
                .fill(FGTheme.danger)
                .frame(width: 8, height: 8)
                .offset(x: gutter - 4)
            Rectangle()
                .fill(FGTheme.danger)
                .frame(height: 2)
        }
        .offset(y: y)
        .allowsHitTesting(false)
    }

    private var timedEvents: [CalendarEvent] {
        allEvents.filter { !$0.isAllDay && calendar.isDate($0.start, inSameDayAs: services.selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var allDayEvents: [CalendarEvent] {
        allEvents.filter { $0.isAllDay && calendar.isDate($0.start, inSameDayAs: services.selectedDate) }
    }

    private var allEvents: [CalendarEvent] {
        let day = services.selectedDate
        let weekday = calendar.component(.weekday, from: day)
        let dayStart = calendar.startOfDay(for: day)
        var events: [CalendarEvent] = []

        for block in classBlocks where block.dayOfWeek == weekday && block.isActive(on: day, calendar: calendar) {
            let start = dayStart.addingTimeInterval(block.startTime)
            let end = start.addingTimeInterval(block.duration)
            events.append(
                CalendarEvent(
                    id: block.id,
                    start: start,
                    end: end,
                    title: block.course?.code.isEmpty == false ? (block.course?.code ?? "Class") : (block.summary.isEmpty ? "Class" : block.summary),
                    subtitle: [block.meetingType, "Class"].filter { !$0.isEmpty }.joined(separator: " · "),
                    kind: .schoolClass,
                    source: .classBlock(block.id),
                    isAllDay: false
                )
            )
        }

        for assessment in assessments {
            let onDay = calendar.isDate(assessment.start, inSameDayAs: day)
                || (assessment.isAllDay && calendar.isDate(assessment.start, inSameDayAs: day))
            guard onDay else { continue }
            let kind: CalendarEvent.Kind = assessment.assessmentKind == .test ? .exam : .due
            events.append(
                CalendarEvent(
                    id: assessment.id,
                    start: assessment.start,
                    end: assessment.end,
                    title: assessment.title,
                    subtitle: assessment.assessmentKind.displayName,
                    kind: kind,
                    source: .assessment(assessment.id),
                    isAllDay: assessment.isAllDay
                )
            )
        }

        for task in tasks {
            guard !task.isCompleted else { continue }
            guard let start = task.scheduledStart, let end = task.scheduledEnd else { continue }
            guard calendar.isDate(start, inSameDayAs: day) else { continue }
            let kind: CalendarEvent.Kind = {
                if task.isCompleted { return .completed }
                switch task.kind {
                case .testPrep: return .testPrep
                case .homework: return .homework
                case .study: return .study
                }
            }()
            events.append(
                CalendarEvent(
                    id: task.id,
                    start: start,
                    end: end,
                    title: task.title,
                    subtitle: task.scheduleReason,
                    kind: kind,
                    source: .task(task.id),
                    isAllDay: false
                )
            )
        }

        // Add visual break blocks between consecutive study sessions
        let studyEvents = events.filter { $0.kind == .study || $0.kind == .testPrep || $0.kind == .homework }
            .sorted { $0.start < $1.start }
        if studyEvents.count > 1 {
            for i in 0..<(studyEvents.count - 1) {
                let currentEnd = studyEvents[i].end
                let nextStart = studyEvents[i + 1].start
                let gap = nextStart.timeIntervalSince(currentEnd)
                if gap >= 5 * 60 && gap <= 120 * 60 {
                    let breakMinutes = Int(gap / 60)
                    var subtitle = "\(breakMinutes)m rest"
                    if case .task(let idA) = studyEvents[i].source,
                       case .task(let idB) = studyEvents[i + 1].source,
                       let taskA = tasks.first(where: { $0.id == idA }),
                       let taskB = tasks.first(where: { $0.id == idB }),
                       taskA.subjectCluster != .general,
                       taskA.subjectCluster == taskB.subjectCluster {
                        subtitle = "\(breakMinutes)m rest · \(taskA.subjectCluster.shortTag) block"
                    }
                    events.append(
                        CalendarEvent(
                            id: UUID(),
                            start: currentEnd,
                            end: nextStart,
                            title: "Break",
                            subtitle: subtitle,
                            kind: .studyBreak,
                            source: studyEvents[i].source,
                            isAllDay: false
                        )
                    )
                }
            }
        }

        return events
    }

    private var weekDays: [Date] {
        let weekday = calendar.component(.weekday, from: services.selectedDate)
        let start = calendar.date(byAdding: .day, value: 1 - weekday, to: calendar.startOfDay(for: services.selectedDate)) ?? services.selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthTitle: String {
        services.selectedDate.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_US_POSIX"))).uppercased()
    }

    private func shiftWeek(_ delta: Int) {
        services.selectedDate = calendar.date(byAdding: .day, value: delta * 7, to: services.selectedDate) ?? services.selectedDate
    }

    private func visibleHours(for events: [CalendarEvent]) -> Range<Int> {
        var start = services.configuration.windowStartHour
        var end = services.configuration.windowEndHour
        for event in events {
            start = min(start, calendar.component(.hour, from: event.start))
            let endHour = calendar.component(.hour, from: event.end)
            let endMinute = calendar.component(.minute, from: event.end)
            end = max(end, endMinute > 0 ? endHour + 1 : max(endHour, endHour + 1))
        }
        start = min(max(0, start), 23)
        end = min(24, max(start + 1, end))
        return start..<end
    }

    private func yOffset(_ date: Date, range: Range<Int>) -> CGFloat {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (CGFloat(hour - range.lowerBound) + CGFloat(minute) / 60) * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = calendar.dateComponents([.year, .month, .day], from: services.selectedDate)
        components.hour = hour
        components.minute = 0
        let date = calendar.date(from: components) ?? services.selectedDate
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func timeRange(_ event: CalendarEvent) -> String {
        "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
    }

    private func target(for event: CalendarEvent) -> CalendarEditorTarget {
        switch event.source {
        case .task(let id): .task(id)
        case .classBlock(let id): .classBlock(id)
        case .assessment(let id): .assessment(id)
        }
    }

    private struct LaidOutEvent: Identifiable {
        var id: UUID { event.id }
        var event: CalendarEvent
        var column: Int
        var columnCount: Int
    }

    private func laidOutEvents(_ events: [CalendarEvent]) -> [LaidOutEvent] {
        let sorted = events.sorted { $0.start < $1.start }
        var clusters: [[CalendarEvent]] = []
        for event in sorted {
            if var last = clusters.last, last.contains(where: { $0.start < event.end && event.start < $0.end }) {
                last.append(event)
                clusters[clusters.count - 1] = last
            } else {
                clusters.append([event])
            }
        }

        var result: [LaidOutEvent] = []
        for cluster in clusters {
            var columns: [[CalendarEvent]] = []
            for event in cluster {
                if let index = columns.firstIndex(where: { col in col.allSatisfy { $0.end <= event.start } }) {
                    columns[index].append(event)
                    result.append(LaidOutEvent(event: event, column: index, columnCount: 0))
                } else {
                    columns.append([event])
                    result.append(LaidOutEvent(event: event, column: columns.count - 1, columnCount: 0))
                }
            }
            let count = max(1, columns.count)
            for index in result.indices where cluster.contains(where: { $0.id == result[index].event.id }) {
                result[index].columnCount = count
            }
        }
        return result
    }
}
