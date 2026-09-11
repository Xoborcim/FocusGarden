#if !SKIP
import SwiftData
#endif
import SwiftUI

struct ImportSyllabusView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    let course: Course

    @State var rawText: String = ""
    @State var parsedItems: [ParsedSyllabusItem] = []
    @State var hasParsed: Bool = false

    private var calendar: Calendar { services.configuration.calendar() }

    private var selectedCount: Int {
        parsedItems.filter { $0.isSelected }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        instructionCard

                        textInputCard

                        if !parsedItems.isEmpty {
                            parsedResultsSection
                        } else if hasParsed {
                            noResultsCard
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("IMPORT SYLLABUS")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !parsedItems.isEmpty {
                        Button("Import (\(selectedCount))") {
                            importSelected()
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(selectedCount > 0 ? FGTheme.green : FGTheme.muted)
                        .disabled(selectedCount == 0)
                    }
                }
            }
        }
    }

    private var instructionCard: some View {
        FGCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                    Text("AUTO-IMPORT ASSESSMENTS")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.green)
                }
                Text("Paste your syllabus schedule, course outline, or deadline table for \(course.code). Sprout automatically detects tests, homework, and dates.")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }
        }
    }

    private var textInputCard: some View {
        FGCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SYLLABUS TEXT")
                        .font(FGTheme.mono(.caption, weight: .bold))
                        .foregroundStyle(FGTheme.muted)
                    Spacer()
                    Button("Paste Sample") {
                        loadSample()
                    }
                    .font(FGTheme.mono(.caption2, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
                }

                TextEditor(text: $rawText)
                    .frame(minHeight: 120, maxHeight: 180)
                    .font(FGTheme.mono(.caption))
                    .padding(8)
                    .background(FGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(FGTheme.muted.opacity(0.3), lineWidth: 1)
                    )

                HStack {
                    if !rawText.isEmpty {
                        Button("Clear") {
                            rawText = ""
                            parsedItems = []
                            hasParsed = false
                        }
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                    }
                    Spacer()
                    FGButton(title: "SCAN SYLLABUS") {
                        parseSyllabus()
                    }
                }
            }
        }
    }

    private var noResultsCard: some View {
        FGCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("NO ASSESSMENTS DETECTED")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.amber)
                Text("Make sure the text includes test/homework names and dates (e.g. 'Midterm 1: Oct 14 at 2pm', or a Markdown table).")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }
        }
    }

    private var parsedResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DETECTED (\(parsedItems.count))")
                    .font(FGTheme.mono(.caption, weight: .bold))
                    .foregroundStyle(FGTheme.green)
                Spacer()
                Button(allSelected ? "Deselect all" : "Select all") {
                    let target = !allSelected
                    for i in parsedItems.indices {
                        parsedItems[i].isSelected = target
                    }
                }
                .font(FGTheme.mono(.caption2, weight: .bold))
                .foregroundStyle(FGTheme.green)
            }

            ForEach(0..<parsedItems.count, id: \.self) { idx in
                itemCard(index: idx)
            }
        }
    }

    private var allSelected: Bool {
        !parsedItems.isEmpty && parsedItems.allSatisfy { $0.isSelected }
    }

    @ViewBuilder
    private func itemCard(index: Int) -> some View {
        if index < parsedItems.count {
            let item = parsedItems[index]
            let isTest = item.kind == AssessmentKind.test
            let accent = isTest ? FGTheme.danger : Color(red: 0.45, green: 0.75, blue: 1.0)

            FGCard(accent: item.isSelected ? accent : FGTheme.muted.opacity(0.3)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding<Bool>(
                            get: { index < parsedItems.count ? parsedItems[index].isSelected : false },
                            set: { if index < parsedItems.count { parsedItems[index].isSelected = $0 } }
                        ))
                        .labelsHidden()
                        .tint(FGTheme.green)

                        TextField("Title", text: Binding<String>(
                            get: { index < parsedItems.count ? parsedItems[index].title : "" },
                            set: { if index < parsedItems.count { parsedItems[index].title = $0 } }
                        ))
                        .font(FGTheme.mono(.body, weight: .bold))
                        .foregroundStyle(item.isSelected ? .white : FGTheme.muted)

                        Spacer()

                        Picker("Kind", selection: Binding<AssessmentKind>(
                            get: { index < parsedItems.count ? parsedItems[index].kind : AssessmentKind.homework },
                            set: { if index < parsedItems.count { parsedItems[index].kind = $0 } }
                        )) {
                            Text("Test").tag(AssessmentKind.test)
                            Text("HW").tag(AssessmentKind.homework)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }

                    HStack {
                        DatePicker(
                            item.isAllDay ? "Date" : "Starts",
                            selection: Binding<Date>(
                                get: { index < parsedItems.count ? parsedItems[index].date : Date() },
                                set: { if index < parsedItems.count { parsedItems[index].date = $0 } }
                            ),
                            displayedComponents: item.isAllDay ? [DatePickerComponents.date] : [DatePickerComponents.date, DatePickerComponents.hourAndMinute]
                        )
                        .font(FGTheme.mono(.caption))

                        Toggle("All day", isOn: Binding<Bool>(
                            get: { index < parsedItems.count ? parsedItems[index].isAllDay : false },
                            set: { if index < parsedItems.count { parsedItems[index].isAllDay = $0 } }
                        ))
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                    }

                    HStack {
                        Stepper("Extra study: \(item.extraStudyMinutes)m") {
                            if index < parsedItems.count && parsedItems[index].extraStudyMinutes < 360 {
                                parsedItems[index].extraStudyMinutes += 30
                            }
                        } onDecrement: {
                            if index < parsedItems.count && parsedItems[index].extraStudyMinutes > 0 {
                                parsedItems[index].extraStudyMinutes -= 30
                            }
                        }
                        .font(FGTheme.mono(.caption2))
                        .foregroundStyle(FGTheme.muted)
                    }
                }
            }
        }
    }

    private func parseSyllabus() {
        let parser = SyllabusParser(calendar: calendar, referenceDate: services.clock.now)
        let results = parser.parse(text: rawText, courseCode: course.code)
        parsedItems = results
        hasParsed = true
    }

    private func loadSample() {
        rawText = """
        Course Schedule & Assessments:
        - Quiz 1: Oct 02, 2026 at 10:00 AM (5%)
        - Midterm 1: Oct 16, 2026, 2:00 PM - 4:00 PM (20%)
        - Assignment 1: Oct 28, 2026 at 11:59 PM (10%)
        - Midterm 2: Nov 13, 2026, 2:00 PM - 4:00 PM (20%)
        - Final Project: Dec 04, 2026 (15%)
        - Final Exam: Dec 16, 2026, 9:00 AM - 12:00 PM (30%)
        """
        parseSyllabus()
    }

    private func importSelected() {
        services.addAssessments(parsedItems, to: course)
        dismiss()
    }
}
