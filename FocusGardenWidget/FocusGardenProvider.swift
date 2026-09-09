import WidgetKit
import SwiftUI

struct FocusGardenProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusGardenEntry {
        FocusGardenEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusGardenEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        completion(FocusGardenEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusGardenEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load() ?? .placeholder
        let entry = FocusGardenEntry(date: Date(), snapshot: snapshot)

        var policy: TimelineReloadPolicy = .after(Date().addingTimeInterval(15 * 60))
        if let nextTime = snapshot.nextTaskTime, nextTime > Date() {
            policy = .after(nextTime)
        }

        completion(Timeline(entries: [entry], policy: policy))
    }
}

struct FocusGardenEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}
