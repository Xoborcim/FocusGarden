import Foundation

/// Lightweight snapshot shared with the widget extension via App Group.
struct WidgetSnapshot: Codable, Equatable {
    var plantEmoji: String
    var plantName: String
    var health: Double
    var waterLevel: Double
    var streak: Int
    var growthProgress: Double
    var stageDescription: String
    var moodMessage: String

    /// Full if-then implementation intention (Gollwitzer, 1999).
    var nextIntention: String
    var nextTaskTitle: String
    var nextTaskTime: Date?

    var completedToday: Int
    var pendingToday: Int
    var focusMinutesToday: Int

    /// Spaced repetition review due soon (Cepeda et al., 2006).
    var reviewDueTitle: String?

    /// Short research caption shown on medium widget.
    var researchCaption: String

    /// Up to two daily goals for widget rings.
    var goalProgress: [WidgetGoalProgress]

    var updatedAt: Date

    var nextTimeText: String? {
        nextTaskTime?.formatted(date: .omitted, time: .shortened)
    }

    /// First step without the "I will" prefix — tighter for widget space.
    var focusLine: String {
        let trimmed = nextIntention.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("i will ") {
            return String(trimmed.dropFirst(7))
        }
        return trimmed
    }

    static let placeholder = WidgetSnapshot(
        plantEmoji: "🌱",
        plantName: "Sprout",
        health: 80,
        waterLevel: 60,
        streak: 0,
        growthProgress: 0.2,
        stageDescription: "Seed",
        moodMessage: "Your garden is waiting.",
        nextIntention: "I will open FocusGarden and plan my next study block.",
        nextTaskTitle: "Plan your day",
        nextTaskTime: nil,
        completedToday: 0,
        pendingToday: 0,
        focusMinutesToday: 0,
        reviewDueTitle: nil,
        researchCaption: "If-then plans · Gollwitzer, 1999",
        goalProgress: [
            WidgetGoalProgress(emoji: "📖", name: "Reading", progressMinutes: 18, targetMinutes: 30)
        ],
        updatedAt: Date()
    )
}

struct WidgetGoalProgress: Codable, Equatable {
    var emoji: String
    var name: String
    var progressMinutes: Int
    var targetMinutes: Int

    var fraction: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(1, Double(progressMinutes) / Double(targetMinutes))
    }

    var label: String {
        "\(progressMinutes)/\(targetMinutes)"
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.sebastian.focusgarden"
    static let snapshotKey = "focusGardenWidgetSnapshot"

    /// App Groups require a paid developer account. Sideload builds omit them, so
    /// the widget shows placeholder data until you ship with TestFlight/App Store.
    static var isAvailable: Bool {
        #if SIDELOAD
        false
        #else
        UserDefaults(suiteName: appGroupID) != nil
        #endif
    }

    static func save(_ snapshot: WidgetSnapshot) {
        #if SIDELOAD
        return
        #else
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        #endif
    }

    static func load() -> WidgetSnapshot? {
        #if SIDELOAD
        return nil
        #else
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #endif
    }
}
