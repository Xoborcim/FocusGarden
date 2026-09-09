import SwiftUI
import WidgetKit

// MARK: - Small

struct SmallFocusWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(snapshot.plantEmoji)
                    .font(.title2)

                Spacer(minLength: 4)

                if let time = snapshot.nextTimeText {
                    Text(time)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }

            Text(snapshot.nextTaskTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.focusLine)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            if let goal = snapshot.goalProgress.first {
                HStack(spacing: 6) {
                    Text(goal.emoji)
                    Text("\(goal.name) \(goal.label)m")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.85))
            } else {
                HStack(spacing: 10) {
                    miniStat(icon: "checkmark.circle.fill", value: "\(snapshot.completedToday)")
                    miniStat(icon: "flame.fill", value: "\(snapshot.streak)d")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func miniStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.8))
    }
}

// MARK: - Medium

struct MediumFocusWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            Text(snapshot.nextTaskTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(snapshot.focusLine)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let review = snapshot.reviewDueTitle {
                Label(review, systemImage: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.95))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !snapshot.goalProgress.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(snapshot.goalProgress.enumerated()), id: \.offset) { _, goal in
                        HStack(spacing: 4) {
                            Text(goal.emoji)
                            Text("\(goal.label)m")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }

            footerRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(snapshot.plantEmoji)
                .font(.title3)

            Text("Next")
                .font(.caption.weight(.bold))
                .foregroundStyle(.mint.opacity(0.9))
                .textCase(.uppercase)

            if let time = snapshot.nextTimeText {
                Text(time)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 0)

            Text("\(Int(snapshot.health))%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            miniStat(icon: "checkmark.circle.fill", text: "\(snapshot.completedToday) today")
            miniStat(icon: "flame.fill", text: "\(snapshot.streak)d")

            Spacer(minLength: 0)

            Link(destination: URL(string: "focusgarden://log")!) {
                Text("Log")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }

    private func miniStat(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.75))
    }
}

// MARK: - Lock Screen

struct AccessoryCircularWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Gauge(value: snapshot.health, in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            Text(snapshot.plantEmoji)
                .font(.caption)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct AccessoryRectangularWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(snapshot.plantEmoji)
                if let time = snapshot.nextTimeText {
                    Text(time)
                        .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
            }

            Text(snapshot.nextTaskTitle)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct AccessoryInlineWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if let time = snapshot.nextTimeText {
            Text("\(snapshot.plantEmoji) \(snapshot.nextTaskTitle) · \(time)")
                .lineLimit(1)
        } else {
            Text("\(snapshot.plantEmoji) \(snapshot.nextTaskTitle)")
                .lineLimit(1)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FocusGardenWidget()
} timeline: {
    FocusGardenEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    FocusGardenWidget()
} timeline: {
    FocusGardenEntry(date: .now, snapshot: .placeholder)
}
