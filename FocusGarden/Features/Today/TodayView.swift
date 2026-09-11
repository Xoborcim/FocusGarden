import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct TimelineItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case classBlock
        case activityLog(ActivityCategory)
        case openTime
    }

    var id: String
    var title: String
    var subtitle: String
    var startTime: Date
    var endTime: Date
    var kind: Kind
    var durationMinutes: Int
}

struct TodayView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @Query var classBlocks: [ClassBlock]
    @Query(sort: \Course.code) var courses: [Course]

    @State var showingLogSheet = false
    @State var showingTimerSheet = false
    @State var showingCoursesSheet = false
    @State var showingSettingsSheet = false

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection

                        // Day Summary Reality Cards
                        realityCardsGrid

                        // Observational Timeline
                        timelineSection

                        // Action Buttons
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("SPROUT")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingCoursesSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "books.vertical.fill")
                                .font(.caption)
                            Text("Courses")
                                .font(FGTheme.mono(.caption, weight: .bold))
                        }
                        .foregroundStyle(FGTheme.muted)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.subheadline)
                            .foregroundStyle(FGTheme.muted)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                QuickLogView()
            }
            .sheet(isPresented: $showingTimerSheet) {
                FocusTimerView()
            }
            .sheet(isPresented: $showingCoursesSheet) {
                NavigationStack {
                    CoursesView()
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText.uppercased())
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.green)

            Text(dateText)
                .font(FGTheme.rounded(.title2, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 4)
    }

    private var greetingText: String {
        let hour = calendar.component(.hour, from: now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: now)
    }

    // MARK: - Reality Cards
    private var todayLogs: [ActivityLog] {
        allLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
    }

    private var currentTerm: AcademicTerm {
        AcademicTerm.containing(now, calendar: calendar)
    }

    private var todayClasses: [ClassBlock] {
        let weekday = calendar.component(.weekday, from: now)
        return classBlocks.filter { block in
            block.dayOfWeek == weekday &&
            block.isActive(on: now, calendar: calendar) &&
            block.belongs(to: currentTerm, now: now, calendar: calendar)
        }
    }

    private var focusedMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var independentMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy && $0.isIndependent }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var aiAssistedMinutes: Int {
        todayLogs.filter { $0.isFocusedStudy && $0.aiUsage.isAIAssisted }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var classMinutes: Int {
        let scheduledClassMinutes = todayClasses.reduce(0) { $0 + Int(($1.duration / 60).rounded()) }
        let loggedClassMinutes = todayLogs.filter { $0.category == .classMeeting }.reduce(0) { $0 + $1.durationMinutes }
        return max(scheduledClassMinutes, loggedClassMinutes)
    }

    private var exerciseMinutes: Int {
        todayLogs.filter { $0.category == .exercise }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var leisureMinutes: Int {
        todayLogs.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var realityCardsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY AT A GLANCE")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                realityCard(title: "Focused Work", minutes: focusedMinutes, icon: "brain.head.profile", color: FGTheme.green)
                realityCard(title: "Independent", minutes: independentMinutes, icon: "person.fill", color: FGTheme.green.opacity(0.85))
                realityCard(title: "AI-Assisted", minutes: aiAssistedMinutes, icon: "sparkles", color: FGTheme.amber)
                realityCard(title: "Classes", minutes: classMinutes, icon: "graduationcap.fill", color: Color.cyan)
                realityCard(title: "Exercise", minutes: exerciseMinutes, icon: "figure.run", color: Color.orange)
                realityCard(title: "Leisure & Rest", minutes: leisureMinutes, icon: "cup.and.saucer.fill", color: FGTheme.muted)
            }
        }
    }

    private func realityCard(title: String, minutes: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
                Spacer()
                Text(formatMinutes(minutes))
                    .font(FGTheme.mono(.headline, weight: .bold))
                    .foregroundStyle(minutes > 0 ? .white : FGTheme.muted)
            }

            Text(title)
                .font(FGTheme.mono(.caption, weight: .medium))
                .foregroundStyle(FGTheme.muted)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FGTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(minutes > 0 ? color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func formatMinutes(_ total: Int) -> String {
        if total <= 0 { return "0m" }
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    // MARK: - Observational Timeline
    private var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        let todayStart = calendar.startOfDay(for: now)

        // 1. Add class blocks today
        for block in todayClasses {
            let start = todayStart.addingTimeInterval(block.startTime)
            let end = start.addingTimeInterval(block.duration)
            let code = block.course?.code ?? block.summary
            items.append(
                TimelineItem(
                    id: "class-\(block.id)",
                    title: "\(code) (\(block.meetingType))",
                    subtitle: block.location.isEmpty ? "Class" : block.location,
                    startTime: start,
                    endTime: end,
                    kind: .classBlock,
                    durationMinutes: Int(block.duration / 60)
                )
            )
        }

        // 2. Add logged activities today
        for log in todayLogs {
            let end = log.timestamp
            let start = log.startTime ?? end.addingTimeInterval(-TimeInterval(max(1, log.durationMinutes) * 60))
            items.append(
                TimelineItem(
                    id: "log-\(log.id)",
                    title: log.title,
                    subtitle: log.notes.isEmpty ? log.category.displayName : "\(log.category.displayName) · \(log.notes)",
                    startTime: start,
                    endTime: end,
                    kind: .activityLog(log.category),
                    durationMinutes: log.durationMinutes
                )
            )
        }

        // Sort chronologically
        items.sort { $0.startTime < $1.startTime }

        // 3. Interlace open / unlogged periods between events if gap >= 20 mins
        var resolved: [TimelineItem] = []
        for (idx, item) in items.enumerated() {
            if idx > 0 {
                let prev = resolved.last ?? items[idx - 1]
                if item.startTime > prev.endTime {
                    let gapMinutes = Int(item.startTime.timeIntervalSince(prev.endTime) / 60)
                    if gapMinutes >= 20 {
                        resolved.append(
                            TimelineItem(
                                id: "open-\(prev.id)-\(item.id)",
                                title: "Free / unlogged",
                                subtitle: "\(gapMinutes)m available",
                                startTime: prev.endTime,
                                endTime: item.startTime,
                                kind: .openTime,
                                durationMinutes: gapMinutes
                            )
                        )
                    }
                }
            }
            resolved.append(item)
        }

        return resolved
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TIMELINE")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
                Spacer()
                Text("\(timelineItems.count) events")
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }

            if timelineItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(FGTheme.green.opacity(0.8))
                    Text("No activities logged yet today.")
                        .font(FGTheme.mono(.body))
                        .foregroundStyle(.white)
                    Text("Live your day first, then tap below to record what you did.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FGTheme.surface.opacity(0.6))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(timelineItems) { item in
                        timelineRow(for: item)
                    }
                }
            }
        }
    }

    private func timelineRow(for item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(from: item.startTime))
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(.white)
                Text(timeString(from: item.endTime))
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }
            .frame(width: 54, alignment: .trailing)

            // Timeline dot & line
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(for: item.kind))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(FGTheme.mono(.body, weight: .bold))
                        .foregroundStyle(item.kind == .openTime ? FGTheme.muted : .white)
                    Spacer()
                    Text("\(item.durationMinutes)m")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(item.kind == .openTime ? FGTheme.muted.opacity(0.6) : FGTheme.green)
                }
                Text(item.subtitle)
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.kind == .openTime ? Color.clear : FGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.kind == .openTime ? FGTheme.muted.opacity(0.15) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func dotColor(for kind: TimelineItem.Kind) -> Color {
        switch kind {
        case .classBlock: return Color.cyan
        case .activityLog(let cat):
            switch cat {
            case .study, .project: return FGTheme.green
            case .exercise: return Color.orange
            case .leisure: return FGTheme.amber
            default: return FGTheme.muted
            }
        case .openTime: return FGTheme.muted.opacity(0.3)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                showingLogSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                    Text("LOG ACTIVITY")
                        .font(FGTheme.mono(.headline, weight: .bold))
                }
                .foregroundStyle(FGTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(FGTheme.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: FGTheme.green.opacity(0.3), radius: 8, x: 0, y: 3)
            }

            Button {
                showingTimerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.subheadline)
                    Text("Optional Focus Timer")
                        .font(FGTheme.mono(.subheadline, weight: .bold))
                }
                .foregroundStyle(FGTheme.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(FGTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FGTheme.green.opacity(0.3), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 10)
    }
}
