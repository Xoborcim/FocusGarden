import SwiftData
import SwiftUI

enum ManualAssessmentDraft: String, Identifiable {
    case termTest
    case homework
    case finalExam

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .termTest: "TERM TEST"
        case .homework: "HOMEWORK"
        case .finalExam: "FINAL EXAM"
        }
    }

    var kind: AssessmentKind {
        self == .homework ? .homework : .test
    }

    func defaultTitle(courseCode: String) -> String {
        switch self {
        case .termTest: "\(courseCode) Term Test"
        case .homework: "\(courseCode) Homework"
        case .finalExam: "\(courseCode) Final"
        }
    }

    var defaultAllDay: Bool { self == .homework }

    var defaultDurationHours: Double {
        switch self {
        case .termTest: 2
        case .homework: 24
        case .finalExam: 3
        }
    }
}

struct AddAssessmentView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let draft: ManualAssessmentDraft

    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var durationHours: Double
    @State private var extraStudyMinutes: Double = 0

    init(course: Course, draft: ManualAssessmentDraft) {
        self.course = course
        self.draft = draft
        _title = State(initialValue: draft.defaultTitle(courseCode: course.code))
        _date = State(initialValue: Date().addingTimeInterval(7 * 24 * 3600))
        _isAllDay = State(initialValue: draft.defaultAllDay)
        _durationHours = State(initialValue: draft.defaultDurationHours)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                List {
                    Section("DETAILS") {
                        TextField("Title", text: $title)
                        Toggle("All-day", isOn: $isAllDay)
                        DatePicker(
                            isAllDay ? "Due" : "Starts",
                            selection: $date,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                        if !isAllDay {
                            Stepper(
                                "Length \(Int(durationHours))h",
                                value: $durationHours,
                                in: 1...6,
                                step: 1
                            )
                        }
                        Stepper(
                            "Extra study \(Int(extraStudyMinutes))m",
                            value: $extraStudyMinutes,
                            in: 0...360,
                            step: 30
                        )
                    }
                    Section {
                        Text("FocusGarden spaces prep inside your lead window before this date. Extra study adds more time on top of the default.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                }
                .scrollContentBackground(.hidden)
                .font(FGTheme.mono(.body))
            }
            .navigationTitle(draft.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func save() {
        let calendar = services.configuration.calendar()
        let start: Date
        let end: Date
        if isAllDay {
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
        } else {
            start = date
            end = date.addingTimeInterval(durationHours * 3600)
        }
        services.addAssessment(
            to: course,
            kind: draft.kind,
            title: title,
            start: start,
            end: end,
            isAllDay: isAllDay,
            extraStudyMinutes: Int(extraStudyMinutes)
        )
        dismiss()
    }
}
