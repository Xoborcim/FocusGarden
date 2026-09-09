import WidgetKit
import SwiftUI

struct FocusGardenWidget: Widget {
    let kind: String = "FocusGardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusGardenProvider()) { entry in
            FocusGardenWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.36, blue: 0.25),
                            Color(red: 0.05, green: 0.17, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Focus Intention")
        .description("Your if-then plan for the next block, plant vitals, and one-tap log — grounded in planning research.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct FocusGardenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FocusGardenEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFocusWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumFocusWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            AccessoryCircularWidgetView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryRectangularWidgetView(snapshot: entry.snapshot)
        case .accessoryInline:
            AccessoryInlineWidgetView(snapshot: entry.snapshot)
        default:
            SmallFocusWidgetView(snapshot: entry.snapshot)
        }
    }
}

@main
struct FocusGardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusGardenWidget()
    }
}
