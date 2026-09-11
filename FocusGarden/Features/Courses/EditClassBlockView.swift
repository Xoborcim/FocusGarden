#if !SKIP
import SwiftData
#endif
import SwiftUI

struct EditClassBlockView: View {
    @Environment(AppServices.self) var services
    @Environment(\.dismiss) var dismiss
    let course: Course?
    let block: ClassBlock?

    @State var dayOfWeek: Int
    @State var startDate: Date
    @State var durationMinutes: Int
    @State var meetingType: String
    @State var location: String
    @State var showingDeleteConfirmation = false

    init(block: ClassBlock) {
        self.block = block
        self.course = block.course
        _dayOfWeek = State(initialValue: block.dayOfWeek)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let totalMinutes = Int(block.startTime / 60)
        components.hour = totalMinutes / 60
        components.minute = totalMinutes % 60
        _startDate = State(initialValue: calendar.date(from: components) ?? Date())
        _durationMinutes = State(initialValue: max(15, Int((block.duration / 60).rounded())))
        _meetingType = State(initialValue: block.meetingType.isEmpty ? "CLASS" : block.meetingType)
        _location = State(initialValue: block.location)
    }

    init(course: Course) {
        self.course = course
        self.block = nil
        _dayOfWeek = State(initialValue: 2) // Monday
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10
        components.minute = 0
        _startDate = State(initialValue: calendar.date(from: components) ?? Date())
        _durationMinutes = State(initialValue: 60)
        _meetingType = State(initialValue: "LEC")
        _location = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FGTheme.background.ignoresSafeArea()
                List {
                    Section("WEEKLY MEETING") {
                        Picker("Day", selection: $dayOfWeek) {
                            ForEach(1...7, id: \.self) { day in
                                Text(WeekdayLabel.names[safe: day] ?? "Day \(day)").tag(day)
                            }
                        }
                        DatePicker("Starts", selection: $startDate, displayedComponents: DatePickerComponents.hourAndMinute)
                        Stepper("Length \(durationMinutes)m") {
                            if durationMinutes < 240 { durationMinutes += 15 }
                        } onDecrement: {
                            if durationMinutes > 15 { durationMinutes -= 15 }
                        }
                        TextField("Type (LEC, TUT, LAB…)", text: $meetingType)
                        TextField("Location", text: $location)
                    }
                    Section {
                        Text("This updates the class for the whole term. Study slots rebuild around the new time.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                    if block != nil {
                        Section {
                            Button("Delete Class", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                            .foregroundStyle(FGTheme.danger)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .font(FGTheme.mono(.body))
            }
            .navigationTitle(block == nil ? "ADD CLASS" : "EDIT CLASS")
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
            .alert("Delete this class timing?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Class", role: .destructive) {
                    if let block {
                        services.deleteClassBlock(block)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove this class timing and rebuild your schedule around remaining classes.")
            }
        }
    }

    private func save() {
        let calendar = services.configuration.calendar()
        let hour = calendar.component(.hour, from: startDate)
        let minute = calendar.component(.minute, from: startDate)
        let startTime = TimeInterval((hour * 60 + minute) * 60)
        if let block {
            services.updateClassBlock(
                block,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                durationMinutes: durationMinutes,
                meetingType: meetingType,
                location: location
            )
        } else if let course {
            services.addClassBlock(
                course: course,
                dayOfWeek: dayOfWeek,
                startTime: startTime,
                durationMinutes: durationMinutes,
                meetingType: meetingType,
                location: location
            )
        }
        dismiss()
    }
}
