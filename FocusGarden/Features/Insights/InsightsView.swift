import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

enum InsightTimeframe: String, CaseIterable, Identifiable {
    case today = "TODAY"
    case thisWeek = "THIS WEEK"
    case allTime = "ALL TIME"

    var id: String { rawValue }
}

struct DayProductivityItem: Identifiable {
    var id: String
    var date: Date
    var dayLetter: String
    var dayNumber: String
    var isToday: Bool
    var studyMinutes: Int
    var classMinutes: Int
    var otherMinutes: Int
    var totalMinutes: Int { studyMinutes + classMinutes + otherMinutes }
}

struct TimeBlockProductivity: Identifiable {
    var id: String
    var label: String
    var hoursRange: String
    var studyMinutes: Int
    var classMinutes: Int
    var totalMinutes: Int { studyMinutes + classMinutes }
}

struct WeekProductivityItem: Identifiable {
    var id: String
    var label: String
    var studyMinutes: Int
    var classMinutes: Int
    var totalMinutes: Int { studyMinutes + classMinutes }
}

typealias ProductivityView = InsightsView

struct InsightsView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @Query(sort: \Course.code) var courses: [Course]
    @Query var classBlocks: [ClassBlock]

    @State var timeframe: InsightTimeframe = .thisWeek
    @State var showingWeeklyReview = false
    @State var selectedDayID: String? = nil

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    // Productivity Targets (Minutes)
    private let dailyTargetMinutes: Int = 4 * 60 // 4 hours
    private let weeklyTargetMinutes: Int = 20 * 60 // 20 hours

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Timeframe Switcher
                        timeframePicker

                        // Visual Productivity Gauge Card
                        productivityHeroGauge

                        // Visual Productivity Bar Chart
                        visualProductivityChartSection

                        // Visual Proportional Distribution Bar
                        proportionalDistributionSection

                        // Key Productivity Metrics Grid
                        productivityMetricsGrid

                        // Study Independence & AI Breakdown
                        independenceSection

                        // Course / Subject Breakdown with Visual Bars
                        courseDistributionSection

                        // Weekly Review Reflection Banner
                        weeklyReviewBanner

                        // Recent Log Stream
                        recentLogsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("PRODUCTIVITY")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .sheet(isPresented: $showingWeeklyReview) {
                WeeklyReviewView()
            }
        }
    }

    // MARK: - Filtered Logs
    private var filteredLogs: [ActivityLog] {
        switch timeframe {
        case .today:
            return allLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        case .thisWeek:
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                return allLogs
            }
            return allLogs.filter { $0.timestamp >= weekStart }
        case .allTime:
            return allLogs
        }
    }

    // MARK: - Timeframe Picker
    private var timeframePicker: some View {
        HStack(spacing: 8) {
            ForEach(InsightTimeframe.allCases) { tf in
                let selected = timeframe == tf
                Button {
                    timeframe = tf
                } label: {
                    Text(tf.rawValue)
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(selected ? FGTheme.ink : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? FGTheme.green : FGTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Productivity Calculations
    private var totalStudyMinutes: Int {
        filteredLogs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalClassMinutes: Int {
        filteredLogs.filter { $0.category == .classMeeting }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalExerciseMinutes: Int {
        filteredLogs.filter { $0.category == .exercise }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalLeisureMinutes: Int {
        filteredLogs.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalProductiveMinutes: Int {
        totalStudyMinutes + totalClassMinutes
    }

    private var totalAllLoggedMinutes: Int {
        totalProductiveMinutes + totalExerciseMinutes + totalLeisureMinutes
    }

    private var currentTargetMinutes: Int {
        switch timeframe {
        case .today: return dailyTargetMinutes
        case .thisWeek: return weeklyTargetMinutes
        case .allTime: return weeklyTargetMinutes * 4
        }
    }

    private var progressRatio: Double {
        guard currentTargetMinutes > 0 else { return 0 }
        return min(1.0, Double(totalProductiveMinutes) / Double(currentTargetMinutes))
    }

    private var productivityPercentage: Int {
        guard totalAllLoggedMinutes > 0 else { return 100 }
        return Int((Double(totalProductiveMinutes) / Double(totalAllLoggedMinutes) * 100).rounded())
    }

    // MARK: - Visual Productivity Hero Gauge
    private var productivityHeroGauge: some View {
        HStack(spacing: 20) {
            // Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 96, height: 96)

                Circle()
                    .trim(from: 0, to: CGFloat(max(0.008, progressRatio)))
                    .stroke(
                        AngularGradient(
                            colors: [FGTheme.green, Color.cyan, FGTheme.green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 96, height: 96)
                    .shadow(color: FGTheme.green.opacity(0.35), radius: 6, x: 0, y: 0)

                VStack(spacing: 2) {
                    Text("\(Int((progressRatio * 100).rounded()))%")
                        .font(FGTheme.mono(.title3, weight: .bold))
                        .foregroundStyle(.white)
                    Text("OF TARGET")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                }
            }

            // Stats & Label
            VStack(alignment: .leading, spacing: 4) {
                Text(timeframe == .today ? "TODAY'S PRODUCTIVITY" : (timeframe == .thisWeek ? "THIS WEEK'S PRODUCTIVITY" : "ALL-TIME PRODUCTIVITY"))
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.green)

                Text(formatDuration(totalProductiveMinutes))
                    .font(FGTheme.mono(.title, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: totalProductiveMinutes >= currentTargetMinutes ? "checkmark.seal.fill" : "target")
                        .font(.caption2)
                        .foregroundStyle(totalProductiveMinutes >= currentTargetMinutes ? FGTheme.green : FGTheme.amber)

                    if totalProductiveMinutes >= currentTargetMinutes {
                        Text("Target achieved! Great work.")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.green)
                    } else {
                        Text("\(formatDuration(max(0, currentTargetMinutes - totalProductiveMinutes))) to \(formatDuration(currentTargetMinutes)) target")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                    }
                }

                if totalAllLoggedMinutes > 0 {
                    Text("\(productivityPercentage)% of logged time was focused study or class")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FGTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FGTheme.green.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
    }

    // MARK: - Visual Productivity Bar Chart Section
    private var visualProductivityChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(timeframe == .today ? "HOURLY PRODUCTIVITY TODAY" : (timeframe == .thisWeek ? "DAILY PRODUCTIVITY THIS WEEK" : "WEEKLY PRODUCTIVITY TREND"))
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(FGTheme.green).frame(width: 6, height: 6)
                        Text("Study").font(FGTheme.mono(.caption2)).foregroundStyle(FGTheme.muted)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.cyan).frame(width: 6, height: 6)
                        Text("Class").font(FGTheme.mono(.caption2)).foregroundStyle(FGTheme.muted)
                    }
                }
            }

            VStack(spacing: 12) {
                switch timeframe {
                case .thisWeek:
                    weeklyBarChart
                case .today:
                    todayDiurnalChart
                case .allTime:
                    allTimeTrendChart
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(FGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FGTheme.surface.opacity(0.6), lineWidth: 1)
            )
        }
    }

    // 1. Weekly 7-Day Bar Chart
    private var weekDaysData: [DayProductivityItem] {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = calendar.date(from: comps) else { return [] }

        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        var items: [DayProductivityItem] = []

        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let isToday = calendar.isDate(dayDate, inSameDayAs: now)
            let dayLogs = allLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: dayDate) }

            let studyMins = dayLogs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
            let classMins = dayLogs.filter { $0.category == .classMeeting }.reduce(0) { $0 + $1.durationMinutes }
            let otherMins = dayLogs.filter { $0.category == .project }.reduce(0) { $0 + $1.durationMinutes }

            let dayNum = "\(calendar.component(.day, from: dayDate))"
            let letter = i < dayLetters.count ? dayLetters[i] : "•"

            items.append(
                DayProductivityItem(
                    id: "day-\(i)",
                    date: dayDate,
                    dayLetter: letter,
                    dayNumber: dayNum,
                    isToday: isToday,
                    studyMinutes: studyMins,
                    classMinutes: classMins,
                    otherMinutes: otherMins
                )
            )
        }
        return items
    }

    private var maxWeekDayMinutes: Int {
        let maxVal = weekDaysData.map(\.totalMinutes).max() ?? 0
        return max(180, maxVal) // at least 3h scale
    }

    private var weeklyBarChart: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(weekDaysData) { item in
                    let isSelected = selectedDayID == item.id
                    VStack(spacing: 6) {
                        // Value label above bar
                        Text(item.totalMinutes > 0 ? formatCompactHours(item.totalMinutes) : "—")
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(item.isToday ? FGTheme.green : (item.totalMinutes > 0 ? .white : FGTheme.muted.opacity(0.4)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        // Vertical Bar Container
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 120)

                            if item.totalMinutes > 0 {
                                let totalHeight = max(8.0, CGFloat(item.totalMinutes) / CGFloat(maxWeekDayMinutes) * 120)
                                VStack(spacing: 1) {
                                    if item.studyMinutes > 0 {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [FGTheme.green, FGTheme.green.opacity(0.8)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: max(4.0, CGFloat(item.studyMinutes) / CGFloat(item.totalMinutes) * totalHeight))
                                    }
                                    if item.classMinutes > 0 {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.cyan)
                                            .frame(height: max(4.0, CGFloat(item.classMinutes) / CGFloat(item.totalMinutes) * totalHeight))
                                    }
                                }
                                .frame(height: totalHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(item.isToday ? FGTheme.green : (isSelected ? FGTheme.amber : Color.clear), lineWidth: 1.5)
                        )
                        .onTapGesture {
                            selectedDayID = selectedDayID == item.id ? nil : item.id
                        }

                        // Day Letter
                        Text(item.dayLetter)
                            .font(FGTheme.mono(.caption, weight: item.isToday ? .bold : .medium))
                            .foregroundStyle(item.isToday ? FGTheme.green : .white)

                        // Date Number
                        Text(item.dayNumber)
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(item.isToday ? FGTheme.green.opacity(0.8) : FGTheme.muted)
                    }
                }
            }

            // Detail callout when a day is tapped
            if let selected = weekDaysData.first(where: { $0.id == selectedDayID }) {
                HStack {
                    Text("\(selected.dayLetter) (\(selected.dayNumber)) Details:")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                    Spacer()
                    Text("Study: \(formatDuration(selected.studyMinutes)) · Class: \(formatDuration(selected.classMinutes))")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(FGTheme.surface))
            }
        }
    }

    // 2. Today's Diurnal / Time Block Chart
    private var todayDiurnalBlocks: [TimeBlockProductivity] {
        let todayLogs = allLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }

        var morningStudy = 0, morningClass = 0
        var afternoonStudy = 0, afternoonClass = 0
        var eveningStudy = 0, eveningClass = 0
        var nightStudy = 0, nightClass = 0

        for log in todayLogs {
            let hour = calendar.component(.hour, from: log.timestamp)
            let isStudy = log.isFocusedStudy
            let isClass = log.category == .classMeeting
            let mins = log.durationMinutes

            if hour >= 6 && hour < 12 {
                if isStudy { morningStudy += mins }
                if isClass { morningClass += mins }
            } else if hour >= 12 && hour < 17 {
                if isStudy { afternoonStudy += mins }
                if isClass { afternoonClass += mins }
            } else if hour >= 17 && hour < 22 {
                if isStudy { eveningStudy += mins }
                if isClass { eveningClass += mins }
            } else {
                if isStudy { nightStudy += mins }
                if isClass { nightClass += mins }
            }
        }

        return [
            TimeBlockProductivity(id: "morning", label: "Morning", hoursRange: "6:00 - 12:00", studyMinutes: morningStudy, classMinutes: morningClass),
            TimeBlockProductivity(id: "afternoon", label: "Afternoon", hoursRange: "12:00 - 17:00", studyMinutes: afternoonStudy, classMinutes: afternoonClass),
            TimeBlockProductivity(id: "evening", label: "Evening", hoursRange: "17:00 - 22:00", studyMinutes: eveningStudy, classMinutes: eveningClass),
            TimeBlockProductivity(id: "night", label: "Night", hoursRange: "22:00 - 6:00", studyMinutes: nightStudy, classMinutes: nightClass)
        ]
    }

    private var todayDiurnalChart: some View {
        VStack(spacing: 10) {
            let maxMins = max(60, todayDiurnalBlocks.map(\.totalMinutes).max() ?? 60)
            ForEach(todayDiurnalBlocks) { block in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(block.label)
                            .font(FGTheme.mono(.subheadline, weight: .bold))
                            .foregroundStyle(.white)
                        Text("(\(block.hoursRange))")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Spacer()
                        Text(formatDuration(block.totalMinutes))
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(block.totalMinutes > 0 ? FGTheme.green : FGTheme.muted)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 10)

                            if block.totalMinutes > 0 {
                                HStack(spacing: 1) {
                                    if block.studyMinutes > 0 {
                                        Capsule()
                                            .fill(FGTheme.green)
                                            .frame(width: max(4.0, geo.size.width * CGFloat(block.studyMinutes) / CGFloat(maxMins)))
                                    }
                                    if block.classMinutes > 0 {
                                        Capsule()
                                            .fill(Color.cyan)
                                            .frame(width: max(4.0, geo.size.width * CGFloat(block.classMinutes) / CGFloat(maxMins)))
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
    }

    // 3. All Time Weekly Trend Chart
    private var allTimeTrendData: [WeekProductivityItem] {
        var weeks: [WeekProductivityItem] = []
        for i in (0..<4).reversed() {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: -i, to: now),
                  let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekDate)),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }

            let logs = allLogs.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
            let study = logs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
            let classes = logs.filter { $0.category == .classMeeting }.reduce(0) { $0 + $1.durationMinutes }
            let label = i == 0 ? "This Wk" : (i == 1 ? "Last Wk" : "\(i)w ago")

            weeks.append(WeekProductivityItem(id: "wk-\(i)", label: label, studyMinutes: study, classMinutes: classes))
        }
        return weeks
    }

    private var allTimeTrendChart: some View {
        let maxVal = max(600, allTimeTrendData.map(\.totalMinutes).max() ?? 600)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(allTimeTrendData) { item in
                VStack(spacing: 6) {
                    Text(item.totalMinutes > 0 ? formatCompactHours(item.totalMinutes) : "0h")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(item.totalMinutes > 0 ? FGTheme.green : FGTheme.muted)

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 100)

                        if item.totalMinutes > 0 {
                            let height = max(8.0, CGFloat(item.totalMinutes) / CGFloat(maxVal) * 100)
                            VStack(spacing: 1) {
                                if item.studyMinutes > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(FGTheme.green)
                                        .frame(height: max(4.0, CGFloat(item.studyMinutes) / CGFloat(item.totalMinutes) * height))
                                }
                                if item.classMinutes > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.cyan)
                                        .frame(height: max(4.0, CGFloat(item.classMinutes) / CGFloat(item.totalMinutes) * height))
                                }
                            }
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text(item.label)
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Visual Proportional Distribution Bar
    private var proportionalDistributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIME DISTRIBUTION")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            if totalAllLoggedMinutes == 0 {
                Text("No activity recorded yet in this timeframe.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            } else {
                VStack(spacing: 14) {
                    // Segmented horizontal progress bar
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            if totalStudyMinutes > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(FGTheme.green)
                                    .frame(width: max(4.0, geo.size.width * CGFloat(totalStudyMinutes) / CGFloat(totalAllLoggedMinutes)))
                            }
                            if totalClassMinutes > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.cyan)
                                    .frame(width: max(4.0, geo.size.width * CGFloat(totalClassMinutes) / CGFloat(totalAllLoggedMinutes)))
                            }
                            if totalExerciseMinutes > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                                    .frame(width: max(4.0, geo.size.width * CGFloat(totalExerciseMinutes) / CGFloat(totalAllLoggedMinutes)))
                            }
                            if totalLeisureMinutes > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(FGTheme.amber)
                                    .frame(width: max(4.0, geo.size.width * CGFloat(totalLeisureMinutes) / CGFloat(totalAllLoggedMinutes)))
                            }
                        }
                    }
                    .frame(height: 12)
                    .clipShape(Capsule())

                    // Color Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        legendItem(title: "Focused Study", minutes: totalStudyMinutes, color: FGTheme.green, icon: "brain.head.profile")
                        legendItem(title: "Classes & Lectures", minutes: totalClassMinutes, color: Color.cyan, icon: "graduationcap.fill")
                        legendItem(title: "Exercise & Health", minutes: totalExerciseMinutes, color: Color.orange, icon: "figure.run")
                        legendItem(title: "Leisure & Rest", minutes: totalLeisureMinutes, color: FGTheme.amber, icon: "cup.and.saucer.fill")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            }
        }
    }

    private func legendItem(title: String, minutes: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
                Text(formatDuration(minutes))
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(minutes > 0 ? .white : FGTheme.muted.opacity(0.5))
            }
            Spacer()
        }
    }

    // MARK: - Key Productivity Metrics Grid
    private var averageFocusRating: Double {
        let rated = filteredLogs.filter { $0.focusRating > 0 }
        guard !rated.isEmpty else { return 0 }
        let sum = rated.reduce(0) { $0 + $1.focusRating }
        return Double(sum) / Double(rated.count)
    }

    private var independentRoundsRatio: Int {
        let studyLogs = filteredLogs.filter { $0.isFocusedStudy }
        guard !studyLogs.isEmpty else { return 100 }
        let independent = studyLogs.filter { $0.independentAttemptFirst }.count
        return Int((Double(independent) / Double(studyLogs.count) * 100).rounded())
    }

    private var productivityMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEY PRODUCTIVITY METRICS")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                metricCard(
                    title: "Productive Focus",
                    value: formatDuration(totalStudyMinutes),
                    subtitle: "\(filteredLogs.filter { $0.isFocusedStudy }.count) sessions",
                    icon: "brain.head.profile",
                    accent: FGTheme.green
                )
                metricCard(
                    title: "Class Time",
                    value: formatDuration(totalClassMinutes),
                    subtitle: "Lectures & labs",
                    icon: "graduationcap.fill",
                    accent: Color.cyan
                )
                metricCard(
                    title: "Independence",
                    value: "\(independentRoundsRatio)%",
                    subtitle: "Solved before AI",
                    icon: "sparkles",
                    accent: FGTheme.green
                )
                metricCard(
                    title: "Focus Quality",
                    value: averageFocusRating > 0 ? String(format: "%.1f/5", averageFocusRating) : "—",
                    subtitle: "Self-rated depth",
                    icon: "star.fill",
                    accent: FGTheme.amber
                )
            }
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
                Spacer()
                Text(value)
                    .font(FGTheme.mono(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            Text(subtitle)
                .font(FGTheme.mono(.caption2))
                .foregroundStyle(FGTheme.muted.opacity(0.8))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FGTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Independence & AI Section
    private var independentMinutes: Int {
        filteredLogs.filter { $0.isFocusedStudy && $0.isIndependent }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var aiAssistedMinutes: Int {
        filteredLogs.filter { $0.isFocusedStudy && $0.aiUsage.isAIAssisted }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var independenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COGNITIVE INDEPENDENCE & AI")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Independent Work")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatDuration(independentMinutes))
                            .font(FGTheme.mono(.title3, weight: .bold))
                            .foregroundStyle(FGTheme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().frame(height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI-Assisted Work")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatDuration(aiAssistedMinutes))
                            .font(FGTheme.mono(.title3, weight: .bold))
                            .foregroundStyle(FGTheme.amber)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Independent attempt first")
                            .font(FGTheme.mono(.caption, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Target: outline or draft before consulting AI")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                    }
                    Spacer()
                    Text("\(independentRoundsRatio)%")
                        .font(FGTheme.mono(.title3, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FGTheme.green.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Course / Activity Breakdown with Visual Progress Bars
    private var studyLogsByCourse: [String: [ActivityLog]] {
        var grouped: [String: [ActivityLog]] = [:]
        for log in filteredLogs where log.isFocusedStudy || log.category == .classMeeting {
            let key = log.linkedCourse?.code ?? log.title
            grouped[key, default: []].append(log)
        }
        return grouped
    }

    private var maxCourseMinutes: Int {
        let maxVal = studyLogsByCourse.values.map { logs in
            logs.reduce(0) { $0 + $1.durationMinutes }
        }.max() ?? 1
        return max(1, maxVal)
    }

    private var courseDistributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRODUCTIVITY BY COURSE / ACTIVITY")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            if studyLogsByCourse.isEmpty {
                Text("No study logs recorded in this timeframe.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            } else {
                VStack(spacing: 12) {
                    ForEach(studyLogsByCourse.keys.sorted(), id: \.self) { key in
                        let logs = studyLogsByCourse[key] ?? []
                        let mins = logs.reduce(0) { $0 + $1.durationMinutes }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(key)
                                    .font(FGTheme.mono(.subheadline, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(formatDuration(mins))
                                    .font(FGTheme.mono(.subheadline, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                            }

                            // Visual horizontal progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [FGTheme.green, Color.cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(4.0, geo.size.width * CGFloat(mins) / CGFloat(maxCourseMinutes)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            }
        }
    }

    // MARK: - Weekly Review Banner
    private var weeklyReviewBanner: some View {
        Button {
            showingWeeklyReview = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.title3)
                    .foregroundStyle(FGTheme.amber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEKLY REVIEW")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                    Text("Reflect on your habits, accomplishments, and focus depth.")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(FGTheme.muted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FGTheme.amber.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Logs Section
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ACTIVITY LOGS")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            if filteredLogs.isEmpty {
                Text("No activity logs recorded.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(FGTheme.surface))
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredLogs.prefix(10)) { log in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title)
                                    .font(FGTheme.mono(.subheadline, weight: .bold))
                                    .foregroundStyle(.white)
                                HStack(spacing: 6) {
                                    Text(log.category.displayName)
                                    if log.aiUsage.isAIAssisted {
                                        Text("· \(log.aiUsage.displayName)")
                                            .foregroundStyle(FGTheme.amber)
                                    }
                                    if log.focusRating > 0 {
                                        Text("· Focus \(log.focusRating)/5")
                                    }
                                }
                                .font(FGTheme.mono(.caption2))
                                .foregroundStyle(FGTheme.muted)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(log.durationMinutes)m")
                                    .font(FGTheme.mono(.subheadline, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                                Text(relativeDate(log.timestamp))
                                    .font(FGTheme.mono(.caption2))
                                    .foregroundStyle(FGTheme.muted)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(FGTheme.surface))
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                services.deleteActivityLog(log)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Formatters
    private func formatDuration(_ totalMinutes: Int) -> String {
        if totalMinutes <= 0 { return "0m" }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func formatCompactHours(_ totalMinutes: Int) -> String {
        if totalMinutes <= 0 { return "0h" }
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 {
            return "\(h)h"
        }
        let tenths = (m * 10) / 60
        if tenths == 0 {
            return "\(h)h"
        }
        return "\(h).\(tenths)h"
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private func relativeDate(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? Date.distantPast
        if calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        return Self.monthDayFormatter.string(from: date)
    }
}
