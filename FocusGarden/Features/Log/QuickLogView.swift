import Foundation
#if !SKIP
import SwiftData
#endif
import SwiftUI

struct QuickLogView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Course.code) var courses: [Course]
    @Query(sort: \ActivityLog.timestamp, order: .reverse) private var recentLogs: [ActivityLog]

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
    @State private var isSaving: Bool = false
    @State private var showSavedBanner: Bool = false
    @State private var savedSuccessMessage: String = ""

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
                        // Success Confirmation Banner
                        if showSavedBanner {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(FGTheme.stainedGlassViolet)
                                Text(savedSuccessMessage)
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(FGTheme.stoneElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(FGTheme.stainedGlassViolet.opacity(0.6), lineWidth: 1)
                            )
                            .transition(.opacity)
                        }

                        // Quick Activity Chips
                        recentChipsSection

                        // Activity Name Input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ACTIVITY")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.stainedGlassViolet)

                            TextField("e.g. MAT305 problem set, Gym, Reading", text: $title)
                                .font(FGTheme.mono(.body))
                                .padding(12)
                                .background(FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(FGTheme.stainedGlassViolet.opacity(0.5), lineWidth: 1)
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
                            HStack(spacing: 8) {
                                if isSaving {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                    Text("RECORDED")
                                        .font(FGTheme.mono(.headline, weight: .bold))
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.headline)
                                    Text("RECORD ACTIVITY")
                                        .font(FGTheme.mono(.headline, weight: .bold))
                                }
                            }
                            .foregroundStyle(FGTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                FGTheme.stainedGlassViolet,
                                                FGTheme.stainedGlassViolet.opacity(0.85)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                FGTheme.stoneBevel.opacity(0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.2
                                    )
                            )
                            .shadow(color: FGTheme.stainedGlassViolet.opacity(0.35), radius: 8, x: 0, y: 3)
                        }
                        .disabled(isSaving)
                        .fgTactileButton(fill: true, accent: FGTheme.stainedGlassViolet, cornerRadius: 12)
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
                    Button("Cancel") {
                        cancelLog()
                    }
                    .font(FGTheme.mono(.subheadline))
                    .foregroundStyle(FGTheme.muted)
                }
            }
        }
    }

    private var displayedRecentTitles: [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(8)
        for log in recentLogs.prefix(30) {
            let t = log.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && seen.insert(t.uppercased()).inserted {
                result.append(t)
                if result.count >= 8 { break }
            }
        }
        if result.isEmpty {
            var fallback: [String] = []
            for course in courses {
                let code = course.code.trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty && seen.insert(code.uppercased()).inserted {
                    fallback.append(code)
                    if fallback.count >= 8 { break }
                }
            }
            let standard = ["Study", "Problem Set", "Reading", "Gym", "Leisure", "Personal Project"]
            for s in standard where seen.insert(s.uppercased()).inserted {
                fallback.append(s)
                if fallback.count >= 8 { break }
            }
            return fallback
        }
        return result
    }

    private func selectRecentActivity(_ item: String) {
        title = item
        if let match = courses.first(where: { $0.code.uppercased() == item.uppercased() }) {
            selectedCourseID = match.id
            category = .study
        }
    }

    private var recentChipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT ACTIVITIES")
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(displayedRecentTitles, id: \.self) { item in
                        Button {
                            selectRecentActivity(item)
                        } label: {
                            Text(item)
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(title.uppercased() == item.uppercased() ? FGTheme.stainedGlassViolet : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(FGTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(title.uppercased() == item.uppercased() ? FGTheme.stainedGlassViolet : FGTheme.muted.opacity(0.3), lineWidth: 1)
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
        courses
    }

    private func coursePickerLabel(for course: Course) -> String {
        course.displayName
    }

    private func saveLog() {
        guard !isSaving else { return }
        isSaving = true
        FGTheme.triggerHaptic()

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

        savedSuccessMessage = "Logged \(durationMinutes)m of \(finalTitle)"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSavedBanner = true
        }

        // Reset fields for subsequent entries
        resetForm()

        dismiss()
        services.selectedTab = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedBanner = false
                isSaving = false
            }
        }
    }

    private func cancelLog() {
        FGTheme.triggerHaptic()
        resetForm()
        dismiss()
        services.selectedTab = 0
    }

    private func resetForm() {
        title = ""
        notes = ""
        focusRating = 0
        energyRating = 0
        aiUsage = .none
        independentAttemptFirst = true
        selectedCourseID = nil
        category = .study
        durationMinutes = 45
    }
}
