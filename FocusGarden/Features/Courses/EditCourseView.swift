#if !SKIP
import SwiftData
#endif
import SwiftUI

struct EditCourseView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    let course: Course

    @State var code: String
    @State var title: String
    @State var difficulty: Int

    init(course: Course) {
        self.course = course
        _code = State(initialValue: course.code)
        _title = State(initialValue: course.title)
        _difficulty = State(initialValue: Course.clampedDifficulty(course.difficulty))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                List {
                    Section("COURSE INFORMATION") {
                        TextField("Course Code (e.g. CSC108)", text: $code)
                        TextField("Course Title (e.g. Computer Science I)", text: $title)
                    }

                    Section("DIFFICULTY") {
                        Picker("Difficulty", selection: $difficulty) {
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

                    Section {
                        Text("Renaming or changing difficulty adjusts weekly study generation and exam prep pacing.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                }
                .scrollContentBackground(.hidden)
                .font(FGTheme.mono(.body))
            }
            .navigationTitle("EDIT COURSE")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var difficultyCaption: String {
        switch difficulty {
        case 1: return "Fewer study blocks so the week stays flexible."
        case 2: return "A bit less weekly study than normal."
        case 3: return "Standard weekly study (1.2× class time)."
        case 4: return "More weekly study; prep also scales up."
        default: return "Heaviest load — more sessions and longer prep."
        }
    }

    private func save() {
        services.updateCourse(course, code: code, title: title)
        services.setCourseDifficulty(course, difficulty: difficulty)
        dismiss()
    }
}
