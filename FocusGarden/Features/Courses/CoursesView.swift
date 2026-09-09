import SwiftData
import SwiftUI

struct CoursesView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \Course.code) private var courses: [Course]
    @State private var showingImporter = false

    var body: some View {
        FGScreen(
            title: "COURSES",
            trailing: AnyView(
                Button("Import") { showingImporter = true }
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.green)
            )
        ) {
            if visibleCourses.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Courses come from your .ics file. Nothing is added by hand.")
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

                                    HStack(spacing: 3) {
                                        Image(systemName: course.subjectCluster.icon)
                                            .font(.system(size: 8))
                                        Text(course.subjectCluster.shortTag)
                                            .font(FGTheme.mono(.caption2, weight: .bold))
                                    }
                                    .foregroundStyle(course.subjectCluster.accentColor)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(course.subjectCluster.accentColor.opacity(0.12))
                                    .overlay(Rectangle().stroke(course.subjectCluster.accentColor.opacity(0.35), lineWidth: 1))
                                }

                                Text(summary(for: course))
                                    .font(FGTheme.mono(.caption))
                                    .foregroundStyle(FGTheme.muted)
                            }
                        }
                        .listRowBackground(FGTheme.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .calendarImporter(isPresented: $showingImporter)
    }

    private var visibleCourses: [Course] {
        let calendar = services.configuration.calendar()
        let now = services.clock.now
        let term = AcademicTerm.containing(now, calendar: calendar)
        return courses.filter { course in
            (course.classBlocks ?? []).contains { $0.belongs(to: term, now: now, calendar: calendar) }
                || (course.assessments ?? []).contains { term.contains($0.start, calendar: calendar) }
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
    @Environment(AppServices.self) private var services
    let course: Course
    @State private var draft: ManualAssessmentDraft?
    @State private var editingBlock: ClassBlock?

    private var calendar: Calendar { services.configuration.calendar() }
    private var now: Date { services.clock.now }
    private var term: AcademicTerm { AcademicTerm.containing(now, calendar: calendar) }

    private var termBlocks: [ClassBlock] {
        (course.classBlocks ?? []).filter { $0.belongs(to: term, now: now, calendar: calendar) }
    }

    private var termTests: [Assessment] {
        course.tests.filter { term.contains($0.start, calendar: calendar) }
    }

    private var termHomework: [Assessment] {
        course.homeworks.filter { term.contains($0.start, calendar: calendar) }
    }

    var body: some View {
        ZStack {
            FGTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FGCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text(course.displayName)
                                    .font(FGTheme.mono(.title3, weight: .bold))
                                    .foregroundStyle(FGTheme.green)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: course.subjectCluster.icon)
                                        .font(.system(size: 9))
                                    Text(course.subjectCluster.rawValue.uppercased())
                                        .font(FGTheme.mono(.caption2, weight: .bold))
                                }
                                .foregroundStyle(course.subjectCluster.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(course.subjectCluster.accentColor.opacity(0.12))
                                .overlay(Rectangle().stroke(course.subjectCluster.accentColor.opacity(0.35), lineWidth: 1))
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
                    section("CLASSES", FGTheme.amber, termBlocks, empty: "No weekly classes this term.") { block in
                        classRow(block)
                    }
                    section(
                        "TESTS",
                        FGTheme.danger,
                        termTests,
                        empty: "None yet. Add a term test or final exam.",
                        addTitle: "Add test"
                    ) {
                        draft = .termTest
                    } content: { item in
                        assessmentRow(item)
                    }
                    section(
                        "HOMEWORK",
                        Color(red: 0.45, green: 0.75, blue: 1.0),
                        termHomework,
                        empty: "None yet. Add a homework due date.",
                        addTitle: "Add homework"
                    ) {
                        draft = .homework
                    } content: { item in
                        assessmentRow(item)
                    }
                    section("STUDY SLOTS", FGTheme.green, course.incompleteTasks, empty: "None scheduled yet.") { task in
                        Text("\(task.title) · \(task.estimatedMinutes)m · \(task.kind.displayName)")
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(course.code)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Term test") { draft = .termTest }
                    Button("Homework") { draft = .homework }
                    Button("Final exam") { draft = .finalExam }
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
        case 3: return "Standard weekly study (1.5× class time)."
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
            Stepper(
                "Extra study \(item.extraStudyMinutes)m",
                value: Binding(
                    get: { item.extraStudyMinutes },
                    set: { services.setExtraStudyMinutes(for: item, minutes: $0) }
                ),
                in: 0...360,
                step: 30
            )
            .font(FGTheme.mono(.caption2))
        }
    }

    private func section<Item: Identifiable, Content: View>(
        _ title: String,
        _ accent: Color,
        _ items: [Item],
        empty: String = "None in the timetable.",
        addTitle: String? = nil,
        add: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        FGCard(accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(accent)
                    Spacer()
                    if let addTitle, let add {
                        Button(addTitle, action: add)
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }
                if items.isEmpty {
                    Text(empty)
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                } else {
                    ForEach(items) { item in
                        content(item)
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
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
