import SwiftData
import SwiftUI

struct EditClassBlockView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let block: ClassBlock

    @State private var dayOfWeek: Int
    @State private var startDate: Date
    @State private var durationMinutes: Int
    @State private var meetingType: String
    @State private var location: String

    init(block: ClassBlock) {
        self.block = block
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
                        DatePicker("Starts", selection: $startDate, displayedComponents: .hourAndMinute)
                        Stepper(
                            "Length \(durationMinutes)m",
                            value: $durationMinutes,
                            in: 15...240,
                            step: 15
                        )
                        TextField("Type (LEC, TUT, LAB…)", text: $meetingType)
                        TextField("Location", text: $location)
                    }
                    Section {
                        Text("This updates the class for the whole term. Study slots rebuild around the new time.")
                            .font(FGTheme.mono(.caption))
                            .foregroundStyle(FGTheme.muted)
                    }
                }
                .scrollContentBackground(.hidden)
                .font(FGTheme.mono(.body))
            }
            .navigationTitle("EDIT CLASS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

    private func save() {
        let calendar = services.configuration.calendar()
        let hour = calendar.component(.hour, from: startDate)
        let minute = calendar.component(.minute, from: startDate)
        let startTime = TimeInterval((hour * 60 + minute) * 60)
        services.updateClassBlock(
            block,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            durationMinutes: durationMinutes,
            meetingType: meetingType,
            location: location
        )
        dismiss()
    }
}
