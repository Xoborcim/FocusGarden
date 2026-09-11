import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct QuickLogView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Course.code) var courses: [Course]

    @State var title: String
    @State var category: ActivityCategory
    @State var durationMinutes: Int
    @State var selectedCourseID: UUID?
    @State var focusRating: Int = 0
    @State var energyRating: Int = 0
    @State var aiUsage: AIUsageLevel = .none
    @State var independentAttemptFirst: Bool = true
    @State var notes: String = ""
    @State var showOptionalDetails: Bool = false

    private let presetDurations = [15, 25, 45, 60, 90, 120]

    init(
        initialTitle: String = "",
        initialCategory: ActivityCategory = .study,
        initialDuration: Int = 45,
        initialCourse: Course? = nil
    ) {
        _title = State(initialValue: initialTitle)
        _category = State(initialValue: initialCategory)
        _durationMinutes = State(initialValue: max(5, initialDuration))
        _selectedCourseID = State(initialValue: initialCourse?.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick Activity Chips
                        recentChipsSection

                        // Activity Name Input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACTIVITY")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.green)

                            TextField("e.g. MAT305 problem set, Gym, Reading", text: $title)
                                .font(FGTheme.mono(.body))
                                .padding(12)
                                .background(FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(FGTheme.green.opacity(0.6), lineWidth: 1)
                                )
                                .foregroundStyle(.white)
                        }

                        // Category Selector
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CATEGORY")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.amber)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(ActivityCategory.allCases) { cat in
                                    let selected = category == cat
                                    Button {
                                        category = cat
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 11))
                                            Text(cat.displayName)
                                                .font(FGTheme.mono(.caption, weight: .bold))
                                        }
                                        .foregroundStyle(selected ? FGTheme.ink : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 8)
                                        .background(selected ? FGTheme.amber : FGTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(FGTheme.amber.opacity(selected ? 1.0 : 0.3), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Duration Presets
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("DURATION")
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                                Spacer()
                                Text("\(durationMinutes) min")
                                    .font(FGTheme.mono(.headline, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                            }

                            HStack(spacing: 8) {
                                ForEach(presetDurations, id: \.self) { mins in
                                    let selected = durationMinutes == mins
                                    Button {
                                        durationMinutes = mins
                                    } label: {
                                        Text("\(mins)m")
                                            .font(FGTheme.mono(.caption, weight: .bold))
                                            .foregroundStyle(selected ? FGTheme.ink : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selected ? FGTheme.green : FGTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(FGTheme.green.opacity(selected ? 1.0 : 0.3), lineWidth: 1)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(spacing: 12) {
                                Text("Custom: \(durationMinutes)m")
                                    .font(FGTheme.mono(.caption))
                                    .foregroundStyle(FGTheme.muted)

                                Spacer()

                                Button {
                                    if durationMinutes > 5 { durationMinutes -= 5 }
                                } label: {
                                    Text("-5m")
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                        .foregroundStyle(FGTheme.muted)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(FGTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if durationMinutes < 720 { durationMinutes += 5 }
                                } label: {
                                    Text("+5m")
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                        .foregroundStyle(FGTheme.green)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(FGTheme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)
                        }

                        // Optional Details Toggle
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showOptionalDetails.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: showOptionalDetails ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11))
                                Text(showOptionalDetails ? "Hide reflection & details" : "+ Add focus, AI usage, or notes")
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                Spacer()
                            }
                            .foregroundStyle(FGTheme.muted)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if showOptionalDetails {
                            optionalDetailsSection
                        }

                        // Save Button
                        Button {
                            saveLog()
                        } label: {
                            Text("SAVE LOG")
                                .font(FGTheme.mono(.headline, weight: .bold))
                                .foregroundStyle(FGTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FGTheme.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: FGTheme.green.opacity(0.3), radius: 8, x: 0, y: 3)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("LOG ACTIVITY")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(FGTheme.mono(.subheadline))
                        .foregroundStyle(FGTheme.muted)
                }
            }
        }
    }

    private var recentChipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT ACTIVITIES")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(services.recentActivityTitles(), id: \.self) { item in
                        Button {
                            title = item
                            // Auto-match course if title equals course code
                            if let match = courses.first(where: { $0.code.uppercased() == item.uppercased() }) {
                                selectedCourseID = match.id
                                category = .study
                            }
                        } label: {
                            Text(item)
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(title.uppercased() == item.uppercased() ? FGTheme.green : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(title.uppercased() == item.uppercased() ? FGTheme.green : FGTheme.muted.opacity(0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var optionalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Course linking
            if !courses.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COURSE / PROJECT")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.muted)

                    Picker("Course", selection: $selectedCourseID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(sortedCourses) { course in
                            Text(coursePickerLabel(for: course)).tag(course.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(FGTheme.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Focus Level
            VStack(alignment: .leading, spacing: 6) {
                Text("FOCUS LEVEL (1–5)")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.muted)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { level in
                        let selected = focusRating == level
                        Button {
                            focusRating = selected ? 0 : level
                        } label: {
                            Text("\(level)")
                                .font(FGTheme.mono(.subheadline, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                                .frame(width: 44, height: 38)
                                .background(selected ? FGTheme.green : FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(FGTheme.green.opacity(selected ? 1.0 : 0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Energy Level
            VStack(alignment: .leading, spacing: 6) {
                Text("ENERGY LEVEL (1–5)")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.muted)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { level in
                        let selected = energyRating == level
                        Button {
                            energyRating = selected ? 0 : level
                        } label: {
                            Text("\(level)")
                                .font(FGTheme.mono(.subheadline, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                                .frame(width: 44, height: 38)
                                .background(selected ? FGTheme.amber : FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(FGTheme.amber.opacity(selected ? 1.0 : 0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // AI Dependence Tracking
            VStack(alignment: .leading, spacing: 8) {
                Text("AI ASSISTANCE")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.muted)

                HStack(spacing: 6) {
                    ForEach(AIUsageLevel.allCases) { level in
                        let selected = aiUsage == level
                        Button {
                            aiUsage = level
                        } label: {
                            Text(level.displayName)
                                .font(FGTheme.mono(.caption2, weight: .bold))
                                .foregroundStyle(selected ? FGTheme.ink : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selected ? FGTheme.green : FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(FGTheme.green.opacity(selected ? 1.0 : 0.3), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(isOn: $independentAttemptFirst) {
                    Text("Attempted independently first")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                .tint(FGTheme.green)
                .padding(.top, 4)
            }

            // Short Note
            VStack(alignment: .leading, spacing: 6) {
                Text("NOTES")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.muted)

                TextField("Optional brief reflection or accomplishment", text: $notes)
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(FGTheme.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FGTheme.muted.opacity(0.2), lineWidth: 1)
        )
    }

    private var sortedCourses: [Course] {
        let calendar = services.configuration.calendar()
        let now = services.clock.now
        let current = AcademicTerm.containing(now, calendar: calendar)
        return courses.sorted { a, b in
            let aCurrent = (a.classBlocks ?? []).contains { $0.belongs(to: current, now: now, calendar: calendar) } ||
                (a.assessments ?? []).contains { current.contains($0.start, calendar: calendar) }
            let bCurrent = (b.classBlocks ?? []).contains { $0.belongs(to: current, now: now, calendar: calendar) } ||
                (b.assessments ?? []).contains { current.contains($0.start, calendar: calendar) }
            if aCurrent != bCurrent { return aCurrent && !bCurrent }
            return a.code < b.code
        }
    }

    private func coursePickerLabel(for course: Course) -> String {
        let calendar = services.configuration.calendar()
        let now = services.clock.now
        let current = AcademicTerm.containing(now, calendar: calendar)
        let isCurrent = (course.classBlocks ?? []).contains { $0.belongs(to: current, now: now, calendar: calendar) } ||
            (course.assessments ?? []).contains { current.contains($0.start, calendar: calendar) }
        if isCurrent {
            return course.displayName
        }
        if let other = course.classBlocks?.first?.term(now: now, calendar: calendar).displayName {
            return "\(course.displayName) (\(other))"
        }
        return course.displayName
    }

    private func saveLog() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCourse = courses.first(where: { $0.id == selectedCourseID })
        let finalTitle = trimmed.isEmpty ? (resolvedCourse?.code ?? category.displayName) : trimmed

        services.logActivity(
            title: finalTitle,
            category: category,
            durationMinutes: durationMinutes,
            timestamp: Date(),
            focusRating: focusRating,
            energyRating: energyRating,
            aiUsage: aiUsage,
            independentAttemptFirst: independentAttemptFirst,
            notes: notes,
            linkedCourse: resolvedCourse
        )
        dismiss()
    }
}
