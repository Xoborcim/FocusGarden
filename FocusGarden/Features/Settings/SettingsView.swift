#if !SKIP
import SwiftData
#endif
import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) var services
    @Query var blocks: [ClassBlock]
    @Query var courses: [Course]
    @Query var allLogs: [ActivityLog]

    @State var showingImporter = false
    @State var showingClearLogsConfirm = false
    @State var showingResetTimetableConfirm = false
    @State var showingResetAllConfirm = false

    init() {}

    var body: some View {
        FGScreen(title: "SETTINGS") {
            Form {
                Section("TIMETABLE & COURSES") {
                    Button {
                        showingImporter = true
                    } label: {
                        HStack {
                            Label("Import / update ICS calendar", systemImage: "calendar.badge.plus")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(FGTheme.muted)
                        }
                    }
                    Text("Imports lectures, tutorials, and labs from your campus .ics calendar to display them on your daily timeline.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)

                    if !courses.isEmpty {
                        HStack {
                            Text("Enrolled")
                                .foregroundStyle(FGTheme.muted)
                            Spacer()
                            Text("\(visibleCourseCount) courses · \(visibleBlockCount) weekly classes")
                                .foregroundStyle(FGTheme.green)
                        }
                        .font(FGTheme.mono(.caption))
                    }
                }

                Section("FOCUS TIMER") {
                    Stepper("Focus sprint \(services.configuration.timerFocusMinutes)m") {
                        if focusIntervalBinding.wrappedValue < 120 { focusIntervalBinding.wrappedValue += 5 }
                    } onDecrement: {
                        if focusIntervalBinding.wrappedValue > 5 { focusIntervalBinding.wrappedValue -= 5 }
                    }
                    Stepper("Short break \(services.configuration.timerBreakMinutes)m") {
                        if breakIntervalBinding.wrappedValue < 30 { breakIntervalBinding.wrappedValue += 1 }
                    } onDecrement: {
                        if breakIntervalBinding.wrappedValue > 1 { breakIntervalBinding.wrappedValue -= 1 }
                    }
                    Text("Sets default sprint duration and mindful break length for timer sessions.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }

                Section("NOTIFICATIONS") {
                    Toggle("Study & class reminders", isOn: remindersBinding)
                    Text("Sends an alert \(StudyReminderService.leadMinutes) minutes before scheduled classes and study sessions.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }

                Section("DATA & STORAGE") {
                    Button("Clear activity logs", role: .destructive) {
                        showingClearLogsConfirm = true
                    }
                    .disabled(allLogs.isEmpty)
                    Text("Removes all recorded focus sessions and activity history (\(allLogs.count) logged). Preserves courses and classes.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)

                    Button("Reset timetable", role: .destructive) {
                        showingResetTimetableConfirm = true
                    }
                    .disabled(courses.isEmpty && blocks.isEmpty)
                    Text("Deletes imported courses, weekly class blocks, and assessments. Activity logs are kept.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)

                    Button("Reset all app data", role: .destructive) {
                        showingResetAllConfirm = true
                    }
                    Text("Deletes all courses, timetable classes, activity history, and plants.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .font(FGTheme.mono(.body))
        }
        .calendarImporter(isPresented: $showingImporter)
        .alert("Clear activity logs?", isPresented: $showingClearLogsConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Logs", role: .destructive) {
                services.clearAllActivityLogs()
            }
        } message: {
            Text("This deletes all recorded activity logs. Your courses and weekly timetable will be kept.")
        }
        .alert("Reset timetable?", isPresented: $showingResetTimetableConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Timetable", role: .destructive) {
                services.resetTimetable()
            }
        } message: {
            Text("This removes every imported course, class block, and assessment.")
        }
        .alert("Reset all app data?", isPresented: $showingResetAllConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                services.resetAll()
            }
        } message: {
            Text("This completely resets the app, wiping all courses, classes, activity logs, and garden plants.")
        }
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { services.remindersEnabled },
            set: { services.updateRemindersEnabled($0) }
        )
    }

    private var focusIntervalBinding: Binding<Int> {
        Binding(
            get: { services.configuration.timerFocusMinutes },
            set: { services.setTimerIntervals(focus: $0, breakMinutes: services.configuration.timerBreakMinutes) }
        )
    }

    private var breakIntervalBinding: Binding<Int> {
        Binding(
            get: { services.configuration.timerBreakMinutes },
            set: { services.setTimerIntervals(focus: services.configuration.timerFocusMinutes, breakMinutes: $0) }
        )
    }

    private var visibleBlockCount: Int {
        let calendar = services.configuration.calendar()
        let now = services.clock.now
        let term = AcademicTerm.containing(now, calendar: calendar)
        return blocks.filter { $0.belongs(to: term, now: now, calendar: calendar) }.count
    }

    private var visibleCourseCount: Int {
        let calendar = services.configuration.calendar()
        let now = services.clock.now
        let term = AcademicTerm.containing(now, calendar: calendar)
        return courses.filter { course in
            (course.classBlocks ?? []).contains { $0.belongs(to: term, now: now, calendar: calendar) }
                || (course.assessments ?? []).contains { term.contains($0.start, calendar: calendar) }
        }.count
    }
}
