import SwiftData
import SwiftUI

struct MonthCalendarSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [FocusTask]
    @Query private var classBlocks: [ClassBlock]
    @Query private var assessments: [Assessment]

    @State private var visibleMonth: Date

    init(month: Date) {
        _visibleMonth = State(initialValue: month)
    }

    private var calendar: Calendar { services.configuration.calendar() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(FGTheme.green)
                    }
                    Spacer()
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year()).uppercased())
                        .font(FGTheme.mono(.headline, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(FGTheme.green)
                    }
                }
                .padding(.horizontal, 8)

                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { day in
                        Text(WeekdayLabel.short[day])
                            .font(FGTheme.mono(.caption2, weight: .bold))
                            .foregroundStyle(FGTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(FGTheme.background.ignoresSafeArea())
            .navigationTitle("CALENDAR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Today") {
                        services.selectedDate = services.clock.now
                        dismiss()
                    }
                    .foregroundStyle(FGTheme.amber)
                }
            }
        }
    }

    private var monthDays: [Date?] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
        let weekday = calendar.component(.weekday, from: start)
        let pad = weekday - 1
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: pad)
        for offset in 0..<count {
            days.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: services.selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasEvents = hasItems(on: day)
        return Button {
            services.selectedDate = day
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(FGTheme.mono(.body, weight: .bold))
                    .foregroundStyle(selected ? FGTheme.ink : .white)
                Circle()
                    .fill(hasEvents ? (selected ? FGTheme.ink : FGTheme.green) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? FGTheme.green : Color.clear)
            .overlay(
                Rectangle().stroke(isToday && !selected ? FGTheme.amber : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func hasItems(on day: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: day)
        if classBlocks.contains(where: { $0.dayOfWeek == weekday && $0.isActive(on: day, calendar: calendar) }) {
            return true
        }
        if assessments.contains(where: { calendar.isDate($0.start, inSameDayAs: day) }) {
            return true
        }
        return tasks.contains { task in
            guard let start = task.scheduledStart, !task.isCompleted else { return false }
            return calendar.isDate(start, inSameDayAs: day)
        }
    }
}
