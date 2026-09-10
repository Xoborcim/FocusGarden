import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Query private var blocks: [ClassBlock]
    @Query private var assessments: [Assessment]
    @Query private var courses: [Course]
    @State private var showingImporter = false
    @State private var showingResetConfirm = false
    @State private var showingResetStudyConfirm = false

    var body: some View {
        FGScreen(title: "SETTINGS") {
            List {
                Section("CALENDAR") {
                    Button("Import .ics timetable") { showingImporter = true }
                    Text("\(visibleCourseCount) courses this term · \(visibleBlockCount) class blocks")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                Section("STUDY HOURS") {
                    DatePicker(
                        "Earliest",
                        selection: earliestBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Latest",
                        selection: latestBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Toggle("Before first class", isOn: beforeClassBinding)
                    Toggle("Between classes", isOn: betweenClassesBinding)
                    Stepper(
                        "Commute after last class \(services.configuration.commuteMinutesAfterLastClass)m",
                        value: commuteBinding,
                        in: 0...180,
                        step: 5
                    )
                    Stepper(
                        "Break between sessions \(services.configuration.bufferMinutes)m",
                        value: breakMinutesBinding,
                        in: 5...60,
                        step: 5
                    )
                    Text("Guarantees rest time between consecutive study blocks so you stay energized.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                Section("ENERGY & CHRONOTYPE") {
                    Picker("Chronotype", selection: chronotypeBinding) {
                        ForEach(Chronotype.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(services.configuration.chronotype.description)
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                Section("TIMER INTERVALS & BREAKS") {
                    Stepper(
                        "Focus sprint \(services.configuration.timerFocusMinutes)m",
                        value: focusIntervalBinding,
                        in: 10...90,
                        step: 5
                    )
                    Stepper(
                        "Short break \(services.configuration.timerBreakMinutes)m",
                        value: breakIntervalBinding,
                        in: 2...30,
                        step: 1
                    )
                    Text("Splits focus sessions into manageable sprints with relaxing breaks.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                Section("STUDY PLAN") {
                    Text("Only the current term is scheduled. Weekly study is 1.5× that term’s class time. Tests and homework get extra blocks before the due date.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                    Stepper(
                        "Prep window \(services.configuration.assessmentLeadWeeks) weeks",
                        value: leadWeeksBinding,
                        in: 1...8
                    )
                    Text("Test and homework study is spaced inside this window before each due date. Those blocks take priority over weekly study.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                    Button("Rebuild study slots") { services.regenerate() }
                }
                Section("REMINDERS") {
                    Toggle("Notify before study", isOn: remindersBinding)
                    Text("Sends a small alert \(StudyReminderService.leadMinutes) minutes before each study block.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
                Section("RESET") {
                    Button("Reset study sessions", role: .destructive) {
                        showingResetStudyConfirm = true
                    }
                    Text("Re-splits study sessions into 1-hour lecture chunks. Preserves your saved tests, homework, and courses.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)

                    Button("Reset timetable", role: .destructive) {
                        showingResetConfirm = true
                    }
                    Text("Deletes courses, classes, tests, homework, and study blocks.")
                        .font(FGTheme.mono(.caption))
                        .foregroundStyle(FGTheme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .font(FGTheme.mono(.body))
        }
        .calendarImporter(isPresented: $showingImporter)
        .alert("Reset study sessions?", isPresented: $showingResetStudyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Sessions", role: .destructive) { services.resetStudySessions() }
        } message: {
            Text("This regenerates all lecture study into 1-hour chunks. Your saved tests and homework will be kept.")
        }
        .alert("Reset timetable?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { services.resetAll() }
        } message: {
            Text("This removes every imported course and generated study slot.")
        }
    }

    private var earliestBinding: Binding<Date> {
        Binding(
            get: {
                services.clockTime(
                    hour: services.configuration.windowStartHour,
                    minute: services.configuration.windowStartMinute
                )
            },
            set: { newStart in
                services.setStudyWindow(
                    start: newStart,
                    end: services.clockTime(
                        hour: services.configuration.windowEndHour,
                        minute: services.configuration.windowEndMinute
                    )
                )
            }
        )
    }

    private var latestBinding: Binding<Date> {
        Binding(
            get: {
                services.clockTime(
                    hour: services.configuration.windowEndHour,
                    minute: services.configuration.windowEndMinute
                )
            },
            set: { newEnd in
                services.setStudyWindow(
                    start: services.clockTime(
                        hour: services.configuration.windowStartHour,
                        minute: services.configuration.windowStartMinute
                    ),
                    end: newEnd
                )
            }
        )
    }

    private var beforeClassBinding: Binding<Bool> {
        Binding(
            get: { services.configuration.allowBeforeFirstClass },
            set: { services.setAllowBeforeFirstClass($0) }
        )
    }

    private var betweenClassesBinding: Binding<Bool> {
        Binding(
            get: { services.configuration.allowBetweenClasses },
            set: { services.setAllowBetweenClasses($0) }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { services.remindersEnabled },
            set: { services.setRemindersEnabled($0) }
        )
    }

    private var leadWeeksBinding: Binding<Int> {
        Binding(
            get: { services.configuration.assessmentLeadWeeks },
            set: { services.setAssessmentLeadWeeks($0) }
        )
    }

    private var commuteBinding: Binding<Int> {
        Binding(
            get: { services.configuration.commuteMinutesAfterLastClass },
            set: { services.setCommuteMinutesAfterLastClass($0) }
        )
    }

    private var breakMinutesBinding: Binding<Int> {
        Binding(
            get: { services.configuration.bufferMinutes },
            set: { services.setBreakMinutesBetweenSessions($0) }
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

    private var chronotypeBinding: Binding<Chronotype> {
        Binding(
            get: { services.configuration.chronotype },
            set: { services.setChronotype($0) }
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
