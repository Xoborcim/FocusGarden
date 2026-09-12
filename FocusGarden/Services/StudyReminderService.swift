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
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func cancel(taskID: UUID) {
        guard isSupportedEnvironment else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = Self.idPrefix + taskID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAll() {
        guard isSupportedEnvironment else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
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

    func cancelAll() {}
}
#endif
