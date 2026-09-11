#if !SKIP
import SwiftData
#endif
import SwiftUI

struct CoursesView: View {
    @Environment(AppServices.self) var services
    @Query(sort: \Course.code) var courses: [Course]
    @State var showingImporter = false

    @State var selectedTermID: String = ""

    init() {}

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }

    private var currentTerm: AcademicTerm {
        AcademicTerm.containing(now, calendar: calendar)
    }

    private var availableTerms: [AcademicTerm] {
        var termsSet = Set<AcademicTerm>()
        for course in courses {
            for block in course.classBlocks ?? [] {
                termsSet.insert(block.term(now: now, calendar: calendar))
            }
            for assessment in course.assessments ?? [] {
                termsSet.insert(AcademicTerm.containing(assessment.start, calendar: calendar))
            }
        }
        return termsSet.sorted { $0.start(calendar: calendar) < $1.start(calendar: calendar) }
    }

    private var activeTerm: AcademicTerm {
        if let match = availableTerms.first(where: { $0.id == selectedTermID }) {
            return match
        }
        if availableTerms.contains(currentTerm) {
            return currentTerm
        }
        return availableTerms.first ?? currentTerm
    }

    var body: some View {
        FGScreen(
            title: "COURSES",
            trailing: AnyView(
                Button("Import") { showingImporter = true }
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.green)
            )
        ) {
            VStack(spacing: 0) {
                if availableTerms.count > 1 {
                    termPickerBar
                }

                if visibleCourses.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("No courses found for \(selectedTermID == "ALL" ? "any term" : activeTerm.displayName).")
                            .font(FGTheme.mono(.body))
                            .foregroundStyle(FGTheme.muted)
                        FGButton(title: "IMPORT .ICS") { showingImporter = true }
                        Spacer()
                    }
                    .padding(20)
                } else {
                    List {
                        ForEach(visibleCourses) { course in
                            NavigationLink {
                                CourseDetailView(course: course)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(course.displayName)
                                            .font(FGTheme.mono(.headline, weight: .bold))
                                            .foregroundStyle(.white)

                                        Spacer()

                                        if let termBadge = termBadgeFor(course) {
                                            Text(termBadge)
                                                .font(FGTheme.mono(.caption2, weight: .bold))
                                                .foregroundStyle(FGTheme.muted)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(FGTheme.surface)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }

                                        HStack(spacing: 3) {
                                            Image(systemName: course.subjectCluster.icon)
                                                .font(.system(size: 8))
                                            Text(course.subjectCluster.shortTag)
                                                .font(FGTheme.mono(.caption2, weight: .bold))
                                        }
                                        .foregroundStyle(course.subjectCluster.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(course.subjectCluster.accentColor.opacity(0.12))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(course.subjectCluster.accentColor.opacity(0.35), lineWidth: 1)
                                        )
                                    }

                                    Text(summary(for: course))
                                        .font(FGTheme.mono(.caption))
                                        .foregroundStyle(FGTheme.muted)
                                }
                            }
                            .listRowBackground(FGTheme.surface)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Drop", role: .destructive) {
                                    services.deleteCourse(course)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .calendarImporter(isPresented: $showingImporter)
    }

    private var termPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableTerms) { term in
                    let isSelected = (selectedTermID.isEmpty && term == activeTerm) || selectedTermID == term.id
                    Button {
                        selectedTermID = term.id
                    } label: {
                        Text(term.displayName.uppercased())
                            .font(FGTheme.mono(.caption2, weight: isSelected ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? FGTheme.green : FGTheme.surface)
                            .foregroundStyle(isSelected ? Color.black : FGTheme.muted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                let isAll = selectedTermID == "ALL"
                Button {
                    selectedTermID = "ALL"
                } label: {
                    Text("ALL")
                        .font(FGTheme.mono(.caption2, weight: isAll ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isAll ? FGTheme.green : FGTheme.surface)
                        .foregroundStyle(isAll ? Color.black : FGTheme.muted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func termBadgeFor(_ course: Course) -> String? {
        var terms = Set<String>()
        for block in course.classBlocks ?? [] {
            terms.insert(block.term(now: now, calendar: calendar).displayName.uppercased())
        }
        for assessment in course.assessments ?? [] {
            terms.insert(AcademicTerm.containing(assessment.start, calendar: calendar).displayName.uppercased())
        }
        if terms.count == 1 {
            return terms.first
        } else if terms.count > 1 {
            return "MULTI-TERM"
        }
        return nil
    }

    private var visibleCourses: [Course] {
        if selectedTermID == "ALL" {
            return courses
        }
        let targetTerm = activeTerm
        return courses.filter { course in
            let hasMatchingBlock = (course.classBlocks ?? []).contains { $0.belongs(to: targetTerm, now: now, calendar: calendar) }
            let hasMatchingAssessment = (course.assessments ?? []).contains { targetTerm.contains($0.start, calendar: calendar) }
            if hasMatchingBlock || hasMatchingAssessment {
                return true
            }
            // If course has no blocks and no assessments, only show in active term or ALL
            if (course.classBlocks ?? []).isEmpty && (course.assessments ?? []).isEmpty {
                return targetTerm == currentTerm
            }
            return false
        }
    }

    private func summary(for course: Course) -> String {
        let classes = course.classBlocks?.count ?? 0
        let tests = course.tests.count
        let homework = course.homeworks.count
        let study = course.incompleteTasks.filter { $0.kind == .study }.count
        return "\(course.difficultyLabel) · \(classes) classes · \(tests) tests · \(homework) homework · \(study) study"
    }
}

struct CourseDetailView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    let course: Course
    @Query(sort: \ActivityLog.timestamp, order: .reverse) var allLogs: [ActivityLog]
    @State var draft: ManualAssessmentDraft?
    @State var editingBlock: ClassBlock?
    @State var addingClass = false
    @State var showingEditCourse = false
    @State var showingSyllabusImport = false
    @State var showingDropConfirmation = false

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }
    private var term: AcademicTerm { AcademicTerm.containing(now, calendar: calendar) }

    init(course: Course) {
        self.course = course
    }

    private var termBlocks: [ClassBlock] {
        guard let blocks = course.classBlocks, !blocks.isEmpty else { return [] }
        let matching = blocks.filter { $0.belongs(to: term, now: now, calendar: calendar) }
        return matching.isEmpty ? blocks : matching
    }

    private var termTests: [Assessment] {
        let matching = course.tests.filter { term.contains($0.start, calendar: calendar) }
        return matching.isEmpty ? course.tests : matching
    }

    private var termHomework: [Assessment] {
        let matching = course.homeworks.filter { term.contains($0.start, calendar: calendar) }
        return matching.isEmpty ? course.homeworks : matching
    }

    var body: some View {
        ZStack {
            FGTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FGCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(course.displayName)
                                        .font(FGTheme.mono(.title3, weight: .bold))
                                        .foregroundStyle(FGTheme.green)
                                    Button("Edit details") { showingEditCourse = true }
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                        .foregroundStyle(FGTheme.green.opacity(0.8))
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: course.subjectCluster.icon)
                                        .font(.system(size: 9))
                                    Text(course.subjectCluster.rawValue.uppercased())
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                }
                                .foregroundStyle(course.subjectCluster.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(course.subjectCluster.accentColor.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(course.subjectCluster.accentColor.opacity(0.35), lineWidth: 1)
                                )
                            }
                            Text("Difficulty")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.muted)
                            Picker("Difficulty", selection: difficultyBinding) {
                                Text("1 Easy").tag(1)
                                Text("2 Light").tag(2)
                                Text("3 Normal").tag(3)
                                Text("4 Hard").tag(4)
                                Text("5 Brutal").tag(5)
                            }
                            .pickerStyle(.segmented)
                            Text(difficultyCaption)
                                .font(FGTheme.mono(.caption))
                                .foregroundStyle(FGTheme.muted)
                        }
                    }
                    activitySummarySection
                    recentSessionsSection
                    classesSection(termBlocks: termBlocks)

                    FGCard(accent: FGTheme.danger) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DROP COURSE")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.danger)
                            Text("Dropping this course removes its lectures and timings.")
                                .font(FGTheme.mono(.caption))
                                .foregroundStyle(FGTheme.muted)
                            Button("Drop Course", role: .destructive) {
                                showingDropConfirmation = true
                            }
                            .font(FGTheme.mono(.body, weight: .bold))
                            .foregroundStyle(FGTheme.danger)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(course.code)
        #if !os(macOS)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Term test") { draft = .termTest }
                    Button("Homework") { draft = .homework }
                    Button("Final exam") { draft = .finalExam }
                    Divider()
                    Button("Import syllabus...") { showingSyllabusImport = true }
                    Button("Add class timing...") { addingClass = true }
                    Button("Edit course details...") { showingEditCourse = true }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(FGTheme.green)
                }
                .accessibilityLabel("Add test or homework")
            }
        }
        .sheet(item: $draft) { kind in
            AddAssessmentView(course: course, draft: kind)
        }
        .sheet(item: $editingBlock) { block in
            EditClassBlockView(block: block)
        }
        .sheet(isPresented: $addingClass) {
            EditClassBlockView(course: course)
        }
        .sheet(isPresented: $showingEditCourse) {
            EditCourseView(course: course)
        }
        .sheet(isPresented: $showingSyllabusImport) {
            ImportSyllabusView(course: course)
        }
        .alert("Drop \(course.code)?", isPresented: $showingDropConfirmation) {
            Button("Drop Course", role: .destructive) {
                services.deleteCourse(course)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all scheduled lectures, study blocks, and tests for this course.")
        }
    }

    private func classRow(_ block: ClassBlock) -> some View {
        HStack(alignment: .top) {
            Text(blockLabel(block))
            Spacer(minLength: 8)
            Button("Edit") { editingBlock = block }
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.amber)
        }
    }

    private var difficultyBinding: Binding<Int> {
        Binding(
            get: { Course.clampedDifficulty(course.difficulty) },
            set: { services.setCourseDifficulty(course, difficulty: $0) }
        )
    }

    private var difficultyCaption: String {
        switch Course.clampedDifficulty(course.difficulty) {
        case 1: return "Fewer study blocks so the week stays flexible."
        case 2: return "A bit less weekly study than normal."
        case 3: return "Standard weekly study (1.2× class time)."
        case 4: return "More weekly study; prep also scales up."
        default: return "Heaviest load — more sessions and longer prep."
        }
    }

    private func assessmentRow(_ item: Assessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(assessmentLabel(item))
                Spacer(minLength: 8)
                Button("Delete", role: .destructive) {
                    services.deleteAssessment(item)
                }
                .font(FGTheme.mono(.caption2, weight: .bold))
            }
            Stepper("Extra study \(item.extraStudyMinutes)m") {
                if item.extraStudyMinutes < 360 {
                    services.setExtraStudyMinutes(for: item, minutes: item.extraStudyMinutes + 30)
                }
            } onDecrement: {
                if item.extraStudyMinutes > 0 {
                    services.setExtraStudyMinutes(for: item, minutes: item.extraStudyMinutes - 30)
                }
            }
            .font(FGTheme.mono(.caption2))
        }
    }

    private func classesSection(termBlocks: [ClassBlock]) -> some View {
        FGCard(accent: FGTheme.amber) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CLASSES")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                    Spacer()
                    Button("Add class") { addingClass = true }
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                }
                if termBlocks.isEmpty {
                    Text("No weekly classes this term.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                } else {
                    ForEach(termBlocks) { block in
                        classRow(block)
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var courseLogs: [ActivityLog] {
        allLogs.filter { $0.linkedCourse?.id == course.id || $0.title.uppercased().contains(course.code.uppercased()) }
    }

    private var thisWeekMinutes: Int {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return 0 }
        return courseLogs.filter { $0.timestamp >= weekStart }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var thisMonthMinutes: Int {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return 0 }
        return courseLogs.filter { $0.timestamp >= monthStart }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var independentPercentage: Int {
        guard !courseLogs.isEmpty else { return 100 }
        let ind = courseLogs.filter { $0.isIndependent }.count
        return Int((Double(ind) / Double(courseLogs.count) * 100).rounded())
    }

    private var aiPercentage: Int {
        guard !courseLogs.isEmpty else { return 0 }
        let ai = courseLogs.filter { $0.aiUsage.isAIAssisted }.count
        return Int((Double(ai) / Double(courseLogs.count) * 100).rounded())
    }

    private var activitySummarySection: some View {
        FGCard(accent: FGTheme.green) {
            VStack(alignment: .leading, spacing: 10) {
                Text("HISTORICAL TIME")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.green)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THIS WEEK")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatCourseMinutes(thisWeekMinutes))
                            .font(FGTheme.mono(.headline, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("THIS MONTH")
                            .font(FGTheme.mono(.caption2))
                            .foregroundStyle(FGTheme.muted)
                        Text(formatCourseMinutes(thisMonthMinutes))
                            .font(FGTheme.mono(.headline, weight: .bold))
                            .foregroundStyle(FGTheme.green)
                    }
                }

                Divider()

                HStack(spacing: 16) {
                    Text("Independent: \(independentPercentage)%")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                    Text("AI-Assisted: \(aiPercentage)%")
                        .font(FGTheme.mono(.caption2, weight: .bold))
                        .foregroundStyle(FGTheme.amber)
                }
            }
        }
    }

    private var recentSessionsSection: some View {
        FGCard(accent: FGTheme.amber) {
            VStack(alignment: .leading, spacing: 10) {
                Text("RECENT SESSIONS")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.amber)

                if courseLogs.isEmpty {
                    Text("No logged sessions for this course yet.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                } else {
                    ForEach(courseLogs.prefix(6)) { log in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title)
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(formatSessionDate(log.timestamp))
                                    .font(FGTheme.mono(.caption2))
                                    .foregroundStyle(FGTheme.muted)
                            }
                            Spacer()
                            Text("\(log.durationMinutes)m")
                                .font(FGTheme.mono(.caption, weight: .bold))
                                .foregroundStyle(FGTheme.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func formatCourseMinutes(_ total: Int) -> String {
        if total <= 0 { return "0m" }
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func blockLabel(_ block: ClassBlock) -> String {
        let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let day = (block.dayOfWeek >= 1 && block.dayOfWeek <= 7) ? days[block.dayOfWeek] : "?"
        let start = Int(block.startTime / 60)
        return "\(day) \(start / 60):\(String(format: "%02d", start % 60)) · \(Int(block.duration / 60))m · \(block.meetingType.isEmpty ? "CLASS" : block.meetingType)"
    }

    private func assessmentLabel(_ item: Assessment) -> String {
        let time = item.isAllDay
            ? item.start.formatted(date: .abbreviated, time: .omitted)
            : item.start.formatted(date: .abbreviated, time: .shortened)
        return "\(item.title) · \(time)"
    }
}
