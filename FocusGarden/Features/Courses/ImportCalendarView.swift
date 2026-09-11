import SwiftUI
#if !SKIP
import UniformTypeIdentifiers
#endif

struct CalendarImportHost: ViewModifier {
    @Environment(AppServices.self) var services
    @Binding var showingImporter: Bool
    @State var preview: ICSParseResult?
    @State var importError: String?

    func body(content: Content) -> some View {
        #if !SKIP
        content
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType(filenameExtension: "ics") ?? UTType.data, UTType.text],
                allowsMultipleSelection: false
            ) { result in
                handle(result)
            }
            .sheet(item: Binding<PreviewBox?>(
                get: { preview.map { PreviewBox(result: $0) } },
                set: { preview = $0?.result }
            )) { (box: PreviewBox) in
                ICSPreviewSheet(result: box.result) { result in
                    Swift.Task { await services.commitPreview(result) }
                }
            }
            .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        #else
        content
            .sheet(item: Binding<PreviewBox?>(
                get: { preview.map { PreviewBox(result: $0) } },
                set: { preview = $0?.result }
            )) { (box: PreviewBox) in
                ICSPreviewSheet(result: box.result) { result in
                    Swift.Task { await services.commitPreview(result) }
                }
            }
            .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        #endif
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            #if !SKIP
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            #endif
            do {
                let data = try Data(contentsOf: url)
                preview = services.previewCalendar(data: data)
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

struct PreviewBox: Identifiable {
    var id: String { "preview" }
    var result: ICSParseResult
}

struct ICSPreviewSheet: View {
    let result: ICSParseResult
    var onConfirm: (ICSParseResult) -> Void
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    @State var selectedTerm: AcademicTerm?

    init(result: ICSParseResult, onConfirm: @escaping (ICSParseResult) -> Void) {
        self.result = result
        self.onConfirm = onConfirm
    }

    private var calendar: Calendar { services.configuration.calendar() }

    private var terms: [AcademicTerm] {
        result.terms(calendar: calendar)
    }

    private var activeTerm: AcademicTerm? {
        selectedTerm ?? result.preferredTerm(now: services.clock.now, calendar: calendar)
    }

    private var filtered: ICSParseResult {
        guard let activeTerm else { return result }
        return result.filtered(to: activeTerm, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            List {
                if terms.count > 1 {
                    Section("TERM") {
                        Picker("Term", selection: Binding(
                            get: { activeTerm ?? terms[0] },
                            set: { selectedTerm = $0 }
                        )) {
                            ForEach(terms) { term in
                                Text(term.displayName).tag(term)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("This file has more than one term. Only \(activeTerm?.displayName ?? "the selected term") will be added.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                }
                if !filtered.warnings.isEmpty {
                    Section("WARNINGS") {
                        ForEach(filtered.warnings, id: \.message) { warning in
                            Text(warning.message)
                        }
                    }
                }
                Section("CLASSES") {
                    if filtered.previews.isEmpty {
                        Text("No weekly classes found.")
                            .foregroundStyle(FGTheme.muted)
                    }
                    ForEach(filtered.previews) { preview in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(preview.courseCode) \(preview.meetingType)")
                                .font(FGTheme.mono(.headline, weight: .bold))
                            Text("\(weekdayName(preview.dayOfWeek)) · \(Int(preview.duration / 60))m")
                                .font(FGTheme.mono(.caption))
                                .foregroundStyle(FGTheme.muted)
                        }
                    }
                }
                Section("TESTS") {
                    assessmentRows(filtered.assessments.filter { $0.kind == .test }, empty: "No tests or exams found.")
                }
                Section("HOMEWORK") {
                    assessmentRows(filtered.assessments.filter { $0.kind == .homework }, empty: "No homework due dates found.")
                }
            }
            .font(FGTheme.mono(.body))
            .navigationTitle("IMPORT PREVIEW")
            #if !os(macOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add courses") {
                        onConfirm(filtered)
                        dismiss()
                    }
                    .disabled(filtered.previews.isEmpty && filtered.assessments.isEmpty)
                }
            }
            .onAppear {
                if selectedTerm == nil {
                    selectedTerm = result.preferredTerm(now: services.clock.now, calendar: calendar)
                }
            }
        }
    }

    @ViewBuilder
    private func assessmentRows(_ items: [ICSAssessmentPreview], empty: String) -> some View {
        if items.isEmpty {
            Text(empty)
                .foregroundStyle(FGTheme.muted)
        }
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(FGTheme.mono(.headline, weight: .bold))
                Text("\(item.courseCode) · \(item.start.formatted(date: .abbreviated, time: item.isAllDay ? .omitted : .shortened))")
                    .font(FGTheme.mono(.caption))
                    .foregroundStyle(FGTheme.muted)
            }
        }
    }

    private func weekdayName(_ day: Int) -> String {
        WeekdayLabel.names[safe: day] ?? "Day \(day)"
    }
}

extension View {
    func calendarImporter(isPresented: Binding<Bool>) -> some View {
        modifier(CalendarImportHost(showingImporter: isPresented))
    }
}
