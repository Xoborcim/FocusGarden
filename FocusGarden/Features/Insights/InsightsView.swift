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

struct InsightsView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @Query(sort: \Course.code) var courses: [Course]

    @State var timeframe: InsightTimeframe = .thisWeek
    @State var showingWeeklyReview = false

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Timeframe Picker
                        timeframePicker

                        // Weekly Review Hero Trigger
                        weeklyReviewBanner

                        // Time Breakdown Section
                        timeBreakdownSection

                        // AI Dependence & Cognitive Independence Section
                        aiDependenceSection

                        // Course Distribution Section
                        courseDistributionSection

                        // Recent Log Stream
                        recentLogsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("INSIGHTS")
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
                    Text("Reflect on your study habits, distractions, and independence.")
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(FGTheme.muted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FGTheme.amber.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Breakdown Section
    private var totalFocusedMinutes: Int {
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

    private var timeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHERE YOUR TIME WENT")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 8) {
                metricRow(title: "Focused Deep Work", minutes: totalFocusedMinutes, color: FGTheme.green, icon: "brain.head.profile")
                metricRow(title: "Classes & Lectures", minutes: totalClassMinutes, color: Color.cyan, icon: "graduationcap.fill")
                metricRow(title: "Exercise & Health", minutes: totalExerciseMinutes, color: Color.orange, icon: "figure.run")
                metricRow(title: "Leisure & Resting", minutes: totalLeisureMinutes, color: FGTheme.amber, icon: "cup.and.saucer.fill")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
        }
    }

    private func metricRow(title: String, minutes: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(FGTheme.mono(.subheadline))
                .foregroundStyle(.white)

            Spacer()

            Text(formatMinutes(minutes))
                .font(FGTheme.mono(.subheadline, weight: .bold))
                .foregroundStyle(minutes > 0 ? color : FGTheme.muted)
        }
        .padding(.vertical, 4)
    }

    // MARK: - AI Dependence & Quality
    private var independentMinutes: Int {
        filteredLogs.filter { $0.isFocusedStudy && $0.isIndependent }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var aiAssistedMinutes: Int {
        filteredLogs.filter { $0.isFocusedStudy && $0.aiUsage.isAIAssisted }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var independentAttemptsPercentage: Int {
        let studyLogs = filteredLogs.filter { $0.isFocusedStudy }
        guard !studyLogs.isEmpty else { return 100 }
        let independentFirst = studyLogs.filter { $0.independentAttemptFirst }.count
        return Int((Double(independentFirst) / Double(studyLogs.count) * 100).rounded())
    }

    private var aiDependenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDY INDEPENDENCE & AI")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Independent Work")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatMinutes(independentMinutes))
                            .font(FGTheme.mono(.title3, weight: .bold))
                            .foregroundStyle(FGTheme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI-Assisted Work")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatMinutes(aiAssistedMinutes))
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
                        Text("Target: solve or outline before asking AI")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                    }
                    Spacer()
                    Text("\(independentAttemptsPercentage)%")
                        .font(FGTheme.mono(.title3, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FGTheme.green.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Course Distribution Section
    private var studyLogsByCourse: [String: [ActivityLog]] {
        var grouped: [String: [ActivityLog]] = [:]
        for log in filteredLogs where log.isFocusedStudy {
            let key = log.linkedCourse?.code ?? log.title
            grouped[key, default: []].append(log)
        }
        return grouped
    }

    private var courseDistributionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDY TIME BY COURSE / ACTIVITY")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            if studyLogsByCourse.isEmpty {
                Text("No study logs in this timeframe.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FGTheme.surface)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(studyLogsByCourse.keys.sorted(), id: \.self) { key in
                        let logs = studyLogsByCourse[key] ?? []
                        let mins = logs.reduce(0) { $0 + $1.durationMinutes }
                        HStack {
                            Text(key)
                                .font(FGTheme.mono(.subheadline, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(formatMinutes(mins))
                                .font(FGTheme.mono(.subheadline))
                                .foregroundStyle(FGTheme.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FGTheme.surface)
                )
            }
        }
    }

    // MARK: - Recent Logs Section
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT LOGS")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            if filteredLogs.isEmpty {
                Text("No logs recorded.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FGTheme.surface)
                    )
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
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(FGTheme.surface)
                        )
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

    private func formatMinutes(_ total: Int) -> String {
        if total <= 0 { return "0m" }
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func relativeDate(_ date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? Date.distantPast
        if calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
