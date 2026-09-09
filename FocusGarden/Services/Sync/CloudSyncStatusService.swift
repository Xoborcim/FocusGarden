import Foundation

struct WidgetSnapshotService {
    func publish(nextTask: FocusTask?, pendingCount: Int) {
        let snapshot = WidgetSnapshot(
            plantEmoji: "📚",
            plantName: "Focus",
            health: 100,
            waterLevel: 0,
            streak: 0,
            growthProgress: 0,
            stageDescription: "Study",
            moodMessage: nextTask == nil ? "Import a timetable to fill the week." : "Next block is ready.",
            nextIntention: nextTask.map { "I will \($0.title)." } ?? "I will import my course calendar.",
            nextTaskTitle: nextTask?.title ?? "Import .ics",
            nextTaskTime: nextTask?.scheduledStart,
            completedToday: 0,
            pendingToday: pendingCount,
            focusMinutesToday: 0,
            reviewDueTitle: nil,
            researchCaption: "Study around class, then tests and homework",
            goalProgress: [],
            updatedAt: Date()
        )
        WidgetSnapshotStore.save(snapshot)
        #if !SIDELOAD
        WidgetReloader.reload()
        #endif
    }
}

#if !SIDELOAD
import WidgetKit
enum WidgetReloader {
    static func reload() {
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif
