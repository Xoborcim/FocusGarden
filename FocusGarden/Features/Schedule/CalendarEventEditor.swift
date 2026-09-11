#if !SKIP
import SwiftData
#endif
import SwiftUI

struct CalendarEventEditor: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @Query var tasks: [FocusTask]
    @Query var classBlocks: [ClassBlock]
    @Query var assessments: [Assessment]

    let target: CalendarEditorTarget

    init(target: CalendarEditorTarget) {
        self.target = target
    }

    @State var isRescheduling = false
    @State var rescheduleStart = Date()
    @State var isEditingClass = false

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        FGCard(accent: accent) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(kindLabel)
                                    .font(FGTheme.mono(.caption, weight: .bold))
                                    .foregroundStyle(accent)
                                Text(title)
                                    .font(FGTheme.mono(.title3, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(whenText)
                                    .font(FGTheme.mono(.body))
                                    .foregroundStyle(FGTheme.muted)
                                if !reason.isEmpty {
                                    Text(reason)
                                        .font(FGTheme.mono(.caption))
                                        .foregroundStyle(FGTheme.green)
                                }
                            }
                        }

                        if let task, !task.isCompleted {
                            if isRescheduling {
                                FGCard(accent: FGTheme.amber) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("NEW START")
                                            .font(FGTheme.mono(.caption, weight: .bold))
                                            .foregroundStyle(FGTheme.amber)
                                        DatePicker(
                                            "Starts",
                                            selection: $rescheduleStart,
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        Text("Keeps this \(durationLabel(for: task)) block and moves other study around it.")
                                            .font(FGTheme.mono(.caption))
                                            .foregroundStyle(FGTheme.muted)
                                        FGButton(title: "SAVE NEW TIME") {
                                            services.rescheduleTask(task, to: rescheduleStart)
                                            dismiss()
                                        }
                                        FGButton(title: "CANCEL", fill: false) {
                                            isRescheduling = false
                                        }
                                    }
                                }
                            } else {
                                if task.isInSession {
                                    FGButton(title: "RESUME TIMER", accent: accent) {
                                        services.resumeFocusSession(task)
                                        dismiss()
                                    }
                                } else {
                                    FGButton(title: "START", accent: accent) {
                                        services.startFocusSession(task)
                                        dismiss()
                                    }
                                }
                                FGButton(title: "MARK DONE", fill: false) {
                                    services.markTaskDone(task)
                                    dismiss()
                                }
                                FGButton(title: "RESCHEDULE", fill: false) {
                                    rescheduleStart = task.scheduledStart ?? services.clock.now
                                    isRescheduling = true
                                }
                                if task.isSoftLocked {
                                    FGButton(title: "LET FOCUSGARDEN PICK", fill: false) {
                                        services.unlockTaskSchedule(task)
                                        dismiss()
                                    }
                                }
                            }
                        }

                        if let classBlock {
                            Text("Edits apply to every week this term.")
                                .font(FGTheme.mono(.caption))
                                .foregroundStyle(FGTheme.muted)
                            FGButton(title: "EDIT FOR WHOLE TERM", accent: FGTheme.amber) {
                                isEditingClass = true
                            }
                            FGButton(title: "DELETE CLASS", accent: FGTheme.danger, fill: false) {
                                services.deleteClassBlock(classBlock)
                                dismiss()
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("BLOCK")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $isEditingClass) {
                if let classBlock {
                    EditClassBlockView(block: classBlock)
                }
            }
        }
    }

    private func durationLabel(for task: FocusTask) -> String {
        let minutes: Int
        if let start = task.scheduledStart, let end = task.scheduledEnd, end > start {
            minutes = max(1, Int(end.timeIntervalSince(start) / 60))
        } else {
            minutes = max(1, task.estimatedMinutes)
        }
        return "\(minutes)m"
    }

    private var task: FocusTask? {
        if case .task(let id) = target { return tasks.first { $0.id == id } }
        return nil
    }

    private var classBlock: ClassBlock? {
        if case .classBlock(let id) = target { return classBlocks.first { $0.id == id } }
        return nil
    }

    private var assessment: Assessment? {
        if case .assessment(let id) = target { return assessments.first { $0.id == id } }
        return nil
    }

    private var title: String {
        if let task { return task.title }
        if let classBlock {
            return classBlock.course?.displayName ?? (classBlock.summary.isEmpty ? "Class" : classBlock.summary)
        }
        if let assessment { return assessment.title }
        return "Block"
    }

    private var kindLabel: String {
        if let task { return task.kind.displayName.uppercased() }
        if classBlock != nil { return "CLASS" }
        if let assessment { return assessment.assessmentKind.displayName.uppercased() }
        return "BLOCK"
    }

    private var whenText: String {
        let calendar = services.configuration.calendar()
        if let task, let start = task.scheduledStart, let end = task.scheduledEnd {
            return "\(start.formatted(date: .abbreviated, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        if let block = classBlock {
            let day = WeekdayLabel.names[safe: block.dayOfWeek] ?? "Weekly"
            let start = calendar.startOfDay(for: services.selectedDate).addingTimeInterval(block.startTime)
            let end = start.addingTimeInterval(block.duration)
            return "Every \(day) · \(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
        }
        if let assessment {
            if assessment.isAllDay {
                return assessment.start.formatted(date: .abbreviated, time: .omitted)
            }
            return "\(assessment.start.formatted(date: .abbreviated, time: .shortened)) – \(assessment.end.formatted(date: .omitted, time: .shortened))"
        }
        return ""
    }

    private var reason: String {
        task?.scheduleReason ?? ""
    }

    private var accent: Color {
        if classBlock != nil { return FGTheme.amber }
        if let assessment {
            return assessment.assessmentKind == .test ? FGTheme.danger : FGTheme.amber
        }
        switch task?.kind {
        case .testPrep: return FGTheme.danger
        case .homework: return Color(red: 0.45, green: 0.75, blue: 1.0)
        default: return FGTheme.green
        }
    }
}
