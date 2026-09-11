#if !SKIP
import Foundation
import UserNotifications

struct StudyReminderService: Sendable {
    static let leadMinutes = 10
    private static let categoryID = "study-reminder"
    private static let idPrefix = "study-task-"

    private var isSupportedEnvironment: Bool {
        guard let id = Bundle.main.bundleIdentifier, !id.isEmpty, !id.contains("xctest") else {
            return false
        }
        return true
    }

    func requestAuthorization() async -> Bool {
        guard isSupportedEnvironment else { return false }
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func refresh(tasks: [FocusTask], now: Date) async {
        guard isSupportedEnvironment else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let stale = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let upcoming = tasks
            .filter { !$0.isCompleted }
            .compactMap { task -> (FocusTask, Date)? in
                guard let start = task.scheduledStart, start > now else { return nil }
                return (task, start)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(40)

        for (task, start) in upcoming {
            let fireAt = start.addingTimeInterval(TimeInterval(-Self.leadMinutes * 60))
            guard fireAt > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Study coming up"
            content.body = "\(task.title) starts in \(Self.leadMinutes) minutes."
            content.sound = .default
            content.categoryIdentifier = Self.categoryID
            content.userInfo = ["taskID": task.id.uuidString]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireAt
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + task.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancel(taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.idPrefix + taskID.uuidString])
    }
}
#else
import Foundation

struct StudyReminderService: Sendable {
    static let leadMinutes = 10

    func requestAuthorization() async -> Bool {
        return false
    }

    func refresh(tasks: [FocusTask], now: Date) async {}

    func cancel(taskID: UUID) {}
}
#endif
