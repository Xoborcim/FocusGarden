import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct WeeklyReviewView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @Query(sort: \Course.code) var courses: [Course]

    // Reflective answers (persisted in UserDefaults)
    @AppStorage("review_whatWorked") private var whatWorked: String = ""
    @AppStorage("review_whatDistracted") private var whatDistracted: String = ""
    @AppStorage("review_subjectAvoided") private var subjectAvoided: String = ""
    @AppStorage("review_aiReliance") private var aiReliance: String = ""
    @AppStorage("review_bestIndependentThinking") private var bestIndependentThinking: String = ""
    @AppStorage("review_changeNextWeek") private var changeNextWeek: String = ""

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    init() {}

    private var weekLogs: [ActivityLog] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return allLogs
        }
        return allLogs.filter { $0.timestamp >= weekStart }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        // Summary Section
                        timeSummarySection

                        // Quality Section
                        qualitySection

                        // Patterns Section
                        patternsSection

                        // Reflective Questions Section
                        reflectiveQuestionsSection

                        Button {
                            dismiss()
                        } label: {
                            Text("COMPLETE REVIEW")
                                .font(FGTheme.mono(.headline, weight: .bold))
                                .foregroundStyle(FGTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FGTheme.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 12)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("WEEKLY REVIEW")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(FGTheme.mono(.subheadline))
                        .foregroundStyle(FGTheme.muted)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HONEST AWARENESS")
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)
            Text("Review your week to see where time actually went.")
                .font(FGTheme.mono(.body))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Time Summary
    private var focusedMinutes: Int {
        weekLogs.filter { $0.isFocusedStudy }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var exerciseMinutes: Int {
        weekLogs.filter { $0.category == .exercise }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var leisureMinutes: Int {
        weekLogs.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var timeSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIME SPENT THIS WEEK")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 8) {
                summaryRow("Focused Study", formatMinutes(focusedMinutes), FGTheme.green)
                summaryRow("Exercise & Health", formatMinutes(exerciseMinutes), Color.orange)
                summaryRow("Leisure & Rest", formatMinutes(leisureMinutes), FGTheme.amber)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
        }
    }

    private func summaryRow(_ title: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(FGTheme.mono(.subheadline))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(FGTheme.mono(.subheadline, weight: .bold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Quality
    private var independentMinutes: Int {
        weekLogs.filter { $0.isFocusedStudy && $0.isIndependent }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var aiAssistedMinutes: Int {
        weekLogs.filter { $0.isFocusedStudy && $0.aiUsage.isAIAssisted }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var averageFocusRating: Double {
        let rated = weekLogs.filter { $0.focusRating > 0 }
        guard !rated.isEmpty else { return 0 }
        let sum = rated.reduce(0) { $0 + $1.focusRating }
        return Double(sum) / Double(rated.count)
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDY QUALITY & INDEPENDENCE")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 8) {
                summaryRow("Independent Problem Solving", formatMinutes(independentMinutes), FGTheme.green)
                summaryRow("AI-Assisted Study", formatMinutes(aiAssistedMinutes), FGTheme.amber)
                summaryRow("Average Focus Level", String(format: "%.1f / 5.0", averageFocusRating), .white)
                summaryRow("Total Focused Sessions", "\(weekLogs.filter { $0.isFocusedStudy }.count)", FGTheme.green)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
        }
    }

    // MARK: - Patterns
    private var longestSessionMinutes: Int {
        weekLogs.map(\.durationMinutes).max() ?? 0
    }

    private var mostAttendedSubject: String {
        var studyMinutesByCourse: [String: Int] = [:]
        for log in weekLogs where log.isFocusedStudy {
            let key = log.linkedCourse?.code ?? log.title
            studyMinutesByCourse[key, default: 0] += log.durationMinutes
        }
        var topSubject = "None"
        var maxMins = 0
        for (subject, mins) in studyMinutesByCourse {
            if mins > maxMins {
                maxMins = mins
                topSubject = subject
            }
        }
        return topSubject
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OBSERVED PATTERNS")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            VStack(spacing: 8) {
                summaryRow("Longest Session", "\(longestSessionMinutes)m", FGTheme.green)
                summaryRow("Most Studied Subject", mostAttendedSubject, .white)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FGTheme.surface)
            )
        }
    }

    // MARK: - Reflective Questions
    private var reflectiveQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REFLECTIVE INQUIRY")
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.muted)
                Text("Answers are saved for your eyes only. Sprout will never generate tasks or pressure from them.")
                    .font(FGTheme.mono(.caption2))
                    .foregroundStyle(FGTheme.muted)
            }

            questionField(prompt: "What worked well this week?", text: $whatWorked)
            questionField(prompt: "What distracted me?", text: $whatDistracted)
            questionField(prompt: "Which subject did I avoid?", text: $subjectAvoided)
            questionField(prompt: "Did I rely on AI more than I intended?", text: $aiReliance)
            questionField(prompt: "When did I do my best independent thinking?", text: $bestIndependentThinking)
            questionField(prompt: "What do I want to change next week?", text: $changeNextWeek)
        }
    }

    private func questionField(prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt)
                .font(FGTheme.mono(.caption, weight: .bold))
                .foregroundStyle(FGTheme.green)

            TextField("Notes...", text: text, axis: .vertical)
                .lineLimit(3)
                .font(FGTheme.mono(.caption))
                .padding(10)
                .background(FGTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(FGTheme.muted.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(.white)
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
}
